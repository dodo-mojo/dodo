"""RESP2, the Redis wire protocol, without I/O.

A command goes out as an array of bulk strings. A reply is a status, an
error, an integer, a bulk string, nil, or an array of replies. Mojo can't
nest a struct inside a list of itself, so `RedisReply` keeps a whole reply,
nested arrays included, as a flat list of nodes in one shared tree.
"""

from std.memory import ArcPointer

from ..error import DbError
from ..param import Param


comptime DB = "redis"
comptime MAX_BULK = 512 * 1024 * 1024
"""Redis's own limit on a string value."""
comptime MAX_DEPTH = 32
"""Arrays nested deeper than this are refused, so a hostile server can't
exhaust the stack."""
comptime MAX_LINE = 64 * 1024
"""Longest status, error or length line accepted."""


# ── Commands ────────────────────────────────────────────────────────────────


def encode(mut out: List[UInt8], args: List[Param]) raises DbError:
    """Append one command. Every argument goes as a bulk string, so values
    are binary-safe and never parsed as part of the command."""
    if len(args) == 0:
        raise DbError.usage(DB, "empty command")
    _header(out, ord("*"), len(args))
    for ref arg in args:
        if arg.kind == Param.NULL:
            raise DbError.usage(
                DB, "Redis has no NULL value; delete the key instead"
            )
        if arg.kind == Param.BYTES:
            _header(out, ord("$"), len(arg.data))
            out.extend(Span(arg.data))
        elif arg.kind == Param.BOOL:
            _header(out, ord("$"), 1)
            out.append(
                UInt8(ord("1")) if arg.int_value == 1 else UInt8(ord("0"))
            )
        else:
            var text = arg.as_text()
            _header(out, ord("$"), text.byte_length())
            out.extend(text.as_bytes())
        out.append(13)
        out.append(10)


def _header(mut out: List[UInt8], tag: Int, n: Int):
    out.append(UInt8(tag))
    out.extend(String(n).as_bytes())
    out.append(13)
    out.append(10)


def command_name(args: List[Param]) -> String:
    """The command's first word in upper case, or empty."""
    if len(args) == 0 or args[0].kind != Param.TEXT:
        return String()
    return args[0].text.upper()


def is_refused(name: String) -> Bool:
    """Commands that would leave a pooled connection in a state the next
    user can't see: a subscriber or monitor stream, another protocol
    version, another database or user, or a closed socket."""
    return (
        name == "SUBSCRIBE"
        or name == "PSUBSCRIBE"
        or name == "SSUBSCRIBE"
        or name == "MONITOR"
        or name == "SYNC"
        or name == "PSYNC"
        or name == "HELLO"
        or name == "RESET"
        or name == "SELECT"
        or name == "AUTH"
        or name == "QUIT"
    )


# ── Replies ─────────────────────────────────────────────────────────────────


def parse_length(line: Span[UInt8, _]) raises DbError -> Int:
    """The signed number after a reply's type byte."""
    var n = len(line)
    var i = 1
    var negative = False
    if i < n and Int(line[i]) == ord("-"):
        negative = True
        i += 1
    if i == n or n - i > 19:
        raise DbError.protocol(DB, "bad number in reply")
    var value = 0
    while i < n:
        var digit = Int(line[i]) - ord("0")
        if digit < 0 or digit > 9:
            raise DbError.protocol(DB, "bad number in reply")
        value = value * 10 + digit
        i += 1
    if value < 0:
        raise DbError.protocol(DB, "number in reply is out of range")
    return -value if negative else value


@fieldwise_init
struct _Node(Copyable):
    var kind: Int
    var value: Int
    """The integer for an INT reply, the element count for an ARRAY."""
    var start: Int
    var length: Int
    var end: Int
    """The index of the first node after this one's subtree."""


struct ReplyTree(Movable):
    """Every node of one reply, in depth-first order, and their bytes."""

    var nodes: List[_Node]
    var data: List[UInt8]

    def __init__(out self):
        self.nodes = List[_Node]()
        self.data = List[UInt8]()

    def push(mut self, kind: Int, value: Int, bytes: Span[UInt8, _]) -> Int:
        """Add a node; return its index. Call `close` after its children."""
        var index = len(self.nodes)
        self.nodes.append(
            _Node(kind, value, len(self.data), len(bytes), index + 1)
        )
        self.data.extend(bytes)
        return index

    def close(mut self, index: Int):
        self.nodes[index].end = len(self.nodes)


struct RedisReply(Copyable, Sized, Writable):
    """One reply. Cheap to copy: copies and the elements of an array share
    one tree.

    ```mojo
    var reply = db.command("LRANGE", "jobs", 0, -1)
    for i in range(len(reply)):
        print(reply[i].string())
    ```
    """

    var _tree: ArcPointer[ReplyTree]
    var _at: Int

    comptime STATUS = 1
    comptime ERROR = 2
    comptime INT = 3
    comptime BULK = 4
    comptime NIL = 5
    comptime ARRAY = 6

    def __init__(out self, var tree: ReplyTree):
        self._tree = ArcPointer(tree^)
        self._at = 0

    def __init__(out self, tree: ArcPointer[ReplyTree], at: Int):
        self._tree = tree
        self._at = at

    def _node(self) -> _Node:
        return self._tree[].nodes[self._at].copy()

    def kind(self) -> Int:
        return self._node().kind

    def is_nil(self) -> Bool:
        return self.kind() == Self.NIL

    def is_error(self) -> Bool:
        return self.kind() == Self.ERROR

    def _span(self) -> Span[UInt8, origin_of(self._tree[].data)]:
        var node = self._node()
        return Span(self._tree[].data)[node.start : node.start + node.length]

    def string(self) raises DbError -> String:
        """A status, error, bulk string or integer as text."""
        var node = self._node()
        if node.kind == Self.INT:
            return String(node.value)
        if node.kind == Self.NIL or node.kind == Self.ARRAY:
            raise DbError.decode(
                "reply is " + self.kind_name() + ", not a string"
            )
        return String(from_utf8_lossy=self._span())

    def bytes(self) raises DbError -> List[UInt8]:
        """A bulk string's raw bytes."""
        var node = self._node()
        if (
            node.kind == Self.NIL
            or node.kind == Self.ARRAY
            or node.kind == Self.INT
        ):
            raise DbError.decode("reply is " + self.kind_name() + ", not bytes")
        return List[UInt8](self._span())

    def int(self) raises DbError -> Int:
        """An integer reply, or a bulk string holding one (`GET counter`)."""
        var node = self._node()
        if node.kind == Self.INT:
            return node.value
        if node.kind == Self.BULK or node.kind == Self.STATUS:
            var text = self._span()
            if len(text) > 0:
                var with_tag = List[UInt8](capacity=len(text) + 1)
                with_tag.append(UInt8(ord(":")))
                with_tag.extend(text)
                try:
                    return parse_length(Span(with_tag))
                except:
                    pass
        raise DbError.decode(
            "reply is " + self.kind_name() + ", not an integer"
        )

    def __len__(self) -> Int:
        """Elements in an array reply; 0 for anything else."""
        var node = self._node()
        if node.kind == Self.ARRAY:
            return node.value
        return 0

    def __getitem__(self, index: Int) raises DbError -> RedisReply:
        var count = len(self)
        if index < 0 or index >= count:
            raise DbError.usage(
                DB, String("reply index ", index, " out of range (", count, ")")
            )
        var at = self._at + 1
        for _ in range(index):
            at = self._tree[].nodes[at].end
        return RedisReply(self._tree, at)

    def items(self) -> List[RedisReply]:
        """An array's elements in order; empty for anything else."""
        var out = List[RedisReply](capacity=len(self))
        var at = self._at + 1
        for _ in range(len(self)):
            out.append(RedisReply(self._tree, at))
            at = self._tree[].nodes[at].end
        return out^

    def strings(self) raises DbError -> List[String]:
        """An array of strings (`LRANGE`, `SMEMBERS`, `KEYS`)."""
        var out = List[String](capacity=len(self))
        for item in self.items():
            out.append(item.string())
        return out^

    def error_code(self) -> String:
        """An error's first word: `ERR`, `WRONGTYPE`, `NOAUTH`."""
        if not self.is_error():
            return String()
        var span = self._span()
        var end = 0
        while end < len(span) and Int(span[end]) != ord(" "):
            end += 1
        return String(from_utf8_lossy=span[0:end])

    def kind_name(self) -> String:
        var kind = self.kind()
        if kind == Self.STATUS:
            return "status"
        if kind == Self.ERROR:
            return "error"
        if kind == Self.INT:
            return "integer"
        if kind == Self.BULK:
            return "bulk string"
        if kind == Self.NIL:
            return "nil"
        return "array"

    def write_to[W: Writer](self, mut writer: W):
        var kind = self.kind()
        if kind == Self.NIL:
            writer.write("(nil)")
        elif kind == Self.INT:
            writer.write("(integer) ", self._node().value)
        elif kind == Self.ARRAY:
            writer.write("[")
            var first = True
            for item in self.items():
                if not first:
                    writer.write(", ")
                first = False
                writer.write(item)
            writer.write("]")
        elif kind == Self.ERROR:
            writer.write("(error) ", String(from_utf8_lossy=self._span()))
        else:
            writer.write(String(from_utf8_lossy=self._span()))


def reply_error(reply: RedisReply) -> DbError:
    """The `DbError` for an error reply. Credential errors are `AUTH`."""
    var code = reply.error_code()
    var message = String()
    try:
        message = reply.string()
    except:
        pass
    if code == "NOAUTH" or code == "WRONGPASS":
        return DbError.auth(DB, message, code)
    return DbError.server(DB, code, message)

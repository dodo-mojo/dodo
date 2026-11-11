"""`dodo mcp`: the MCP server over stdio, one JSON message per line.

Before reading anything, dodo moves the protocol's stdin and stdout to
descriptors of its own that no child process inherits. Descriptor 0
becomes `/dev/null` and descriptor 1 becomes stderr, so neither a tool's
child process nor a stray `print` can read from or write into the
message stream. It answers one message at a time and exits when stdin
closes.
"""

from std.ffi import c_int, c_size_t, external_call, get_errno
from std.os.path import realpath
from std.sys import argv

from dodo.utils.process import set_inherited

from .app_output import write_fd
from .args import ParsedArgs
from .mcp import McpServer
from .report import EXIT_OK, EXIT_UNAVAILABLE, Report

comptime MAX_LINE_BYTES = 16 * 1024 * 1024
"""A longer message is answered with a parse error and skipped."""
comptime _READ_BYTES = 65536
comptime _EINTR = 4


def cmd_mcp(parsed: ParsedArgs, mut report: Report) raises -> Int:
    var input: Int
    var output: Int
    try:
        input = _private_copy(0)
        output = _private_copy(1)
        _point_at_null(0)
        _ = external_call["dup2", c_int](c_int(2), c_int(1))
    except e:
        return report.fail(
            "io", String("cannot set up stdio: ", e), EXIT_UNAVAILABLE
        )

    var server = McpServer(own_path())
    var reader = LineReader(input)
    while True:
        var line = reader.next_line()
        if not line:
            break
        if String(line.value().strip()) == "":
            continue
        var answer = server.handle(line.value())
        if answer != "":
            write_fd(output, String(answer, "\n").as_bytes())
    return EXIT_OK


def own_path() -> String:
    """This `dodo` program: `argv[0]`, made absolute when it is a path."""
    var name = String(argv()[0])
    if "/" not in name:
        return name
    try:
        return realpath(name)
    except:
        return name


struct LineReader(Movable):
    """Reads `\\n`-ended lines from a file descriptor."""

    var fd: Int
    var pending: List[UInt8]
    var skipping: Bool
    """Inside a line that was too long, dropping it."""
    var done: Bool

    def __init__(out self, fd: Int):
        self.fd = fd
        self.pending = List[UInt8]()
        self.skipping = False
        self.done = False

    def next_line(mut self) -> Optional[String]:
        """The next line without its newline (or `\\r\\n`), or None at the
        end. A line longer than `MAX_LINE_BYTES` comes back as text that
        is not JSON, so it is answered with a parse error."""
        while True:
            var newline = _find_newline(self.pending)
            if newline >= 0:
                var line = _take_line(self.pending, newline)
                if self.skipping:
                    self.skipping = False
                    return String("(a message longer than the limit)")
                return line^
            if self.done:
                if len(self.pending) == 0 or self.skipping:
                    return None
                var rest = _decode(Span(self.pending))
                self.pending.clear()
                return rest^
            if len(self.pending) > MAX_LINE_BYTES:
                self.pending.clear()
                self.skipping = True
            self._read_more()

    def _read_more(mut self):
        var chunk = List[UInt8](length=_READ_BYTES, fill=0)
        while True:
            var got = external_call["read", Int](
                c_int(self.fd), chunk.unsafe_ptr(), c_size_t(_READ_BYTES)
            )
            if got > 0:
                self.pending.extend(Span(chunk)[:got])
                return
            if got < 0 and _errno() == _EINTR:
                continue
            self.done = True
            return


def _find_newline(data: List[UInt8]) -> Int:
    for i in range(len(data)):
        if data[i] == UInt8(ord("\n")):
            return i
    return -1


def _take_line(mut data: List[UInt8], newline: Int) -> String:
    """Remove the line that ends at `newline` from `data` and return it."""
    var end = newline
    if end > 0 and data[end - 1] == UInt8(ord("\r")):
        end -= 1
    var line = _decode(Span(data)[:end])
    var rest = List[UInt8](Span(data)[newline + 1 :])
    data = rest^
    return line^


def _decode(data: Span[UInt8, _]) -> String:
    return String(from_utf8_lossy=data)


def _private_copy(fd: Int) raises -> Int:
    """A copy of `fd` that child processes do not inherit.

    Raises:
        Error: If `fd` cannot be copied.
    """
    var copy = Int(external_call["dup", c_int](c_int(fd)))
    if copy < 0:
        raise Error("dup(", fd, ") failed")
    set_inherited(copy, False)
    return copy


def _point_at_null(fd: Int) raises:
    """Make `fd` read from and write to `/dev/null`.

    Raises:
        Error: If `/dev/null` cannot be opened.
    """
    with open("/dev/null", "r") as null:
        var rc = external_call["dup2", c_int](c_int(null.handle), c_int(fd))
        if rc < 0:
            raise Error("cannot point descriptor ", fd, " at /dev/null")


def _errno() -> Int:
    return Int(get_errno().value)

"""MongoDB OP_MSG spike against Docker (MongoDB 8).

Proves: OP_MSG framing, a small BSON writer and reader, `hello`,
SCRAM-SHA-256 through saslStart / saslContinue, insert, find with a filter,
update, delete, count, and a server error.
"""

from dodo.crypto.base64 import base64_encode, base64_decode
from dodo.crypto.digest import hmac_sha256_of, pbkdf2_hmac_sha256, sha256
from dodo.crypto.random import random_bytes
from dodo.tcp import TcpStream


# ── BSON writer ─────────────────────────────────────────────────────────────


struct Doc(Copyable, Movable):
    """A BSON document under construction."""

    var body: List[UInt8]

    def __init__(out self):
        self.body = List[UInt8]()

    def _head(mut self, kind: UInt8, key: String):
        self.body.append(kind)
        self.body.extend(key.as_bytes())
        self.body.append(0)

    def int32(mut self, key: String, v: Int):
        self._head(0x10, key)
        put_le(self.body, v, 4)

    def int64(mut self, key: String, v: Int):
        self._head(0x12, key)
        put_le(self.body, v, 8)

    def double(mut self, key: String, v: Float64):
        self._head(0x01, key)
        put_le(self.body, Int(v.to_bits()), 8)

    def string(mut self, key: String, v: String):
        self._head(0x02, key)
        put_le(self.body, v.byte_length() + 1, 4)
        self.body.extend(v.as_bytes())
        self.body.append(0)

    def boolean(mut self, key: String, v: Bool):
        self._head(0x08, key)
        self.body.append(UInt8(1) if v else UInt8(0))

    def null(mut self, key: String):
        self._head(0x0A, key)

    def binary(mut self, key: String, v: Span[UInt8, _]):
        self._head(0x05, key)
        put_le(self.body, len(v), 4)
        self.body.append(0)
        self.body.extend(v)

    def doc(mut self, key: String, v: Doc):
        self._head(0x03, key)
        self.body.extend(Span(v.bytes()))

    def array(mut self, key: String, items: List[Doc]):
        var arr = Doc()
        for i in range(len(items)):
            arr.doc(String(i), items[i])
        self._head(0x04, key)
        self.body.extend(Span(arr.bytes()))

    def bytes(self) -> List[UInt8]:
        var out = List[UInt8]()
        put_le(out, len(self.body) + 5, 4)
        out.extend(Span(self.body))
        out.append(0)
        return out^


def put_le(mut out: List[UInt8], v: Int, n: Int):
    for i in range(n):
        out.append(UInt8((v >> (8 * i)) & 255))


def le(b: Span[UInt8, _], at: Int, n: Int) -> Int:
    var v = 0
    for i in range(n):
        v |= Int(b[at + i]) << (8 * i)
    return v


# ── BSON reader (to text, and field lookup) ─────────────────────────────────


def cstr_end(b: Span[UInt8, _], at: Int) -> Int:
    var end = at
    while b[end] != 0:
        end += 1
    return end


def value_size(b: Span[UInt8, _], kind: Int, at: Int) raises -> Int:
    if kind == 0x01 or kind == 0x09 or kind == 0x11 or kind == 0x12:
        return 8
    if kind == 0x10:
        return 4
    if kind == 0x08:
        return 1
    if kind == 0x0A:
        return 0
    if kind == 0x07:
        return 12
    if kind == 0x13:
        return 16
    if kind == 0x02:
        return 4 + le(b, at, 4)
    if kind == 0x03 or kind == 0x04:
        return le(b, at, 4)
    if kind == 0x05:
        return 5 + le(b, at, 4)
    raise Error("unsupported BSON type " + String(kind))


def hex(b: Span[UInt8, _]) -> String:
    var digits = "0123456789abcdef"
    var out = String()
    for x in b:
        out += digits[byte = Int(x >> 4)]
        out += digits[byte = Int(x & 15)]
    return out


def to_text(b: Span[UInt8, _], is_array: Bool = False) raises -> String:
    var out = String("[" if is_array else "{")
    var at = 4
    var first = True
    while b[at] != 0:
        var kind = Int(b[at])
        var key_end = cstr_end(b, at + 1)
        var key = String(unsafe_from_utf8=b[at + 1 : key_end])
        var v = key_end + 1
        if not first:
            out += ", "
        first = False
        if not is_array:
            out += key + ": "
        if kind == 0x01:
            out += String(Float64(from_bits=UInt64(le(b, v, 8))))
        elif kind == 0x02:
            var n = le(b, v, 4)
            out += '"' + String(unsafe_from_utf8=b[v + 4 : v + 3 + n]) + '"'
        elif kind == 0x03:
            out += to_text(b[v:])
        elif kind == 0x04:
            out += to_text(b[v:], True)
        elif kind == 0x05:
            out += "<binary " + String(le(b, v, 4)) + ">"
        elif kind == 0x07:
            out += "ObjectId(" + hex(b[v : v + 12]) + ")"
        elif kind == 0x08:
            out += "true" if b[v] == 1 else "false"
        elif kind == 0x09:
            out += "Date(" + String(le(b, v, 8)) + ")"
        elif kind == 0x0A:
            out += "null"
        elif kind == 0x10:
            out += String(Int32(le(b, v, 4)))
        elif kind == 0x12:
            out += String(le(b, v, 8))
        else:
            out += "<type " + String(kind) + ">"
        at = v + value_size(b, kind, v)
    return out + ("]" if is_array else "}")


def find_field(b: Span[UInt8, _], name: String) raises -> Tuple[Int, Int]:
    """(kind, offset of value) for a top-level field, or (-1, 0)."""
    var at = 4
    while b[at] != 0:
        var kind = Int(b[at])
        var key_end = cstr_end(b, at + 1)
        var v = key_end + 1
        if String(unsafe_from_utf8=b[at + 1 : key_end]) == name:
            return (kind, v)
        at = v + value_size(b, kind, v)
    return (-1, 0)


# ── OP_MSG ─────────────────────────────────────────────────────────────────


struct Conn(Movable):
    var tcp: TcpStream
    var next_id: Int

    def __init__(out self, var tcp: TcpStream):
        self.tcp = tcp^
        self.next_id = 1

    def read_exact(mut self, n: Int) raises -> List[UInt8]:
        var out = List[UInt8](length=n, fill=0)
        self.tcp.read_exact(out.unsafe_ptr(), n)
        return out^

    def command(mut self, cmd: Doc) raises -> List[UInt8]:
        var doc = cmd.bytes()
        var msg = List[UInt8]()
        put_le(msg, 16 + 4 + 1 + len(doc), 4)
        put_le(msg, self.next_id, 4)
        put_le(msg, 0, 4)
        put_le(msg, 2013, 4)
        put_le(msg, 0, 4)
        msg.append(0)
        msg.extend(Span(doc))
        self.next_id += 1
        self.tcp.write_all(Span(msg))

        var header = self.read_exact(16)
        var length = le(header, 0, 4)
        var op = le(header, 12, 4)
        if op != 2013:
            raise Error("unexpected opcode " + String(op))
        var rest = self.read_exact(length - 16)
        if rest[4] != 0:
            raise Error("expected a body section")
        return List[UInt8](rest[5:])


def check_ok(reply: List[UInt8]) raises:
    var ok = find_field(reply, "ok")
    if ok[0] == 0x01 and Float64(from_bits=UInt64(le(reply, ok[1], 8))) == 1.0:
        return
    raise Error("server error: " + to_text(reply))


def binary_payload(reply: List[UInt8], name: String) raises -> String:
    var f = find_field(reply, name)
    var n = le(reply, f[1], 4)
    return String(unsafe_from_utf8=reply[f[1] + 5 : f[1] + 5 + n])


def auth(mut c: Conn, user: String, password: String) raises:
    var nonce = base64_encode(random_bytes(24))
    var first_bare = "n=" + user + ",r=" + nonce
    var gs2 = "n,," + first_bare
    var start = Doc()
    start.int32("saslStart", 1)
    start.string("mechanism", "SCRAM-SHA-256")
    start.binary("payload", gs2.as_bytes())
    var opts = Doc()
    opts.boolean("skipEmptyExchange", True)
    start.doc("options", opts)
    start.string("$db", "admin")
    var r1 = c.command(start)
    check_ok(r1)
    var server_first = binary_payload(r1, "payload")
    var conv = find_field(r1, "conversationId")
    var conv_id = le(r1, conv[1], 4)

    var server_nonce = String()
    var salt = List[UInt8]()
    var iterations = 0
    for part in server_first.split(","):
        var p = String(part)
        if p.startswith("r="):
            server_nonce = String(p[byte=2:])
        elif p.startswith("s="):
            salt = base64_decode(String(p[byte=2:]))
        elif p.startswith("i="):
            iterations = Int(String(p[byte=2:]))
    var salted = pbkdf2_hmac_sha256(password.as_bytes(), salt, iterations)
    var client_key = hmac_sha256_of(salted, "Client Key".as_bytes())
    var without_proof = "c=biws,r=" + server_nonce
    var auth_message = first_bare + "," + server_first + "," + without_proof
    var signature = hmac_sha256_of(sha256(client_key), auth_message.as_bytes())
    var proof = List[UInt8]()
    for i in range(len(client_key)):
        proof.append(client_key[i] ^ signature[i])
    var final = without_proof + ",p=" + base64_encode(proof)

    var cont = Doc()
    cont.int32("saslContinue", 1)
    cont.int32("conversationId", conv_id)
    cont.binary("payload", final.as_bytes())
    cont.string("$db", "admin")
    var r2 = c.command(cont)
    check_ok(r2)
    var server_key = hmac_sha256_of(salted, "Server Key".as_bytes())
    var want = "v=" + base64_encode(hmac_sha256_of(server_key, auth_message.as_bytes()))
    if binary_payload(r2, "payload") != want:
        raise Error("server signature mismatch")
    var done = find_field(r2, "done")
    print("  SCRAM ok, server verified, done =", r2[done[1]] == 1)


def user_doc(id: Int, name: String, score: Float64, active: Bool) -> Doc:
    var d = Doc()
    d.int64("_id", id)
    d.string("name", name)
    d.double("score", score)
    d.boolean("active", active)
    d.null("note")
    return d^


def main() raises:
    var c = Conn(TcpStream.connect("127.0.0.1", 47017))
    var hello = Doc()
    hello.int32("hello", 1)
    hello.string("$db", "admin")
    var h = c.command(hello)
    var wire = find_field(h, "maxWireVersion")
    print("hello: maxWireVersion", le(h, wire[1], 4))

    var unauth = Doc()
    unauth.string("find", "users")
    unauth.string("$db", "dodo")
    try:
        check_ok(c.command(unauth))
    except e:
        print("before auth:", e)

    auth(c, "dodo", "dodo-test")

    var drop = Doc()
    drop.string("drop", "users")
    drop.string("$db", "dodo")
    _ = c.command(drop)

    var insert = Doc()
    insert.string("insert", "users")
    var docs = List[Doc]()
    docs.append(user_doc(1, "ada", 9.5, True))
    docs.append(user_doc(2, "bob {$ne: 1} 🦤", -1.25, False))
    insert.array("documents", docs)
    insert.string("$db", "dodo")
    var ins = c.command(insert)
    check_ok(ins)
    print("insert:", to_text(ins))

    var dup = Doc()
    dup.string("insert", "users")
    var again = List[Doc]()
    again.append(user_doc(1, "dup", 0.0, False))
    dup.array("documents", again)
    dup.string("$db", "dodo")
    print("duplicate key:", to_text(c.command(dup)))

    var find = Doc()
    find.string("find", "users")
    var filter = Doc()
    var gt = Doc()
    gt.double("$gt", 0.0)
    filter.doc("score", gt)
    find.doc("filter", filter)
    find.string("$db", "dodo")
    var found = c.command(find)
    check_ok(found)
    print("find score > 0:", to_text(found))

    var update = Doc()
    update.string("update", "users")
    var u = Doc()
    var q = Doc()
    q.int64("_id", 2)
    var setter = Doc()
    var fields = Doc()
    fields.boolean("active", True)
    setter.doc("$set", fields)
    u.doc("q", q)
    u.doc("u", setter)
    var updates = List[Doc]()
    updates.append(u^)
    update.array("updates", updates)
    update.string("$db", "dodo")
    print("update:", to_text(c.command(update)))

    var count = Doc()
    count.string("count", "users")
    count.string("$db", "dodo")
    print("count:", to_text(c.command(count)))

    print("wrong password:")
    try:
        var c2 = Conn(TcpStream.connect("127.0.0.1", 47017))
        auth(c2, "dodo", "nope")
    except e:
        print(" ", e)

"""PostgreSQL wire protocol v3 spike against Docker.

Proves: startup, SCRAM-SHA-256 (postgres) and trust (CockroachDB insecure),
the extended query protocol with text parameters, row decoding, errors and
recovery to ReadyForQuery.

    docker compose -f tests/live/db/compose.yaml up -d --wait
    pixi run mojo run -I . research/db-spikes/pg_spike.mojo
"""

from std.memory import Pointer

from dodo.crypto.base64 import base64_encode, base64_decode
from dodo.crypto.digest import hmac_sha256_of, pbkdf2_hmac_sha256, sha256
from dodo.crypto.random import random_bytes
from dodo.tcp import TcpStream


struct Conn(Movable):
    var tcp: TcpStream
    var buf: List[UInt8]
    var pos: Int

    def __init__(out self, var tcp: TcpStream):
        self.tcp = tcp^
        self.buf = List[UInt8]()
        self.pos = 0

    def fill(mut self, need: Int) raises:
        """Make `need` unread bytes available."""
        while len(self.buf) - self.pos < need:
            if self.pos > 0:
                var rest = List[UInt8](self.buf[self.pos :])
                self.buf = rest^
                self.pos = 0
            var chunk = List[UInt8](length=16384, fill=0)
            var n = self.tcp.read(chunk.unsafe_ptr(), 16384)
            if n == 0:
                raise Error("server closed the connection")
            for i in range(n):
                self.buf.append(chunk[i])

    def read_msg(mut self) raises -> Tuple[Int, List[UInt8]]:
        self.fill(5)
        var tag = Int(self.buf[self.pos])
        var length = be32(self.buf, self.pos + 1)
        self.fill(1 + length)
        var body = List[UInt8](self.buf[self.pos + 5 : self.pos + 1 + length])
        self.pos += 1 + length
        return (tag, body^)

    def send(mut self, data: List[UInt8]) raises:
        self.tcp.write_all(Span(data))


def be32(b: List[UInt8], at: Int) -> Int:
    return (
        (Int(b[at]) << 24)
        | (Int(b[at + 1]) << 16)
        | (Int(b[at + 2]) << 8)
        | Int(b[at + 3])
    )


def be16(b: List[UInt8], at: Int) -> Int:
    return (Int(b[at]) << 8) | Int(b[at + 1])


def put32(mut out: List[UInt8], v: Int):
    out.append(UInt8((v >> 24) & 255))
    out.append(UInt8((v >> 16) & 255))
    out.append(UInt8((v >> 8) & 255))
    out.append(UInt8(v & 255))


def put16(mut out: List[UInt8], v: Int):
    out.append(UInt8((v >> 8) & 255))
    out.append(UInt8(v & 255))


def put_cstr(mut out: List[UInt8], s: String):
    for b in s.as_bytes():
        out.append(b)
    out.append(0)


def message(tag: String, body: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8]()
    out.append(tag.as_bytes()[0])
    put32(out, len(body) + 4)
    out.extend(Span(body))
    return out^


def as_text(b: Span[UInt8, _]) -> String:
    return String(unsafe_from_utf8=b)


def error_text(body: List[UInt8]) -> String:
    var out = String()
    var i = 0
    while i < len(body) and body[i] != 0:
        var code = Int(body[i])
        var start = i + 1
        var end = start
        while body[end] != 0:
            end += 1
        if code == ord("M") or code == ord("C"):
            out += as_text(body[start:end]) + " "
        i = end + 1
    return out


def startup(mut c: Conn, user: String, database: String, password: String) raises:
    var body = List[UInt8]()
    put32(body, 196608)
    put_cstr(body, "user")
    put_cstr(body, user)
    put_cstr(body, "database")
    put_cstr(body, database)
    put_cstr(body, "client_encoding")
    put_cstr(body, "UTF8")
    body.append(0)
    var msg = List[UInt8]()
    put32(msg, len(body) + 4)
    msg.extend(Span(body))
    c.send(msg)

    var client_first_bare = String()
    var nonce = String()
    var salted = List[UInt8]()
    var auth_message = String()
    while True:
        var m = c.read_msg()
        var tag = m[0]
        ref body2 = m[1]
        if tag == ord("E"):
            raise Error("startup: " + error_text(body2))
        if tag == ord("R"):
            var kind = be32(body2, 0)
            if kind == 0:
                print("  auth ok")
            elif kind == 10:
                nonce = base64_encode(random_bytes(18))
                client_first_bare = "n=,r=" + nonce
                var first = "n,," + client_first_bare
                var out = List[UInt8]()
                put_cstr(out, "SCRAM-SHA-256")
                put32(out, first.byte_length())
                out.extend(first.as_bytes())
                c.send(message("p", out))
            elif kind == 11:
                var server_first = as_text(body2[4:])
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
                if not server_nonce.startswith(nonce):
                    raise Error("server nonce does not extend ours")
                salted = pbkdf2_hmac_sha256(password.as_bytes(), salt, iterations)
                var client_key = hmac_sha256_of(salted, "Client Key".as_bytes())
                var stored_key = sha256(client_key)
                var without_proof = "c=biws,r=" + server_nonce
                auth_message = (
                    client_first_bare + "," + server_first + "," + without_proof
                )
                var signature = hmac_sha256_of(stored_key, auth_message.as_bytes())
                var proof = List[UInt8]()
                for i in range(len(client_key)):
                    proof.append(client_key[i] ^ signature[i])
                var final = without_proof + ",p=" + base64_encode(proof)
                var out = List[UInt8]()
                out.extend(final.as_bytes())
                c.send(message("p", out))
            elif kind == 12:
                var server_final = as_text(body2[4:])
                var server_key = hmac_sha256_of(salted, "Server Key".as_bytes())
                var want = "v=" + base64_encode(
                    hmac_sha256_of(server_key, auth_message.as_bytes())
                )
                if server_final != want:
                    raise Error("server signature mismatch")
                print("  SCRAM server signature verified")
            else:
                raise Error("unsupported auth kind " + String(kind))
        elif tag == ord("Z"):
            return


def query(mut c: Conn, sql: String, params: List[String]) raises:
    """Parse/Bind/Describe/Execute/Sync with text params; print rows."""
    var parse = List[UInt8]()
    put_cstr(parse, "")
    put_cstr(parse, sql)
    put16(parse, 0)
    var bind = List[UInt8]()
    put_cstr(bind, "")
    put_cstr(bind, "")
    put16(bind, 0)
    put16(bind, len(params))
    for p in params:
        if p == "NULL":
            put32(bind, -1)
        else:
            put32(bind, p.byte_length())
            bind.extend(p.as_bytes())
    put16(bind, 0)
    var describe = List[UInt8]()
    describe.append(UInt8(ord("P")))
    put_cstr(describe, "")
    var execute = List[UInt8]()
    put_cstr(execute, "")
    put32(execute, 0)
    var out = message("P", parse)
    out.extend(Span(message("B", bind)))
    out.extend(Span(message("D", describe)))
    out.extend(Span(message("E", execute)))
    out.extend(Span(message("S", List[UInt8]())))
    c.send(out)

    var names = List[String]()
    while True:
        var m = c.read_msg()
        var tag = m[0]
        ref body = m[1]
        if tag == ord("T"):
            var n = be16(body, 0)
            var at = 2
            var line = String("  columns:")
            for _ in range(n):
                var end = at
                while body[end] != 0:
                    end += 1
                var name = as_text(body[at:end])
                var oid = be32(body, end + 7)
                line += " " + name + "(oid " + String(oid) + ")"
                names.append(name)
                at = end + 19
            print(line)
        elif tag == ord("D"):
            var n = be16(body, 0)
            var at = 2
            var line = String("  row:")
            for _ in range(n):
                var length = be32(body, at)
                at += 4
                if length == 0xFFFFFFFF:
                    line += " NULL"
                else:
                    line += " " + as_text(body[at : at + length])
                    at += length
            print(line)
        elif tag == ord("C"):
            print("  done:", as_text(body[: len(body) - 1]))
        elif tag == ord("E"):
            print("  error:", error_text(body))
        elif tag == ord("Z"):
            return


def run(label: String, port: UInt16, user: String, db: String, password: String) raises:
    print(label)
    var c = Conn(TcpStream.connect("127.0.0.1", port))
    startup(c, user, db, password)
    query(c, "select version()", List[String]())
    query(c, "drop table if exists spike_users", List[String]())
    query(
        c,
        "create table spike_users (id int primary key, name text, score float8, active bool, note text)",
        List[String](),
    )
    query(
        c,
        "insert into spike_users values ($1, $2, $3, $4, $5), ($6, $7, $8, $9, $10)",
        ["1", "ada", "9.5", "true", "NULL", "2", "bob 'quote'; drop table x;--", "-1.25", "false", "héllo 🦤"],
    )
    query(c, "select * from spike_users where id >= $1 order by id", ["1"])
    query(c, "select * from no_such_table", List[String]())
    query(c, "select 1 + $1::int as two", ["1"])


def main() raises:
    run("postgres", 45432, "dodo", "dodo", "dodo-test")
    run("cockroach", 46257, "root", "defaultdb", "")
    print("wrong password:")
    try:
        var c = Conn(TcpStream.connect("127.0.0.1", 45432))
        startup(c, "dodo", "dodo", "nope")
    except e:
        print(" ", e)

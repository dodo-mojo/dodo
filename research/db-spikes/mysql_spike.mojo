"""MySQL client/server protocol spike against Docker (MySQL 8.4 and MariaDB 11).

Proves: the v10 handshake, caching_sha2_password (fast path and full auth
over RSA), mysql_native_password, auth switch, COM_QUERY text result sets,
COM_STMT_PREPARE / EXECUTE with binary rows and NULL params, and errors.
"""

from dodo.crypto.digest import sha1, sha256
from dodo.crypto.rsa import rsa_oaep_encrypt
from dodo.tcp import TcpStream

comptime LONG_PASSWORD = 1
comptime CONNECT_WITH_DB = 8
comptime PROTOCOL_41 = 0x200
comptime TRANSACTIONS = 0x2000
comptime SECURE_CONNECTION = 0x8000
comptime MULTI_RESULTS = 0x20000
comptime PLUGIN_AUTH = 0x80000
comptime PLUGIN_AUTH_LENENC = 0x200000
comptime DEPRECATE_EOF = 0x1000000


struct Conn(Movable):
    var tcp: TcpStream
    var buf: List[UInt8]
    var pos: Int
    var seq: Int
    var caps: Int

    def __init__(out self, var tcp: TcpStream):
        self.tcp = tcp^
        self.buf = List[UInt8]()
        self.pos = 0
        self.seq = 0
        self.caps = 0

    def fill(mut self, need: Int) raises:
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

    def read_packet(mut self) raises -> List[UInt8]:
        self.fill(4)
        var length = (
            Int(self.buf[self.pos])
            | (Int(self.buf[self.pos + 1]) << 8)
            | (Int(self.buf[self.pos + 2]) << 16)
        )
        self.seq = (Int(self.buf[self.pos + 3]) + 1) & 255
        self.fill(4 + length)
        var body = List[UInt8](self.buf[self.pos + 4 : self.pos + 4 + length])
        self.pos += 4 + length
        return body^

    def write_packet(mut self, body: List[UInt8]) raises:
        var out = List[UInt8]()
        out.append(UInt8(len(body) & 255))
        out.append(UInt8((len(body) >> 8) & 255))
        out.append(UInt8((len(body) >> 16) & 255))
        out.append(UInt8(self.seq))
        out.extend(Span(body))
        self.seq = (self.seq + 1) & 255
        self.tcp.write_all(Span(out))

    def command(mut self, body: List[UInt8]) raises:
        self.seq = 0
        self.write_packet(body)


struct Reader:
    var data: List[UInt8]
    var at: Int

    def __init__(out self, var data: List[UInt8]):
        self.data = data^
        self.at = 0

    def u8(mut self) -> Int:
        var v = Int(self.data[self.at])
        self.at += 1
        return v

    def le(mut self, n: Int) -> Int:
        var v = 0
        for i in range(n):
            v |= Int(self.data[self.at + i]) << (8 * i)
        self.at += n
        return v

    def lenenc(mut self) -> Int:
        var first = self.u8()
        if first < 0xFB:
            return first
        if first == 0xFC:
            return self.le(2)
        if first == 0xFD:
            return self.le(3)
        return self.le(8)

    def bytes(mut self, n: Int) -> List[UInt8]:
        var out = List[UInt8](self.data[self.at : self.at + n])
        self.at += n
        return out^

    def lenenc_str(mut self) -> String:
        var n = self.lenenc()
        return String(unsafe_from_utf8=self.bytes(n))

    def cstr(mut self) -> String:
        var end = self.at
        while self.data[end] != 0:
            end += 1
        var s = String(unsafe_from_utf8=self.data[self.at : end])
        self.at = end + 1
        return s


def put_le(mut out: List[UInt8], v: Int, n: Int):
    for i in range(n):
        out.append(UInt8((v >> (8 * i)) & 255))


def put_lenenc(mut out: List[UInt8], v: Int):
    if v < 0xFB:
        out.append(UInt8(v))
    elif v < 0x10000:
        out.append(0xFC)
        put_le(out, v, 2)
    elif v < 0x1000000:
        out.append(0xFD)
        put_le(out, v, 3)
    else:
        out.append(0xFE)
        put_le(out, v, 8)


def put_cstr(mut out: List[UInt8], s: String):
    out.extend(s.as_bytes())
    out.append(0)


def xor(a: List[UInt8], b: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8]()
    for i in range(len(a)):
        out.append(a[i] ^ b[i % len(b)])
    return out^


def scramble(plugin: String, password: String, nonce: List[UInt8]) raises -> List[UInt8]:
    if password == "":
        return List[UInt8]()
    if plugin == "caching_sha2_password":
        var p1 = sha256(password.as_bytes())
        var p2 = sha256(p1)
        var mix = List[UInt8](p2)
        mix.extend(Span(nonce))
        return xor(p1, sha256(mix))
    if plugin == "mysql_native_password":
        var p1 = sha1(password.as_bytes())
        var p2 = sha1(p1)
        var mix = List[UInt8](nonce)
        mix.extend(Span(p2))
        return xor(p1, sha1(mix))
    raise Error("unsupported auth plugin " + plugin)


def err_text(body: List[UInt8]) -> String:
    var r = Reader(List[UInt8](body))
    _ = r.u8()
    var code = r.le(2)
    var state = String()
    if Int(r.data[r.at]) == ord("#"):
        _ = r.u8()
        state = String(unsafe_from_utf8=r.bytes(5))
    return "ERR " + String(code) + " " + state + " " + String(unsafe_from_utf8=r.data[r.at :])


def connect(port: UInt16, user: String, password: String, db: String) raises -> Conn:
    var c = Conn(TcpStream.connect("127.0.0.1", port))
    var r = Reader(c.read_packet())
    _ = r.u8()
    var version = r.cstr()
    _ = r.le(4)
    var nonce = r.bytes(8)
    _ = r.u8()
    var server_caps = r.le(2)
    _ = r.u8()
    _ = r.le(2)
    server_caps |= r.le(2) << 16
    var auth_len = r.u8()
    r.at += 10
    var part2 = max(13, auth_len - 8)
    var rest = r.bytes(part2)
    for i in range(12):
        nonce.append(rest[i])
    var plugin = r.cstr()
    print("  server", version, "plugin", plugin)

    var want = (
        LONG_PASSWORD | CONNECT_WITH_DB | PROTOCOL_41 | TRANSACTIONS
        | SECURE_CONNECTION | MULTI_RESULTS | PLUGIN_AUTH | PLUGIN_AUTH_LENENC
        | DEPRECATE_EOF
    )
    c.caps = want & server_caps
    print("  deprecate_eof:", (c.caps & DEPRECATE_EOF) != 0)
    var resp = List[UInt8]()
    put_le(resp, c.caps, 4)
    put_le(resp, 1 << 24, 4)
    resp.append(255)  # utf8mb4_0900_ai_ci; MariaDB maps it
    for _ in range(23):
        resp.append(0)
    put_cstr(resp, user)
    var auth = scramble(plugin, password, nonce)
    put_lenenc(resp, len(auth))
    resp.extend(Span(auth))
    put_cstr(resp, db)
    put_cstr(resp, plugin)
    c.write_packet(resp)

    while True:
        var p = c.read_packet()
        var head = Int(p[0])
        if head == 0x00:
            print("  auth ok")
            return c^
        if head == 0xFF:
            raise Error(err_text(p))
        if head == 0xFE:
            var sw = Reader(List[UInt8](p))
            _ = sw.u8()
            plugin = sw.cstr()
            nonce = List[UInt8](sw.data[sw.at : sw.at + 20])
            print("  auth switch to", plugin)
            c.write_packet(scramble(plugin, password, nonce))
        elif head == 0x01:
            if len(p) == 2 and p[1] == 3:
                print("  caching_sha2 fast auth")
            elif len(p) == 2 and p[1] == 4:
                print("  caching_sha2 full auth: asking for the public key")
                c.write_packet([UInt8(2)])
            else:
                var pem = List[UInt8](p[1:])
                var plain = List[UInt8](password.as_bytes())
                plain.append(0)
                var encrypted = rsa_oaep_encrypt(pem, xor(plain, nonce))
                print("  sending RSA-encrypted password,", len(encrypted), "bytes")
                c.write_packet(encrypted)
        else:
            raise Error("unexpected auth packet " + String(head))


def column_defs(mut c: Conn, n: Int) raises -> List[Tuple[String, Int]]:
    var cols = List[Tuple[String, Int]]()
    for _ in range(n):
        var r = Reader(c.read_packet())
        for _ in range(4):
            _ = r.lenenc_str()
        var name = r.lenenc_str()
        _ = r.lenenc_str()
        _ = r.lenenc()
        _ = r.le(2)
        _ = r.le(4)
        var type_code = r.u8()
        cols.append((name, type_code))
    if (c.caps & DEPRECATE_EOF) == 0:
        _ = c.read_packet()
    return cols^


def query(mut c: Conn, sql: String) raises:
    var body = List[UInt8]()
    body.append(0x03)
    body.extend(sql.as_bytes())
    c.command(body)
    var first = c.read_packet()
    if first[0] == 0xFF:
        print("  ", err_text(first))
        return
    if first[0] == 0x00:
        var r = Reader(first^)
        _ = r.u8()
        print("  ok, affected", r.lenenc(), "last id", r.lenenc())
        return
    var head = Reader(first^)
    var n = head.lenenc()
    var cols = column_defs(c, n)
    while True:
        var p = c.read_packet()
        if p[0] == 0xFE and len(p) < 0xFFFFFF:
            return
        var r = Reader(p^)
        var line = String("  text row:")
        for i in range(n):
            if r.data[r.at] == 0xFB:
                r.at += 1
                line += " " + cols[i][0] + "=NULL"
            else:
                line += " " + cols[i][0] + "=" + r.lenenc_str()
        print(line)


def binary_value(mut r: Reader, type_code: Int) -> String:
    if type_code == 0x01:
        return String(r.le(1))
    if type_code == 0x02 or type_code == 0x0D:
        return String(r.le(2))
    if type_code == 0x03 or type_code == 0x09:
        return String(Int32(r.le(4)))
    if type_code == 0x08:
        return String(r.le(8))
    if type_code == 0x05:
        var bits = UInt64(r.le(8))
        return String(Float64(from_bits=bits))
    if type_code == 0x04:
        var bits = UInt32(r.le(4))
        return String(Float32(from_bits=bits))
    if type_code == 0x07 or type_code == 0x0A or type_code == 0x0C:
        var n = r.u8()
        if n == 0:
            return "zero-date"
        var year = r.le(2)
        var month = r.u8()
        var day = r.u8()
        var out = String(year, "-", month, "-", day)
        if n >= 7:
            out += String(" ", r.u8(), ":", r.u8(), ":", r.u8())
        if n == 11:
            out += String(".", r.le(4))
        return out
    return r.lenenc_str()


def execute(mut c: Conn, sql: String, params: List[String]) raises:
    var prep = List[UInt8]()
    prep.append(0x16)
    prep.extend(sql.as_bytes())
    c.command(prep)
    var ok = c.read_packet()
    if ok[0] == 0xFF:
        print("  prepare:", err_text(ok))
        return
    var r = Reader(ok^)
    _ = r.u8()
    var stmt = r.le(4)
    var ncols = r.le(2)
    var nparams = r.le(2)
    if nparams > 0:
        _ = column_defs(c, nparams)
    if ncols > 0:
        _ = column_defs(c, ncols)

    var ex = List[UInt8]()
    ex.append(0x17)
    put_le(ex, stmt, 4)
    ex.append(0)
    put_le(ex, 1, 4)
    if nparams > 0:
        var bitmap = List[UInt8](length=(nparams + 7) // 8, fill=0)
        for i in range(nparams):
            if params[i] == "NULL":
                bitmap[i // 8] |= UInt8(1 << (i % 8))
        ex.extend(Span(bitmap))
        ex.append(1)
        for i in range(nparams):
            if params[i] == "NULL":
                ex.append(0x06)
            else:
                ex.append(0xFD)
            ex.append(0)
        for i in range(nparams):
            if params[i] != "NULL":
                put_lenenc(ex, params[i].byte_length())
                ex.extend(params[i].as_bytes())
    c.command(ex)
    var first = c.read_packet()
    if first[0] == 0xFF:
        print("  ", err_text(first))
    elif first[0] == 0x00:
        var okr = Reader(first^)
        _ = okr.u8()
        print("  ok, affected", okr.lenenc(), "last id", okr.lenenc())
    else:
        var head = Reader(first^)
        var n = head.lenenc()
        var cols = column_defs(c, n)
        while True:
            var p = c.read_packet()
            if p[0] == 0xFE:
                break
            var row = Reader(p^)
            _ = row.u8()
            var bitmap = row.bytes((n + 7 + 2) // 8)
            var line = String("  binary row:")
            for i in range(n):
                var bit = i + 2
                if (Int(bitmap[bit // 8]) >> (bit % 8)) & 1 == 1:
                    line += " " + cols[i][0] + "=NULL"
                else:
                    line += " " + cols[i][0] + "=" + binary_value(row, cols[i][1])
            print(line)
    var close = List[UInt8]()
    close.append(0x19)
    put_le(close, stmt, 4)
    c.command(close)


def run(label: String, port: UInt16, user: String, password: String) raises:
    print(label)
    var c = connect(port, user, password, "dodo")
    query(c, "select version() as v, 1 + 1 as two, null as nothing")
    query(c, "drop table if exists spike_users")
    query(
        c,
        "create table spike_users (id bigint primary key auto_increment, name"
        " varchar(100), score double, active bool, born date, seen datetime(6),"
        " note text) character set utf8mb4",
    )
    execute(
        c,
        "insert into spike_users (name, score, active, born, seen, note) values"
        " (?, ?, ?, ?, ?, ?), (?, ?, ?, ?, ?, ?)",
        [
            "ada", "9.5", "1", "1815-12-10", "2026-11-02 10:30:00.123456", "NULL",
            "bob 'q'; drop table x;--", "-1.25", "0", "2000-01-01", "2026-01-01 00:00:00", "héllo 🦤",
        ],
    )
    execute(c, "select * from spike_users where id >= ? order by id", ["1"])
    query(c, "select * from spike_users order by id")
    execute(c, "select * from no_such_table", List[String]())
    query(c, "select * from no_such_table")
    query(c, "select 'still alive' as status")


def main() raises:
    run("mysql (dodo)", 43306, "dodo", "dodo-test")
    run("mysql (root, cold cache: full auth)", 43306, "root", "dodo-root")
    run("mariadb", 43307, "dodo", "dodo-test")
    print("wrong password:")
    try:
        _ = connect(43306, "dodo", "nope", "dodo")
    except e:
        print(" ", e)

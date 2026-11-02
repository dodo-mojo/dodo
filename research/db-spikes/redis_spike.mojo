"""Redis RESP2 spike against Docker: AUTH, binary-safe values, nil, errors,
integers, arrays and pipelining (several commands, one write)."""

from dodo.tcp import TcpStream


struct Conn(Movable):
    var tcp: TcpStream
    var buf: List[UInt8]
    var pos: Int

    def __init__(out self, var tcp: TcpStream):
        self.tcp = tcp^
        self.buf = List[UInt8]()
        self.pos = 0

    def more(mut self) raises:
        if self.pos > 0:
            var rest = List[UInt8](self.buf[self.pos :])
            self.buf = rest^
            self.pos = 0
        var chunk = List[UInt8](length=16384, fill=0)
        var n = self.tcp.read(chunk.unsafe_ptr(), 16384)
        if n == 0:
            raise Error("closed")
        for i in range(n):
            self.buf.append(chunk[i])

    def line(mut self) raises -> String:
        while True:
            for i in range(self.pos, len(self.buf) - 1):
                if self.buf[i] == 13 and self.buf[i + 1] == 10:
                    var s = String(unsafe_from_utf8=self.buf[self.pos : i])
                    self.pos = i + 2
                    return s
            self.more()

    def exact(mut self, n: Int) raises -> List[UInt8]:
        while len(self.buf) - self.pos < n + 2:
            self.more()
        var out = List[UInt8](self.buf[self.pos : self.pos + n])
        self.pos += n + 2
        return out^

    def reply(mut self) raises -> String:
        var head = self.line()
        var kind = head[byte=0]
        var rest = String(head[byte=1:])
        if kind == "+":
            return "status " + rest
        if kind == "-":
            return "error " + rest
        if kind == ":":
            return "int " + rest
        if kind == "$":
            var n = Int(rest)
            if n < 0:
                return "nil"
            var data = self.exact(n)
            return "bulk(" + String(n) + ") " + String(unsafe_from_utf8=data)
        if kind == "*":
            var n = Int(rest)
            if n < 0:
                return "nil array"
            var out = String("array[")
            for i in range(n):
                if i > 0:
                    out += ", "
                out += self.reply()
            return out + "]"
        raise Error("bad reply: " + head)


def encode(args: List[String]) -> List[UInt8]:
    var s = "*" + String(len(args)) + "\r\n"
    for a in args:
        s += "$" + String(a.byte_length()) + "\r\n" + a + "\r\n"
    return List[UInt8](s.as_bytes())


def main() raises:
    var c = Conn(TcpStream.connect("127.0.0.1", 46379))
    c.tcp.write_all(Span(encode(["GET", "x"])))
    print("before auth:", c.reply())
    c.tcp.write_all(Span(encode(["AUTH", "dodo-test"])))
    print("auth:", c.reply())

    var batch = List[UInt8]()
    batch.extend(Span(encode(["DEL", "k", "n", "l"])))
    batch.extend(Span(encode(["SET", "k", "line1\r\nline2 🦤"])))
    batch.extend(Span(encode(["GET", "k"])))
    batch.extend(Span(encode(["GET", "missing"])))
    batch.extend(Span(encode(["INCRBY", "n", "41"])))
    batch.extend(Span(encode(["INCR", "n"])))
    batch.extend(Span(encode(["RPUSH", "l", "a", "b", "c"])))
    batch.extend(Span(encode(["LRANGE", "l", "0", "-1"])))
    batch.extend(Span(encode(["INCR", "k"])))
    batch.extend(Span(encode(["SET", "t", "v", "EX", "60"])))
    batch.extend(Span(encode(["TTL", "t"])))
    c.tcp.write_all(Span(batch))
    for _ in range(11):
        print(" ", c.reply())

from std.random import random_ui64, seed
from lightbug_http.header import parse_request_headers
from lightbug_http.http.chunked import HTTPChunkedDecoder
from lightbug_http.uri import URI
from lightbug_http.io.bytes import Bytes


fn rnd(n: Int) -> Int:
    return Int(random_ui64(0, UInt64(n - 1)))


fn mutate(src: Bytes) -> Bytes:
    var b = src.copy()
    var n = 1 + rnd(8)
    for _ in range(n):
        var op = rnd(4)
        if len(b) == 0:
            b.append(UInt8(rnd(256)))
            continue
        var i = rnd(len(b))
        if op == 0:
            b[i] = UInt8(rnd(256))
        elif op == 1:
            b.insert(i, UInt8(rnd(256)))
        elif op == 2:
            _ = b.pop(i)
        else:
            # insert an interesting byte
            var specials: List[UInt8] = [13, 10, 58, 32, 9, 0, 255, 127, 48, 102]
            b.insert(i, specials[rnd(len(specials))])
    return b^


fn main() raises:
    seed(1234)
    var seeds = List[Bytes]()
    seeds.append(Bytes("GET /a/b?c=d HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\nX-Y: z\r\n\r\n".as_bytes()))
    seeds.append(Bytes("POST / HTTP/1.0\r\nTransfer-Encoding: chunked\r\nCookie: a=b\r\n\r\n".as_bytes()))
    var parsed_ok = 0
    var errs = 0
    for it in range(300000):
        var inp = mutate(seeds[it % 2])
        with open("last_input.bin", "w") as f:
            f.write_bytes(Span(inp))
        try:
            var p = parse_request_headers(Span(inp))
            parsed_ok += 1
            # touch the strings to surface bad UTF-8 handling
            _ = len(p.path) + len(p.method)
            try:
                var u = URI.parse(p.path.copy())
                _ = len(u.path)
            except:
                pass
        except:
            errs += 1
    print("header fuzz: iterations=300000 parsed_ok=", parsed_ok, " rejected=", errs)

    var cseed = Bytes("5\r\nhello\r\n6;ext=1\r\n world\r\n0\r\nTrailer: x\r\n\r\n".as_bytes())
    var cbad = 0
    for it in range(300000):
        var inp = mutate(cseed)
        var d = HTTPChunkedDecoder()
        var r = d.decode(Span(inp))
        if r[1] > len(inp) or r[1] < 0:
            cbad += 1
    print("chunked fuzz: iterations=300000 impossible_outputs=", cbad)

    # targeted: chunk size overflow
    var ov = Bytes("ffffffffffffffffffff\r\nabc\r\n0\r\n\r\n".as_bytes())
    var d2 = HTTPChunkedDecoder()
    var r2 = d2.decode(Span(ov))
    print("overflow chunk size -> ret=", r2[0], " decoded_len=", r2[1], " bytes_left_in_chunk=", d2.bytes_left_in_chunk)
    var neg = Bytes("8000000000000000\r\nabc".as_bytes())
    var d3 = HTTPChunkedDecoder()
    var r3 = d3.decode(Span(neg))
    print("2^63 chunk size -> ret=", r3[0], " bytes_left_in_chunk=", d3.bytes_left_in_chunk)

    # URI percent-decoding into invalid UTF-8
    var u = URI.parse("/a%ff%fe%c3?x=%ff")
    print("pct-decoded path byte length=", len(u.path.as_bytes()), " valid-utf8-claim string len=", len(u.path))

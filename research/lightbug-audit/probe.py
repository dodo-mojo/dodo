import socket, time, sys, threading
HOST, PORT = "127.0.0.1", 8099

def raw(data, timeout=3.0, read=True):
    s = socket.create_connection((HOST, PORT), timeout=timeout)
    t0 = time.time()
    try:
        s.sendall(data)
        if not read: return s
        buf = b""
        while True:
            try:
                c = s.recv(65536)
            except socket.timeout:
                return buf, "TIMEOUT", time.time()-t0
            except ConnectionResetError:
                return buf, "RESET", time.time()-t0
            if not c: break
            buf += c
        return buf, "OK", time.time()-t0
    finally:
        if read: s.close()

def show(name, data, **kw):
    try:
        buf, st, dt = raw(data, **kw)
    except Exception as e:
        print(f"[{name}] EXC {e!r}"); return
    head = buf.split(b"\r\n\r\n",1)
    status = head[0].split(b"\r\n")[0] if buf else b"<no response>"
    body = head[1][:200] if len(head)>1 else b""
    extra = [l for l in head[0].split(b"\r\n")[1:] if l.lower().startswith((b"x-echo", b"set-cookie", b"connection"))]
    print(f"[{name}] {st} {dt:.2f}s | {status.decode(errors='replace')} | {extra} | {body!r}")

def alive():
    try:
        buf, st, dt = raw(b"GET / HTTP/1.1\r\nHost: x\r\n\r\n", timeout=3)
        return buf.startswith(b"HTTP/1.1 200")
    except Exception as e:
        return False

probes = [
 ("baseline", b"GET /hello HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("http10", b"GET / HTTP/1.0\r\n\r\n"),
 ("neg-CL", b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: -5\r\n\r\nhello"),
 ("plus-CL", b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: +5\r\n\r\nhello"),
 ("dup-CL", b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\nContent-Length: 2\r\n\r\nhello"),
 ("garbage-CL", b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5abc\r\n\r\nhello"),
 ("chunked-body", b"POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"),
 ("TE+CL", b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 3\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"),
 ("obs-fold", b"GET / HTTP/1.1\r\nHost: x\r\nX-A: a\r\n folded-line\r\n\r\n"),
 ("no-host-1.1", b"GET / HTTP/1.1\r\n\r\n"),
 ("utf8-bad-path", b"GET /\xff\xfe\xc3 HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("utf8-bad-header", b"GET / HTTP/1.1\r\nHost: x\r\nX-A: \xff\xfe\xc3\r\n\r\n"),
 ("bare-LF", b"GET / HTTP/1.1\nHost: x\n\n"),
 ("101-headers", b"GET / HTTP/1.1\r\n" + b"".join(b"X-%d: v\r\n"%i for i in range(101)) + b"\r\n"),
 ("body>4MB", b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5000000\r\n\r\n" + b"a"*100),
 ("uri>8KB", b"GET /" + b"a"*9000 + b" HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("abs-form", b"GET http://example.com/abs?q=1 HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("bad-method", b"G@T / HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("http2-preface", b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"),
 ("http/1.9", b"GET / HTTP/1.9\r\nHost: x\r\n\r\n"),
 ("space-before-colon", b"GET / HTTP/1.1\r\nHost : x\r\n\r\n"),
 ("pipelined-2", b"GET /one HTTP/1.1\r\nHost: x\r\n\r\nGET /two HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("keepalive-req", b"GET / HTTP/1.1\r\nHost: x\r\nConnection: keep-alive\r\n\r\n"),
 ("hdr-inject-app", b"GET /inject2 HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("query-pct-crlf", b"GET /inject?a%0d%0aSet-Cookie:%20evil=1 HTTP/1.1\r\nHost: x\r\n\r\n"),
 ("empty-request", b"\r\n\r\n"),
]
only = sys.argv[1:] 
for name, data in probes:
    if only and name not in only: continue
    show(name, data)
    if not alive():
        print(f"   !!! SERVER DEAD/UNRESPONSIVE after {name}")
        sys.exit(2)

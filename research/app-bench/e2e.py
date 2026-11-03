"""End-to-end checks against bench_app. Usage: python3 e2e.py PORT"""

import http.client
import json
import socket
import sys
import threading

PORT = int(sys.argv[1])
failures = []


def request(method, path, body=None, headers=None):
    conn = http.client.HTTPConnection("127.0.0.1", PORT, timeout=5)
    if isinstance(body, str):
        body = body.encode("utf-8")
    conn.request(method, path, body=body, headers=headers or {})
    resp = conn.getresponse()
    data = resp.read()
    conn.close()
    return resp.status, data, resp


def raw(payload):
    sock = socket.create_connection(("127.0.0.1", PORT), timeout=3)
    sock.sendall(payload)
    sock.shutdown(socket.SHUT_WR)
    chunks = []
    try:
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
    except socket.timeout:
        chunks.append(b"<timeout>")
    sock.close()
    return b"".join(chunks)


def check(name, method, path, status, contains=None, body=None, headers=None):
    got, data, _ = request(method, path, body, headers)
    passed = got == status
    if contains is not None and contains.encode() not in data:
        passed = False
    label = "ok  " if passed else "FAIL"
    print(f"{label} {name}: {got} {data[:90]!r}")
    if not passed:
        failures.append(name)


JSON = {"Content-Type": "application/json"}

check("plain", "GET", "/plain", 200, "hello")
check("last route", "GET", "/last", 200, "hello")
check("unknown path", "GET", "/nope", 404)
check("wrong method", "DELETE", "/plain", 405)
check("path and state", "GET", "/users/42", 200, '"people"')
check("path negative", "GET", "/users/-1", 200, "-1")
check("path not int", "GET", "/users/abc", 400, "expected Int")
check("path overflow", "GET", "/users/99999999999999999999999", 400)
check("trailing slash matches /users, POST only", "GET", "/users/", 405)
check("path decoded", "GET", "/orgs/a%20b/users/1", 200, "a b")
check("path bad escape", "GET", "/orgs/a%zz/users/1", 400)
check("path encoded slash", "GET", "/orgs/a%2Fb/users/1", 200, "a/b")
check("path unicode", "GET", "/orgs/%E2%9C%93/users/1", 200)
check("query", "GET", "/search?q=hi&limit=3", 200, '"hi"')
check("query optional absent", "GET", "/search?q=hi", 200, "10")
check("query plus", "GET", "/search?q=a+b", 200, "a b")
check("query missing", "GET", "/search", 400, "missing field")
check("query bad int", "GET", "/search?q=a&limit=x", 400, "expected Int")
check("query bad escape", "GET", "/search?q=%zz", 400)
check("body", "POST", "/users", 200, '"ann"', '{"name":"ann","age":3}', JSON)
check("body unicode", "POST", "/users", 200, None, '{"name":"✓","age":3}', JSON)
check("body empty", "POST", "/users", 400, None, "", JSON)
check("body not json", "POST", "/users", 400, None, "{{{", JSON)
check("body missing field", "POST", "/users", 400, "age", '{"name":"a"}', JSON)
check("body wrong type", "POST", "/users", 400, None, '{"name":1,"age":3}', JSON)
check("body deep nesting", "POST", "/users", 400, None, "[" * 100000, JSON)
check("body extra fields", "POST", "/users", 200, None, '{"name":"a","age":1,"x":[1]}', JSON)
big_name = "x" * 500000
check("body 500 KB", "POST", "/users", 200, None, json.dumps({"name": big_name, "age": 1}), JSON)
check("handler error hides detail", "GET", "/boom", 500, "Internal Server Error")
_, boom_body, _ = request("GET", "/boom")
if b"secret" in boom_body:
    print("FAIL handler error leaked detail")
    failures.append("leak")
check("404 does not echo path", "GET", "/%3Cscript%3E", 404)
_, nope_body, _ = request("GET", "/%3Cscript%3E")
if b"script" in nope_body:
    print("FAIL 404 echoed path")
    failures.append("echo")
_, _, head = request("GET", "/users/1")
print("content-type:", head.getheader("Content-Type"))
if "application/json" not in (head.getheader("Content-Type") or ""):
    failures.append("json content type")

# Two requests sent together on one connection.
pipe = raw(
    b"GET /plain HTTP/1.1\r\nHost: x\r\n\r\n"
    b"GET /users/7 HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
)
print("pipelined responses:", pipe.count(b"HTTP/1.1 200"))
if pipe.count(b"HTTP/1.1 200") != 2:
    failures.append("pipelining")

# Malformed input must get an error or a close, and the server must survive.
for name, payload in [
    ("garbage", b"\x00\xff\xfe nonsense\r\n\r\n"),
    ("no host", b"GET /plain HTTP/1.1\r\n\r\n"),
    ("bad length", b"POST /users HTTP/1.1\r\nHost: x\r\nContent-Length: -5\r\n\r\n"),
    ("short body", b"POST /users HTTP/1.1\r\nHost: x\r\nContent-Length: 50\r\n\r\n{"),
    ("two lengths", b"POST /users HTTP/1.1\r\nHost: x\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\n{}"),
    ("long uri", b"GET /" + b"a" * 200000 + b" HTTP/1.1\r\nHost: x\r\n\r\n"),
]:
    print(f"malformed {name}: {raw(payload)[:40]!r}")
check("alive after malformed", "GET", "/plain", 200)

# Concurrent mixed traffic: every response must match its request.
wrong = []


def worker(n):
    conn = http.client.HTTPConnection("127.0.0.1", PORT, timeout=10)
    for i in range(300):
        conn.request("GET", f"/users/{n}{i}")
        resp = conn.getresponse()
        data = json.loads(resp.read())
        if data["id"] != int(f"{n}{i}"):
            wrong.append((n, i, data))
    conn.close()


threads = [threading.Thread(target=worker, args=(n + 1,)) for n in range(16)]
for thread in threads:
    thread.start()
for thread in threads:
    thread.join()
print("mismatched concurrent responses:", len(wrong))
if wrong:
    failures.append("concurrency")

print("FAILURES:", failures)
sys.exit(1 if failures else 0)

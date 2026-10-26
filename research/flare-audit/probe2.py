import socket, time, threading
H, P = "127.0.0.1", 8099


def get(timeout=3, path=b"/"):
    t = time.time()
    try:
        s = socket.create_connection((H, P), timeout=timeout)
        s.sendall(b"GET " + path + b" HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n")
        b = s.recv(4096)
        s.close()
        return b[:15], round(time.time() - t, 3)
    except Exception as e:
        return repr(e), round(time.time() - t, 3)


def wait_closed(s, limit):
    t = time.time()
    s.settimeout(limit)
    try:
        d = s.recv(4096)
        return f"closed after {time.time()-t:.1f}s data={d[:40]!r}"
    except socket.timeout:
        return f"STILL OPEN after {limit}s"
    except Exception as e:
        return f"{e!r} after {time.time()-t:.1f}s"


def drip(prefix, payload, label, limit=75):
    s = socket.create_connection((H, P))
    s.sendall(prefix)
    t = time.time()
    try:
        for c in payload:
            s.sendall(bytes([c]))
            time.sleep(0.5)
            if time.time() - t > limit:
                return f"{label}: STILL OPEN after {limit}s"
        return f"{label}: finished without close"
    except Exception as e:
        return f"{label}: closed after {time.time()-t:.1f}s ({e!r})"
    finally:
        s.close()


# 1. One idle connection mid-headers
idle = socket.create_connection((H, P))
idle.sendall(b"GET / HTTP/1.1\r\nHost: x\r\n")
time.sleep(0.3)
print("[slowloris-1] other client while 1 idle conn open:", get(timeout=5))
print("[slowloris-1] server closes idle-mid-headers conn:", wait_closed(idle, 75))

# 2. Idle keep-alive connection after a full request
ka = socket.create_connection((H, P))
ka.sendall(b"GET / HTTP/1.1\r\nHost: x\r\n\r\n")
ka.recv(4096)
print("[idle-keepalive] server closes idle keep-alive conn:", wait_closed(ka, 75))

# 3. Byte drip of headers (header deadline vs per-read timeout)
print("[byte-drip]", drip(b"", b"GET / HTTP/1.1\r\nHost: x\r\nX-Pad: " + b"a" * 400, "headers"))

# 4. Body drip
print("[body-drip]", drip(b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 1000\r\n\r\n", b"a" * 1000, "body"))

# 5. Many idle connections, then a normal request
conns, err = [], None
for i in range(1000):
    try:
        s = socket.create_connection((H, P), timeout=3)
        s.sendall(b"GET / HTTP/1.1\r\n")
        conns.append(s)
    except Exception as e:
        err = repr(e)
        break
print(f"[1000-idle] opened={len(conns)} err={err} normal req:", get(timeout=5))
for s in conns:
    s.close()
time.sleep(0.5)

# 6. Client disconnects mid-body
s = socket.create_connection((H, P))
s.sendall(b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 100\r\n\r\nabc")
s.close()
time.sleep(0.2)
print("[disconnect mid-body] alive:", get())

# 7. Client pipelines many requests and never reads the responses
nr = socket.create_connection((H, P))
nr.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
nr.settimeout(5)
sent = 0
try:
    for i in range(20000):
        nr.sendall(b"GET / HTTP/1.1\r\nHost: x\r\n\r\n")
        sent += 1
    print("[no-read pipeline] sent 20000 reqs without reading")
except Exception as e:
    print(f"[no-read pipeline] send stopped after {sent}: {e!r}")
print("[no-read pipeline] other client:", get(timeout=5))
nr.close()

# 8. Concurrency 50x40
lat, errs = [], [0]


def worker():
    for _ in range(40):
        r, dt = get(timeout=10)
        if isinstance(r, bytes) and r.startswith(b"HTTP/1.1 200"):
            lat.append(dt)
        else:
            errs[0] += 1


t0 = time.time()
ts = [threading.Thread(target=worker) for _ in range(50)]
[t.start() for t in ts]
[t.join() for t in ts]
el = time.time() - t0
lat.sort()
print(f"[concurrency 50x40] ok={len(lat)} err={errs[0]} rps={len(lat)/el:.0f} "
      f"p50={lat[len(lat)//2]*1000:.1f}ms p99={lat[int(len(lat)*.99)]*1000:.1f}ms")

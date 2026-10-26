# Network mutation fuzzer: mutated requests through the live server, split at
# random points to exercise incremental parsing. Checks the server stays up and
# every response is a well-formed HTTP/1.x status line.
# Usage: python3 net_fuzz.py [iterations] [seed]
import random, socket, sys, time
from extra_probes import EXTRA

H, P = "127.0.0.1", 8099
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 1
rng = random.Random(SEED)
LAST = f"last_input_{SEED}.bin"

SEEDS = [d for _, d in EXTRA if len(d) < 20000] + [
    b"GET / HTTP/1.1\r\nHost: x\r\n\r\n",
    b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhello",
    b"POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n3\r\nabc\r\n0\r\n\r\n",
    b"GET /a?b=c HTTP/1.1\r\nHost: x\r\nCookie: a=b\r\nAccept: */*\r\n\r\nGET /2 HTTP/1.1\r\nHost: x\r\n\r\n",
]
TOKENS = [b"\r\n", b"\n", b"\r", b":", b" ", b"\t", b"\x00", b"\xff", b"\x88", b"0", b"-1",
          b"Content-Length: ", b"Transfer-Encoding: chunked\r\n", b"ffffffffffffffff",
          b"8000000000000000", b"\r\n\r\n", b"HTTP/1.1", b"%", b"%0d%0a", b";", b",",
          b"Connection: close\r\n", b"Expect: 100-continue\r\n", b"Upgrade: h2c\r\n"]


def mutate(d):
    d = bytearray(d)
    for _ in range(rng.randint(1, 6)):
        op = rng.randrange(6)
        i = rng.randrange(len(d) + 1)
        if op == 0 and d:
            d[min(i, len(d) - 1)] = rng.randrange(256)
        elif op == 1:
            d[i:i] = rng.choice(TOKENS)
        elif op == 2 and d:
            del d[i:i + rng.randint(1, 8)]
        elif op == 3:
            j = rng.randrange(len(d) + 1)
            d[i:i] = d[min(i, j):max(i, j)][:200]
        elif op == 4:
            d[i:i] = bytes(rng.randrange(256) for _ in range(rng.randint(1, 8)))
        else:
            d += rng.choice(SEEDS)
    return bytes(d)


def send(data, timeout=2.0):
    s = socket.create_connection((H, P), timeout=timeout)
    try:
        cuts = sorted(rng.sample(range(1, len(data)), min(3, max(0, len(data) - 1)))) if rng.random() < 0.5 and len(data) > 4 else []
        prev = 0
        for c in cuts + [len(data)]:
            s.sendall(data[prev:c])
            prev = c
            if c != len(data):
                time.sleep(0.002)
        s.shutdown(socket.SHUT_WR) if rng.random() < 0.3 else None
        buf = b""
        while True:
            try:
                c = s.recv(65536)
            except socket.timeout:
                return buf, "TIMEOUT"
            except ConnectionResetError:
                return buf, "RESET"
            if not c:
                return buf, "EOF"
            buf += c
            if len(buf) > 1 << 20:
                return buf, "BIG"
    finally:
        s.close()


def alive():
    try:
        b, _ = send(b"GET / HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n", 3)
        return b.startswith(b"HTTP/1.1 200")
    except Exception:
        return False


stats, bad = {}, []
t0 = time.time()
for it in range(N):
    data = mutate(rng.choice(SEEDS))
    open(LAST, "wb").write(data)
    try:
        buf, st = send(data)
    except Exception as e:
        buf, st = b"", repr(e)[:40]
    stats[st] = stats.get(st, 0) + 1
    if buf and not buf.startswith((b"HTTP/1.1 ", b"HTTP/1.0 ")):
        bad.append((data, buf[:80]))
    code = buf[9:12] if buf else b"---"
    stats[code] = stats.get(code, 0) + 1
    if it % 200 == 199 and not alive():
        print(f"!!! SERVER DOWN at iteration {it}; last input saved to {LAST}")
        sys.exit(2)
print(f"{N} inputs in {time.time()-t0:.0f}s; server alive={alive()}")
print("outcomes:", dict(sorted(stats.items(), key=lambda kv: str(kv[0]))))
print("malformed responses:", len(bad))
for d, b in bad[:5]:
    print("  in:", d[:120], "\n  out:", b)

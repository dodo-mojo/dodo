# Find request stalls under keep-alive load.
# Usage: python3 stall.py [connections] [seconds] [runs]
# Each connection sends requests back to back. Any request slower than
# 200 ms is printed with its connection number and the time it started.
import socket
import sys
import threading
import time

HOST = "127.0.0.1"
PORT = 8099
REQUEST = b"GET / HTTP/1.1\r\nHost: x\r\n\r\n"
SLOW = 0.2


def read_response(sock):
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("closed")
        data += chunk
    head, _, body = data.partition(b"\r\n\r\n")
    length = 0
    for line in head.split(b"\r\n"):
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":")[1])
    while len(body) < length:
        body += sock.recv(4096)


def worker(conn_id, deadline, start, slow, counts):
    sock = socket.create_connection((HOST, PORT))
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    n = 0
    while time.monotonic() < deadline:
        t0 = time.monotonic()
        try:
            sock.sendall(REQUEST)
            read_response(sock)
        except ConnectionError:
            # The server closes after max_keepalive_requests. Reconnect.
            sock.close()
            sock = socket.create_connection((HOST, PORT))
            continue
        took = time.monotonic() - t0
        if took > SLOW:
            slow.append((conn_id, t0 - start, took, n))
        n += 1
    counts[conn_id] = n
    sock.close()


def run(conns, seconds):
    start = time.monotonic()
    deadline = start + seconds
    slow = []
    counts = {}
    threads = []
    for i in range(conns):
        t = threading.Thread(target=worker, args=(i, deadline, start, slow, counts))
        t.start()
        threads.append(t)
    for t in threads:
        t.join()
    return sum(counts.values()), slow


def main():
    conns = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 5
    runs = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    for r in range(runs):
        total, slow = run(conns, seconds)
        print(f"run {r + 1}: {total} requests, {len(slow)} slow")
        for conn_id, at, took, info in slow[:10]:
            print(f"   conn {conn_id} at {at:.2f}s took {took:.3f}s ({info})")


main()

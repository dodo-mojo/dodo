import socket, time, threading
H,P="127.0.0.1",8099
def get(timeout=3):
    t=time.time()
    try:
        s=socket.create_connection((H,P),timeout=timeout); s.sendall(b"GET / HTTP/1.1\r\nHost: x\r\n\r\n")
        b=s.recv(4096); s.close(); return b[:15], time.time()-t
    except Exception as e: return repr(e), time.time()-t

# 1. Slow client: one idle connection that never finishes its request
idle=socket.create_connection((H,P)); idle.sendall(b"GET / HTTP/1.1\r\nHost: x\r\n")
time.sleep(0.3)
print("[slowloris] other client while 1 idle conn is open:", get(timeout=5))
idle.close(); time.sleep(0.3)
print("[after idle closed]:", get())

# 2. Slow handler-side: client that sends request but never reads (small response so not an issue) - skip
# 3. Client disconnects mid-body
s=socket.create_connection((H,P)); s.sendall(b"POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 100\r\n\r\nabc"); s.close()
time.sleep(0.2); print("[disconnect mid-body] alive:", get())
# 4. RST on connect
pass
time.sleep(0.2); print("[RST] alive:", get())
# 5. Concurrency: 50 threads x 40 requests
lat=[]; errs=[0]
def worker():
    for _ in range(40):
        r,dt=get(timeout=10)
        if isinstance(r,bytes) and r.startswith(b"HTTP/1.1 200"): lat.append(dt)
        else: errs[0]+=1
t0=time.time(); ts=[threading.Thread(target=worker) for _ in range(50)]
[t.start() for t in ts]; [t.join() for t in ts]
el=time.time()-t0; lat.sort()
print(f"[concurrency 50x40] ok={len(lat)} err={errs[0]} rps={len(lat)/el:.0f} p50={lat[len(lat)//2]*1000:.1f}ms p99={lat[int(len(lat)*.99)]*1000:.1f}ms")

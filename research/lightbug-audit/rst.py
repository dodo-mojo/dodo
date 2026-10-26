import socket, struct, time
for i in range(20):
    s=socket.create_connection(("127.0.0.1",8099))
    s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii',1,0))
    s.close()   # sends RST before server has accepted
print("sent 20 RST connections")

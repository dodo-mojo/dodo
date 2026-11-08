# `dodo.tcp.stream`

TCP stream: a connected, bidirectional byte stream.

``TcpStream`` owns a ``RawSocket`` and exposes blocking read/write
operations. ``TCP_NODELAY`` is set automatically on every new stream so
callers get low-latency behaviour by default (Nagle's algorithm is
disabled).

Design rules enforced here:
- ``write`` retries transparently on ``EINTR``.
- ``write_all`` loops until every byte is sent.
- ``read`` returning 0 means EOF — it is never converted to an error.
- ``connect_timeout`` on macOS/arm64 delegates to ``dodo_connect_timeout``
  in ``libdodo_tls.so`` to sidestep a Mojo ABI bug with variadic functions
  (e.g. ``fcntl``) on that platform. On Linux, ``connect_timeout`` calls
  ``fcntl`` / ``connect`` / ``poll`` / ``getsockopt`` directly via
  ``external_call`` — ``OwnedDLHandle.get_function`` crashes on Linux when
  calling into a freshly-loaded shared library.

## Structs

### `TcpStream`

```mojo
struct TcpStream
```

A connected TCP socket.

Owns a ``RawSocket`` and exposes blocking read/write operations.
``TCP_NODELAY`` is set automatically on every new stream so callers
get low-latency behaviour without any configuration.

This type is ``Movable`` but not ``Copyable`` — a TCP connection
cannot be duplicated without tracking both file descriptors.

The connection is closed automatically when the struct is destroyed.

Thread safety:

```mojo
Not thread-safe . Do not share a ``TcpStream`` across
threads without external synchronisation.
```

Example:
```mojo
from dodo.tcp import TcpStream
from dodo.net import SocketAddr

var stream = TcpStream.connect(SocketAddr.localhost(8080))
stream.write_all("hello".as_bytes())
var buf = List[UInt8](capacity=1024)
buf.resize(1024, 0)
var n = stream.read(buf.unsafe_ptr(), len(buf))
stream.close()
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `Readable`, `_ChunkWriter`

#### `TcpStream.__init__`

```mojo
def __init__(out self, var socket: RawSocket, peer: SocketAddr)
```

Wrap an already-connected ``RawSocket``.

Safety:
``socket`` must be connected before calling this constructor.
``TCP_NODELAY`` should already be set by the factory functions.

Args:

- `socket`: An open, connected file descriptor (ownership transferred).
- `peer`: The remote address.

#### `TcpStream.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `TcpStream.connect`

```mojo
def connect(addr: SocketAddr) raises -> Self
```

Open a blocking TCP connection to ``addr``.

Sets ``TCP_NODELAY`` automatically.

Example:
```mojo
var stream = TcpStream.connect(SocketAddr.localhost(8080))
```

Args:

- `addr`: The remote socket address to connect to.

Returns: A connected ``TcpStream``.

Raises: ConnectionRefused: If the remote port actively refuses. ConnectionTimeout: If the OS connect timeout expires. ConnectionReset: If the peer sends a TCP RST during connect. NetworkError: For any other OS error.

```mojo
def connect(host: String, port: UInt16) raises -> Self
```

Resolve ``host`` via DNS and open a blocking TCP connection.

Convenience overload that performs DNS resolution then calls
``TcpStream.connect(SocketAddr(...))`` automatically.

Example:
```mojo
var stream = TcpStream.connect("example.com", 80)
```

Args:

- `host`: Hostname or IP address string (e.g. ``"example.com"``).
- `port`: TCP port number.

Returns: A connected ``TcpStream``.

Raises: DnsError: If ``host`` cannot be resolved. ConnectionRefused: If the remote port actively refuses. ConnectionTimeout: If the OS connect timeout expires. NetworkError: For any other OS error.

```mojo
def connect(host: String, port: UInt16, timeout_ms: Int) raises -> Self
```

Resolve ``host`` via DNS (dual-stack) and connect with a timeout.

Tries each resolved address in order (IPv4 and IPv6), falling back
to the next on failure.

Args:

- `host`: Hostname or IP address string.
- `port`: TCP port number.
- `timeout_ms`: Maximum time to wait in milliseconds.

Returns: A connected ``TcpStream``.

Raises: DnsError: If ``host`` cannot be resolved. ConnectionTimeout: If all addresses time out. ConnectionRefused: If all addresses refuse. NetworkError: For any other OS error.

#### `TcpStream.connect_timeout`

```mojo
def connect_timeout(addr: SocketAddr, timeout_ms: Int) raises -> Self
```

Open a TCP connection, failing if it takes longer than ``timeout_ms``.

On macOS/arm64 this delegates to ``dodo_connect_timeout`` in
``libdodo_tls.so`` to avoid a Mojo ABI bug where ``external_call``
silently corrupts variadic-function arguments (e.g. the third argument
of ``fcntl``) on that platform.

On Linux, the non-blocking connect + ``poll(POLLOUT)`` +
``getsockopt(SO_ERROR)`` sequence is implemented directly via
``external_call``. ``OwnedDLHandle.get_function`` crashes on Linux
when calling into a freshly-loaded shared library, so the C helper
cannot be used there.

Example:
```mojo
var stream = TcpStream.connect_timeout(SocketAddr.localhost(8080), 5000)
```

Args:

- `addr`: The remote socket address.
- `timeout_ms`: Maximum time to wait in milliseconds (must be > 0).

Returns: A connected ``TcpStream``.

Raises: ConnectionTimeout: If the deadline expires before connecting. ConnectionRefused: If the port actively refuses. NetworkError: For any other OS error.

#### `TcpStream.__enter__`

```mojo
def __enter__(var self) -> Self
```

Transfer ownership of ``self`` into the ``with`` block.

Returns: This ``TcpStream`` (moved).

#### `TcpStream.read`

```mojo
def read(mut self, buf: Pointer[UInt8], size: Int) raises -> Int
```

Read up to ``size`` bytes from the stream into ``buf``.

Retries transparently on ``EINTR``. Returns 0 on EOF (the peer
closed the connection) — this is not an error.

Example:
```mojo
var buf = List[UInt8](capacity=4096)
buf.resize(4096, 0)
var n = stream.read(buf.unsafe_ptr(), len(buf))
if n == 0:
    print("connection closed")
```

Args:

- `buf`: Destination buffer; the caller must provide at least ``size`` bytes of valid storage.
- `size`: Maximum number of bytes to read.

Returns: Number of bytes placed in ``buf``. **0 means EOF.**

Raises: ConnectionReset: If the peer sent a TCP RST. Timeout: If a recv timeout was set and expired. NetworkError: For any other OS read error.

#### `TcpStream.read_exact`

```mojo
def read_exact(mut self, buf: Pointer[UInt8], size: Int) raises
```

Read exactly ``size`` bytes into ``buf``.

Loops over ``read()`` until ``size`` bytes have been received.

Example:
```mojo
var exact = List[UInt8](capacity=8)
exact.resize(8, 0)
stream.read_exact(exact.unsafe_ptr(), 8)
```

Args:

- `buf`: Destination buffer; must have at least ``size`` bytes.
- `size`: Exact number of bytes to read.

Raises: NetworkError: If EOF is reached before ``size`` bytes are received, or on any other I/O error.

#### `TcpStream.write`

```mojo
def write(self, data: Span[UInt8]) raises -> Int
```

Write up to ``len(data)`` bytes to the stream.

A single call may write fewer bytes than requested (partial write).
Use ``write_all`` to guarantee all bytes are sent. Retries on
``EINTR``.

Example:
```mojo
var n = stream.write("hello".as_bytes())
```

Args:

- `data`: The bytes to send.

Returns: Number of bytes actually written (>= 1 if data is non-empty).

Raises: BrokenPipe: If the peer has closed the read end. Timeout: If a send timeout was set and expired. NetworkError: For any other OS write error.

#### `TcpStream.write_all`

```mojo
def write_all(self, data: Span[UInt8]) raises
```

Write all of ``data``, looping until every byte is sent.

Example:
```mojo
stream.write_all("Hello, server!".as_bytes())
```

Args:

- `data`: The bytes to send completely.

Raises: BrokenPipe: If the peer closes before all bytes are sent. NetworkError: For any other OS write error, or if ``send(2)`` returns 0 for a non-empty buffer (no progress is possible).

#### `TcpStream.peer_addr`

```mojo
def peer_addr(self) -> SocketAddr
```

Return the remote socket address.

Returns: The ``SocketAddr`` this stream is connected to.

#### `TcpStream.local_addr`

```mojo
def local_addr(self) raises -> SocketAddr
```

Return the local socket address assigned by the OS.

Returns: The local ``SocketAddr`` (IP + ephemeral port).

Raises: NetworkError: If ``getsockname(2)`` fails.

#### `TcpStream.shutdown_read`

```mojo
def shutdown_read(self) raises
```

Shut down the read half of the connection.

After this call, any subsequent ``read()`` returns 0 (EOF). The
peer will receive a FIN indicating no more data will be read.

Raises: NetworkError: If ``shutdown(2)`` fails.

#### `TcpStream.shutdown_write`

```mojo
def shutdown_write(self) raises
```

Shut down the write half of the connection.

Sends a FIN to the peer, signalling that no more data will be
written. The peer will see EOF on their next ``read()``.

Raises: NetworkError: If ``shutdown(2)`` fails.

#### `TcpStream.close`

```mojo
def close(mut self)
```

Close the connection explicitly. Idempotent.

#### `TcpStream.set_nodelay`

```mojo
def set_nodelay(self, enabled: Bool) raises
```

Toggle ``TCP_NODELAY`` (Nagle's algorithm).

Args:

- `enabled`: ``True`` disables Nagle (low-latency); ``False`` re-enables it.

#### `TcpStream.set_keepalive`

```mojo
def set_keepalive(self, enabled: Bool) raises
```

Toggle ``SO_KEEPALIVE``.

Args:

- `enabled`: ``True`` to send keepalive probes on idle connections.

#### `TcpStream.set_recv_timeout`

```mojo
def set_recv_timeout(self, ms: Int) raises
```

Set a per-read timeout.

After the timeout expires, ``read()`` raises ``Timeout``.

Args:

- `ms`: Timeout in milliseconds. 0 disables the timeout.

#### `TcpStream.set_send_timeout`

```mojo
def set_send_timeout(self, ms: Int) raises
```

Set a per-write timeout.

After the timeout expires, ``write()`` raises ``Timeout``.

Args:

- `ms`: Timeout in milliseconds. 0 disables the timeout.

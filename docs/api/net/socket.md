# `dodo.net.socket`

Raw POSIX socket wrapper — the single point where dodo touches the OS.

Every higher-level type (``TcpStream``, ``UdpSocket``, etc.) is built on
top of ``RawSocket``. No module above ``dodo.net`` calls libc directly.

Safety contracts for this module:
1. ``fd >= 0`` iff the socket is open. ``close()`` sets ``fd = INVALID_FD``.
2. Every libc call that returns -1 reads ``errno`` immediately (before any
   subsequent libc call) and maps it to a typed error.
3. ``TCP_NODELAY`` is set by the caller, not here — ``RawSocket`` is
   transport-agnostic and does not know whether it carries TCP or UDP.

## Structs

### `RawSocket`

```mojo
struct RawSocket
```

A thin, owning wrapper around a POSIX socket file descriptor.

``RawSocket`` is ``Movable`` but intentionally **not** ``Copyable``.
Duplicating a file descriptor without tracking both copies leads to
double-close bugs and hard-to-find resource leaks.

Lifecycle:
- ``__init__``: calls ``socket(2)``; raises on failure.
- ``__deinit__``: calls ``close(2)`` when ``fd >= 0``.
- Move: the synthesized move hands the fd over; the moved-from value
  is dead, so its ``__deinit__`` never runs.
- ``close()``: explicit, idempotent close.

Fields:
    fd: The OS file descriptor. ``INVALID_FD`` means closed/invalid.
    family: Address family (``AF_INET`` or ``AF_INET6``).
    kind: Socket type (``SOCK_STREAM`` or ``SOCK_DGRAM``).

Example:
```mojo
var sock = RawSocket(AF_INET, SOCK_STREAM)
sock.set_reuse_addr(True)
# ... use sock.fd ...
sock.close() # or let it fall out of scope
```

Fields:

- `fd` (`c_int`)
- `family` (`c_int`)
- `kind` (`c_int`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `RawSocket.__init__`

```mojo
def __init__(out self, family: Int32, kind: Int32) raises
```

Create a new socket via ``socket(2)``.

Example:
```mojo
var tcp = RawSocket(AF_INET, SOCK_STREAM)
var udp = RawSocket(AF_INET, SOCK_DGRAM)
```

Args:

- `family`: Address family (``AF_INET`` or ``AF_INET6``).
- `kind`: Socket type (``SOCK_STREAM`` for TCP, ``SOCK_DGRAM`` for UDP).

Raises: NetworkError: If ``socket(2)`` returns -1, with the OS errno and ``strerror`` message included.

```mojo
def __init__(out self, fd: Int32, family: Int32, kind: Int32, _wrap: Bool)
```

Wrap an existing file descriptor without calling ``socket(2)``.

Safety:
``fd`` must be a valid, open file descriptor. The caller
transfers ownership — ``RawSocket.__deinit__`` will call
``close(fd)`` exactly once.

Args:

- `fd`: An already-open file descriptor (from ``accept(2)`` etc.).
- `family`: Address family (``AF_INET`` or ``AF_INET6``).
- `kind`: Socket type (``SOCK_STREAM`` or ``SOCK_DGRAM``).
- `_wrap`: Dummy parameter that disambiguates this overload from the public ``__init__(family, kind)`` constructor.

#### `RawSocket.__deinit__`

```mojo
def __deinit__(deinit self)
```

Close the file descriptor if it is open.

A moved-from socket is never destroyed, so each fd closes once.

#### `RawSocket.close`

```mojo
def close(mut self)
```

Close the socket explicitly. Idempotent.

Sets ``fd = INVALID_FD`` so subsequent calls and the destructor
are no-ops.

#### `RawSocket.set_reuse_addr`

```mojo
def set_reuse_addr(self, enabled: Bool) raises
```

Set ``SO_REUSEADDR`` so the port can be reused immediately after the socket is closed.

Should be called before ``bind()``. This is the default for all
``TcpListener`` instances.

Example:
```mojo
sock.set_reuse_addr(True)
```

Args:

- `enabled`: ``True`` to enable address reuse, ``False`` to disable.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_reuse_port`

```mojo
def set_reuse_port(self, enabled: Bool) raises
```

Set ``SO_REUSEPORT`` for multi-process listener load balancing.

Allows multiple processes or threads to bind the same port. Each
accept loop gets a fair share of incoming connections from the kernel.

Args:

- `enabled`: ``True`` to enable port reuse.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_keepalive`

```mojo
def set_keepalive(self, enabled: Bool) raises
```

Enable or disable ``SO_KEEPALIVE``.

When enabled, the kernel sends TCP keepalive probes on idle
connections to detect dead peers.

Example:
```mojo
stream._socket.set_keepalive(True)
```

Args:

- `enabled`: ``True`` to send keepalive probes.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_tcp_nodelay`

```mojo
def set_tcp_nodelay(self, enabled: Bool) raises
```

Disable Nagle's algorithm via ``TCP_NODELAY``.

Must be called on all TCP sockets in dodo. Nagle coalesces small
writes, which introduces latency that surprises virtually every
networking caller.

Example:
```mojo
sock.set_tcp_nodelay(True)
```

Args:

- `enabled`: ``True`` to disable Nagle (send immediately).

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_recv_timeout`

```mojo
def set_recv_timeout(self, ms: Int) raises
```

Set a receive timeout via ``SO_RCVTIMEO``.

After the timeout expires, ``recv``/``recvfrom`` returns ``EAGAIN``.

Example:
```mojo
sock.set_recv_timeout(5_000) # 5 seconds
```

Args:

- `ms`: Timeout in milliseconds. ``0`` disables the timeout.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_send_timeout`

```mojo
def set_send_timeout(self, ms: Int) raises
```

Set a send timeout via ``SO_SNDTIMEO``.

Args:

- `ms`: Timeout in milliseconds. ``0`` disables the timeout.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_recv_buffer`

```mojo
def set_recv_buffer(self, bytes: Int) raises
```

Request a kernel receive-buffer size via ``SO_RCVBUF``.

The kernel doubles the request for bookkeeping and clamps it to
``net.core.rmem_max``; the effective size may be smaller than
``bytes``. Larger buffers absorb datagram bursts so the kernel
does not drop packets between reactor ticks (which would force
the peer into PTO backoff under load).

Args:

- `bytes`: Requested receive-buffer size in bytes.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_send_buffer`

```mojo
def set_send_buffer(self, bytes: Int) raises
```

Request a kernel send-buffer size via ``SO_SNDBUF``.

Args:

- `bytes`: Requested send-buffer size in bytes.

Raises: NetworkError: If ``setsockopt(2)`` fails.

#### `RawSocket.set_nonblocking`

```mojo
def set_nonblocking(self, enabled: Bool) raises
```

Toggle non-blocking mode on the socket.

On macOS/arm64 delegates to ``dodo_set_nonblocking`` in
``libdodo_tls.so`` to avoid a Mojo ABI bug where ``external_call``
silently corrupts the third argument of variadic C functions (like
``fcntl``) on that platform.

On Linux, calls ``fcntl`` directly via ``external_call``.
``OwnedDLHandle.get_function`` crashes on Linux when calling into a
freshly-loaded shared library.

Args:

- `enabled`: ``True`` to enable non-blocking I/O; ``False`` to restore blocking mode.

Raises: NetworkError: If the underlying ``fcntl(F_SETFL)`` call fails.

#### `RawSocket.local_addr`

```mojo
def local_addr(self) raises -> SocketAddr
```

Return the local address assigned by the OS.

Supports both IPv4 and IPv6 sockets (buffer sized for sockaddr_in6).

Returns: The local ``SocketAddr`` (IP + port).

Raises: NetworkError: If ``getsockname(2)`` fails.

#### `RawSocket.peer_addr`

```mojo
def peer_addr(self) raises -> SocketAddr
```

Return the remote address of the connected peer.

Supports both IPv4 and IPv6 sockets.

Returns: The peer ``SocketAddr``.

Raises: NetworkError: If ``getpeername(2)`` fails (e.g. not connected).

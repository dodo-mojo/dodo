# `dodo.uds.stream`

Connected AF_UNIX byte stream.

``UnixStream`` is the UDS sibling of :class:`dodo.tcp.TcpStream`.
The wire shape is identical (``read`` / ``write`` / ``write_all``
/ ``shutdown`` / ``close``); the differences are limited to the
address-family layer:

- Peer address is a path string (or empty when the peer side
  didn't bind).
- ``TCP_NODELAY`` doesn't apply (no Nagle on UDS); the constructor
  skips it.
- ``MSG_NOSIGNAL`` still applies — a writer to a peer that has
  closed must not get ``SIGPIPE`` on Linux. macOS uses
  ``SO_NOSIGPIPE`` which the underlying ``RawSocket`` already
  sets in :class:`dodo.net.socket.RawSocket.__init__`.

## Structs

### `UnixStream`

```mojo
struct UnixStream
```

A connected AF_UNIX byte stream.

Owns a ``RawSocket`` (kind = ``SOCK_STREAM``, family =
``AF_UNIX``). ``Movable`` but not ``Copyable`` — same
rationale as :class:`dodo.tcp.TcpStream`: a connection is a
single owned resource, duplicating it without tracking both
fds leads to double-close.

Closed automatically when the struct is destroyed.

Thread safety:

```mojo
Not thread-safe. Do not share across threads without
external synchronisation.
```

Example:
```mojo
from dodo.uds import UnixStream

var s = UnixStream.connect("/tmp/sidecar.sock")
s.write_all("ping".as_bytes())
s.close()
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `_ChunkWriter`

#### `UnixStream.__init__`

```mojo
def __init__(out self, var socket: RawSocket, peer_path: String)
```

Wrap an already-connected ``RawSocket``.

Safety: ``socket`` must be connected (kind = SOCK_STREAM,
family = AF_UNIX) before calling this constructor.

#### `UnixStream.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `UnixStream.connect`

```mojo
def connect(path: String) raises -> Self
```

Connect to an AF_UNIX listener bound at ``path``.

Raises :class:`ConnectionRefused` if no listener is bound
at the path (mirrors TCP's ``ECONNREFUSED`` shape).
Raises :class:`NetworkError` for other connect(2) errors.

#### `UnixStream.read`

```mojo
def read(self, buf: Pointer[UInt8], n: Int) raises -> Int
```

Read up to ``n`` bytes into ``buf``. Returns 0 on EOF.

Retries transparently on ``EINTR``. Raises
:class:`ConnectionReset` on ``ECONNRESET``,
:class:`NetworkError` on every other failure.

#### `UnixStream.write`

```mojo
def write(self, buf: Pointer[UInt8], n: Int) raises -> Int
```

Write at most ``n`` bytes from ``buf``. Returns the byte count actually written (may be less than ``n``).

Retries on ``EINTR``. Raises :class:`BrokenPipe` on
``EPIPE``, :class:`NetworkError` on every other failure.

#### `UnixStream.write_all`

```mojo
def write_all(self, data: Span[UInt8]) raises
```

Write every byte of ``data``, looping until done.

Raises :class:`BrokenPipe` on ``EPIPE`` and :class:`NetworkError` on
every other failure, including a ``send(2)`` return of 0 for a
non-empty buffer (no progress is possible).

#### `UnixStream.shutdown_read`

```mojo
def shutdown_read(self) raises
```

Half-close the read side (``SHUT_RD``).

#### `UnixStream.shutdown_write`

```mojo
def shutdown_write(self) raises
```

Half-close the write side (``SHUT_WR``).

#### `UnixStream.shutdown`

```mojo
def shutdown(self) raises
```

Half-close both directions (``SHUT_RDWR``).

#### `UnixStream.close`

```mojo
def close(mut self)
```

Close the connection. Idempotent.

#### `UnixStream.peer_path`

```mojo
def peer_path(self) -> String
```

Return the filesystem path of the peer side, or ``""`` when the peer didn't bind a path.

#### `UnixStream.as_raw_fd`

```mojo
def as_raw_fd(self) -> c_int
```

Return the underlying file descriptor.

The returned fd is borrowed; its lifetime is tied to
``self``. Callers must not ``close(fd)`` themselves; let
``UnixStream`` own the close. Same contract as
:meth:`dodo.tcp.TcpStream.as_raw_fd`.

# `dodo.tcp.listener`

TCP listener: a socket bound and listening for incoming connections.

``TcpListener`` wraps a ``RawSocket`` in the listening state. Call
``accept()`` to receive incoming connections as ``TcpStream`` instances.

Design rules enforced here:
- ``SO_REUSEADDR`` is set before every ``bind()`` call.
- ``TCP_NODELAY`` is set on every accepted ``TcpStream``.
- ``accept()`` sets ``TCP_NODELAY`` on the client socket automatically.

## Structs

### `TcpListener`

```mojo
struct TcpListener
```

A TCP socket in the listening state.

``TcpListener`` accepts incoming TCP connections and returns each one
as a ``TcpStream``. ``SO_REUSEADDR`` is always set before ``bind()``.

The listener is closed automatically when the struct is destroyed.

Thread safety:

```mojo
Not thread-safe . Do not call ``accept()`` concurrently.
```

Example:
```mojo
from dodo.tcp import TcpListener, TcpStream
from dodo.net import SocketAddr

var listener = TcpListener.bind(SocketAddr.localhost(8080))
var stream = listener.accept() # blocks until a client connects
stream.write_all("welcome".as_bytes())
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `TcpListener.__init__`

```mojo
def __init__(out self, var socket: RawSocket, local: SocketAddr)
```

Wrap an already-bound, listening ``RawSocket``.

Safety:
``socket`` must already be in the listening state (``listen(2)``
was called). The caller must not close ``socket`` after this.

Args:

- `socket`: Open, listening socket (ownership transferred).
- `local`: The address the socket was bound to.

#### `TcpListener.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `TcpListener.bind`

```mojo
def bind(addr: SocketAddr) raises -> Self
```

Bind a TCP listener to ``addr`` with default options.

``SO_REUSEADDR`` is set before binding. The backlog is 128.

Example:
```mojo
var l = TcpListener.bind(SocketAddr.localhost(8080))
```

Args:

- `addr`: The local address to bind (use port 0 for OS-assigned port).

Returns: A ``TcpListener`` ready to call ``accept()``.

Raises: AddressInUse: If the port is already in use. NetworkError: For any other OS bind/listen error.

#### `TcpListener.bind_with_options`

```mojo
def bind_with_options(addr: SocketAddr, backlog: Int = Int(128), reuse_port: Bool = False) raises -> Self
```

Bind with explicit backlog and ``SO_REUSEPORT`` control.

Example:
```mojo
var l = TcpListener.bind_with_options(
    SocketAddr.localhost(8080), backlog=1024, reuse_port=True
)
```

Args:

- `addr`: The local address to bind.
- `backlog`: Maximum length of the pending-connections queue.
- `reuse_port`: If ``True``, set ``SO_REUSEPORT`` (useful for multi-process load balancing).

Returns: A ``TcpListener`` ready to call ``accept()``.

Raises: AddressInUse: If the port is already in use. NetworkError: For any other OS error.

#### `TcpListener.from_raw_fd`

```mojo
def from_raw_fd(fd: Int32, local: SocketAddr) -> Self
```

Take ownership of a listening socket handed over as a bare fd.

The counterpart of :meth:`into_raw_fd`.

Args:

- `fd`: An open socket in the listening state.
- `local`: The address it is bound to.

Returns: A ``TcpListener`` that closes ``fd`` when destroyed.

#### `TcpListener.inherit`

```mojo
def inherit(fd: Int) raises -> Self
```

Take over a listening socket another process passed down, such as the one `dodo dev` keeps open across restarts.

Unlike :meth:`from_raw_fd` it checks the fd and reads its address.

Raises: Error: If `fd` is not an open, listening TCP socket.

#### `TcpListener.into_raw_fd`

```mojo
def into_raw_fd(mut self) -> c_int
```

Give up ownership of the socket and return its fd.

The listener no longer closes it; whoever receives the fd does
(usually through :meth:`from_raw_fd`). Afterwards this listener
behaves as closed.

Returns: The fd, or a negative value when the listener was closed.

#### `TcpListener.accept`

```mojo
def accept(self) raises -> TcpStream
```

Block until an incoming connection arrives and return it.

Sets ``TCP_NODELAY`` on the accepted socket automatically.

Example:
```mojo
while True:
    var client = listener.accept()
    client.write_all("hello".as_bytes())
    client.close()
```

Returns: A connected ``TcpStream`` for the new client.

Raises: NetworkError: If ``accept(2)`` fails. If the peer address cannot be decoded afterwards the accepted socket is closed before the error propagates (it is never leaked).

#### `TcpListener.local_addr`

```mojo
def local_addr(self) -> SocketAddr
```

Return the local address the listener is bound to.

Returns: The bound ``SocketAddr`` (useful when port 0 was requested).

#### `TcpListener.as_raw_fd`

```mojo
def as_raw_fd(self) -> c_int
```

Return the underlying file descriptor.

Intended for the shared-listener scheduler: bind once on
the main thread, then hand the fd (a small integer) to every
worker via the per-worker context struct. Workers call
``dodo.tcp.accept_fd`` directly rather than touching the
non-thread-safe ``TcpListener`` object.

The returned fd is borrowed; its lifetime is tied to ``self``.
Callers must not ``close(fd)`` themselves; let ``TcpListener``
own the close.

Returns: The kernel file descriptor for the listening socket.

#### `TcpListener.close`

```mojo
def close(mut self)
```

Close the listening socket. Idempotent.

## Functions

### `accept_fd`

```mojo
def accept_fd(listener_fd: Int32) raises -> TcpStream
```

Accept one connection on a borrowed listener fd.

Functionally equivalent to ``TcpListener.accept(self)`` but takes
the listener as a raw integer fd, so the caller can share a single
listener across multiple workers without giving any one worker
ownership of the underlying ``TcpListener`` (multi-worker
scheduler path; see ``dodo.runtime.scheduler``).

The returned ``TcpStream`` owns the accepted client fd and has
``TCP_NODELAY`` already set, matching ``TcpListener.accept``'s
contract. Same error semantics: raises ``NetworkError`` on
``accept(2)`` failure (including ``EAGAIN`` / ``EWOULDBLOCK``,
which the multi-worker reactor catches as a normal "no more
pending conns" signal).

Args:

- `listener_fd`: Fd of a listener socket. Caller must keep the socket open for the duration of this call; this function does NOT take ownership of the fd.

Returns: A connected ``TcpStream`` for the new client.

Raises: NetworkError: If ``accept(2)`` fails. The errno-bearing variant lets the caller distinguish ``EAGAIN`` (drain the accept loop) from a hard failure.

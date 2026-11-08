# `dodo.uds.listener`

AF_UNIX listener — bound + listening Unix domain socket.

``UnixListener`` is the UDS sibling of
:class:`dodo.tcp.TcpListener`. Same lifecycle (``bind`` → 0..N
``accept`` → automatic ``close`` on destruction), same
``accept_uds_fd`` shape for the multi-worker shared-listener
scheduler. The differences:

- ``bind`` takes a filesystem path, not a :class:`SocketAddr`.
- A previous socket file at the same path is unlinked before
  ``bind(2)`` (controllable via ``unlink_existing=False``).
- ``UnixListener.__deinit__`` unlinks the socket file on destruction
  by default — opt out via ``cleanup_path=False`` for the
  shared-listener case where one fd is being passed to many
  workers and the path lifecycle is owned externally.
- ``SO_REUSEADDR`` is not set (UDS has no port concept; the path
  collision is handled by the unlink step).

## Structs

### `UnixListener`

```mojo
struct UnixListener
```

A bound + listening AF_UNIX socket.

Lifecycle: ``bind(path)`` then 0..N ``accept()`` calls then an
automatic close + (optional) ``unlink(path)`` when the struct
is destroyed.

Thread safety:

```mojo
Not thread-safe. Do not call ``accept()`` concurrently.
For the multi-worker shared-listener case, hand out the
listener fd via :meth:`as_raw_fd` and have each worker
call :func:`accept_uds_fd`; that mirrors
:func:`dodo.tcp.accept_fd`.
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `UnixListener.__init__`

```mojo
def __init__(out self, var socket: RawSocket, path: String, cleanup_path: Bool)
```

Wrap an already-bound, listening ``RawSocket``.

Safety: ``socket`` must be in the listening state and
bound to ``path``.

#### `UnixListener.__deinit__`

```mojo
def __deinit__(deinit self)
```

Close the socket. If ``cleanup_path`` is ``True`` (the :meth:`bind` default), also ``unlink(2)`` the socket file so the next ``bind(path)`` doesn't have to fight a stale file. Failure to unlink is silent (the file may already have been moved / deleted by an admin).

#### `UnixListener.bind`

```mojo
def bind(path: String) raises -> Self
```

Bind a UDS listener at ``path`` with default options.

Cleans up a stale socket at ``path`` (``unlink(2)``) before
``bind(2)`` so a crashed-and-restarted server can come
back without manual intervention. The backlog is 128.

#### `UnixListener.bind_with_options`

```mojo
def bind_with_options(path: String, backlog: Int = Int(128), unlink_existing: Bool = True, cleanup_path: Bool = True) raises -> Self
```

Bind with explicit backlog + path-cleanup control.

Args:

- `path`: Filesystem path for the socket. Must fit the platform's ``sun_path`` field (108 bytes on Linux, 104 on macOS, including NUL); paths longer than that raise ``Error``.
- `backlog`: ``listen(2)`` backlog.
- `unlink_existing`: Remove a stale socket at ``path`` before ``bind(2)``: one a probe ``connect(2)`` proves nobody is listening on (``ECONNREFUSED``). A live socket, or one the probe cannot judge (``EACCES`` on a socket file the caller may not write, a socket of another type, ...), raises ``AddressInUse`` and anything that is not a socket raises ``NetworkError``; neither is touched. Defaults ``True`` so a crashed-then-restarted process recovers cleanly. Set ``False`` if you want a hard ``EADDRINUSE`` when a previous instance is still running.
- `cleanup_path`: ``unlink(path)`` on destruction. Defaults ``True``. Set ``False`` for the multi-worker shared-listener case where the path lifecycle is owned externally (e.g. by systemd).

Raises: AddressInUse: ``EADDRINUSE`` on bind. NetworkError: Other libc failures.

#### `UnixListener.accept`

```mojo
def accept(self) raises -> UnixStream
```

Block until an incoming connection arrives and return it.

Returns a connected :class:`UnixStream` whose ``peer_path``
is the empty string — UDS clients are anonymous unless they
explicitly bind() a path before connect() (rare).

#### `UnixListener.local_path`

```mojo
def local_path(self) -> String
```

Return the path the listener was bound to.

#### `UnixListener.queried_local_path`

```mojo
def queried_local_path(self) raises -> String
```

Round-trip the path through ``getsockname(2)`` — primarily for the test suite (proves we built a correctly-shaped ``sockaddr_un``). Most callers want :meth:`local_path` instead.

#### `UnixListener.as_raw_fd`

```mojo
def as_raw_fd(self) -> c_int
```

Return the underlying file descriptor.

Same contract as :meth:`dodo.tcp.TcpListener.as_raw_fd`:
the fd is borrowed, its lifetime is tied to ``self``,
callers must not ``close(fd)`` themselves.

#### `UnixListener.close`

```mojo
def close(mut self)
```

Close the listening socket. Idempotent.

Does **not** unlink the path; that happens in
:meth:`__deinit__` if ``cleanup_path`` was set.

## Functions

### `accept_uds_fd`

```mojo
def accept_uds_fd(listener_fd: Int32) raises -> UnixStream
```

Accept one connection on a borrowed listener fd.

Functionally equivalent to :meth:`UnixListener.accept` but
takes the listener as a raw integer fd, so the multi-worker
scheduler can share a single listener across worker pthreads
without any one worker owning the :class:`UnixListener`
object. Mirror of :func:`dodo.tcp.accept_fd`.

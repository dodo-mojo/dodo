# `dodo.runtime.reactor`

Reactor: the event-loop core powering dodo's single-threaded HTTP server.

The ``Reactor`` wraps ``epoll`` (Linux) and ``kqueue`` (macOS) behind a
uniform API. A single thread calls ``poll`` in a loop, then dispatches each
returned ``Event`` to the per-connection state machine.

Design:
- **One struct, comptime-dispatched backend.** No traits, no dynamic
  dispatch, no generic parameter. ``comptime if
  CompilationTarget.is_linux()`` picks between epoll and kqueue at compile
  time. The caller writes backend-agnostic code.
- **Level-triggered semantics on both platforms.** Edge-triggered is a
  possible optimisation; measure before switching.
- **Tokens are UInt64** so the reactor can fit either an fd (when we don't
  care) or a pointer-sized handle (to a per-connection state struct) into
  the same field. Internally, epoll stores the token directly in
  ``data.u64``; kqueue stores it in ``udata``.
- **Wakeup primitive included.** Linux uses ``eventfd``; macOS uses a
  self-pipe. The wakeup fd is registered internally with
  ``WAKEUP_TOKEN``; ``poll`` surfaces those events to the caller who can
  filter them via ``Event.is_wakeup()``.
- **``Movable`` but not ``Copyable``.** The reactor owns an fd; duplicating
  the struct would lead to double-close bugs.

Not handled here (by design):
- Per-fd timers: ``TimerWheel``.
- The connection state machine: ``dodo.http._reactor``.
- Multiple workers and SO_REUSEPORT: ``dodo.runtime.scheduler``.

## Structs

### `Reactor`

```mojo
struct Reactor
```

An OS-event-loop handle with a uniform API over epoll and kqueue.

Typical usage (single-threaded server loop):

```mojo
from dodo.runtime import Reactor, Event, INTEREST_READ

var reactor = Reactor()
reactor.register(listen_fd, UInt64(0), INTEREST_READ)
var events = List[Event]()
while True:
    var n = reactor.poll(-1, events)
    for i in range(n):
        var evt = events[i]
        if evt.is_wakeup():
            continue
        # dispatch by token ...
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Reactor.__init__`

```mojo
def __init__(out self) raises
```

Create a new reactor with its wakeup fd pre-registered.

Raises: NetworkError: If any of the underlying syscalls fails (epoll_create1, eventfd, pipe, kqueue, initial registration).

#### `Reactor.__deinit__`

```mojo
def __deinit__(deinit self)
```

Close the reactor fd and the wakeup fds.

#### `Reactor.register`

```mojo
def register(mut self, fd: Int32, token: UInt64, interest: Int) raises
```

Register ``fd`` with the reactor under ``token`` with the given interest bits.

Args:

- `fd`: The file descriptor to watch.
- `token`: Opaque value returned in events for this fd. Must not equal ``WAKEUP_TOKEN``.
- `interest`: Bitmask of ``INTEREST_READ | INTEREST_WRITE``.

Raises: NetworkError: If ``fd`` is already registered, ``token`` equals the sentinel, ``interest`` is 0, or the underlying syscall fails.

#### `Reactor.register_exclusive`

```mojo
def register_exclusive(mut self, fd: Int32, token: UInt64, interest: Int) raises
```

Register ``fd`` with ``EPOLLEXCLUSIVE`` semantics on Linux.

Used by the multi-worker scheduler so all workers share a single
listener fd: each worker registers the same fd in its own epoll
instance with ``EPOLLEXCLUSIVE``, and the kernel wakes only one
worker per accept-event instead of all of them. This eliminates
the SO_REUSEPORT 4-tuple-hash distribution variance that drives
head-of-line tail latency under high concurrency on this
benchmark probe.

On macOS / kqueue there is no exclusive-wakeup flag; this method
falls back to plain ``register``. Modern macOS kernels still
deliver each ``EVFILT_READ`` event to one watcher at a time on
the same listener fd (the rest see ``EAGAIN`` on ``accept``),
so the practical behaviour is similar minus the kernel-level
fairness guarantee.

Registration uses ``EPOLLIN | EPOLLEXCLUSIVE`` and deliberately
omits the ``EPOLLRDHUP`` that ``register`` adds for read interest:
``epoll_ctl(2)`` rejects that combination with ``EINVAL``. Wakeups
are exclusive, not balanced: the kernel wakes one waiting worker
per event, so a lightly loaded server may keep landing new
connections on the same worker.

``EPOLLEXCLUSIVE`` is only valid on the initial ``EPOLL_CTL_ADD``
— modifying an existing registration to add it is rejected by
the kernel. The shared-listener path therefore registers once
per worker and never modifies the listener entry.

Args:

- `fd`: Listener fd, expected to be shared across workers.
- `token`: Opaque value returned in events. Must not equal ``WAKEUP_TOKEN``.
- `interest`: Bitmask; in practice always ``INTEREST_READ`` for the listener path.

Raises: NetworkError: Same conditions as ``register``.

#### `Reactor.modify`

```mojo
def modify(mut self, fd: Int32, interest: Int) raises
```

Change the interest bits for an already-registered fd.

The token remains the same; pass the interest you want going forward.

Args:

- `fd`: Previously-registered fd.
- `interest`: New interest bits (must be non-zero).

Raises: NetworkError: If ``fd`` is not registered or the syscall fails.

#### `Reactor.unregister`

```mojo
def unregister(mut self, fd: Int32) raises
```

Remove an fd from the reactor.

Args:

- `fd`: Previously-registered fd.

Raises: NetworkError: If ``fd`` is not registered.

#### `Reactor.poll`

```mojo
def poll(mut self, timeout_ms: Int, mut out: List[Event], max_events: Int = Int(64)) raises -> Int
```

Wait for events and append them to ``out``.

The caller owns ``out`` — existing contents are replaced (cleared
first). On success returns the number of events appended. Wakeup
events are included; callers filter via ``Event.is_wakeup()``.

Args:

- `timeout_ms`: -1 = block indefinitely, 0 = poll (return immediately), positive = max milliseconds to wait.
- `out`: Output list. Cleared on entry.
- `max_events`: Maximum events to return in one call.

Returns: Number of events in ``out``.

Raises: NetworkError: On underlying syscall failure (EINTR is handled internally and returns 0).

#### `Reactor.wakeup`

```mojo
def wakeup(self) raises
```

Trigger a wakeup event so a sleeping ``poll`` returns promptly.

Safe to call from any thread (Stage 2+ will exercise this). On
Linux, writes 8 bytes to the eventfd; on macOS, writes 1 byte to the
self-pipe. Errors are swallowed because the caller has no
meaningful recovery — a dropped wakeup just means the reactor will
wait out the current timeout.

#### `Reactor.wake_fd`

```mojo
def wake_fd(self) -> Int
```

The fd another thread writes to make ``poll`` return.

Lets a peer wake this reactor without holding a reference to it
(``dodo.runtime._balance`` publishes it for connection
hand-off). Write 8 bytes; ``poll`` drains them.

#### `Reactor.registered_count`

```mojo
def registered_count(self) -> Int
```

Return the number of fds currently registered (excludes wakeup).

#### `Reactor.is_registered`

```mojo
def is_registered(self, fd: Int32) -> Bool
```

Return True if ``fd`` is currently registered on the reactor.

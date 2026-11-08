# `dodo.http.client_pool`

HTTP/1.1 client connection pool.

Idle-connection reuse for :class:`dodo.http.HttpClient`. Avoids
the per-request TCP / TLS handshake when consecutive requests
target the same origin (RFC 7230 §6.3 keep-alive semantics on the
client side).

The pool is keyed on ``(scheme, host, port)`` -- one idle deque
per origin. ``acquire(key)`` pops the most recently inserted fd
(LIFO so the warmest TCP / TLS state is reused first); ``release``
pushes the fd back onto the deque if there's room; otherwise the
fd is closed. A first read on a freshly-acquired fd that returns
0 (peer closed the keep-alive idly) signals stale, and the caller
retries on a fresh connection (RFC 7230 §6.3.1).

Scope -- the pool is deliberately kept small:

* Plain TCP (``http://``) only. ``https://`` connections are
  pooled separately by :class:`dodo.http._client.tls_pool.TlsConnectionPool`.
* No background eviction thread -- idle entries are evicted
  lazily on the next ``acquire(key)`` if their wallclock-age has
  exceeded :attr:`idle_timeout_ms`.
* Per-host cap (``max_idle_per_host``) and total cap
  (``max_idle_total``) bound memory; over-cap fds are closed
  immediately on release rather than queued.
* Synchronous, single-threaded -- the pool is owned by an
  ``HttpClient`` instance, and ``HttpClient`` is ``Movable`` (not
  ``Copyable``), so the pool is never shared across threads.
  Multi-worker pooling is a future addition.

The ``ClientPool`` struct itself is a thin handle holding the
heap address of an internal ``_ClientPoolState`` (mirrors the
Cancel / Pool ownership patterns used elsewhere in the codebase).
``HttpClient`` stores the address and re-materialises a typed
pointer on every access; on ``HttpClient.__deinit__`` the state is
freed and any remaining fds are closed.

## Structs

### `ClientPool`

```mojo
struct ClientPool
```

Idle-connection pool handle.

``Copyable`` because the wrapped state is heap-allocated and
every copy points to the same ``_ClientPoolState``. The
OWNER (the original creator -- typically an
:class:`HttpClient`) is responsible for calling :meth:`free`
once it's done; copies created during normal use (e.g. by
Mojo's implicit copy on argument passing) MUST NOT call
:meth:`free`.

The pool is an HTTP/1.1 building block; see the module
docstring for scope.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `ClientPool.__init__`

```mojo
def __init__(out self, addr: Int)
```

#### `ClientPool.disabled`

```mojo
def disabled() -> Self
```

Return the no-op handle (``_addr == 0``).

Equivalent to ``HttpClient(...)`` without pooling: every
:meth:`acquire` returns ``-1`` and every :meth:`release`
closes the fd immediately.

#### `ClientPool.new`

```mojo
def new(max_idle_per_host: Int = Int(8), max_idle_total: Int = Int(64), idle_timeout_ms: Int = Int(90000)) raises -> Self
```

Allocate a fresh pool with the given caps.

Args:

- `max_idle_per_host`: Per-origin idle cap (RFC 7230 §6.3 keep-alive parallelism budget). 0 disables idle-keeping for that origin.
- `max_idle_total`: Total idle cap across all origins. 0 disables the total cap.
- `idle_timeout_ms`: Max wallclock age for a pooled fd before it's evicted on the next acquire(key). 0 disables timeout eviction.

#### `ClientPool.enabled`

```mojo
def enabled(self) -> Bool
```

Return ``True`` when ``_addr != 0`` (pooling is on).

#### `ClientPool.build_key`

```mojo
def build_key(scheme: String, host: String, port: Int) -> String
```

Canonicalise the origin into a single-string lookup key.

Format: ``scheme://host:port``. ``port`` is always emitted
explicitly (no default-port elision) so a pooled
``http://api/`` fd can never land in an ``http://api:8080/``
bucket by accident. Used by both :meth:`acquire` and
:meth:`release`.

#### `ClientPool.acquire`

```mojo
def acquire(self, key: String) raises -> Int
```

Pop the most-recently-inserted idle fd for ``key``.

Evicts every fd whose age exceeds
:attr:`_ClientPoolState.idle_timeout_ms` before pulling
from the deque (the eviction is lazy / on-acquire, not
background-driven).

Returns: The fd, or ``-1`` when no idle entry is available (pooling disabled, deque empty, or the freshest entry was timed out).

#### `ClientPool.release`

```mojo
def release(self, key: String, fd: Int) raises
```

Hand ``fd`` back to the pool for ``key``, or close it if the cap is reached.

``fd`` must be in keep-alive shape -- the caller has
already confirmed the response was completely read AND the
server didn't send ``Connection: close``. ``release`` does
NOT validate this; it trusts the caller.

#### `ClientPool.total_idle`

```mojo
def total_idle(self) -> Int
```

Public mirror of :meth:`_total_idle` for tests + the :meth:`HttpClient.idle_count` accessor.

#### `ClientPool.free`

```mojo
def free(mut self) raises
```

Close every pooled fd and free the state.

Idempotent on ``_addr == 0``: a no-op on a moved-from /
disabled handle. After ``free`` returns, ``_addr`` is set
to ``0`` so subsequent ``__deinit__`` calls (e.g. from a
moved-from copy) are no-ops.

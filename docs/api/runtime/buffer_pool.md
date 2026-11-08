# `dodo.runtime.buffer_pool`

Per-worker, size-class-bucketed buffer pool.

Hands out and returns ``BufferHandle`` byte buffers from one of
four size classes (1 KiB / 4 KiB / 16 KiB / 64 KiB) so the
HTTP/1.1 reactor's read- and write-side temporaries don't pay
``alloc(N)`` / ``free(N)`` per request.

Background
----------

dodo's reactor reads from each accepted socket into a
``List[UInt8]`` chunk buffer (``ServerConfig.read_buffer_size``,
default 8 KiB) per ``recv(2)`` call, and serialises every
response into a second contiguous ``List[UInt8]`` before the
``send(2)`` (or ``writev(2)`` via :mod:`dodo.runtime.iovec`)
syscall. Both lists
are constructed-and-destructed once per request on the keep-alive
hot path. At realistic high-throughput targets (>200K req/s on
4 workers) that's ~1.7 M ``alloc + free`` pairs per second per
buffer side — glibc's malloc is fast but the cache-line eviction
it causes for every small allocation is not free.

The Rust analogues to look at:

* ``hyper`` keeps a per-connection 8 KiB read buffer that is
  reused for the lifetime of the connection (no realloc per
  request, no per-message-frame ``Vec::new``). The buffer is
  owned by the connection state, not pooled across connections.
* ``actix-web`` and ``axum`` (via ``hyper``) inherit the same
  shape; ``actix``'s framework adds a per-worker ``BytesMut``
  freelist for response builders.

``BufferPool`` picks the more conservative shape: a **per-worker pool
of fixed-size-class buffers** that is independent of any
connection. The reactor borrows a buffer for one request, fills
it, drains it, and returns it to the pool; the next request on
any connection (same worker) gets the same buffer back. No
cross-worker handoff, no atomic, no mutex — same per-worker
discipline as ``DateCache`` and ``ResponsePool``.

Size classes
------------

Four power-of-two classes pinned at:

* **1 KiB** — tiny payloads (most plaintext / health-check
  responses, the TFB plaintext target itself).
* **4 KiB** — typical JSON responses, typical HTTP/1.1 request
  headers + small body.
* **16 KiB** — moderate payloads (small file responses, a
  typical compressed-body buffer).
* **64 KiB** — large reads / writes (chunked-body single-chunk
  serialisation upper bound, large file-served responses).

The ``acquire(min_capacity)`` API takes a *minimum* capacity and
rounds up to the smallest size class that fits. Requests larger
than 64 KiB fall through to a one-off heap allocation that bypass
the pool — the buffer is destroyed on release rather than
recycled, so giant requests don't cause the pool to grow
unbounded.

What this module provides
-------------------------

* ``BufferHandle`` — the value moved in / out of the pool. Wraps
  a ``List[UInt8]`` plus an Int recording the size class so the
  matching pool bucket knows which class to push into on
  release. ``Movable`` (not ``Copyable``) for the same reason
  ``Response`` is.
* ``BufferPool`` — per-worker bucketed pool with the four size
  classes above. ``acquire(min_capacity) -> BufferHandle`` /
  ``release(var BufferHandle)`` shape. Each bucket is bounded
  at a small capacity (default 8 per class) so the pool's
  steady-state memory is at most ``8 * (1+4+16+64) KiB ≈
  680 KiB`` per worker.
* ``BufferPool.with_class_capacity(N)`` factory for tests and
  custom workloads.
* ``BufferPool.size_for(min_capacity) -> Int`` helper exposed
  publicly for callers that want to allocate without pooling
  but still snap to the canonical size classes (e.g. on the
  oversize fall-through path).

Storage strategy
----------------

Same as ``ResponsePool``: ``BufferHandle`` is ``Movable``
but not ``Copyable``, so each per-class bucket is a ``List[Int]``
of heap addresses managed via ``Pool[BufferHandle]``. ``acquire``
pops an address, takes the pointee, frees the cell.
``release`` moves the supplied handle into a fresh cell and
pushes the address. Net allocation cost: one ``Pool.alloc/free``
pair per acquire/release; the actual win is that the **underlying
``List[UInt8]`` capacity is preserved** across the move-in / out.

Not wired into the HTTP/1.1 reactor. ``ConnHandle.read_buf`` /
``write_buf`` are allocated once per *connection*, not per request, and
``Pool[ConnHandle].free`` genuinely destroys the handle, so the
allocation this would remove happens once per accept. On a keep-alive
workload (64 persistent connections serving millions of requests) there
is essentially nothing to save; the target is connection *churn*.

So the measurement to run before wiring is the ``churn`` config, not
``throughput``. Wiring also needs a per-worker pool threaded through
``_conn_alloc_addr`` and the accept paths, since the pool must outlive
the handles and must not be shared across threads.

## Structs

### `BufferHandle`

```mojo
struct BufferHandle
```

An owned byte buffer with a size-class tag.

``buf.bytes`` is the underlying ``List[UInt8]`` — append /
resize / clear it as a normal List. The ``class_index``
field is set by ``BufferPool.acquire`` and is consumed by
``BufferPool.release`` to find the right bucket on return.

Fields:
    bytes: The owned byte buffer. Capacity is the size class
           that the pool handed out; ``len(bytes)`` may be 0
           on first acquire and grows / shrinks via the
           caller's ``append`` / ``resize`` / ``clear``.
    class_index: 0..3 for the four standard size classes;
           ``_OVERSIZE_CLASS`` (-1) for one-off oversize
           buffers.

Fields:

- `bytes` (`List[UInt8]`)
- `class_index` (`Int`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `BufferHandle.__init__`

```mojo
def __init__(out self, capacity: Int, class_index: Int)
```

Construct a fresh handle with the requested capacity.

Args:

- `capacity`: Initial capacity to reserve in ``bytes``.
- `class_index`: 0..3 or ``_OVERSIZE_CLASS``.

#### `BufferHandle.for_class`

```mojo
def for_class(class_index: Int) -> Self
```

Construct a fresh handle for one of the standard size classes.

Args:

- `class_index`: 0..3 (1 KiB / 4 KiB / 16 KiB / 64 KiB).

Returns: A handle whose backing ``bytes`` has the matching reserved capacity.

#### `BufferHandle.reset`

```mojo
def reset(mut self)
```

Clear the buffer in place without releasing capacity.

``BufferPool.acquire`` calls this on every recycled
handle so the caller sees a length-0 buffer with the
original size-class capacity intact.

### `BufferPool`

```mojo
struct BufferPool
```

Per-worker bucketed buffer pool over four size classes.

Buckets are independent ``List[Int]`` stacks of heap-allocated
``BufferHandle`` cell addresses (managed via
``Pool[BufferHandle]``). Each bucket is capped at
``class_capacity`` (default 8) so the pool's steady-state
memory is at most ``class_capacity * (1+4+16+64) KiB ≈
680 KiB`` per worker.

Fields:
    _buckets: Length-4 list of per-class ``List[Int]`` stacks.
            The outer list is fixed-length (one entry per
            size class); the inner lists grow up to
            ``_class_capacity`` and shrink as buffers are
            acquired.
    _class_capacity: Maximum number of recycled buffers per
            size class. Releases past this cap drop the
            released handle.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `BufferPool.__init__`

```mojo
def __init__(out self)
```

Construct an empty pool with the default per-class capacity (8).

#### `BufferPool.__deinit__`

```mojo
def __deinit__(deinit self)
```

Free every retained cell across every bucket.

#### `BufferPool.with_class_capacity`

```mojo
def with_class_capacity(class_capacity: Int) -> Self
```

Construct an empty pool with a custom per-class cap.

Args:

- `class_capacity`: Maximum recycled buffers per size class. Clamped to ≥ 1.

Returns: A fresh ``BufferPool``.

#### `BufferPool.size_for`

```mojo
def size_for(min_capacity: Int) -> Int
```

Return the canonical size-class capacity for a request, or ``min_capacity`` itself if the request exceeds the largest class.

Useful for the oversize fall-through path that bypasses
the pool but still wants a deterministic capacity.

#### `BufferPool.acquire`

```mojo
def acquire(mut self, min_capacity: Int) raises -> BufferHandle
```

Return a buffer with at least ``min_capacity`` bytes of capacity, drawn from the pool if available else constructed fresh.

On a hit the returned handle's ``bytes`` is reset to
length 0 but retains the size-class capacity. On a miss
the pool constructs a fresh ``BufferHandle`` for the
right size class. Requests larger than 64 KiB skip the
pool and allocate one-off (the returned handle's
``class_index`` is ``_OVERSIZE_CLASS``, and ``release``
will drop it rather than push it into a non-existent
bucket).

Args:

- `min_capacity`: Minimum buffer capacity required.

Returns: A reset-empty ``BufferHandle`` with capacity ≥ ``min_capacity``.

#### `BufferPool.release`

```mojo
def release(mut self, var handle: BufferHandle) raises
```

Return a buffer to its size-class bucket.

Oversize handles (``class_index == _OVERSIZE_CLASS``),
releases past the per-class cap, and handles whose
``bytes.capacity()`` is below their class capacity (the
caller replaced or shrank the public ``bytes``) drop the
handle on the floor (Mojo destructor runs), so ``acquire``
always returns capacity >= ``min_capacity``.

Args:

- `handle`: Owned ``BufferHandle`` to recycle.

#### `BufferPool.size`

```mojo
def size(self, class_index: Int) -> Int
```

Return the number of recycled buffers in a class.

Out-of-range ``class_index`` returns 0.

#### `BufferPool.class_capacity`

```mojo
def class_capacity(self) -> Int
```

Return the per-class capacity cap.

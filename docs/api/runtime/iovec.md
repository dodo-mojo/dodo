# `dodo.runtime.iovec`

``writev(2)`` vectored-I/O primitive.

Provides ``IoVecBuf`` — a typed wrapper around a heap-allocated
``struct iovec[]`` array — and the high-level ``writev_buf_all``
helper that loops over partial writes until every byte across
every vector has been sent.

Background
----------

dodo's HTTP/1.1 response serializer today copies the status
line + every header + the body into a single contiguous
``List[UInt8]`` and calls ``send(2)`` once. The ``memcpy`` of
the body into that intermediate buffer is the dominant
allocation + copy cost on every response — for a 1 KiB body
that's a 1 KiB ``memcpy`` per request that doesn't actually
need to move bytes (the body is already in some other
``List[UInt8]`` owned by the handler).

``writev(2)`` lets the kernel scatter-gather a list of
``iovec`` cells (each a ``{ ptr, len }`` pair) into one TCP
segment without touching the body bytes from userspace. For
the same 1 KiB body case, the response serializer can pass:

* iovec[0] = status line bytes (≤ ~30 B)
* iovec[1] = header block bytes (~100-500 B)
* iovec[2] = body bytes (untouched, borrowed)

…and skip the ``memcpy``. On a workload where the body is
already a long-lived ``List[UInt8]`` (any handler that returns
a precomputed payload), this is a strict win.

This is the same approach hyper / actix-web / axum take at the
H1 layer: hyper's ``h1::role::Server::encode`` builds an
``EncodedBuf`` of multiple slices and passes them to
``Tokio``'s ``write_vectored`` (which is ``writev`` on
epoll/kqueue, ``WSASend`` on IOCP).

What this module provides (only the primitive)
----------------------------------------------

* ``IoVecBuf(n)`` — allocates a heap region of
  ``n * sizeof(struct iovec)`` bytes (16 B per cell on every
  64-bit Linux / macOS target). Callers populate cells via
  ``set(i, ptr, len)``.
* ``IoVecBuf.size_for(n) -> Int`` — exposes the byte-count
  computation for callers that want to ``stack_allocation`` an
  iovec array themselves.
* ``writev_buf(fd, iov_base, iovcnt) -> Int`` — single
  ``writev(2)`` call with EINTR retry. Returns bytes written
  on success; raises on EAGAIN / EPIPE / etc. (matches
  ``TcpStream.write`` semantics).
* ``writev_buf_all(fd, iov_base, iovcnt, total_bytes)`` —
  loops over partial writes by advancing through the iovec
  list until every byte across every cell is written. Updates
  the iovec cells in-place (advances ``iov_base[i].iov_base``
  / shrinks ``iov_base[i].iov_len`` for cells that were
  partially written).

The HTTP/1.1 response serializer does not use it: the chunked write
path measured the copy it would save and kept one contiguous buffer
(see ``dodo/http/response_stream.mojo``).

iovec layout
------------

On every supported target (64-bit Linux + macOS), the C
``struct iovec`` is 16 bytes::

```mojo
struct iovec {
    void  *iov_base;  // 8 bytes
    size_t iov_len;   // 8 bytes
};
```

This module models the array as a flat ``Pointer[UInt8]``
buffer of ``n * 16`` bytes, with ``set(i, ptr, len)`` writing
the two 8-byte words at the right offset. Reading the buffer
back via ``writev(2)`` gets the layout the kernel expects.

## Structs

### `IoVecBuf`

```mojo
struct IoVecBuf
```

A heap-allocated ``struct iovec[n]`` array.

Owns the underlying buffer; frees on drop. Callers populate
cells via ``set(i, ptr, len)``; the buffer's base pointer is
exposed via ``base()`` for the ``writev(2)`` call.

Fields:
    _buf: The owning heap pointer to the raw byte buffer
          that backs the iovec array.
    _n: Number of iovec cells the buffer holds. Bounded
        on construction; cells are NOT bounds-checked at
        ``set`` time for performance.

Example:
```mojo
var iov = IoVecBuf(3)
iov.set(0, status_line_ptr, status_line_len)
iov.set(1, headers_ptr, headers_len)
iov.set(2, body_ptr, body_len)
var n = writev_buf(fd, iov.base(), 3)
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `IoVecBuf.__init__`

```mojo
def __init__(out self, n: Int)
```

Construct a buffer holding ``n`` iovec cells.

Args:

- `n`: Number of cells. Must be > 0.

#### `IoVecBuf.__deinit__`

```mojo
def __deinit__(deinit self)
```

Free the underlying buffer.

#### `IoVecBuf.size_for`

```mojo
def size_for(n: Int) -> Int
```

Return the byte size of an iovec array of ``n`` cells.

Useful for ``stack_allocation`` callers that want to
avoid a heap allocation entirely::

```mojo
var raw = stack_allocation[IoVecBuf.size_for(3), UInt8]()
```

#### `IoVecBuf.base`

```mojo
def base(self) -> Pointer[UInt8, MutUntrackedOrigin]
```

Return the buffer's base pointer (suitable as the ``iov`` arg to ``writev_buf``).

#### `IoVecBuf.count`

```mojo
def count(self) -> Int
```

Return the number of cells in the buffer.

#### `IoVecBuf.set`

```mojo
def set(mut self, i: Int, ptr: Int, n: Int)
```

Write the i'th iovec cell.

Args:

- `i`: Cell index. Bounds-checked under ``-D ASSERT=safe`` (the default). The check uses ``debug_assert`` rather than ``std.collections.check_bounds`` because ``check_bounds`` requires the call site to be ``@always_inline`` (it relies on ``call_location[inline_count=2]()``); the per-call cost of inlining ``set`` here would bloat every keep-alive serialiser site without a measurable win. See ``.agent/rules/sanitizers-and-bounds-checking.mdc`` §3 / §4 for the rationale.
- `ptr`: ``iov_base`` value (typically ``Int(some_buffer.unsafe_ptr())``).
- `n`: ``iov_len`` value (number of bytes at ``ptr``).

#### `IoVecBuf.cell_ptr`

```mojo
def cell_ptr(self, i: Int) -> Int
```

Read back the i'th cell's ``iov_base``.

Useful for tests + the ``writev_buf_all`` partial-write
loop that needs to advance the ptr after a short write.
Bounds-checked under ``-D ASSERT=safe``.

#### `IoVecBuf.cell_len`

```mojo
def cell_len(self, i: Int) -> Int
```

Read back the i'th cell's ``iov_len``.

Bounds-checked under ``-D ASSERT=safe``.

## Functions

### `writev_buf`

```mojo
def writev_buf(fd: Int, iov_base: Pointer[UInt8], iovcnt: Int) raises -> Int
```

Single ``writev(2)`` call with EINTR retry.

Returns the number of bytes the kernel accepted across all
iovec cells (may be less than the total — the caller is
responsible for any partial-write loop; use
``writev_buf_all`` for the looped variant).

Args:

- `fd`: Open socket / file descriptor.
- `iov_base`: Pointer to the iovec array (typically ``IoVecBuf.base()``).
- `iovcnt`: Number of cells in the array.

Returns: Bytes written on success.

Raises: BrokenPipe: ``EPIPE`` from the kernel. ConnectionReset: ``ECONNRESET`` from the kernel. Timeout: ``EAGAIN`` / ``EWOULDBLOCK`` (matches ``TcpStream.write`` semantics on a non-blocking socket with a send timeout). NetworkError: For any other libc errno.

### `writev_buf_all`

```mojo
def writev_buf_all(mut iov: IoVecBuf, fd: Int, total_bytes: Int) raises
```

Write every byte across every cell, advancing through the iovec array on partial writes.

Updates the cells in ``iov`` in place: a cell that was
partially written has its ``iov_base`` advanced and its
``iov_len`` shrunk; a fully-written cell is zeroed
(``{ NULL, 0 }``). The kernel ignores zero-length cells, so
leaving them in the array is harmless.

Args:

- `iov`: The iovec buffer; cells are mutated in place.
- `fd`: Open socket / file descriptor.
- `total_bytes`: Sum of ``iov_len`` across every cell at entry. Used to terminate the loop without re-summing the cells on every iteration.

Raises: BrokenPipe / ConnectionReset / Timeout / NetworkError: Per ``writev_buf`` semantics. ``NetworkError`` is also raised if ``writev`` returns 0 while bytes remain (it made no progress, or ``total_bytes`` exceeds what the cells hold): a normal return always means every byte was written.

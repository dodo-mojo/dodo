# `dodo.http.response_stream`

Streaming-response plumbing for the normal Handler path.

The reactor serves a buffered ``Response`` by serialising its whole
``body`` up front. To stream an open-ended body (SSE, a log tail, a
large download, incremental gRPC) through the *same*
``Handler.serve -> Response`` contract, a ``Response`` can carry a
type-erased chunk source that the reactor pulls in bounded batches per
writable edge and frames as ``Transfer-Encoding: chunked``.

This module is the source side, free of any reactor coupling so it
can be tested on its own:

- ``ChunkSourceBox``: a move-only, type-erased box over any
  :trait:`dodo.http.body.ChunkSource`. It heap-allocates the concrete
  source via ``Pool[S]`` and captures monomorphised ``next`` / destroy
  thunks, so ``Response`` and the reactor's ``ConnHandle`` can
  hold and drive a source without being generic over its type.
- Chunked-framing helpers (``frame_chunk_into`` / ``frame_terminator_into``)
  that emit RFC 9112 sec 7.1 chunk framing into a reused buffer.

**writev verdict: not adopted.** ``frame_chunk_into`` copies each
payload into the connection's ``write_buf`` so one ``send(2)`` covers a
whole batch of chunks. ``dodo.runtime.iovec`` could skip that copy, at
the cost of keeping every pulled chunk alive across the syscall and of a
second, cleartext-only send path (TLS needs contiguous bytes for
``SSL_write``). Profiled instead: at 70k req/s on ``/stream``,
``ConnHandle.on_writable`` -- which inlines this framing and the copy --
is 2.05 % of cycles, while ``__send`` is 61.7 % inclusive (kernel) and
the source's own per-chunk ``next`` allocation is 14.9 %. The copy is not
the cost center, so writev is not worth the second path. Revisit only if
a profile puts the framing copy above the syscall.

## Aliases

### `STREAM_BATCH_CHUNKS`

```mojo
comptime STREAM_BATCH_CHUNKS = Int(16)
```

Max chunks a reactor drains from one source per batch.

### `STREAM_BATCH_BYTES`

```mojo
comptime STREAM_BATCH_BYTES = Int(65536)
```

Max bytes a reactor queues from one source per batch.

Whichever cap is hit first ends the batch. Shared by the h1 and h2
connection handles so both wires yield to their peers on the same
budget: without one, a single endless source would hold the worker.

## Structs

### `ChunkSourceBox`

```mojo
struct ChunkSourceBox
```

Move-only, type-erased owner of a heap-boxed ``ChunkSource``.

Built via :meth:`create`; drives the source via :meth:`next`; frees
the box exactly once on drop (or when moved-from, ownership
transfers so the destructor runs only on the final owner). The
reactor takes the box out of a ``Response`` onto its per-connection
state and pulls ``next(cancel)`` in bounded batches per writable
edge until it returns ``None`` (end-of-stream).

Fields:

- `addr` (`Int`): Heap address of the boxed concrete source (0 = empty / moved-from).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `ChunkSourceBox.__init__`

```mojo
def __init__(out self, addr: Int, next_fn: def(Int, Cancel) raises thin -> Optional[List[UInt8]], destroy_fn: def(Int) thin -> None)
```

#### `ChunkSourceBox.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `ChunkSourceBox.create`

```mojo
def create[S: ChunkSource](var source: S) raises -> Self
```

Heap-box ``source`` and capture its monomorphised thunks.

#### `ChunkSourceBox.next`

```mojo
def next(mut self, cancel: Cancel) raises -> Optional[List[UInt8]]
```

Pull the next chunk, or ``None`` at end-of-stream.

## Functions

### `frame_chunk_into`

```mojo
def frame_chunk_into(mut buf: List[UInt8], chunk: List[UInt8])
```

Append one framed chunk ``{hexlen}\r\n{bytes}\r\n`` to ``buf``.

``chunk`` MUST be non-empty: a zero-length chunk is the terminator
(see :func:`frame_terminator_into`), so callers skip empty chunks
rather than framing them here.

### `frame_terminator_into`

```mojo
def frame_terminator_into(mut buf: List[UInt8])
```

Append the last-chunk terminator ``0\r\n\r\n`` (no trailers).

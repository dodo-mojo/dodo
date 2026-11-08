# `dodo.http.async_body`

Reactor-integrated external streaming source.

The synchronous ``ChunkSource`` (``dodo.http.body``) is a *pull*: each
``next`` returns the next chunk or ``None`` for EOF. That is exactly
right for an in-process FIFO (e.g. ``SseChannel``) but it can never
*wait* -- it has no way to say "nothing yet, the bytes are coming on
another fd." A streaming proxy whose chunks arrive on a UDS / pipe /
eventfd needs that third state, or every front re-implements an epoll
loop and a hand-rolled fd->client copy.

This module adds the missing state as a small, total API:

- ``ChunkPoll`` -- a tri-state poll result. Exactly one of: a ready
  chunk, "pending, wake me on this fd", or EOF. The three states are
  constructed by named factories (``ready`` / ``pending`` / ``eof``) and
  read by predicates, so an illegal combination (a chunk *and* a wait fd)
  is unrepresentable.
- ``AsyncChunkSource`` -- the async sibling of ``ChunkSource``: one
  method, ``poll(cancel) -> ChunkPoll``. Synchronous sources keep using
  ``ChunkSource``; this is purely additive.
- ``UpstreamChunkSource`` -- the concrete impl a streaming proxy needs:
  a single framed logical stream over a non-blocking connection. It
  composes the frame codec (``FrameDemux``) for parsing and reports
  ``pending(fd)`` on EAGAIN so the reactor parks instead of busy-polling.

Composition with the typed streaming surface
--------------------------------------------

A handler drives an ``AsyncChunkSource`` with no bespoke reactor code,
no file descriptors, and no per-connection bookkeeping -- attach the
source and let the framework pump it::

```mojo
def on_open(mut self, mut conn: StreamConn) raises:
    conn.attach_upstream(UpstreamChunkSource.connect(self.worker))

def on_upstream(mut self, mut conn: StreamConn) raises:
    conn.relay_upstream()              # drains ready chunks, EOF -> close
```

``attach_upstream`` takes the source (it reads the fd to watch
internally and owns the source for the connection's lifetime, closing
it on teardown), and ``relay_upstream`` is the standard drain loop:
pull ready chunks into the client with backpressure, request close on
EOF, park on pending. A front that needs custom per-chunk handling can
still drive the source directly via ``conn.upstream().poll(...)``.

The reactor calls ``on_upstream`` only when the attached fd is readable,
so the ``pending`` branch is a genuine park, not a poll loop (no
busy-poll between gaps). Watermark backpressure additionally gates the
*upstream* read interest when the client is write-blocked.

## Structs

### `ChunkPoll`

```mojo
struct ChunkPoll
```

The result of one ``AsyncChunkSource.poll`` -- a total tri-state.

Exactly one state holds:

- **ready**: a chunk is available now (``is_ready()``; take it with
  ``take_chunk()``).
- **pending**: nothing yet; the caller should wait until ``wait_fd()``
  is readable and poll again (``is_pending()``). No busy-poll.
- **eof**: the stream is complete; no more chunks (``is_eof()``).

Built only through ``ready`` / ``pending`` / ``eof`` so a chunk can
never coexist with a wait fd.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `ChunkPoll.__init__`

```mojo
def __init__(out self, _state: Int, var chunk: List[UInt8], fd: Int32)
```

Internal: prefer the ``ready`` / ``pending`` / ``eof`` factories.

#### `ChunkPoll.ready`

```mojo
def ready(var chunk: List[UInt8]) -> Self
```

A chunk is available now.

#### `ChunkPoll.pending`

```mojo
def pending(fd: Int32) -> Self
```

Nothing yet; wake and re-poll when ``fd`` is readable.

#### `ChunkPoll.eof`

```mojo
def eof() -> Self
```

The stream is complete.

#### `ChunkPoll.is_ready`

```mojo
def is_ready(self) -> Bool
```

True if a chunk is available now.

#### `ChunkPoll.is_pending`

```mojo
def is_pending(self) -> Bool
```

True if the source is waiting on ``wait_fd()``.

#### `ChunkPoll.is_eof`

```mojo
def is_eof(self) -> Bool
```

True if the stream is complete.

#### `ChunkPoll.wait_fd`

```mojo
def wait_fd(self) -> c_int
```

The fd to wait on (valid only when ``is_pending()``; ``-1`` otherwise).

#### `ChunkPoll.take_chunk`

```mojo
def take_chunk(mut self) -> List[UInt8]
```

Move the ready chunk out (valid only when ``is_ready()``; leaves the poll holding an empty chunk).

#### `ChunkPoll.consume`

```mojo
def consume(mut self) raises -> Optional[List[UInt8]]
```

Collapse the ready/eof split into one move-out.

Returns ``Some(chunk)`` when a chunk is ready (moved out, as
``take_chunk``) and ``None`` on EOF. Raises on ``pending``: a
pending poll must be parked on ``wait_fd()`` and re-polled, never
consumed. This is the one-call form for callers that drain to EOF
and have already handled the pending branch (the reactor only
delivers an upstream edge when the fd is readable, so a relay loop
sees only ready / eof).

### `UpstreamChunkSource`

```mojo
struct UpstreamChunkSource
```

One framed logical stream over a non-blocking connection.

Owns a ``UnixStream`` to a worker and reads frames for a single
``request_id`` off it. ``poll`` drains any buffered ``CHUNK`` frame,
else does one non-blocking read: a completed ``CHUNK`` -> ``ready``;
a ``DONE`` / connection EOF -> ``eof``; ``EAGAIN`` -> ``pending(fd)``
so the reactor waits on the fd instead of spinning; ``ERROR`` raises.

The frame parsing is the same ``FrameDemux`` the multiplexed
``FrameMux`` uses, so a worker can speak one wire shape to both
the single-stream and multiplexed fronts.

One source owns one connection (a dedicated framed link).
The many-streams-over-one-connection case is the handler owning a
``FrameMux`` as shared state and driving it directly; a future
``FrameMux.open`` returning a lightweight per-stream handle is the
multiplexed evolution (it needs a shared-mux reference the fixed
trait method cannot carry).

Fields:

- `conn` (`UnixStream`): The owned framed upstream connection (set non-blocking at init).
- `demux` (`FrameDemux`): Frame reassembly for the inbound byte stream.
- `request_id` (`UInt64`): The single logical stream this source reads.

Implemented traits: `AnyType`, `AsyncChunkSource`, `Deinitable`, `Movable`

#### `UpstreamChunkSource.__init__`

```mojo
def __init__(out self, var conn: UnixStream, request_id: UInt64 = UInt64(1)) raises
```

Adopt ``conn`` (switched to non-blocking) for ``request_id``.

``request_id`` defaults to ``1`` -- a dedicated single-stream link
carries one logical stream, so the id is meaningful only when a
front multiplexes several streams over one connection.

#### `UpstreamChunkSource.connect`

```mojo
def connect(path: String, request_id: UInt64 = UInt64(1)) raises -> Self
```

Open a dedicated framed upstream over the UDS at ``path``.

The one-call convenience: dials the worker and adopts the
connection, so a front never assembles a ``UnixStream`` by hand
just to feed it here. Mirrors ``UnixStream.connect`` /
``TcpStream.connect``.

```mojo
var src = UpstreamChunkSource.connect("/run/backend.sock")
```

#### `UpstreamChunkSource.fd`

```mojo
def fd(self) -> c_int
```

The upstream fd to register / wait on (for ``attach_upstream``).

#### `UpstreamChunkSource.send_cancel`

```mojo
def send_cancel(mut self) raises
```

Emit a CANCEL frame for this ``request_id`` upstream.

Tells the backend to stop producing tokens nobody will read --
e.g. the client disconnected mid-generation. Idempotent and
best-effort framed (a 13-byte CANCEL fits one write); after this
the source is EOF. Call it from a front's ``on_close`` when the
connection's ``cancel`` is set, and ``poll`` calls it too when it
observes cancellation on an upstream edge.

#### `UpstreamChunkSource.poll`

```mojo
def poll(mut self, cancel: Cancel) raises -> ChunkPoll
```

Drain a ready frame, else one non-blocking read; never blocks.

## Traits

### `AsyncChunkSource`

```mojo
trait AsyncChunkSource
```

A byte-chunk source whose chunks may arrive on a registered fd.

The async sibling of ``ChunkSource``: instead of a blocking pull,
``poll`` returns immediately with one of the three ``ChunkPoll``
states. A source that has data returns ``ready``; a source still
waiting for bytes on its fd returns ``pending(fd)`` (the caller parks
the response on that fd); a finished source returns ``eof``.

Implementors must not block in ``poll`` -- that is the whole point.
The ``cancel`` token lets a source short-circuit on client FIN /
deadline / drain.

Inherits from: `AnyType`, `Deinitable`, `Movable`

#### `AsyncChunkSource.poll`

```mojo
def poll(mut self, cancel: Cancel) raises -> ChunkPoll
```

Return the next chunk, a pending-on-fd signal, or EOF.

Args:

- `cancel`: Per-request cancel token; poll it to abort early.

Returns: A ``ChunkPoll``: ``ready`` / ``pending`` / ``eof``.

Raises: Error: On an unrecoverable source error; the reactor closes the connection.

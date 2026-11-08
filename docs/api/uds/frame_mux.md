# `dodo.uds.frame_mux`

Multiplexed duplex framed transport over one connection.

A streaming-proxy front otherwise opens one backend connection *per
request* -- fd churn and a connect(2) round trip on the hot path at high
concurrency, plus an ad-hoc length prefix re-invented at each call site.
This module replaces that with a persistent multiplexed transport: many
concurrent logical streams ride one ``UnixStream``, demuxed by a 64-bit
``request_id``, framed once here.

Wire frame (all integers big-endian)::

```mojo
| u32 payload_len | u64 request_id | u8 kind | payload[payload_len] |
```

``kind`` is one of ``FrameKind.{OPEN, CHUNK, DONE, ERROR, CANCEL}``. The
13-byte fixed header means a reader knows the full frame size after the
first 13 bytes, so partial reads reassemble deterministically.

Three layers, smallest first (each is independently testable):

- ``encode_frame`` / ``decode_frame`` -- the pure codec over
  ``ByteWriter`` / ``ByteReader``. No I/O, no allocation beyond the
  payload copy. This is the fuzz/ASan core.
- ``FrameDemux`` -- a sans-I/O reassembly buffer: ``feed(bytes)`` appends
  raw bytes (possibly splitting or coalescing frames arbitrarily) and
  routes every *complete* frame into a per-``request_id`` FIFO inbox.
  ``poll(id)`` / ``take_all(id)`` drain a stream's inbox. One stream's
  malformed payload never reaches another stream's inbox (isolation);
  frames within a stream keep arrival order (ordering).
- ``FrameMux`` -- ties a ``FrameDemux`` and an outbound ``ByteWriter`` to
  one owned ``UnixStream``: ``open`` / ``send_chunk`` / ``done`` /
  ``cancel`` queue outbound frames, ``flush`` writes them, ``pump`` reads
  inbound bytes and demuxes. No call ever reconnects -- the connection is
  opened once and owned for the mux's lifetime.

``FrameDemux`` accumulates into a single ``List[UInt8]`` and
compacts the consumed prefix after each drain (so a slow consumer cannot
make the buffer grow without bound across the *consumed* bytes). The
limit is one in-flight frame's payload held contiguously; a frame
larger than ``MAX_FRAME_PAYLOAD`` is rejected as a protocol error rather
than allocated. ``open`` returns nothing here; the single-stream
``UpstreamChunkSource`` (``dodo.http.async_body``) is the reactor-
integrated wrapper over one logical stream.

## Aliases

### `HEADER_LEN`

```mojo
comptime HEADER_LEN = Int(13)
```

Fixed frame header size: u32 len + u64 request_id + u8 kind.

### `MAX_FRAME_PAYLOAD`

```mojo
comptime MAX_FRAME_PAYLOAD = Int(67108864)
```

Reject any frame claiming a payload larger than this (protocol-error guard against a corrupt/hostile 4-byte length blowing up allocation). 64 MiB is generous for a token-streaming relay; raise it only with a matching backpressure story.

## Structs

### `FrameKind`

```mojo
struct FrameKind
```

The five frame kinds. Plain ``UInt8`` tags (no enum in b2).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `OPEN = UInt8(0)`: Begin a logical stream for ``request_id``.
- `CHUNK = UInt8(1)`: A payload chunk for an open stream.
- `DONE = UInt8(2)`: Stream completed normally; no more frames for this id.
- `ERROR = UInt8(3)`: Stream failed; payload may carry a diagnostic. Isolated to this id.
- `CANCEL = UInt8(4)`: Caller abandoned the stream; peer should stop producing.

### `Frame`

```mojo
struct Frame
```

One decoded frame: ``request_id`` + ``kind`` + owned ``payload``.

Fields:

- `request_id` (`UInt64`): The logical stream this frame belongs to.
- `kind` (`UInt8`): One of ``FrameKind.*``.
- `payload` (`List[UInt8]`): Owned payload bytes (empty for OPEN/DONE/CANCEL typically).

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Frame.__init__`

```mojo
def __init__(out self, request_id: UInt64, kind: UInt8, var payload: List[UInt8])
```

### `FrameDemux`

```mojo
struct FrameDemux
```

Sans-I/O frame reassembler with per-stream inboxes.

Feed it arbitrary byte runs (frames may be split across feeds or
several frames may arrive in one feed); it routes every complete
frame into a FIFO keyed by ``request_id``.

Fields:

- `buf` (`List[UInt8]`): Bytes received but not yet forming a complete frame's worth past the parse cursor. Compacted after each drain.
- `inbox` (`Dict[UInt64, List[Frame]]`): Per-stream FIFO of decoded frames awaiting consumption.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `FrameDemux.__init__`

```mojo
def __init__(out self)
```

#### `FrameDemux.feed`

```mojo
def feed(mut self, data: Span[UInt8]) raises
```

Append ``data`` and route every complete frame now available.

Raises only on a protocol error (a payload length above
``MAX_FRAME_PAYLOAD``); a merely incomplete trailing frame is
retained for the next ``feed``. Frames routed before the bad header
stay routed exactly once (they are consumed from the buffer before
the raise); the connection is unusable afterwards, since every
later ``feed`` raises on the same header.

#### `FrameDemux.poll`

```mojo
def poll(mut self, request_id: UInt64) raises -> Optional[Frame]
```

Pop the oldest queued frame for ``request_id`` (FIFO), or ``None`` if its inbox is empty / absent.

#### `FrameDemux.pending`

```mojo
def pending(self, request_id: UInt64) raises -> Int
```

Number of queued frames for ``request_id``.

#### `FrameDemux.drop`

```mojo
def drop(mut self, request_id: UInt64) raises
```

Discard a stream's inbox entirely (e.g. after CANCEL).

### `FrameMux`

```mojo
struct FrameMux
```

Multiplexes many logical streams over one owned ``UnixStream``.

Outbound frames are queued in ``out`` and written by ``flush``;
inbound bytes are read by ``pump`` and demuxed into per-stream
inboxes drained via ``poll`` / ``pending``. The connection is opened
once by the caller and owned here -- no method ever reconnects.

Fields:

- `stream` (`UnixStream`): The single owned backend connection.
- `demux` (`FrameDemux`): Inbound reassembly + per-stream inboxes.
- `out` (`ByteWriter`): Queued outbound frame bytes (flushed by ``flush``).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `FrameMux.__init__`

```mojo
def __init__(out self, var stream: UnixStream)
```

#### `FrameMux.next_id`

```mojo
def next_id(mut self) -> UInt64
```

Allocate a fresh, never-reused ``request_id``.

#### `FrameMux.open`

```mojo
def open(mut self, request_id: UInt64) raises
```

Queue an OPEN frame to begin ``request_id``. No connect(2).

#### `FrameMux.send_chunk`

```mojo
def send_chunk(mut self, request_id: UInt64, payload: Span[UInt8]) raises
```

Queue a CHUNK frame carrying ``payload`` for ``request_id``.

#### `FrameMux.done`

```mojo
def done(mut self, request_id: UInt64) raises
```

Queue a DONE frame closing ``request_id`` normally.

#### `FrameMux.cancel`

```mojo
def cancel(mut self, request_id: UInt64) raises
```

Queue a CANCEL frame and drop the local inbox for ``request_id`` (the upstream-cancel path builds on this).

#### `FrameMux.flush`

```mojo
def flush(mut self) raises
```

Write all queued outbound frames to the connection.

#### `FrameMux.pump`

```mojo
def pump(mut self, max_bytes: Int = Int(65536)) raises -> Int
```

Read up to ``max_bytes`` inbound bytes and demux them.

Returns the number of bytes read (0 means the peer closed the
connection). Routes any complete frames into per-stream inboxes.

#### `FrameMux.poll`

```mojo
def poll(mut self, request_id: UInt64) raises -> Optional[Frame]
```

Pop the oldest reassembled frame for ``request_id``.

#### `FrameMux.pending`

```mojo
def pending(self, request_id: UInt64) raises -> Int
```

Queued inbound frame count for ``request_id``.

## Functions

### `encode_frame`

```mojo
def encode_frame(mut w: ByteWriter, request_id: UInt64, kind: UInt8, payload: Span[UInt8]) raises
```

Append one framed message to ``w``.

Raises if ``payload`` exceeds ``MAX_FRAME_PAYLOAD`` (the same ceiling
the decoder enforces, so an encoder cannot emit a frame its own
decoder would reject).

### `decode_frame`

```mojo
def decode_frame(mut r: ByteReader) raises -> Frame
```

Decode exactly one frame from ``r`` (which must hold a full frame).

Raises on a short buffer (via ``ByteReader``) or a payload length
above ``MAX_FRAME_PAYLOAD``. Used by ``FrameDemux``; also directly
fuzzable.

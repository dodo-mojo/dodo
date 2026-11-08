# `dodo.http2.state`

HTTP/2 state machines (RFC 9113 §5).

This module pairs the byte-level :mod:`frame` codec and the
:mod:`hpack` codec with the per-stream / per-connection state
machines that make a sequence of frames a *valid* HTTP/2 session.

What lives here:

- :class:`StreamState` — the 6 RFC 9113 §5.1 stream states.
- :class:`Stream` — per-stream record (id, state, flow-control
  windows, accumulated header / data buffers).
- :class:`Connection` — connection-level state: open streams,
  next-stream-id watermark, peer + local SETTINGS, the receive
  window, and the GOAWAY / RST_STREAM machinery.
- :class:`Http2Error` — typed connection / stream errors with their
  RFC 9113 §7 error codes.

The state machine is enforced by :meth:`Connection.handle_frame`
which is the one entry point higher layers (the server reactor)
call for every parsed frame. Returns a list of *outgoing* frames
the caller must enqueue (e.g. SETTINGS ACK, RST_STREAM, GOAWAY).

Connection-level concerns *not* implemented :

- Priority dependency tree (deprecated by RFC 9113 §5.3.2 — frames
  are accepted and ignored).
- Server push (we never originate PUSH_PROMISE).

## Aliases

### `StreamId`

```mojo
comptime StreamId = Int
```

## Structs

### `Http2ErrorCode`

```mojo
struct Http2ErrorCode
```

One of the 14 RFC 9113 §7 error codes.

Fields:

- `value` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `Http2ErrorCode.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, v: Int)
```

#### `Http2ErrorCode.NO_ERROR`

```mojo
def NO_ERROR() -> Self
```

#### `Http2ErrorCode.PROTOCOL_ERROR`

```mojo
def PROTOCOL_ERROR() -> Self
```

#### `Http2ErrorCode.INTERNAL_ERROR`

```mojo
def INTERNAL_ERROR() -> Self
```

#### `Http2ErrorCode.FLOW_CONTROL_ERROR`

```mojo
def FLOW_CONTROL_ERROR() -> Self
```

#### `Http2ErrorCode.SETTINGS_TIMEOUT`

```mojo
def SETTINGS_TIMEOUT() -> Self
```

#### `Http2ErrorCode.STREAM_CLOSED`

```mojo
def STREAM_CLOSED() -> Self
```

#### `Http2ErrorCode.FRAME_SIZE_ERROR`

```mojo
def FRAME_SIZE_ERROR() -> Self
```

#### `Http2ErrorCode.REFUSED_STREAM`

```mojo
def REFUSED_STREAM() -> Self
```

#### `Http2ErrorCode.CANCEL`

```mojo
def CANCEL() -> Self
```

#### `Http2ErrorCode.COMPRESSION_ERROR`

```mojo
def COMPRESSION_ERROR() -> Self
```

#### `Http2ErrorCode.ENHANCE_YOUR_CALM`

```mojo
def ENHANCE_YOUR_CALM() -> Self
```

### `Http2Error`

```mojo
struct Http2Error
```

A typed HTTP/2 error. ``stream_id == 0`` means connection error.

Fields:

- `code` (`Http2ErrorCode`)
- `stream_id` (`Int`)
- `debug` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `Http2Error.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, var code: Http2ErrorCode, stream_id: Int, var debug: String)
```

### `StreamState`

```mojo
struct StreamState
```

Stream lifecycle states. Numeric values are intentional.

Fields:

- `value` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `StreamState.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, v: Int)
```

#### `StreamState.IDLE`

```mojo
def IDLE() -> Self
```

#### `StreamState.OPEN`

```mojo
def OPEN() -> Self
```

#### `StreamState.HALF_CLOSED_LOCAL`

```mojo
def HALF_CLOSED_LOCAL() -> Self
```

#### `StreamState.HALF_CLOSED_REMOTE`

```mojo
def HALF_CLOSED_REMOTE() -> Self
```

#### `StreamState.CLOSED`

```mojo
def CLOSED() -> Self
```

### `Stream`

```mojo
struct Stream
```

Per-stream record.

Fields:

- `id` (`StreamId`)
- `state` (`StreamState`)
- `headers` (`List[HpackHeader]`)
- `initial_header_count` (`Int`)
- `data` (`List[UInt8]`)
- `received_body_bytes` (`Int`)
- `response_body_allowed` (`Bool`)
- `defer_body_credit` (`Bool`): Return DATA credit on body drains for a streaming response reader.
- `pending_body_credit` (`Int`)
- `send_window` (`Int`)
- `recv_window` (`Int`)
- `headers_complete` (`Bool`)
- `data_complete` (`Bool`)
- `header_list_bytes` (`Int`): Running RFC 9113 6.5.2 header-list size (sum of ``name + value + 32`` over every field decoded so far for this stream, across HEADERS + CONTINUATION). Enforced against the connection cap to reject oversized header blocks.
- `continuation_count` (`Int`): CONTINUATION frames seen for this stream's header block; capped to stop a CONTINUATION flood.
- `content_length` (`Int`): Declared ``content-length``, or ``-1`` when absent. RFC 9113 sec 8.1.2.6 makes a mismatch against the DATA actually received a malformed request.
- `response_started` (`Bool`): Set once a response has been scheduled for this stream.
- `extended_connect_protocol` (`String`): RFC 8441 ``:protocol`` pseudo-header value when the stream was opened with ``:method = CONNECT``. Empty string otherwise. The unified WebSocket-over-HTTP/2 dispatcher uses this to route ``"websocket"`` Extended CONNECT streams to the WS handler instead of treating them as a regular CONNECT proxy request.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`, `SlabEntry`

#### `Stream.__init__`

```mojo
def __init__(out self)
```

#### `Stream.slab_active`

```mojo
def slab_active(self) -> Bool
```

#### `Stream.slab_ready`

```mojo
def slab_ready(self) -> Bool
```

A request fully buffered and not yet dispatched; see ``Http2Connection.take_completed_streams``.

### `Connection`

```mojo
struct Connection
```

Per-connection HTTP/2 state.

Fields:

- `streams` (`StreamSlab[Stream]`): Per-connection stream table. See :mod:`dodo.http2.stream_slab` for the design rationale -- dense small-int keys hit a flat-array fast path; large IDs spill into a Dict overflow. Drop-in API parity with the prior ``Dict[StreamId, Stream]``.
- `hpack_decoder` (`HpackDecoder`)
- `hpack_encoder` (`HpackEncoder`)
- `max_frame_size` (`Int`)
- `max_concurrent_streams` (`Int`)
- `max_request_body_size` (`Int`): Maximum buffered request bytes per stream; defaults to 10 MiB.
- `initial_window_size` (`Int`): Our SETTINGS_INITIAL_WINDOW_SIZE: the receive window each new stream starts with, and what we advertise.
- `peer_initial_window_size` (`Int`): The peer's SETTINGS_INITIAL_WINDOW_SIZE: the *send* window each new stream starts with. One field used to serve both, so the peer's value overwrote ours (and vice versa), and the two ends disagreed about every stream's window.
- `max_header_list_size` (`Int`): SETTINGS_MAX_HEADER_LIST_SIZE (RFC 9113 §6.5.2). ``0`` means unset / advertise no cap (the RFC default). ``Http2Config`` sets this to 8192 by default; emitted only when ``> 0``.
- `send_window` (`Int`)
- `recv_window` (`Int`): Connection-level receive window: what the peer may still send. DATA debits it; every WINDOW_UPDATE(0) we emit credits it, so credit withheld above ``_MAX_BUFFERED_REQUEST_BYTES`` is a hard bound, not a request: DATA past it is GOAWAY(FLOW_CONTROL_ERROR) (RFC 9113 §6.9.1).
- `goaway_received` (`Bool`)
- `preface_seen` (`Bool`)
- `settings_acked` (`Bool`)
- `is_client` (`Bool`): When ``True``, this :class:`Connection` is driven from the client side (``dodo.http2.client.Http2ClientConnection``). Affects the :meth:`handle_frame` HEADERS-receive transition: a stream we sent HEADERS+END_STREAM on (HALF_CLOSED_LOCAL) that receives HEADERS+END_STREAM transitions to CLOSED, not HALF_CLOSED_REMOTE. Defaults to ``False`` (server semantics) so existing server callers are unchanged.
- `enable_connect_protocol` (`Bool`): When ``True``, the server advertises ``SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`` (RFC 8441) in its initial SETTINGS frame. Required for clients to issue an ``Extended CONNECT`` request (the WebSocket-over-HTTP/2 bootstrap). Default ``False`` so existing servers don't accidentally opt into bootstrapping protocols they can't speak; flipped to ``True`` by the unified :class:`dodo.http.HttpServer` once the unified :class:`dodo.ws.WsServer` is wired in.
- `peer_header_table_size` (`Int`): The peer's SETTINGS_HEADER_TABLE_SIZE: the dynamic table limit for *our encoder*. Our encoder never indexes, so this is recorded only. Applying it to our decoder -- as this code once did -- made a peer's 0 evict entries its own encoder still referenced, and its 2^32-1 lift our decoder's memory bound.
- `peer_enable_connect_protocol` (`Bool`): When ``True``, the *peer* advertised ``SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`` in its initial SETTINGS. The HTTP/2 client checks this before issuing an Extended CONNECT (RFC 8441 §3 SHOULD); if the server didn't advertise the setting, the client falls back to the HTTP/1.1 Upgrade dance for WebSocket.
- `rst_stream_count` (`Int`): Connection-lifetime count of inbound RST_STREAM frames. Trips a GOAWAY(ENHANCE_YOUR_CALM) past ``_RST_FLOOD_THRESHOLD`` (rapid-reset mitigation).
- `goaway_sent` (`Bool`): Set once the driver has queued a GOAWAY so it is emitted at most once.
- `last_peer_stream_id` (`Int`): Highest peer-initiated stream id seen. Feeds the GOAWAY last-stream-id field and the RFC 9113 sec 5.1.1 monotonicity check (a peer must not open a stream numbered below one it already opened).
- `max_local_stream_id` (`Int`): Client role: highest stream id this endpoint has opened (0 if none). ``last_peer_stream_id`` only tracks peer-initiated ids, so without this a client cannot tell a stream it opened and finished with from one that was never opened (``_idle_id``).
- `local_max_frame_size` (`Int`): The SETTINGS_MAX_FRAME_SIZE *we* advertise, and therefore the largest inbound frame we accept (RFC 9113 sec 4.2).
- `continuing_stream` (`Int`): Stream whose header block is still open, ``0`` when none.
- `header_block` (`List[UInt8]`): Accumulated header-block fragments for ``continuing_stream``.
- `header_block_end_stream` (`Bool`): END_STREAM seen on the HEADERS that opened ``header_block``.
- `buffered_request_bytes` (`Int`): Request body bytes buffered on streams whose request has not been taken yet (server side).
- `withheld_conn_credit` (`Int`): Connection-level WINDOW_UPDATE credit held back while ``buffered_request_bytes`` is over the cap.
- `reset_by_us` (`List[Int]`): Streams we sent RST_STREAM on, most recent last, bounded. DATA the peer had in flight for them is dropped quietly, so it does not become a connection-level STREAM_CLOSED that tears down every other stream.
- `header_block_refuse` (`Int`): Non-zero: the open block belongs to a stream being refused, with this RST_STREAM error code. The block is still decoded when it completes -- RFC 9113 sec 4.3: every header block updates the connection-wide HPACK context, refused or not.
- `header_block_continuations` (`Int`): CONTINUATION frames seen on the open block (flood guard). Kept on the connection: at most one block is open (sec 6.10), and a refused stream has no entry in ``streams`` to count on.
- `reset_streams` (`List[Int]`): Stream ids that received an inbound RST_STREAM since the last :meth:`take_reset_streams` call (RFC 9113 §6.4). Drained by :class:`dodo.http._h2_conn_handle.Http2ConnHandle` before each handler-dispatch round so per-stream :class:`CancelCell` plumbing can flip the right cell. The driver also tracks the transition via :class:`StreamState.CLOSED`; the explicit list exists so the reactor can react in O(1) per RST_STREAM rather than scanning every open stream.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `Connection.__init__`

```mojo
def __init__(out self)
```

#### `Connection.initial_settings`

```mojo
def initial_settings(self) -> Frame
```

The first SETTINGS frame the server emits after preface.

#### `Connection.note_local_stream`

```mojo
def note_local_stream(mut self, sid: Int)
```

Record that this endpoint opened stream ``sid`` (client role).

#### `Connection.release_request_credit`

```mojo
def release_request_credit(mut self, released: Int) -> List[Frame]
```

Account ``released`` body bytes as handed to a handler, and return the withheld connection credit once buffering is back under the cap.

#### `Connection.handle_frame`

```mojo
def handle_frame(mut self, var f: Frame) raises -> List[Frame]
```

Apply ``f`` to the connection state, return reply frames.

#### `Connection.make_response`

```mojo
def make_response(mut self, sid: Int, status: Int, headers: Span[HpackHeader], body: Span[UInt8]) -> List[Frame]
```

Produce ``HEADERS [+ DATA]`` frames for ``sid``.

#### `Connection.make_response_with_trailers`

```mojo
def make_response_with_trailers(mut self, sid: Int, status: Int, headers: Span[HpackHeader], body: Span[UInt8], trailers: Span[HpackHeader]) -> List[Frame]
```

Produce ``HEADERS [+ DATA] + trailing-HEADERS`` frames for ``sid``.

Unlike :meth:`make_response`, END_STREAM rides on the trailing
HEADERS block (RFC 9113 6.10), not on the initial HEADERS or the
DATA frame. This is the gRPC-over-HTTP/2 response shape: the
``grpc-status`` (and optional ``grpc-message``) live in trailers
that close the stream. The trailing block carries only regular
fields -- pseudo-headers are forbidden after the leading block,
so the caller must pass non-colon names only.

If ``trailers`` is empty this degrades to plain
:meth:`make_response` semantics so callers can route every
response through one path.

#### `Connection.make_stream_headers`

```mojo
def make_stream_headers(mut self, sid: Int, status: Int, headers: Span[HpackHeader]) -> Frame
```

Leading HEADERS for an incremental streaming response.

Carries ``:status`` + real headers with END_HEADERS but never
END_STREAM -- DATA frames (and possibly trailing HEADERS) follow
on later writable edges. Companion to :meth:`make_response` for
the h2 server-streaming path.

#### `Connection.make_stream_trailers`

```mojo
def make_stream_trailers(mut self, sid: Int, trailers: Span[HpackHeader]) -> Frame
```

Trailing HEADERS closing a streaming response (RFC 9113 6.10).

END_HEADERS | END_STREAM ride on this block; only regular field
names are legal after the leading block.

## Functions

### `h2_setting_error`

```mojo
def h2_setting_error(id: Int, v: Int) -> Int
```

The RFC 9113 sec 6.5.2 error code for SETTINGS pair ``(id, v)``, or 0 when it is valid. Every place a peer's settings are applied -- a SETTINGS frame and the h2c ``HTTP2-Settings`` header -- goes through this one check.

### `validate_request_fields`

```mojo
def validate_request_fields(hdrs: List[HpackHeader], is_trailers: Bool, allow_extended_connect: Bool) -> Bool
```

Return ``True`` when ``hdrs`` is a well-formed request header list (RFC 9113 sec 8.1.2 and sec 8.3).

A ``False`` return is a malformed request: the caller answers
with RST_STREAM(PROTOCOL_ERROR) rather than serving it.

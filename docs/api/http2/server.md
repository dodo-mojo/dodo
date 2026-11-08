# `dodo.http2.server`

HTTP/2 server glue (RFC 9113).

Connects :mod:`dodo.http2.frame` + :mod:`dodo.http2.hpack` +
:mod:`dodo.http2.state` to dodo's existing ``Handler`` interface.

The high-level surface:

- :class:`Http2Connection` — a synchronous, buffer-driven driver. The
  caller feeds it inbound bytes (``feed``) and pulls outbound bytes
  (``drain``). When a stream's request is complete, :meth:`take_request`
  yields a :class:`dodo.http.Request` ready for a normal Handler.
  After the handler produces a :class:`dodo.http.Response`,
  :meth:`emit_response` schedules the appropriate ``HEADERS [+ DATA]``
  frames.

- :func:`detect_h2c_upgrade` — sniff an inbound HTTP/1.1 request for
  ``Connection: Upgrade, HTTP2-Settings`` + ``Upgrade: h2c`` and
  return ``True`` when the connection should switch protocols. The
  caller is responsible for emitting the 101 response and then
  driving the connection through :class:`Http2Connection`.

- :func:`is_h2_alpn` — string match for ``"h2"`` so TLS code paths
  can dispatch from ALPN.

This is enough to ship a working server today while preserving the
plumbing for a future async / reactor integration: the driver does
not own its sockets, so the same code works in a unit test that
shoves bytes through it directly *and* in the reactor's per-fd
callback.

## Structs

### `Http2Connection`

```mojo
struct Http2Connection
```

Synchronous HTTP/2 driver with separate I/O sides.

A pure state object: the caller drives I/O. It exposes:

- :meth:`feed` — push inbound bytes; returns any reply frames
  (already encoded) that the state machine generated.
- :meth:`drain` — pull queued outbound frames as bytes.
- :meth:`take_completed_streams` — pop ids whose request is
  ready for handler dispatch.
- :meth:`take_request` — convert one stream into a plain
  ``Request`` (a :class:`dodo.http.Request`).
- :meth:`emit_response` — schedule the response frames for a
  finished handler invocation.

Fields:

- `conn` (`Connection`)
- `inbox` (`List[UInt8]`)
- `outbox` (`List[UInt8]`)
- `greeted` (`Bool`)
- `peer_settings_seen` (`Bool`): True once the peer's first frame, a non-ACK SETTINGS, has arrived.
- `config` (`Http2Config`): The :class:`Http2Config` the driver was constructed with. Kept on the driver so the reactor wiring can re-read individual fields per-stream (e.g. the ``max_header_list_size`` cap when applying inbound HEADERS) without threading it through every per-frame call site.
- `pending_body` (`Dict[Int, List[UInt8]]`): Response bytes for a stream that the send window would not take.
- `pending_pos` (`Dict[Int, Int]`): Offset already flushed out of the matching ``pending_body``.
- `pending_trailers_k` (`Dict[Int, List[String]]`): Trailer names to send once the matching ``pending_body`` drains.
- `pending_trailers_v` (`Dict[Int, List[String]]`): Trailer values, parallel to ``pending_trailers_k``.

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`

#### `Http2Connection.__init__`

```mojo
def __init__(out self)
```

Default-construct with :class:`Http2Config` defaults.

Equivalent to ``Http2Connection.with_config(Http2Config())``;
kept as a separate ``__init__`` so callers (``Http2Connection()``
in tests + the inline driver) work byte-for-byte without
an explicit config argument.

#### `Http2Connection.with_config`

```mojo
def with_config(var config: Http2Config) raises -> Self
```

Construct an :class:`Http2Connection` whose underlying :class:`Connection` SETTINGS are populated from ``config``.

Validates ``config`` first (RFC 9113 / RFC 7541 bounds);
raises if any field is out of range. The resulting driver's
first-emitted SETTINGS frame advertises
``max_concurrent_streams`` per the config; later inbound
SETTINGS from the peer can lower the negotiated values per
RFC 9113 §6.5.

The HPACK dynamic-table size budget is propagated to the
decoder. The ``allow_huffman_decode`` flag is plumbed
into ``conn.hpack_decoder.allow_huffman``; the
``allow_huffman_encode`` flag into
``conn.hpack_encoder.allow_huffman``. Both default to
``False`` so the wire format stays byte-identical to the
legacy default unless the user opts in.

#### `Http2Connection.from_h2c_upgrade`

```mojo
def from_h2c_upgrade(var config: Http2Config, req: Request, settings_payload: List[UInt8]) raises -> Self
```

Build a server-side :class:`Http2Connection` seeded for an h2c upgrade.

Per RFC 7540 §3.2 ("Starting HTTP/2 for HTTP URIs"), the original
HTTP/1.1 request becomes stream id 1 (implicitly half-closed from
the client side), and the ``HTTP2-Settings`` header value (the
raw SETTINGS payload, base64url-decoded) is applied to the
connection immediately. The server emits its initial SETTINGS
frame as the server connection preface; the client's connection
preface (``PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n`` + a SETTINGS
frame) still arrives over the same TCP fd and is processed by
:meth:`feed` as usual.

Args:

- `config`: Server SETTINGS to advertise. Validated by :meth:`with_config`.
- `req`: The original HTTP/1.1 request that triggered the upgrade. Becomes stream id 1 in ``HALF_CLOSED_REMOTE`` state with ``headers_complete = data_complete = True`` so the handler dispatch loop picks it up immediately.
- `settings_payload`: Raw bytes of the ``HTTP2-Settings`` header value (base64url-decoded). Format is identical to a SETTINGS frame body (repeated 6-byte ``(id, value)`` pairs). Applied directly to the connection state without emitting a SETTINGS_ACK -- the ACK on the wire is reserved for the proper SETTINGS frame the client sends inside its connection preface.

Returns: An :class:`Http2Connection` whose ``outbox`` already holds the server's initial SETTINGS frame and whose ``conn.streams`` already contains stream 1 ready for handler dispatch via :meth:`take_completed_streams`.

#### `Http2Connection.feed`

```mojo
def feed(mut self, data: Span[UInt8]) raises
```

Push ``data`` (bytes from the socket) into the driver.

#### `Http2Connection.drain`

```mojo
def drain(mut self) -> List[UInt8]
```

Return all queued outbound bytes and clear the buffer.

The buffer is handed over rather than copied: it holds whatever was
framed since the last drain, which for a streaming response is a
window's worth of body.

#### `Http2Connection.mark_dispatched`

```mojo
def mark_dispatched(mut self, sid: Int) raises
```

Keep ``sid`` out of :meth:`take_completed_streams` while its response is produced elsewhere (the offload pool).

#### `Http2Connection.stream_sendable`

```mojo
def stream_sendable(self, sid: Int) raises -> Bool
```

``sid`` still exists and is not CLOSED (not reset by the peer), so a response for it can go out.

#### `Http2Connection.send_goaway`

```mojo
def send_goaway(mut self)
```

Queue a graceful GOAWAY (``NO_ERROR``) naming the last stream the peer opened, once. Streams up to it are still answered.

#### `Http2Connection.take_completed_streams`

```mojo
def take_completed_streams(self) -> List[Int]
```

Return stream ids whose request is fully buffered.

A stream already dispatched is excluded by ``Stream.slab_ready``:
``emit_response`` moves a fully written one to ``CLOSED``, and
``response_started`` covers a response parked in ``pending_body``
whose stream stays open until the window drains, so a
WINDOW_UPDATE never re-runs the handler (RFC 9113 sec 8.1).

#### `Http2Connection.take_reset_streams`

```mojo
def take_reset_streams(mut self) -> List[Int]
```

Pop the list of stream ids reset by the peer since the last call.

Each id corresponds to an inbound RST_STREAM frame
(RFC 9113 §6.4) processed by :class:`Connection.handle_frame`.
Used by :class:`dodo.http._h2_conn_handle.Http2ConnHandle` to
flip the matching per-stream :class:`CancelCell` so the
in-flight handler can short-circuit cooperatively. The list
is drained -- a second call returns an empty list unless a
new RST_STREAM has arrived in the meantime.

#### `Http2Connection.goaway_received_flag`

```mojo
def goaway_received_flag(self) -> Bool
```

Return ``True`` once the peer has sent a GOAWAY frame (RFC 9113 §6.8). The reactor checks this between dispatches to flip the per-stream cancel cells before draining the connection.

#### `Http2Connection.take_request`

```mojo
def take_request(mut self, sid: Int) raises -> Request
```

Convert stream ``sid`` into a :class:`dodo.http.Request`.

#### `Http2Connection.emit_response`

```mojo
def emit_response(mut self, sid: Int, var resp: ResponseImpl) raises
```

Encode + queue the response for ``sid``.

The connection's stream state is advanced to ``CLOSED`` after
the response is queued, mirroring HTTP/1.1's per-request
lifetime in the server. When ``resp.trailers`` is non-empty the
response is framed as HEADERS [+ DATA] + trailing HEADERS with
END_STREAM on the trailing block (the gRPC-over-HTTP/2 shape);
otherwise it frames as a single buffered response.

There are still no streaming-response bodies on h2 here (one
buffered DATA frame per stream). Chunked/flow-controlled h2
response bodies come with the streaming reactor wiring.

#### `Http2Connection.pump_pending`

```mojo
def pump_pending(mut self) raises
```

Flush response bytes parked by a closed send window.

Called after every inbound frame: a WINDOW_UPDATE is what
unblocks them, and nothing else re-drives the stream.

#### `Http2Connection.take_extended_connect_streams`

```mojo
def take_extended_connect_streams(self) raises -> List[Int]
```

Return stream ids of open Extended CONNECT tunnels awaiting acceptance: ``:method=CONNECT`` + ``:protocol=websocket``, headers complete, not yet END_STREAM'd, still OPEN (RFC 8441). The ``:protocol`` marker is cleared by :meth:`accept_ws_over_h2`, so an accepted tunnel is not re-returned.

#### `Http2Connection.accept_ws_over_h2`

```mojo
def accept_ws_over_h2(mut self, sid: Int) raises
```

Accept a WebSocket Extended CONNECT tunnel on ``sid``: emit a ``:status=200`` HEADERS block WITHOUT END_STREAM (RFC 8441 5.2) so the stream stays open for bidirectional WS DATA. Clears the ``:protocol`` marker so the tunnel is not re-surfaced.

#### `Http2Connection.stream_is_open`

```mojo
def stream_is_open(self, sid: Int) raises -> Bool
```

True while ``sid`` exists and is still OPEN (bidirectional).

The WS-over-h2 reactor path uses this to detect peer teardown
(RST_STREAM / END_STREAM moves the stream off OPEN) so it can run
the sidecar handler's ``on_close`` and drop the tunnel.

#### `Http2Connection.drain_stream_data`

```mojo
def drain_stream_data(mut self, sid: Int) raises -> List[UInt8]
```

Move any inbound DATA accumulated for ``sid`` out of the stream record (the WS-over-h2 read path pulls client frames from here).

#### `Http2Connection.begin_stream_response`

```mojo
def begin_stream_response(mut self, sid: Int, var resp: ResponseImpl) raises
```

Queue the leading HEADERS of an incremental streaming response.

Filters hop-by-hop fields (RFC 9113 8.2.2) and encodes a
no-END_STREAM HEADERS block into the outbox. The stream is left
open; :meth:`queue_stream_data` sends the body and
:meth:`end_stream_response` closes it (trailers captured by the
caller from ``resp.trailers`` before this move).

#### `Http2Connection.queue_parked_body`

```mojo
def queue_parked_body(mut self, sid: Int, body: Span[UInt8], pos: Int) raises -> Int
```

Frame as much of `body[pos:]` as the send windows will take.

The point of it is what it does *not* copy. A body too large for the
window is parked and re-pumped on every WINDOW_UPDATE, so handing the
whole remainder over each time and letting `queue_stream_data` use a
window's worth of it is quadratic in the body: at a 64 KiB window a
28 MiB response copies about 6 GB to send 28 MB. Asking the window
first makes each pump cost a window, not a body.

Returns the bytes consumed, which the caller adds to its own offset.
Both pump paths — a buffered response here and a streaming one in
`Http2ConnHandle` — go through this rather than repeating it.

#### `Http2Connection.queue_stream_data`

```mojo
def queue_stream_data(mut self, sid: Int, data: Span[UInt8]) raises -> Int
```

Frame as much of ``data`` as the send windows allow.

Emits DATA frames (each <= ``max_frame_size``) bounded by the
min of the connection and per-stream send windows, decrements
both, and returns the number of bytes consumed. Returns 0 when
the window is exhausted -- the caller stashes the remainder and
re-pumps on the next WINDOW_UPDATE.

#### `Http2Connection.end_stream_response`

```mojo
def end_stream_response(mut self, sid: Int, trailers_k: List[String], trailers_v: List[String]) raises
```

Close a streaming response.

Emits trailing HEADERS with END_STREAM when trailers are present,
otherwise an empty DATA frame with END_STREAM, and advances the
stream to CLOSED.

## Functions

### `is_h2_alpn`

```mojo
def is_h2_alpn(alpn: String) -> Bool
```

Return True when the negotiated ALPN protocol is HTTP/2.

### `detect_h2c_upgrade`

```mojo
def detect_h2c_upgrade(headers: HeaderMap) -> Bool
```

RFC 7540 §3.2 — detect inbound ``Upgrade: h2c`` request.

Delegates to :func:`dodo.http.proto.h2c_upgrade.detect_h2c_upgrade`,
the canonical sans-I/O implementation. The decoded
``HTTP2-Settings`` payload is fed into the connection during
initialisation by the caller via
:meth:`Http2Connection.feed_settings_payload` — that step is the
reactor-bound side of the upgrade and does not happen here.

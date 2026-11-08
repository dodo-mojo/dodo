# `dodo.http2.client`

HTTP/2 client byte driver (RFC 9113).

Cleartext (h2c) and TLS (h2) client-side counterpart to
:class:`dodo.http2.server.Http2Connection`.

This module exposes the *low-level* HTTP/2 client byte driver
that :class:`dodo.http.HttpClient` uses internally when it
needs to speak HTTP/2 (either via TLS+ALPN ``h2`` for
``https://`` URLs, or via cleartext prior knowledge when the
caller passes ``prefer_h2c=True``). Application code should
go through :class:`dodo.http.HttpClient`; the driver is kept
public for callers who want to roll their own dispatch loop.

- :class:`Http2ClientConfig` -- client-advertised SETTINGS
  values (mirrors :class:`dodo.http2.server.Http2Config`).
- :class:`Http2ClientConnection` -- the stateful,
  *socket-agnostic* driver. The caller pumps inbound bytes
  into ``feed`` and pulls outbound bytes from ``drain``;
  per-stream completion is observed via
  ``response_ready(sid)`` / ``take_response(sid)``. Same
  shape as :class:`dodo.http2.server.Http2Connection` so the
  two drivers can be paired entirely in-memory in tests.

Wire-protocol scope:

* RFC 9113 §3.5 client connection preface
  (``"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"``) emitted first.
* RFC 9113 §6.5 SETTINGS exchange: client emits its initial
  SETTINGS frame after the preface; ACKs every server SETTINGS
  it observes; honors peer-advertised
  ``SETTINGS_INITIAL_WINDOW_SIZE`` /
  ``SETTINGS_MAX_FRAME_SIZE`` /
  ``SETTINGS_HEADER_TABLE_SIZE``.
* RFC 9113 §5.1 client stream IDs: odd integers starting at 1,
  monotonically increasing per connection.
* RFC 9113 §6.2 / §6.10 HEADERS + CONTINUATION send and recv
  via :class:`dodo.http2.hpack.HpackEncoder` /
  :class:`dodo.http2.hpack.HpackDecoder` (shared with the server).
* RFC 9113 §6.1 DATA send and recv with per-stream + connection
  flow-control accounting; we eagerly emit
  ``WINDOW_UPDATE`` for received DATA so default-sized responses
  do not stall (same shape as the server-side driver).
* RFC 9113 §6.7 PING: we ACK every non-ACK PING the peer sends
  and ignore the ACK side.
* RFC 9113 §6.8 GOAWAY: we surface the received flag via
  :attr:`Http2ClientConnection.goaway_received`; in-flight
  streams below the announced last-stream-id continue normally;
  callers SHOULD stop opening new streams.
* RFC 9113 §6.4 RST_STREAM: when received, the affected stream
  is marked closed with the peer's error code stashed for the
  caller to read via :meth:`Http2ClientConnection.stream_error`.

Out of scope (intentional, mirrors the server's scope):

* Server push (``PUSH_PROMISE``) -- we never originate it and
  treat an inbound PUSH_PROMISE from a server as a connection error
  (GOAWAY with PROTOCOL_ERROR, RFC 9113 §8.4) since dodo clients do
  not opt into the SETTINGS_ENABLE_PUSH affordance.
* Stream priority (deprecated by RFC 9113 §5.3.2).
* Trailers (HEADERS frames *after* the response DATA stream
  closes) -- accepted at the parser level but not surfaced
  through the high-level :class:`Http2Client` API.

The wire-codec / HPACK / frame-state machinery is shared with
the server (via :class:`dodo.http2.state.Connection`); only the
client-specific behaviour (preface, odd stream ids, client
stream-state transitions, the high-level request/response
plumbing) lives here.

## Structs

### `Http2ClientConnection`

```mojo
struct Http2ClientConnection
```

Stateful, socket-agnostic HTTP/2 client driver.

A pure state object -- the caller owns I/O. The lifecycle is:

1. Construct via :meth:`__init__` or
   :meth:`with_config`. The constructor pre-queues the
   client connection preface
   (``"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"``) plus the
   initial SETTINGS frame, ready to be drained.

2. Call :meth:`drain` once to pull the preface + initial
   SETTINGS bytes; write them onto the socket.

3. For each request:

   a. Allocate a stream id via :meth:`next_stream_id` (odd
      integers starting at 1).
   b. Call :meth:`send_request(sid, ...)` to enqueue the
      HEADERS frame (with optional CONTINUATION) and any
      DATA frames bounded by current flow-control windows.
      DATA that exceeds the window is held back; the
      driver releases more on inbound WINDOW_UPDATE.
   c. Call :meth:`drain` to pull outbound bytes; write them.

4. On the inbound side: call :meth:`feed(bytes)` with bytes
   read from the socket. Internally the driver:

   - decodes frames via :func:`parse_frame`
   - dispatches them through :meth:`Connection.handle_frame`
     (with ``is_client = True`` so HEADERS / DATA receipt
     transitions HALF_CLOSED_LOCAL streams to CLOSED instead
     of HALF_CLOSED_REMOTE)
   - ACKs SETTINGS / PING as appropriate
   - emits WINDOW_UPDATE for received DATA
   - on RST_STREAM, surfaces the error code via
     :meth:`stream_error` and marks the stream closed

   Then call :meth:`drain` again to pull any auto-emitted
   outbound bytes (SETTINGS ACK, PING ACK, WINDOW_UPDATE).

5. Poll :meth:`response_ready(sid)`; once ``True``, call
   :meth:`take_response(sid)` to pop the
   ``(status, headers, body)`` tuple.

6. When done, optionally send a GOAWAY via
   :meth:`send_goaway` and close the socket.

The driver is :class:`Movable` but not :class:`Copyable`; the
HPACK dynamic table inside :class:`Connection` is mutable
state that must not alias across two driver instances.

Fields:

- `conn` (`Connection`): The shared frame / HPACK / stream state machinery (:class:`dodo.http2.state.Connection`). ``conn.is_client`` is set to ``True`` so HEADERS / DATA receipt transitions HALF_CLOSED_LOCAL streams to CLOSED.
- `inbox` (`List[UInt8]`): Inbound byte buffer. Filled by :meth:`feed`; drained frame-by-frame on each :meth:`feed` call.
- `outbox` (`List[UInt8]`): Outbound byte buffer. Pre-loaded with preface + initial SETTINGS at construction; appended-to by every method that emits a frame. Drained by :meth:`drain`.
- `greeted` (`Bool`): ``True`` once the preface + initial SETTINGS have been queued in :attr:`outbox`. Mirrors :attr:`Http2Connection.greeted`.
- `config` (`Http2ClientConfig`): The :class:`Http2ClientConfig` the driver was constructed with. Kept on the driver so the high-level :class:`Http2Client` facade can re-read individual fields per-stream (e.g. the ``max_header_list_size`` cap when building outbound HEADERS) without threading it through every per-frame call site.

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`

#### `Http2ClientConnection.__init__`

```mojo
def __init__(out self)
```

Default-construct with :class:`Http2ClientConfig` defaults.

#### `Http2ClientConnection.from_h2c_upgrade`

```mojo
def from_h2c_upgrade(var config: Http2ClientConfig) raises -> Self
```

Build a client-side driver pre-seeded for an h2c upgrade.

Per RFC 7540 §3.2 ("Starting HTTP/2 for HTTP URIs"), after the
server accepts the upgrade with ``101 Switching Protocols``
the original HTTP/1.1 request implicitly becomes stream id 1
in HALF_CLOSED_LOCAL state from the client's perspective: the
request body has already been delivered on the h1 wire, so
the client sends no further bytes on stream 1; the server
will respond on stream 1 with HEADERS + DATA.

After construction the caller MUST:

1. Drain the connection preface + SETTINGS frame from
   :attr:`outbox` and write it to the (now-h2) socket as the
   client's connection preface (RFC 9113 §3.5);
2. Feed inbound bytes into :meth:`feed`, expecting the
   server's initial SETTINGS frame followed by a HEADERS+DATA
   response on stream 1;
3. Poll :meth:`response_ready(1)` and pop the response via
   :meth:`take_response(1)`.

The next client-initiated stream id starts at 3 (RFC 9113
§5.1.1: odd, monotonically increasing, and stream 1 is
already taken).

Args:

- `config`: Same client config the upgrade request advertised via the ``HTTP2-Settings`` header (the SETTINGS frame in the connection preface MUST agree with the values the upgrade request committed to).

Returns: An :class:`Http2ClientConnection` whose outbox holds the client's connection preface + initial SETTINGS frame and whose ``conn.streams`` already contains stream id 1 in HALF_CLOSED_LOCAL state.

#### `Http2ClientConnection.with_config`

```mojo
def with_config(var config: Http2ClientConfig) raises -> Self
```

Construct a driver whose underlying SETTINGS reflect ``config``.

Validates ``config`` first (RFC 9113 / RFC 7541 bounds);
raises if any field is out of range. Same construction
shape as :meth:`Http2Connection.with_config`.

#### `Http2ClientConnection.drain`

```mojo
def drain(mut self) -> List[UInt8]
```

Return all queued outbound bytes and clear the buffer.

Mirrors :meth:`Http2Connection.drain` for symmetry.

#### `Http2ClientConnection.feed`

```mojo
def feed(mut self, data: Span[UInt8]) raises
```

Push ``data`` (bytes from the socket) into the driver.

Decodes any complete frames in :attr:`inbox`, applies them
via :meth:`Connection.handle_frame`, and queues any
auto-generated reply frames (SETTINGS ACK, PING ACK,
WINDOW_UPDATE) into :attr:`outbox`. Per-stream completion
becomes observable via :meth:`response_ready` after this
call returns.

An oversized frame (RFC 9113 sec 4.2) queues
GOAWAY(FRAME_SIZE_ERROR) and discards the rest of the input
instead of raising; check :attr:`conn.goaway_sent` and flush
:meth:`drain` before closing.

Raises: Error: On a connection-level protocol violation the frame layer cannot report as a frame (malformed frame header, etc.).

#### `Http2ClientConnection.receive`

```mojo
def receive(mut self, data: Span[UInt8]) raises
```

:meth:`feed` that also grows the receive windows with the measured bandwidth-delay product: drivers call this.

#### `Http2ClientConnection.next_stream_id`

```mojo
def next_stream_id(mut self) -> Int
```

Allocate the next client-initiated stream id.

RFC 9113 §5.1.1: client-initiated stream identifiers must
be odd, MUST be monotonically increasing, and MUST NOT
exceed ``2^31 - 1``. Once we'd wrap, the connection MUST
be closed gracefully via GOAWAY.

#### `Http2ClientConnection.pump_pending_body`

```mojo
def pump_pending_body(mut self, sid: Int) raises
```

Re-attempt draining a stream's stashed body after a WINDOW_UPDATE opened the send window. No-op when the stream has no pending body.

#### `Http2ClientConnection.has_pending_body`

```mojo
def has_pending_body(self, sid: Int) -> Bool
```

True if stream ``sid`` has a body remainder still awaiting a WINDOW_UPDATE (RFC 9113 §6.9).

#### `Http2ClientConnection.finish_upload`

```mojo
def finish_upload(mut self, sid: Int) raises
```

Drop unsent request bytes and finish our half after an early reply.

Preserve the received response. A peer reset may already have closed
the stream, in which case no further DATA is permitted.

#### `Http2ClientConnection.send_request`

```mojo
def send_request(mut self, sid: Int, method: String, scheme: String, authority: String, path: String, extra_headers: List[HpackHeader], body: Span[UInt8]) raises
```

Encode + queue a request on stream ``sid``.

Builds the pseudo-header block per RFC 9113 §8.1.2.3 in the
required order (``:method``, ``:scheme``, ``:authority``,
``:path``) followed by the caller-supplied
``extra_headers`` (already lower-cased; RFC 9113 §8.1.2),
HPACK-encodes the lot via the shared :class:`HpackEncoder`,
and emits a HEADERS frame.

If ``body`` is empty, the HEADERS frame carries
``END_STREAM`` and the stream transitions to
HALF_CLOSED_LOCAL. Otherwise the body is split into one
or more DATA frames bounded by the negotiated
``max_frame_size`` and the connection-level + per-stream
send windows; the *last* DATA frame carries
``END_STREAM``. If the windows can't fit the entire body
right now, we emit as much as fits and stash the
remainder for the caller to flush via
:meth:`pump_pending_body` after WINDOW_UPDATE has
loosened the windows.

Args:

- `sid`: Stream id allocated via :meth:`next_stream_id`.
- `method`: HTTP method (e.g. ``"GET"``, ``"POST"``).
- `scheme`: ``"http"`` or ``"https"``.
- `authority`: ``Host``-equivalent (RFC 9113 §8.1.2.3.1).
- `path`: Request target (RFC 9113 §8.1.2.3.4).
- `extra_headers`: Caller-supplied request headers (lowercased name -> value). MUST NOT contain any of the connection-level headers forbidden by RFC 9113 §8.2.2 (``connection``, ``transfer-encoding``, ``keep-alive``, ``proxy-connection``, ``upgrade``); the high-level facade strips them before calling.
- `body`: Request body bytes; may be empty.

#### `Http2ClientConnection.send_extended_connect`

```mojo
def send_extended_connect(mut self, sid: Int, scheme: String, authority: String, path: String, protocol: String, extra_headers: List[HpackHeader]) raises
```

Open an RFC 8441 Extended CONNECT stream.

Emits a HEADERS frame with the Extended-CONNECT pseudo-header
set (``:method = CONNECT, :scheme, :authority, :path,
:protocol``) **without** ``END_STREAM``. The stream stays in
OPEN state so the caller can pump bidirectional DATA frames
(e.g. WebSocket frames over h2 -- ``protocol="websocket"``).

The peer MUST have advertised
``SETTINGS_ENABLE_CONNECT_PROTOCOL=1`` (RFC 8441 §3) before
the caller invokes this; gate the call on
:meth:`peer_supports_extended_connect`. The driver does NOT
block here -- callers may pre-stage the frame and the peer
may have already ACKed our SETTINGS by the time the bytes
are flushed.

Args:

- `sid`: Stream id allocated via :meth:`next_stream_id`.
- `scheme`: ``"http"`` or ``"https"`` per RFC 8441 §4.
- `authority`: ``Host``-equivalent.
- `path`: Request target.
- `protocol`: Tunnelled protocol token, e.g. ``"websocket"``.
- `extra_headers`: Caller-supplied headers (lowercased).

#### `Http2ClientConnection.send_data`

```mojo
def send_data(mut self, sid: Int, body: Span[UInt8], end_stream: Bool) raises
```

Queue ``body`` as one or more DATA frames on stream ``sid``.

Used by tunnelling clients (Extended CONNECT bodies, or
chunked POSTs that need to be fed incrementally) where the
caller wants explicit control over ``END_STREAM`` placement.
Same flow-control accounting as the body-emission path of
:meth:`send_request`. Honours the negotiated send windows;
raises if the body wouldn't fit.

#### `Http2ClientConnection.peer_supports_extended_connect`

```mojo
def peer_supports_extended_connect(self) -> Bool
```

Return ``True`` once the peer has advertised ``SETTINGS_ENABLE_CONNECT_PROTOCOL = 1`` (RFC 8441 §3).

Latches on the first server-side SETTINGS that includes the
bit and never flips back -- RFC 9113 §6.5 forbids tearing
down an already-advertised SETTINGS value once peers have
acted on it. Callers should gate any
:meth:`send_extended_connect` call on this returning ``True``.

#### `Http2ClientConnection.send_goaway`

```mojo
def send_goaway(mut self, last_stream_id: Int, error_code: Int = Int(0))
```

Queue a GOAWAY frame (RFC 9113 §6.8).

The peer should treat any stream id > ``last_stream_id``
as not-processed; in-flight streams below that id MAY
complete. ``error_code`` defaults to 0 (NO_ERROR) for a
clean shutdown; pass an :class:`Http2ErrorCode` value for
an abnormal close.

#### `Http2ClientConnection.response_ready`

```mojo
def response_ready(mut self, sid: Int) raises -> Bool
```

Return ``True`` when the response on stream ``sid`` is fully buffered and ready to be popped via :meth:`take_response`.

A response is "ready" iff its HEADERS block has been
completely received (END_HEADERS observed on either
HEADERS or trailing CONTINUATION) **and** either:

- the stream has been ENDed by the peer (END_STREAM seen
  on HEADERS or DATA), or
- the stream has been RESET by the peer.

#### `Http2ClientConnection.stream_error`

```mojo
def stream_error(self, sid: Int) raises -> Optional[Int]
```

Return the peer-supplied RST_STREAM error code for ``sid``, if any. ``None`` means the stream completed cleanly (or has not been reset).

#### `Http2ClientConnection.take_response`

```mojo
def take_response(mut self, sid: Int) raises -> Http2Response
```

Pop and return the :class:`Http2Response` for stream ``sid``.

The returned :class:`Http2Response` owns the header list
and body bytes; the entry is removed from
:attr:`conn.streams` so the per-connection memory is
reclaimed across many sequential requests on one driver.

Raises: Error: When ``sid`` is unknown, the stream is not yet ready (use :meth:`response_ready` to gate), or the response lacks the required ``:status`` pseudo-header.

#### `Http2ClientConnection.goaway_received`

```mojo
def goaway_received(self) -> Bool
```

``True`` once the peer has sent a GOAWAY frame (RFC 9113 §6.8). The high-level facade SHOULD stop opening new streams; in-flight streams MAY complete.

#### `Http2ClientConnection.send_request_open`

```mojo
def send_request_open(mut self, sid: Int, method: String, scheme: String, authority: String, path: String, extra_headers: List[HpackHeader]) raises
```

Open a request stream that stays OPEN for incremental body writes (client-streaming / bidi).

Like :meth:`send_request` but emits HEADERS *without*
``END_STREAM`` and never any body, leaving the stream in OPEN
state so the caller pumps request DATA frames via
:meth:`send_data` and half-closes with an empty
``end_stream=True`` DATA frame when the request body is done.

#### `Http2ClientConnection.headers_received`

```mojo
def headers_received(self, sid: Int) raises -> Bool
```

``True`` once the response HEADERS block on ``sid`` is fully received (END_HEADERS observed). Body / trailers may still be arriving.

#### `Http2ClientConnection.stream_ended`

```mojo
def stream_ended(self, sid: Int) raises -> Bool
```

``True`` once the peer has ENDed (END_STREAM) or RESET the stream, i.e. no more response DATA will arrive.

#### `Http2ClientConnection.drain_body`

```mojo
def drain_body(mut self, sid: Int) raises -> List[UInt8]
```

Move out and return the response DATA accumulated on ``sid`` so far, clearing the stream's buffer.

Returns an empty list when no new DATA has arrived. Keeps the
stream entry alive (unlike :meth:`take_response`) so subsequent
DATA frames keep accumulating; this is what bounds memory on a
long streaming response.

#### `Http2ClientConnection.enable_response_streaming`

```mojo
def enable_response_streaming(mut self, sid: Int) raises
```

Return this stream's DATA credit only when drain_body consumes it.

Call before feeding the response. Drain outbound WINDOW_UPDATEs
before waiting for more inbound data.

#### `Http2ClientConnection.response_headers`

```mojo
def response_headers(self, sid: Int) raises -> List[HpackHeader]
```

Return a copy of the current header list for ``sid`` (initial HEADERS plus any trailing HEADERS the driver has merged in). Read after :meth:`stream_ended` to pick up gRPC trailers (``grpc-status`` / ``grpc-message``).

#### `Http2ClientConnection.discard_stream`

```mojo
def discard_stream(mut self, sid: Int)
```

Drop the stream entry for ``sid`` (after the caller has read the trailers), reclaiming its per-connection memory.

#### `Http2ClientConnection.initial_response_headers`

```mojo
def initial_response_headers(self, sid: Int) raises -> List[HpackHeader]
```

#### `Http2ClientConnection.response_trailers`

```mojo
def response_trailers(self, sid: Int) raises -> List[HpackHeader]
```

#### `Http2ClientConnection.cancel_stream`

```mojo
def cancel_stream(mut self, sid: Int)
```

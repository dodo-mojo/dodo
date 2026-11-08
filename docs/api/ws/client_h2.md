# `dodo.ws.client_h2`

WebSocket-over-HTTP/2 stream <-> frame adapter (RFC 8441).

This module bolts the WebSocket framing layer (`dodo.ws.frame`) on
top of a single HTTP/2 stream driven by
`dodo.http2.client.Http2ClientConnection`. It ships the *primitive*
for WS-over-h2 -- the high-level ALPN-driven
`WsClient.prefer_h2 = True` dispatcher, the Extended CONNECT
200-response wait, and the nghttp2/browser-interop test suite are
tracked as follow-up work in `docs/features.md`.

Design constraints (RFC 8441 §5):

- The HTTP/2 stream replaces the HTTP/1.1 socket; WS frames travel
  inside DATA frames, never spanning HEADERS frames.
- A WS frame may be split across multiple DATA frames; conversely
  a single DATA frame may carry multiple WS frames. The adapter
  buffers receive bytes and pulls frames as they complete.
- The Extended CONNECT stream stays in the OPEN state for the
  whole tunnel lifetime. END_STREAM closes the WS connection
  cleanly; RST_STREAM maps to an abnormal WS close.
- Masking: RFC 6455 §5.3 mandates client->server masking *for the
  WS protocol*. RFC 8441 does not relax that requirement. We
  preserve it so the adapter is interchangeable with a plain
  HTTP/1.1 WS client at the frame layer.

Public surface:

- :class:`WsOverH2Stream` -- stateful wrapper around one h2 stream.
- :func:`bootstrap_ws_over_h2` -- helper to queue the Extended
  CONNECT request (HEADERS without END_STREAM) on a brand-new
  stream id.

## Structs

### `WsOverH2Stream`

```mojo
struct WsOverH2Stream
```

Stream-keyed adapter that turns an h2 stream into a WS tunnel.

Owns the per-stream receive buffer (DATA frames are appended,
WS frames are pulled out as they complete) and the outgoing
masking-key state (a deterministic monotonic counter is fine
here -- the over-the-wire mask is moot when h2 is itself
over TLS, but we still emit it so the adapter is symmetrical
with the h1 path).

Lifetime: one instance per Extended CONNECT stream. The
adapter does *not* drive the underlying h2 connection; the
caller is responsible for feeding bytes into / draining bytes
out of the connection. The adapter only reads
``conn.conn.streams[sid].data`` (and clears it after each
successful decode) and pushes outgoing WS frames into
``conn.send_data``.

Fields:

- `stream_id` (`Int`): The h2 stream id (must match the id used in :func:`bootstrap_ws_over_h2`).
- `read_buffer` (`List[UInt8]`): Accumulated, undecoded receive bytes from :attr:`Stream.data`. Refilled on every :meth:`pull_frames`.
- `closed` (`Bool`): Set to ``True`` after a CLOSE frame is sent or received. Subsequent send/recv attempts raise.
- `max_frame_size` (`Int`): Largest frame payload :meth:`try_pull_frame` accepts. A frame that declares more is answered with CLOSE 1009 (MESSAGE_TOO_BIG) and the pull raises. Defaults to :data:`DEFAULT_MAX_FRAME_BYTES`.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WsOverH2Stream.__init__`

```mojo
def __init__(out self, stream_id: Int)
```

Create an adapter bound to ``stream_id``.

Args:

- `stream_id`: The h2 stream id for the Extended CONNECT tunnel; allocate via :meth:`Http2ClientConnection.next_stream_id`.

#### `WsOverH2Stream.send_frame`

```mojo
def send_frame(mut self, mut conn: Http2ClientConnection, frame: WsFrame) raises
```

Encode ``frame`` and queue it as a DATA frame on this stream.

Per RFC 6455 §5.3 we mask the payload (mandatory on the
client side) with a fresh key from the OS CSPRNG. It was a
32-bit counter, which the RFC rules out: the key must be
unpredictable to whoever controls the payload, or masking does
not stop intermediary cache poisoning. The ``end_stream`` flag is set IFF the
frame is a CLOSE frame, which mirrors RFC 8441 §5.5
("close handshake completion translates to half-close").

Args:

- `conn`: The HTTP/2 client connection.
- `frame`: The WS frame to send.

#### `WsOverH2Stream.try_pull_frame`

```mojo
def try_pull_frame(mut self, mut conn: Http2ClientConnection) raises -> Optional[WsFrame]
```

Drain the stream's DATA buffer and decode at most one complete WS frame.

Returns ``None`` if the buffer doesn't yet hold a full
frame (call again once more bytes have been fed). Returns
the next ``WsFrame`` otherwise; callers loop until ``None``
to flush all frames waiting in this stream.

RFC 6455 §5.5 CLOSE frames flip :attr:`closed` so the
caller can treat the next outbound send as illegal and
the next inbound poll as EOF.

Args:

- `conn`: The HTTP/2 client connection.

#### `WsOverH2Stream.is_closed`

```mojo
def is_closed(self) -> Bool
```

Return ``True`` once a CLOSE frame has been sent or received on this stream. Used by the caller to stop pumping after the close handshake completes.

#### `WsOverH2Stream.close`

```mojo
def close(mut self, mut conn: Http2ClientConnection, code: UInt16 = UInt16(1000), reason: String = "") raises
```

Send a WS CLOSE frame and END_STREAM the h2 stream atomically.

After this call :attr:`closed` is ``True`` and further
:meth:`send_frame` invocations raise. The caller is still
responsible for draining any in-flight CLOSE response
from the peer (RFC 6455 §5.5.1: the responder echoes the
code + reason when it acknowledges).

Args:

- `conn`: The HTTP/2 client connection.
- `code`: Close status code (default :attr:`WsCloseCode.NORMAL`).
- `reason`: UTF-8 reason phrase (<= 123 bytes).

## Functions

### `bootstrap_ws_over_h2`

```mojo
def bootstrap_ws_over_h2(mut conn: Http2ClientConnection, sid: Int, authority: String, path: String, sec_ws_key_b64: String, sec_ws_protocol: String = "", sec_ws_extensions: String = "", scheme: String = "https") raises
```

Open an Extended CONNECT stream for a WebSocket tunnel.

Wraps :meth:`Http2ClientConnection.send_extended_connect` with
the WebSocket-specific extra headers (RFC 8441 §5.1):

- ``sec-websocket-version: 13`` (RFC 6455 §11.6)
- ``sec-websocket-key: <base64 16-byte nonce>`` (RFC 6455 §11.3.1).
  Note: per RFC 8441 §5.1 the key is informational over h2 --
  the server is *not* required to compute the
  ``Sec-WebSocket-Accept`` hash. Provide one anyway for parity
  with HTTP/1.1 servers reused as h2 backends.
- ``sec-websocket-protocol`` and ``sec-websocket-extensions``
  (optional sub-protocol / extension negotiation).

The stream is left in OPEN state so the caller can pump WS
frames via :class:`WsOverH2Stream` once the peer's HEADERS
response (status :status = 200) has been received.

The peer MUST have advertised
``SETTINGS_ENABLE_CONNECT_PROTOCOL = 1``; gate this call on
:meth:`Http2ClientConnection.peer_supports_extended_connect`.

Args:

- `conn`: The HTTP/2 client connection.
- `sid`: Stream id allocated via :meth:`Http2ClientConnection.next_stream_id`.
- `authority`: ``Host``-equivalent (e.g. ``"example.com"``).
- `path`: WebSocket resource path (e.g. ``"/chat"``).
- `sec_ws_key_b64`: Pre-computed base64 ``Sec-WebSocket-Key``.
- `sec_ws_protocol`: Optional sub-protocol token list.
- `sec_ws_extensions`: Optional extension offer list (e.g. ``"permessage-deflate"``).
- `scheme`: ``"http"`` or ``"https"`` (RFC 8441 §5.1).

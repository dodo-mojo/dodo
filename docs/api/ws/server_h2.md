# `dodo.ws.server_h2`

Server-side WebSocket-over-HTTP/2 carrier (RFC 8441).

The inverse of :class:`dodo.ws.client_h2.WsOverH2Stream`: it bridges the
WebSocket framing layer onto one server-side HTTP/2 stream driven by
:class:`dodo.http2.server.Http2Connection`. After the server accepts an
Extended CONNECT tunnel (``Http2Connection.accept_ws_over_h2``), this
carrier sends server->client frames UNMASKED (RFC 6455 5.3) as DATA via
``queue_stream_data`` and reads client->server frames (masked) out of the
stream's inbound DATA buffer via ``drain_stream_data``.

Symmetric with the client carrier's sans-I/O contract: it does not drive
the connection; the caller feeds/drains the underlying
:class:`Http2Connection` (reactor or paired-driver test).

## Structs

### `WsOverH2ServerStream`

```mojo
struct WsOverH2ServerStream
```

Stream-keyed server adapter turning one h2 stream into a WS tunnel.

The RFC 6455 rules live in :class:`dodo.ws.protocol.WsProtocol`; this
carrier moves its bytes. Outbound frames are unmasked (RFC 6455 5.3)
and go out through :meth:`Http2Connection.queue_stream_data` as far
as the stream's send window allows; the rest waits in the protocol's
bounded outbox.

Fields:

- `stream_id` (`Int`)
- `proto` (`WsProtocol`)
- `closed` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsOverH2ServerStream.__init__`

```mojo
def __init__(out self, stream_id: Int)
```

#### `WsOverH2ServerStream.flush`

```mojo
def flush(mut self, mut conn: Http2Connection) raises -> Int
```

Push queued outbound bytes as far as the window allows; return how many are still waiting.

#### `WsOverH2ServerStream.send_frame`

```mojo
def send_frame(mut self, mut conn: Http2Connection, frame: WsFrame) raises
```

Queue ``frame`` UNMASKED as DATA on this stream. A CLOSE ends the tunnel (later sends raise), and so does a send that would take the outbox past its bound (closed with 1008).

#### `WsOverH2ServerStream.try_pull_frame`

```mojo
def try_pull_frame(mut self, mut conn: Http2Connection) raises -> Optional[WsFrame]
```

Drain inbound DATA and return the next complete message as one TEXT or BINARY frame, a CLOSE frame once the session has ended (by the peer, or by a protocol violation answered with its CLOSE code), or ``None`` until more data arrives. PING, PONG and the CLOSE reply are handled here.

#### `WsOverH2ServerStream.is_closed`

```mojo
def is_closed(self) -> Bool
```

#### `WsOverH2ServerStream.close`

```mojo
def close(mut self, mut conn: Http2Connection, code: UInt16 = UInt16(1000), reason: String = "") raises
```

Send a server CLOSE frame (unmasked) to complete the handshake.

### `WsH2Hooks`

```mojo
struct WsH2Hooks
```

Opaque, non-owning boxed WS-over-h2 handler + its thunks.

Carries the heap address of the boxed ``W`` and its monomorphised
thunks so the non-generic reactor handle can invoke ``W``'s methods
without knowing its type. The address is owned by the ``serve`` call
that created it (:func:`make_ws_h2_hooks`); copies threaded to
connection handles are non-owning -- only the owner runs
``destroy_thunk``.

Fields:

- `addr` (`Int`)
- `open_thunk` (`def(Int, mut WsOverH2ServerStream, mut Http2Connection) raises thin -> None`)
- `msg_thunk` (`def(Int, mut WsOverH2ServerStream, mut Http2Connection, WsFrame) raises thin -> None`)
- `close_thunk` (`def(Int, mut WsOverH2ServerStream, mut Http2Connection) raises thin -> None`)
- `destroy_thunk` (`def(Int) thin -> None`)
- `clone_thunk` (`def(Int) raises thin -> Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsH2Hooks.__init__`

```mojo
def __init__(out self, addr: Int, open_thunk: def(Int, mut WsOverH2ServerStream, mut Http2Connection) raises thin -> None, msg_thunk: def(Int, mut WsOverH2ServerStream, mut Http2Connection, WsFrame) raises thin -> None, close_thunk: def(Int, mut WsOverH2ServerStream, mut Http2Connection) raises thin -> None, destroy_thunk: def(Int) thin -> None, clone_thunk: def(Int) raises thin -> Int)
```

#### `WsH2Hooks.clone`

```mojo
def clone(self) raises -> Self
```

Hooks over a fresh boxed copy of the handler (one per worker); the caller destroys it.

## Traits

### `WsH2Handler`

```mojo
trait WsH2Handler
```

Edge-driven handler for WebSocket-over-HTTP/2 tunnels (RFC 8441).

One handler instance is shared across every tunnel on the worker (like
the HTTP :trait:`dodo.http.Handler`); per-tunnel state belongs on the
``carrier`` or in handler-owned maps keyed by ``carrier.stream_id``.

Inherits from: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsH2Handler.on_open`

```mojo
def on_open(mut self, mut carrier: WsOverH2ServerStream, mut conn: Http2Connection) raises
```

Called once when a tunnel is accepted; may send opening frames.

#### `WsH2Handler.on_message`

```mojo
def on_message(mut self, mut carrier: WsOverH2ServerStream, mut conn: Http2Connection, frame: WsFrame) raises
```

Called per decoded client->server frame.

#### `WsH2Handler.on_close`

```mojo
def on_close(mut self, mut carrier: WsOverH2ServerStream, mut conn: Http2Connection) raises
```

Called once on teardown (peer CLOSE / RST / END_STREAM).

## Functions

### `make_ws_h2_hooks`

```mojo
def make_ws_h2_hooks[W: WsH2Handler](var handler: W) raises -> WsH2Hooks
```

Box ``handler`` on the heap and return its :class:`WsH2Hooks`.

The caller owns the returned hooks' allocation and MUST run
``hooks.destroy_thunk(hooks.addr)`` exactly once after the serving
loop exits.

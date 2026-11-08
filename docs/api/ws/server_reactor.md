# `dodo.ws.server_reactor`

Event-driven WebSocket handlers for HTTP/1.1 upgrades on the reactor.

``WsUpgrade.on_reactor(handler)`` keeps an upgraded connection on the
reactor worker that accepted it: the worker reads it without blocking,
runs the RFC 6455 rules in :class:`dodo.ws.protocol.WsProtocol`, and
calls the handler once per event. No thread is spawned per connection,
and a client that stops reading is cut off at the session's outbox
bound instead of growing memory.

Each connection gets its own copy of the handler, made from the one the
server was configured with, so per-connection state can live on
``self``; the copy is destroyed when the connection ends.

## Structs

### `WsSession`

```mojo
struct WsSession
```

One upgraded connection as a handler sees it.

Fields:

- `proto` (`WsProtocol`)
- `peer` (`SocketAddr`)
- `origin` (`String`): The handshake's ``Origin`` (the last one if repeated), or ``""``.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WsSession.__init__`

```mojo
def __init__(out self, peer: SocketAddr, var origin: String, max_message: Int, max_outbox: Int)
```

#### `WsSession.send_text`

```mojo
def send_text(mut self, msg: String) raises
```

Queue a TEXT message. Raises after a CLOSE, and when the peer is too far behind (the session then closes with 1008).

#### `WsSession.send_binary`

```mojo
def send_binary(mut self, data: List[UInt8]) raises
```

Queue a BINARY message; raises as :meth:`send_text` does.

#### `WsSession.close`

```mojo
def close(mut self, code: UInt16 = UInt16(1000))
```

Start the closing handshake.

### `WsReactorHooks`

```mojo
struct WsReactorHooks
```

A boxed handler prototype and its monomorphised thunks.

The prototype is never called; each connection gets a clone
(:meth:`clone_handler`) and destroys it on teardown. The prototype
lives as long as the server configuration that holds it.

Fields:

- `addr` (`Int`)
- `open_thunk` (`def(Int, mut WsSession) raises thin -> None`)
- `msg_thunk` (`def(Int, mut WsSession, var WsMessage) raises thin -> None`)
- `close_thunk` (`def(Int, mut WsSession, Int) thin -> None`)
- `destroy_thunk` (`def(Int) thin -> None`)
- `clone_thunk` (`def(Int) raises thin -> Int`)
- `max_message` (`Int`)
- `max_outbox` (`Int`)
- `idle_timeout_ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsReactorHooks.__init__`

```mojo
def __init__(out self, addr: Int, open_thunk: def(Int, mut WsSession) raises thin -> None, msg_thunk: def(Int, mut WsSession, var WsMessage) raises thin -> None, close_thunk: def(Int, mut WsSession, Int) thin -> None, destroy_thunk: def(Int) thin -> None, clone_thunk: def(Int) raises thin -> Int, max_message: Int, max_outbox: Int, idle_timeout_ms: Int)
```

#### `WsReactorHooks.clone_handler`

```mojo
def clone_handler(self) raises -> Int
```

## Traits

### `WsReactorHandler`

```mojo
trait WsReactorHandler
```

Edge-driven handler for HTTP/1.1 WebSocket connections.

Inherits from: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsReactorHandler.on_open`

```mojo
def on_open(mut self, mut ws: WsSession) raises
```

Called once, right after the upgrade.

#### `WsReactorHandler.on_message`

```mojo
def on_message(mut self, mut ws: WsSession, var msg: WsMessage) raises
```

Called per complete message (fragments already reassembled, text already validated as UTF-8).

#### `WsReactorHandler.on_close`

```mojo
def on_close(mut self, mut ws: WsSession, code: Int)
```

Called once when the connection ends, whichever side ended it: the code from the closing handshake, or 1006 when the connection dropped without one.

## Functions

### `make_ws_reactor_hooks`

```mojo
def make_ws_reactor_hooks[W: WsReactorHandler](var handler: W, max_message: Int = Int(16777216), max_outbox: Int = Int(4194304), idle_timeout_ms: Int = Int(60000)) raises -> WsReactorHooks
```

Box ``handler`` as the prototype for every connection's copy.

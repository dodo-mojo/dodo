# `dodo.ws`

WebSocket client and server (RFC 6455).

Built on `dodo.http` (HTTP Upgrade handshake) and `dodo.tcp`. Supports
text and binary frames, ping/pong keep-alives, masking (client→server), and
clean close handshake. SIMD-accelerated payload masking for payloads ≥128 bytes.

## Public API

```mojo
from dodo.ws import (
    WsClient, WsServer,
    WsFrame, WsOpcode, WsCloseCode,
    WsProtocolError, WsHandshakeError,
)
```

- `WsClient` — WebSocket client: `connect`, `send`, `recv`, `close`.
- `WsServer` — WebSocket server: upgrades HTTP connections to WebSocket.
- `WsFrame` — A single WebSocket frame: `text`, `binary`, `ping`, `pong`, `close`.
- `WsOpcode` — Opcode byte constants (`TEXT`, `BINARY`, `PING`, `PONG`, `CLOSE`).
- `WsCloseCode` — Close status code constants (`NORMAL`, `GOING_AWAY`, …).
- `WsProtocolError` — Raised on RFC 6455 protocol violations.
- `WsHandshakeError` — Raised when the HTTP Upgrade handshake fails.

## Example

```mojo
from dodo.ws import WsClient, WsFrame, WsOpcode

def main() raises:
    # Connect to a WebSocket echo server
    var ws = WsClient.connect("ws://echo.websocket.events")

    # Send a text frame
    _ = ws.send(WsFrame.text("hello, dodo!"))

    # Receive echo
    var frame = ws.recv()
    if frame.opcode == WsOpcode.TEXT:
        print(frame.text_payload()) # hello, dodo!

    # Ping / pong
    _ = ws.send(WsFrame.ping())
    var pong = ws.recv() # WsOpcode.PONG

    # Clean close
    ws.close()
```

### TLS WebSocket

```mojo
from dodo.ws import WsClient
from dodo.tls import TlsConfig

def main() raises:
    var ws = WsClient.connect("wss://echo.websocket.events", TlsConfig())
    _ = ws.send(WsFrame.text("secure hello"))
    var frame = ws.recv()
    print(frame.text_payload())
    ws.close()
```

## Modules

- [`dodo.ws.auto_client`](auto_client.md): `dodo.ws.auto_client` -- ALPN-driven WebSocket client dispatcher.
- [`dodo.ws.client`](client.md): WebSocket client (RFC 6455).
- [`dodo.ws.client_h2`](client_h2.md): WebSocket-over-HTTP/2 stream <-> frame adapter (RFC 8441).
- [`dodo.ws.extensions`](extensions.md): ``Sec-WebSocket-Extensions`` header parser + emitter (RFC 6455 §9 + RFC 7692 §7).
- [`dodo.ws.frame`](frame.md): WebSocket frame codec (RFC 6455 §5).
- [`dodo.ws.permessage_deflate`](permessage_deflate.md): WebSocket permessage-deflate extension (RFC 7692).
- [`dodo.ws.protocol`](protocol.md): Sans-I/O WebSocket server protocol core (RFC 6455).
- [`dodo.ws.server`](server.md): WebSocket server: upgrades HTTP connections to WebSocket (RFC 6455).
- [`dodo.ws.server_h2`](server_h2.md): Server-side WebSocket-over-HTTP/2 carrier (RFC 8441).
- [`dodo.ws.server_reactor`](server_reactor.md): Event-driven WebSocket handlers for HTTP/1.1 upgrades on the reactor.

# `dodo.ws.client`

WebSocket client (RFC 6455).

Opening handshake (§4.1):
  1. Parse ``ws://`` / ``wss://`` URL.
  2. Open TCP (ws) or TLS (wss) stream.
  3. Generate a random 16-byte nonce, base64-encode it as ``Sec-WebSocket-Key``.
  4. Send HTTP/1.1 GET with ``Upgrade: websocket`` headers.
  5. Parse the 101 Switching Protocols response.
  6. Verify ``Sec-WebSocket-Accept = base64(SHA-1(key + GUID))``.

SHA-1 is computed via libcrypto (OpenSSL) FFI -- the same library
already bundled by the TLS FFI build step. Base64 (RFC 4648 §4
standard alphabet) is the canonical helper at
:mod:`dodo.crypto.base64`; the local ``_base64_encode`` alias
keeps the call sites readable while routing through one source
of truth (this used to ship as three near-identical private
encoders).

## Structs

### `WsHandshakeError`

```mojo
struct WsHandshakeError
```

Raised when the WebSocket opening handshake fails.

Fields:

- `message` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `WsHandshakeError.__init__`

```mojo
def __init__(out self, message: String)
```

#### `WsHandshakeError.write_to`

```mojo
def write_to[W: Writer, //](self, mut writer: W)
```

### `WsMessage`

```mojo
struct WsMessage
```

A high-level WebSocket message (Text or Binary).

Produced by ``WsClient.recv_message()``. Use ``is_text`` to
discriminate between message kinds.

Fields:
    is_text: ``True`` for a UTF-8 text message; ``False`` for binary.

Example:
```mojo
var msg = ws.recv_message()
if msg.is_text:
    print(msg.as_text())
else:
    print("binary:", len(msg.as_binary()), "bytes")
```

Fields:

- `is_text` (`Bool`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WsMessage.__init__`

```mojo
def __init__(out self, text: String)
```

Initialise a text ``WsMessage``.

Args:

- `text`: The UTF-8 text payload.

```mojo
def __init__(out self, binary: List[UInt8])
```

Initialise a binary ``WsMessage``.

Args:

- `binary`: The raw binary payload.

#### `WsMessage.as_text`

```mojo
def as_text(self) -> String
```

Return the message payload as a UTF-8 string.

Returns: The text payload when ``is_text`` is ``True``; an empty string otherwise.

#### `WsMessage.as_binary`

```mojo
def as_binary(self) -> List[UInt8]
```

Return the message payload as raw bytes.

Returns: A copy of the binary payload when ``is_text`` is ``False``; an empty list otherwise.

### `WsClient`

```mojo
struct WsClient
```

A WebSocket client connection established via HTTP Upgrade.

Handles the opening handshake, frame encoding/decoding, masking
(client→server frames MUST be masked per RFC 6455 §5.3), and
automatic PONG replies to PING frames.

This type is ``Movable`` but not ``Copyable``. It supports the context
manager protocol (``__enter__`` / ``__exit__``) for use with ``with``.

Fields:
    _stream: Underlying transport (TLS or TCP).
    _key: The ``Sec-WebSocket-Key`` used for this connection.

Example:
```mojo
with WsClient.connect("wss://echo.websocket.events") as ws:
    ws.send_text("hello")
    var msg = ws.recv_message()
    print(msg.as_text())
```

Fields:

- `max_frame_size` (`Int`): Largest frame payload :meth:`recv` accepts. A server frame that declares more is answered with CLOSE 1009 (MESSAGE_TOO_BIG) and :meth:`recv` raises, before any of the payload is buffered. Defaults to :data:`DEFAULT_MAX_FRAME_BYTES`.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WsClient.__init__`

```mojo
def __init__(out self, var stream: _WsStream, key: String)
```

#### `WsClient.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `WsClient.connect`

```mojo
def connect(url: String) raises -> Self
```

Connect to a WebSocket server using default TLS configuration.

Equivalent to ``WsClient.connect(url, TlsConfig())``.

Args:

- `url`: WebSocket URL (``ws://`` or ``wss://``).

Returns: A ``WsClient`` with the handshake complete.

Raises: NetworkError: If the TCP/TLS connection fails. WsHandshakeError: If the server's Upgrade response is invalid.

```mojo
def connect(url: String, config: TlsConfig) raises -> Self
```

Connect to a WebSocket server with custom TLS configuration.

For ``wss://`` URLs, wraps the connection in TLS using ``config``.

Args:

- `url`: WebSocket URL (``ws://`` or ``wss://``).
- `config`: TLS configuration (only used for ``wss://``).

Returns: A ``WsClient`` with the handshake complete.

Raises: NetworkError: If the TCP/TLS connection fails. WsHandshakeError: If the server's Upgrade response is invalid or ``Sec-WebSocket-Accept`` does not match.

#### `WsClient.send_text`

```mojo
def send_text(self, msg: String) raises
```

Send a UTF-8 text message (client→server, masked).

Args:

- `msg`: The message string. Must be valid UTF-8.

Raises: NetworkError: On I/O failure.

#### `WsClient.send_binary`

```mojo
def send_binary(self, data: List[UInt8]) raises
```

Send a binary message (client→server, masked).

Args:

- `data`: The raw binary payload.

Raises: NetworkError: On I/O failure.

#### `WsClient.send_frame`

```mojo
def send_frame(self, frame: WsFrame) raises
```

Send an already-constructed frame.

Args:

- `frame`: The frame to send (masked automatically).

Raises: NetworkError: On I/O failure.

#### `WsClient.recv`

```mojo
def recv(mut self) raises -> WsFrame
```

Receive the next data frame, handling PING transparently.

Automatically replies to PING frames with a PONG and continues
reading. CLOSE frames are returned to the caller.

Returns: The next ``WsFrame`` (TEXT, BINARY, or CLOSE).

Raises: NetworkError: On I/O failure. WsProtocolError: On protocol violation. Error: On truncated frame data.

#### `WsClient.recv_message`

```mojo
def recv_message(mut self) raises -> WsMessage
```

Receive the next complete message as a ``WsMessage``.

A higher-level alternative to ``recv()`` that returns a
``WsMessage`` (Text or Binary) instead of a raw ``WsFrame``.
A fragmented message (a TEXT or BINARY frame without FIN followed
by CONTINUATION frames up to one with FIN, RFC 6455 sec 5.4) is
reassembled and returned whole. PING frames are handled
transparently (PONG sent automatically), PONG frames are skipped,
and either may arrive between fragments. CLOSE frames raise a
``NetworkError``. A text message is checked for valid UTF-8 as a
whole, so a code point may be split across fragments. The
reassembled payload is bounded by ``max_frame_size``.

Example:
```mojo
var msg = ws.recv_message()
if msg.is_text:
    print(msg.as_text())
```

Returns: A ``WsMessage`` with ``is_text=True`` for text frames and ``is_text=False`` for binary frames.

Raises: NetworkError: If a CLOSE frame is received or I/O fails. WsProtocolError: On protocol violation: a CONTINUATION with no message to continue, a new data frame inside a fragmented message, an unknown data opcode, invalid UTF-8 in a text message, or a message over ``max_frame_size`` (CLOSE 1009 is sent first).

#### `WsClient.__enter__`

```mojo
def __enter__(var self) -> Self
```

Transfer ownership of ``self`` into the ``with`` block.

Returns: This ``WsClient`` (moved).

#### `WsClient.close`

```mojo
def close(mut self)
```

Send a CLOSE frame and close the underlying transport.

Idempotent — safe to call multiple times.

# `dodo.ws.protocol`

Sans-I/O WebSocket server protocol core (RFC 6455).

``WsProtocol`` takes the bytes a client sent and hands back complete
messages and the bytes to send in reply. Every carrier -- HTTP/1.1 on
the reactor and HTTP/2 tunnels -- drives the same state machine,
so they enforce the same rules:

- client frames must be masked (1002, sec 5.1);
- a frame's declared length is checked against the cap before its
  payload is buffered, and a reassembled message against the same cap
  before each fragment is appended (1009);
- a CONTINUATION needs a message to continue, and a new data frame may
  not start inside one (1002, sec 5.4);
- a text message must be UTF-8 as a whole (1007, sec 8.1);
- a PING is answered with a PONG; a PONG is ignored (sec 5.5.2-5.5.3);
- a CLOSE is answered once, echoing a valid code and replacing an
  invalid body with 1002 (sec 5.5.1, 7.4.1), and nothing is sent after
  a CLOSE;
- the queue of bytes waiting for the peer is bounded: past
  ``max_outbox`` the connection fails with 1008 rather than buffer
  without limit for a client that does not read.

A protocol violation does not raise. The core queues the CLOSE the RFC
calls for and reports a ``WS_EVENT_CLOSED`` event carrying that code;
the carrier flushes ``outbox`` and drops the connection.

## Aliases

### `WS_EVENT_MESSAGE`

```mojo
comptime WS_EVENT_MESSAGE = Int(1)
```

### `WS_EVENT_CLOSED`

```mojo
comptime WS_EVENT_CLOSED = Int(2)
```

### `DEFAULT_MAX_OUTBOX_BYTES`

```mojo
comptime DEFAULT_MAX_OUTBOX_BYTES = Int(4194304)
```

Bytes a connection may hold for a peer that is not reading.

## Structs

### `WsEvent`

```mojo
struct WsEvent
```

A complete message, or the end of the session.

Fields:

- `kind` (`Int`): ``WS_EVENT_MESSAGE`` or ``WS_EVENT_CLOSED``.
- `is_text` (`Bool`): For a message: TEXT (validated UTF-8) rather than BINARY.
- `payload` (`List[UInt8]`): For a message: the reassembled payload.
- `code` (`Int`): For a close: the code the session ended with (1005 when the peer sent none).

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsEvent.__init__`

```mojo
def __init__(out self, kind: Int, is_text: Bool, var payload: List[UInt8], code: Int)
```

### `WsProtocol`

```mojo
struct WsProtocol
```

One server-side WebSocket session, without I/O.

Fields:

- `inbox` (`List[UInt8]`): Received bytes; those from ``_in_pos`` on are not decoded yet. Carriers append to it.
- `outbox` (`List[UInt8]`): Encoded frames waiting to be sent. Carriers send from the front and call ``consumed``.
- `max_message` (`Int`): Largest frame payload, and largest reassembled message.
- `max_outbox` (`Int`): Largest ``outbox`` before the session fails with 1008.
- `close_sent` (`Bool`)
- `close_received` (`Bool`)
- `failed` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsProtocol.__init__`

```mojo
def __init__(out self, max_message: Int = Int(16777216), max_outbox: Int = Int(4194304))
```

#### `WsProtocol.finished`

```mojo
def finished(self) -> Bool
```

No further event will come: closed by either side or failed.

#### `WsProtocol.wants_input`

```mojo
def wants_input(self) -> Bool
```

Whether reading more is useful: the session is live and the peer is draining what it was sent.

#### `WsProtocol.consumed`

```mojo
def consumed(mut self, n: Int)
```

Drop the first ``n`` bytes of ``outbox`` once they are sent.

#### `WsProtocol.send_text`

```mojo
def send_text(mut self, msg: String) raises
```

#### `WsProtocol.send_binary`

```mojo
def send_binary(mut self, data: List[UInt8]) raises
```

#### `WsProtocol.send_frame`

```mojo
def send_frame(mut self, frame: WsFrame) raises
```

Queue any server frame; a CLOSE goes through :meth:`close` so at most one is ever sent.

#### `WsProtocol.event_frame`

```mojo
def event_frame(self, ev: WsEvent) -> WsFrame
```

``ev`` as the frame a frame-level handler expects: a whole TEXT or BINARY message, or a CLOSE carrying the code the session ended with.

#### `WsProtocol.close`

```mojo
def close(mut self, code: UInt16 = UInt16(1000))
```

Start the closing handshake; a no-op once a CLOSE was sent.

#### `WsProtocol.next_event`

```mojo
def next_event(mut self) -> Optional[WsEvent]
```

Decode buffered frames until a message completes, the session ends, or more bytes are needed (``None``).

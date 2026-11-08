# `dodo.ws.frame`

WebSocket frame codec (RFC 6455 §5).

Frame wire format (§5.2):

```mojo
0 1 2 3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
```

   +-+-+-+-+-------+-+-------------+-------------------------------+
   |F|R|R|R| opcode|M| Payload len | Extended payload length |
   |I|S|S|S| (4) |A| (7) | (16/64) |
   |N|V|V|V| |S| | (if payload len==126/127) |
   | |1|2|3| |K| | |
   +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - -+
   | Extended payload length continued, if payload len == 127 |
   + - - - - - - - - - - - - - - -+-------------------------------+
   | |Masking-key, if MASK set to 1 |
   +-------------------------------+-------------------------------+
   | Masking-key (continued) | Payload Data |
   +-------------------------------- - - - - - - - - - - - - - - -+
   : Payload Data continued ... :
   +---------------------------------------------------------------+

Masking (§5.3):

```mojo
Every client→server frame payload byte is XOR'd with a rotating
4-byte masking key. Server→client frames MUST NOT be masked.
This implementation uses SIMD-32 masking for payloads ≥ 64 bytes.
```

## Aliases

### `DEFAULT_MAX_FRAME_BYTES`

```mojo
comptime DEFAULT_MAX_FRAME_BYTES = Int(16777216)
```

Largest frame payload a receiver accepts by default (16 MiB), the same bound :data:`DEFAULT_MAX_DECOMPRESSED_BYTES` puts on an inflated message. :meth:`WsFrame.decode_one` checks the declared length before any payload is buffered, so a header announcing a 4 GiB frame fails at once instead of having the reader grow its buffer towards it.

### `WS_TOO_BIG_MARKER`

```mojo
comptime WS_TOO_BIG_MARKER = String("frame too big")
```

Text in the :class:`WsProtocolError` that :meth:`WsFrame.decode_one` raises for a frame over its ``max_payload``. Readers look for it to answer with CLOSE :data:`WsCloseCode.MESSAGE_TOO_BIG` (1009) before they drop the connection.

## Structs

### `WsOpcode`

```mojo
struct WsOpcode
```

WebSocket opcode byte constants (RFC 6455 §5.2).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `CONTINUATION = UInt8(0)`
- `TEXT = UInt8(1)`
- `BINARY = UInt8(2)`
- `CLOSE = UInt8(8)`
- `PING = UInt8(9)`
- `PONG = UInt8(10)`

### `WsCloseCode`

```mojo
struct WsCloseCode
```

WebSocket close status code constants (RFC 6455 §7.4.1).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `NORMAL = UInt16(1000)`: Clean, normal closure.
- `GOING_AWAY = UInt16(1001)`: Endpoint going away (e.g. server restart).
- `PROTOCOL_ERROR = UInt16(1002)`: Protocol violation.
- `UNSUPPORTED_DATA = UInt16(1003)`: Received unsupported data type.
- `NO_STATUS = UInt16(1005)`: Reserved — must not be sent; used when code is absent in Close frame.
- `ABNORMAL = UInt16(1006)`: Reserved — must not be sent; used when connection drops without Close.
- `INVALID_PAYLOAD = UInt16(1007)`: Text frame contained invalid UTF-8.
- `POLICY_VIOLATION = UInt16(1008)`: Message violates server policy.
- `MESSAGE_TOO_BIG = UInt16(1009)`: Message exceeded configured size limit.
- `INTERNAL_ERROR = UInt16(1011)`: Server encountered an internal error.

### `WsProtocolError`

```mojo
struct WsProtocolError
```

Raised when an incoming frame violates RFC 6455.

Fields:

- `message` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `WsProtocolError.__init__`

```mojo
def __init__(out self, message: String)
```

#### `WsProtocolError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `WsFrame`

```mojo
struct WsFrame
```

A single WebSocket frame.

Represents the decoded wire form: header fields extracted and
``payload`` already de-masked (clients unmask on receive).

Owns the payload buffer.

Fields:
    fin: True if this is the final fragment of a message.
    rsv1: Extension bit RSV1 (must be False unless extension negotiated).
    opcode: Frame opcode (see ``WsOpcode.*``).
    masked: True if the payload was masked on the wire (client→server only).
    payload: The unmasked payload bytes.

Example:
```mojo
var frame = WsFrame.text("hello")
var wire = frame.encode(mask=True) # client sending to server
```

Fields:

- `fin` (`Bool`)
- `rsv1` (`Bool`)
- `opcode` (`UInt8`)
- `masked` (`Bool`)
- `payload` (`List[UInt8]`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `Writable`

#### `WsFrame.__init__`

```mojo
def __init__(out self, opcode: UInt8, payload: List[UInt8], fin: Bool = True, rsv1: Bool = False, masked: Bool = False)
```

#### `WsFrame.text`

```mojo
def text(msg: String) -> Self
```

Create a text (UTF-8) frame.

Args:

- `msg`: The UTF-8 text payload.

Returns: A ``WsFrame`` with opcode ``TEXT`` and ``fin=True``.

#### `WsFrame.binary`

```mojo
def binary(data: List[UInt8]) -> Self
```

Create a binary frame.

Args:

- `data`: The raw binary payload.

Returns: A ``WsFrame`` with opcode ``BINARY`` and ``fin=True``.

#### `WsFrame.ping`

```mojo
def ping(data: List[UInt8] = List()) -> Self
```

Create a PING control frame (max 125 bytes payload).

Args:

- `data`: Optional PING payload (echo'd back in PONG, ≤125 bytes).

Returns: A ``WsFrame`` with opcode ``PING``.

#### `WsFrame.pong`

```mojo
def pong(data: List[UInt8] = List()) -> Self
```

Create a PONG control frame.

Args:

- `data`: The payload from the corresponding PING.

Returns: A ``WsFrame`` with opcode ``PONG``.

#### `WsFrame.close`

```mojo
def close(code: UInt16 = UInt16(1000), reason: String = "") -> Self
```

Create a CLOSE control frame.

Args:

- `code`: Close status code (see ``WsCloseCode.*``).
- `reason`: UTF-8 reason phrase (≤123 bytes after encoding).

Returns: A ``WsFrame`` with opcode ``CLOSE``.

#### `WsFrame.encode`

```mojo
def encode(self, mask: Bool = False) raises -> List[UInt8]
```

Encode this frame to its RFC 6455 wire representation.

With ``mask=True`` the frame is masked with a fresh 4-byte key from
the OS CSPRNG, as RFC 6455 sec 5.3 requires of every client frame.
This used to be an all-zero key "for testing", and every client
frame dodo sent went out that way: masking with zeros leaves the
payload unchanged on the wire, which is exactly what the mask exists
to prevent (intermediary cache poisoning). Tests that need fixed
bytes call ``encode_with_key``.

Args:

- `mask`: True for a client-to-server frame.

Returns: The complete frame bytes ready to write to the socket.

Raises: WsProtocolError: If ``rsv1`` is set without a negotiated extension, or if a control frame payload exceeds 125 bytes.

#### `WsFrame.encode_with_key`

```mojo
def encode_with_key(self, mask: Bool, key: SIMD[.uint8, 4]) raises -> List[UInt8]
```

Encode this frame with an explicit 4-byte masking key.

Args:

- `mask`: True to apply the masking key.
- `key`: The 4-byte masking key (ignored when ``mask=False``).

Returns: The complete frame bytes.

Raises: WsProtocolError: If a control frame payload exceeds 125 bytes.

#### `WsFrame.decode_one`

```mojo
def decode_one(data: Span[UInt8], allow_rsv1: Bool = False, max_payload: Int = Int(16777216)) raises -> _DecodeResult
```

Parse one frame from ``data``.

Args:

- `data`: Raw bytes from the socket (may contain more than one frame).
- `allow_rsv1`: Accept a set RSV1 bit. Pass ``True`` only on a connection that negotiated an extension defining it (permessage-deflate, RFC 7692); the default rejects it per RFC 6455 sec 5.2, which requires a receiver to fail the connection on a reserved bit no negotiated extension gives meaning to.
- `max_payload`: Largest payload accepted, checked against the declared length as soon as it is parsed, before the payload has arrived.

Returns: A ``_DecodeResult`` with the parsed frame and bytes consumed.

Raises: WsProtocolError: If the frame violates RFC 6455 (bad RSV bits, a reserved opcode, fragmented control frame, etc.). Error: If ``data`` is too short to contain a complete frame.

#### `WsFrame.is_control`

```mojo
def is_control(self) -> Bool
```

Return True if this is a control frame (CLOSE, PING, or PONG).

Control frames MUST NOT be fragmented (RFC 6455 §5.5).

Returns: True for CLOSE (0x8), PING (0x9), and PONG (0xA) opcodes.

#### `WsFrame.text_payload`

```mojo
def text_payload(self) raises -> String
```

Decode the payload as a UTF-8 string with validation.

Validates that the payload is well-formed UTF-8 per RFC 6455 §8.1.
Raises ``WsProtocolError`` on invalid sequences.

Returns: Payload bytes decoded as a ``String``.

Raises: WsProtocolError: If the payload contains invalid UTF-8.

#### `WsFrame.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

## Functions

### `ws_frame_length`

```mojo
def ws_frame_length(data: Span[UInt8]) -> Int
```

Total length of the frame starting at ``data[0]`` once its header is in ``data``, or -1 while the header is still incomplete.

Reads only the length fields; :meth:`WsFrame.decode_one` validates
the frame. A receive loop reads until this many bytes are buffered
instead of attempting a decode that raises on every short read.

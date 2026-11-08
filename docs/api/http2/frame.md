# `dodo.http2.frame`

HTTP/2 frame codec (RFC 9113 §4).

Every HTTP/2 frame is a 9-octet header followed by a payload:

::

```mojo
+-----------------------------------------------+
| Length (24) |
+---------------+---------------+---------------+
| Type (8) | Flags (8) |
+-+-------------+---------------+-------------------------------+
|R| Stream Identifier (31) |
+=+=============================================================+
| Frame Payload (0...) ...
+---------------------------------------------------------------+
```

This module provides:

- :class:`FrameHeader` — the 9-byte fixed header.
- :class:`Frame` — owned wrapper carrying header + payload.
- :class:`FrameType` / :class:`FrameFlags` — typed constants.
- :func:`parse_frame` — best-effort parser; raises ``Http2Error`` on
  malformed length / oversized payload / invalid stream-id.
- :func:`encode_frame` — emit the wire representation.

The codec is *connection-agnostic*: it does not enforce stream
state, frame ordering, or the SETTINGS/window math. Those checks
live in :mod:`dodo.http2.state`.

## Aliases

### `H2_PREFACE`

```mojo
comptime H2_PREFACE = StringSpan("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
```

Fixed connection-preface bytes a client MUST send first.

### `H2_DEFAULT_FRAME_SIZE`

```mojo
comptime H2_DEFAULT_FRAME_SIZE = Int(16384)
```

``SETTINGS_MAX_FRAME_SIZE`` initial value.

### `H2_MAX_FRAME_SIZE`

```mojo
comptime H2_MAX_FRAME_SIZE = Int(16777215)
```

24-bit length field upper bound.

## Structs

### `FrameType`

```mojo
struct FrameType
```

RFC 9113 §6 frame type codes (Table 1).

Fields:

- `value` (`UInt8`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `FrameType.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, v: UInt8)
```

#### `FrameType.DATA`

```mojo
def DATA() -> Self
```

#### `FrameType.HEADERS`

```mojo
def HEADERS() -> Self
```

#### `FrameType.PRIORITY`

```mojo
def PRIORITY() -> Self
```

#### `FrameType.RST_STREAM`

```mojo
def RST_STREAM() -> Self
```

#### `FrameType.SETTINGS`

```mojo
def SETTINGS() -> Self
```

#### `FrameType.PUSH_PROMISE`

```mojo
def PUSH_PROMISE() -> Self
```

#### `FrameType.PING`

```mojo
def PING() -> Self
```

#### `FrameType.GOAWAY`

```mojo
def GOAWAY() -> Self
```

#### `FrameType.WINDOW_UPDATE`

```mojo
def WINDOW_UPDATE() -> Self
```

#### `FrameType.CONTINUATION`

```mojo
def CONTINUATION() -> Self
```

#### `FrameType.name`

```mojo
def name(self) -> String
```

### `FrameFlags`

```mojo
struct FrameFlags
```

RFC 9113 §6 per-type flag bits.

Fields:

- `bits` (`UInt8`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `FrameFlags.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, b: UInt8)
```

#### `FrameFlags.has`

```mojo
def has(self, mask: UInt8) -> Bool
```

#### `FrameFlags.END_STREAM`

```mojo
def END_STREAM() -> UInt8
```

#### `FrameFlags.END_HEADERS`

```mojo
def END_HEADERS() -> UInt8
```

#### `FrameFlags.PADDED`

```mojo
def PADDED() -> UInt8
```

#### `FrameFlags.PRIORITY`

```mojo
def PRIORITY() -> UInt8
```

#### `FrameFlags.ACK`

```mojo
def ACK() -> UInt8
```

### `FrameHeader`

```mojo
struct FrameHeader
```

The 9-octet HTTP/2 frame header (RFC 9113 §4.1).

Stream id is unsigned 31-bit. The reserved high bit is masked
off on parse and ignored on emit.

Fields:

- `length` (`Int`)
- `type` (`FrameType`)
- `flags` (`FrameFlags`)
- `stream_id` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `FrameHeader.__init__`

```mojo
def __init__(out self)
```

### `Frame`

```mojo
struct Frame
```

A complete frame: header + owned payload bytes.

The payload is verbatim from the wire — it has *not* been
decoded into HEADERS / SETTINGS / etc. typed fields. Higher
layers (``state.mojo`` and ``hpack.mojo``) interpret the bytes.

Fields:

- `header` (`FrameHeader`)
- `payload` (`List[UInt8]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `Frame.__init__`

```mojo
def __init__(out self)
```

## Functions

### `parse_frame`

```mojo
def parse_frame(buf: Span[UInt8]) raises -> Optional[Frame]
```

Try to parse one frame from the front of ``buf``.

Returns: ``None`` if ``buf`` doesn't contain a complete frame yet (callers should keep buffering). ``Some(Frame)`` otherwise.

Raises: Error: For frames whose declared length exceeds :data:`H2_MAX_FRAME_SIZE` (RFC 9113 §4.2 — connection error ``FRAME_SIZE_ERROR``).

### `encode_frame_header_into`

```mojo
def encode_frame_header_into(ftype: FrameType, flags: FrameFlags, stream_id: Int, length: Int, mut out: List[UInt8])
```

Append the 9-octet frame header (RFC 9113 sec 4.1) for a payload of ``length`` bytes; the caller appends the payload itself.

### `encode_frame`

```mojo
def encode_frame(f: Frame) -> List[UInt8]
```

Emit the wire bytes for ``f`` (header + payload).

### `encode_frame_into`

```mojo
def encode_frame_into(f: Frame, mut out: List[UInt8])
```

Append the wire bytes for ``f`` (header + payload) to ``out``.

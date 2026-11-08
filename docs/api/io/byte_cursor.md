# `dodo.io.byte_cursor`

Safe, bounds-checked byte cursors.

``ByteReader`` and ``ByteWriter`` replace the
hand-rolled big-endian readers and unchecked ``String(unsafe_from_utf8=...)``
construction that a custom protocol front otherwise reaches for. Every
read is bounds-checked (a short buffer raises rather than reading out
of bounds); ``read_utf8`` validates UTF-8 before constructing the
``String``.

These are sans-I/O value types over an in-memory buffer -- they import
nothing from the reactor / socket layers -- so they are equally usable
in a parser, a fuzz harness, or the multiplexed frame codec
(``dodo.uds.frame_mux``) that builds on them.

## ByteReader

Borrows a ``Span[UInt8, origin]``; the ``origin`` parameter ties the
reader's lifetime to the buffer it reads from, so the borrow checker
prevents the reader (and any ``read_bytes`` sub-span) from outliving
the buffer.

```mojo
from dodo.io import ByteReader

var raw = List[UInt8](0x00, 0x00, 0x00, 0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F)
var r = ByteReader(Span[UInt8, _](raw))
var n = r.read_u32_be()      # 5
var s = r.read_utf8(Int(n))  # "hello" (validated)
```

## ByteWriter

Owns a growable ``List[UInt8]``; the inverse of ``ByteReader``. Both
big-endian and little-endian integer widths are provided on each side.

```mojo
from dodo.io import ByteWriter

var w = ByteWriter()
w.write_u32_be(5)
w.write_str("hello")
var frame = w.take()  # List[UInt8]
```

## Structs

### `ByteReader`

```mojo
struct ByteReader[origin: Origin[mut=origin.mut]]
```

Bounds-checked cursor over a borrowed byte span.

Holds the borrowed ``buf`` and a read position ``pos``. Every
``read_*`` advances ``pos`` and raises ``Error`` if the buffer is
too short, so a malformed/truncated input can never read out of
bounds. ``read_utf8`` additionally validates UTF-8.

Fields:

- `buf` (`Span[UInt8, origin]`): Borrowed source buffer. Lifetime tied to ``origin``.
- `pos` (`Int`): Number of bytes already consumed from the front of ``buf``.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `ByteReader.__init__`

```mojo
def __init__(out self, buf: Span[UInt8, origin])
```

Construct a reader positioned at the start of ``buf``.

#### `ByteReader.remaining`

```mojo
def remaining(self) -> Int
```

Bytes left to read (``len(buf) - pos``).

#### `ByteReader.position`

```mojo
def position(self) -> Int
```

Current read offset from the start of ``buf``.

#### `ByteReader.read_u8`

```mojo
def read_u8(mut self) raises -> UInt8
```

Read one byte.

#### `ByteReader.read_u16_be`

```mojo
def read_u16_be(mut self) raises -> UInt16
```

Read a big-endian ``u16``.

#### `ByteReader.read_u16_le`

```mojo
def read_u16_le(mut self) raises -> UInt16
```

Read a little-endian ``u16``.

#### `ByteReader.read_u32_be`

```mojo
def read_u32_be(mut self) raises -> UInt32
```

Read a big-endian ``u32``.

#### `ByteReader.read_u32_le`

```mojo
def read_u32_le(mut self) raises -> UInt32
```

Read a little-endian ``u32``.

#### `ByteReader.read_u64_be`

```mojo
def read_u64_be(mut self) raises -> UInt64
```

Read a big-endian ``u64``.

#### `ByteReader.read_u64_le`

```mojo
def read_u64_le(mut self) raises -> UInt64
```

Read a little-endian ``u64``.

#### `ByteReader.read_bytes`

```mojo
def read_bytes(mut self, n: Int) raises -> Span[UInt8, origin]
```

Borrow the next ``n`` bytes as a sub-span (no copy).

The returned span shares ``origin`` with this reader's buffer.

#### `ByteReader.read_utf8`

```mojo
def read_utf8(mut self, n: Int) raises -> String
```

Read ``n`` bytes and return them as a validated ``String``.

Raises if fewer than ``n`` bytes remain or the bytes are not
well-formed UTF-8.

#### `ByteReader.skip`

```mojo
def skip(mut self, n: Int) raises
```

Advance the cursor by ``n`` bytes without reading them.

### `ByteWriter`

```mojo
struct ByteWriter
```

Owns a growable byte buffer; the inverse of ``ByteReader``.

Integer writers are infallible (the backing ``List`` grows as
needed). Call ``take()`` to move the accumulated bytes out, or
``bytes()`` to copy them.

Fields:

- `buf` (`List[UInt8]`): Accumulated output bytes.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `ByteWriter.__init__`

```mojo
def __init__(out self)
```

Construct an empty writer.

```mojo
def __init__(out self, var buf: List[UInt8])
```

Construct a writer that appends onto an existing buffer.

#### `ByteWriter.len`

```mojo
def len(self) -> Int
```

Number of bytes written so far.

#### `ByteWriter.write_u8`

```mojo
def write_u8(mut self, v: UInt8)
```

Append one byte.

#### `ByteWriter.write_u16_be`

```mojo
def write_u16_be(mut self, v: UInt16)
```

Append a big-endian ``u16``.

#### `ByteWriter.write_u16_le`

```mojo
def write_u16_le(mut self, v: UInt16)
```

Append a little-endian ``u16``.

#### `ByteWriter.write_u32_be`

```mojo
def write_u32_be(mut self, v: UInt32)
```

Append a big-endian ``u32``.

#### `ByteWriter.write_u32_le`

```mojo
def write_u32_le(mut self, v: UInt32)
```

Append a little-endian ``u32``.

#### `ByteWriter.write_u64_be`

```mojo
def write_u64_be(mut self, v: UInt64)
```

Append a big-endian ``u64``.

#### `ByteWriter.write_u64_le`

```mojo
def write_u64_le(mut self, v: UInt64)
```

Append a little-endian ``u64``.

#### `ByteWriter.write_bytes`

```mojo
def write_bytes(mut self, b: Span[UInt8])
```

Append every byte of ``b`` (single resize + memcpy).

#### `ByteWriter.write_str`

```mojo
def write_str(mut self, s: StringSpan)
```

Append the UTF-8 bytes of ``s``.

#### `ByteWriter.bytes`

```mojo
def bytes(self) -> List[UInt8]
```

Return a copy of the accumulated bytes.

#### `ByteWriter.take`

```mojo
def take(mut self) -> List[UInt8]
```

Move the accumulated bytes out, leaving the writer empty.

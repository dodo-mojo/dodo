# `dodo.http2.hpack`

HPACK header compression (RFC 7541).

This is a complete-but-pragmatic decoder + encoder:

- Static table from RFC 7541 Appendix A.
- Dynamic table with size-eviction (RFC 7541 §4).
- Integer codec (RFC 7541 §5.1) — 7-bit / 6-bit / 5-bit / 4-bit
  prefixes are all handled by :func:`decode_integer` /
  :func:`encode_integer`.
- String literal codec (RFC 7541 §5.2) with optional Huffman.
  ``HpackDecoder`` accepts ``H=1`` literals iff
  ``allow_huffman`` is set. The decoder uses the canonical
  RFC 7541 Appendix B codec from ``dodo.http.hpack_huffman``.
  ``HpackEncoder`` emits raw ``H=0`` literals by default;
  flipping ``allow_huffman`` makes it pick the shorter of raw vs
  Huffman per literal.

  This struct defaults to ``False`` because it is a low-level
  primitive built by hand. The server-facing knob,
  ``Http2Config.allow_huffman_decode``, defaults to **True**, and
  that is the one that matters for interop: RFC 7541 sec 5.2
  makes Huffman the *encoder's* choice, so a decoder that rejects
  ``H=1`` cannot talk to curl, browsers, or h2load.
- ``Indexed Header Field`` (§6.1), ``Literal Header Field with
  Incremental Indexing`` (§6.2.1), ``Literal Header Field without
  Indexing`` (§6.2.2), ``Literal Header Field Never Indexed``
  (§6.2.3), and ``Dynamic Table Size Update`` (§6.3).

The dynamic table eviction policy follows §4.2: a header that
exceeds the current ``max_size`` triggers full eviction; smaller
inserts evict the oldest entry until ``size <= max_size``.

## Aliases

### `HPACK_BUDGET_ERROR`

```mojo
comptime HPACK_BUDGET_ERROR = String("hpack: header block exceeds decode budget")
```

### `STATIC_TABLE_LEN`

```mojo
comptime STATIC_TABLE_LEN = 61
```

## Structs

### `StringPair`

```mojo
struct StringPair
```

Tuple of (string, new_offset).

Fields:

- `value` (`String`)
- `offset` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `StringPair.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, var value: String, offset: Int)
```

### `IntPair`

```mojo
struct IntPair
```

Tuple of (value, new_offset) used by :func:`decode_integer`.

Fields:

- `value` (`Int`)
- `offset` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `IntPair.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, value: Int, offset: Int)
```

### `HpackHeader`

```mojo
struct HpackHeader
```

A decoded ``(name, value)`` header pair.

Fields:

- `name` (`String`)
- `value` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `HpackHeader.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, var name: String, var value: String)
```

### `HpackDecoder`

```mojo
struct HpackDecoder
```

Stateful HPACK decoder.

A decoder must be reused across all HEADERS frames on a single
connection so the dynamic table tracks the peer's encoder.

``allow_huffman`` gates ``H=1`` literal decoding. It defaults to
``True``: RFC 7541 sec 5.2 lets any encoder Huffman-code any
literal, and real peers (curl, browsers, every CDN front end) do,
so a decoder that refuses them cannot talk to them. It used to
default to ``False``, which left every ``HpackDecoder()`` -- the
HTTP client's among them -- answering a real server's first
response with COMPRESSION_ERROR. Setting it ``False`` still makes
the decoder raise on ``H=1`` strings, for tests.

Fields:

- `dynamic` (`List[HpackHeader]`)
- `dynamic_size` (`Int`)
- `max_size` (`Int`)
- `settings_max_size` (`Int`): Ceiling a peer's size update may raise ``max_size`` back to.
- `allow_huffman` (`Bool`)
- `static` (`List[HpackHeader]`): RFC 7541 Appendix A, built once per decoder rather than per block.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `HpackDecoder.__init__`

```mojo
def __init__(out self)
```

#### `HpackDecoder.decode`

```mojo
def decode(mut self, buf: Span[UInt8], budget: Int = Int(0)) raises -> List[HpackHeader]
```

Decode a HEADERS / CONTINUATION block into header pairs.

Args:

- `buf`: The complete header block.
- `budget`: When positive, the most decoded bytes (RFC 7541 entry size: name + value + 32, summed) the block may expand to. Past it decoding stops with ``HPACK_BUDGET_ERROR``. A one-byte indexed field can name a 4 KiB table entry, so 16 KiB of block is 64 MiB of headers; checking the size only after a full decode let that be allocated first. Stopping midway leaves the dynamic table out of step with the peer, so the caller must end the connection.

### `HpackEncoder`

```mojo
struct HpackEncoder
```

Stateless-ish HPACK encoder.

Every header is emitted as a Literal-without-Indexing field
(§6.2.2). The dynamic table on the encoder side is always
empty, which is RFC-legal: HPACK explicitly allows the
encoder to choose not to use the dynamic table at all
(RFC 7541 §2.3.3 / §4.1). This trades a little wire bandwidth
for a much simpler encoder + zero risk of CRIME-class
information leaks across requests.

``allow_huffman`` gates ``H=1`` literal emission. When
``False`` (default) the encoder emits raw ``H=0`` literals.
When ``True``
each literal is emitted as the shorter of raw vs Huffman
(the Huffman length is computed first; the raw form wins
on tie). Since the dynamic table is empty either way, no
cross-request information can leak through compressed-length
side channels: every literal is encoded against the static
Appendix B Huffman table, independent of any prior request's
bytes. Callers that worry about a *per-request* compression-
side channel against secret tokens should leave the flag off.

The static table is searched by name only, never for a full
name-value pair, so ``:method: GET`` still sends ``GET`` as a
literal.

Fields:

- `allow_huffman` (`Bool`)
- `static` (`List[HpackHeader]`): RFC 7541 Appendix A, built once per encoder rather than per block.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `HpackEncoder.__init__`

```mojo
def __init__(out self)
```

#### `HpackEncoder.encode`

```mojo
def encode(self, headers: Span[HpackHeader]) -> List[UInt8]
```

## Functions

### `decode_integer`

```mojo
def decode_integer(buf: Span[UInt8], offset: Int, prefix_bits: Int) raises -> IntPair
```

Decode an integer with ``prefix_bits``-bit prefix at ``offset``.

Returns an :class:`IntPair` of ``(value, new_offset)``.
``prefix_bits`` is one of 4, 5, 6, 7. Raises on truncated input
or pathologically large values (we cap at 2**31 to stop
allocation amplification).

### `encode_integer`

```mojo
def encode_integer(mut out_buf: List[UInt8], value: Int, prefix_bits: Int, prefix_byte: UInt8)
```

Append ``value`` to ``out_buf`` using ``prefix_bits`` prefix.

The high bits of ``prefix_byte`` (above ``prefix_bits``) are
preserved; the prefix-bit slot is overwritten.

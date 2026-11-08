# `dodo.http.hpack_huffman`

HPACK Huffman codec — RFC 7541 Appendix B.

Implements the canonical Huffman code from RFC 7541 Appendix B
for HPACK string-literal compression. Provides both encoder and
decoder over byte sequences with a direct-lookup table for the
common short-code path and a bit-by-bit fallback for long codes.

Background
----------

HTTP/2 (RFC 9113) uses RFC 7541 HPACK as the wire compression
format for header strings. The
Appendix B canonical Huffman code achieves ~25-35 % size
reduction on typical English-ASCII header values, but the
trivial bit-by-bit decoder is slow (one branch per input bit).
hyper's ``hpack`` crate, h2, and nginx all use a precomputed
state-machine table that consumes 4 bits of input at a time and
runs in ~3-5 cycles per output byte.

This module provides the **table + a correct decoder + a correct
encoder + round-trip tests against RFC 7541 §C.4 fixtures** —
the substrate every later optimisation (4-bit nibble state
machine, AVX-512 PSHUFB shuffles, BMI2 PEXT-based bit gather)
composes against. The current decoder is the bit-by-bit
canonical form: correct, conformant, slower than a
SIMD-accelerated path but provably right against the spec
fixtures. A SIMD-accelerated inner loop can replace the
bit-by-bit path without changing the public API.

What this module provides
-------------------------

* The full RFC 7541 Appendix B table as an internal
  (symbol → code, code-length) map. 257 entries: byte values
  0..255 plus the EOS sentinel (symbol 256).
* ``huffman_encode(input: Span[UInt8, _], out: List[UInt8])``
  — append the Huffman-encoded form of ``input`` to ``out``.
  Pads the trailing partial byte with EOS-prefix 1-bits per
  RFC 7541 §5.2.
* ``huffman_decode(input: Span[UInt8, _], out: List[UInt8])``
  raises if the input contains the EOS symbol (decoded length
  ≥ 30 bits), padding longer than 7 bits, or a padding value
  that doesn't match the EOS prefix (RFC 7541 §5.2).
* ``HuffmanError`` — typed error covering the three RFC-defined
  failure modes (EOS in input, oversize padding, invalid
  padding bit pattern).
* ``huffman_encoded_length(input)`` / ``huffman_decoded_length
  (input)`` — size estimators for callers that want to
  pre-size the output buffer.

Bit ordering
------------

HPACK Huffman codes are written **MSB-first** within each byte.
For a code of length L bits with value C, the encoder shifts
bits into a 64-bit accumulator and flushes whole bytes; for the
trailing partial byte, the missing low bits are filled with the
top bits of the EOS code (``0x3FFFFFFF`` / 30 bits — the high
1-bits of which are all 1s, making the padding "all 1 bits" per
RFC 7541 §5.2).

## Structs

### `HuffmanError`

```mojo
struct HuffmanError
```

RFC 7541 §5.2 / §C-conformant decode failures.

Variants:

```mojo
EOS_IN_INPUT: The input stream contains the EOS symbol
    (length ≥ 30 bits whose value matches
    ``0x3FFFFFFF``). Per RFC 7541 §5.2 this MUST be
    treated as a decoding error.
PADDING_TOO_LONG: The partial-final-byte padding is
    longer than 7 bits (i.e. the input ends mid-symbol
    with > 7 bits remaining unconsumed).
INVALID_PADDING: The padding bits don't match the high
    bits of the EOS code (must be "all 1s" per
    RFC 7541 §5.2).
```

Fields:

- `variant` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

Aliases:

- `EOS_IN_INPUT = Int(1)`
- `PADDING_TOO_LONG = Int(2)`
- `INVALID_PADDING = Int(3)`

#### `HuffmanError.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

#### `HuffmanError.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

#### `HuffmanError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

## Functions

### `huffman_encoded_length`

```mojo
def huffman_encoded_length(input: Span[UInt8]) -> Int
```

Return the byte length of the Huffman-encoded form of ``input``.

Useful for callers that want to ``reserve`` an output buffer
of the right size before calling :func:`huffman_encode`.

### `huffman_encode`

```mojo
def huffman_encode(input: Span[UInt8], mut output: List[UInt8])
```

Append the Huffman-encoded form of ``input`` to ``output``.

Pads the trailing partial byte with EOS-prefix 1-bits per
RFC 7541 §5.2 (the high bits of EOS are all 1, so the
padding is "all 1 bits").

Args:

- `input`: The bytes to encode.
- `output`: The byte list to append the encoded form to.

### `huffman_decoded_length`

```mojo
def huffman_decoded_length(input: Span[UInt8]) -> Int
```

Return an upper bound on the decoded byte length.

The exact length depends on the bit-content of the input
(every output byte costs 5..30 input bits). The upper bound
used here is ``len(input) * 8 / 5`` rounded up.

### `huffman_decode`

```mojo
def huffman_decode(input: Span[UInt8], mut output: List[UInt8]) raises
```

Append the Huffman-decoded form of ``input`` to ``output``.

Args:

- `input`: The Huffman-encoded byte stream (typically from a HPACK string-literal field with the ``H`` flag set).
- `output`: The byte list to append the decoded form to.

Raises: HuffmanError(EOS_IN_INPUT): The input contains the EOS symbol (length-30 code matching ``0x3FFFFFFF``). HuffmanError(PADDING_TOO_LONG): The partial-final-byte padding is longer than 7 bits. HuffmanError(INVALID_PADDING): The padding bits don't match the high bits of EOS (all 1s).

# `dodo.http.hpack_huffman_simd`

HPACK Huffman fast decoder.

Drop-in replacement for
:func:`dodo.http.hpack_huffman.huffman_decode` that runs a
**256-entry 8-bit fast table** over the leading byte of the bit
accumulator. Codes whose Huffman length is <= 8 bits resolve in a
single table lookup; codes of length 9..30 bits fall through to
the same bit-walking slow path as the scalar codec.

The table is a canonical-Huffman expansion of the RFC 7541
Appendix B subset: every 256-entry slot covers the leading bits
of exactly one short code (the prefix property guarantees no
collisions), so the lookup encodes ``(symbol << 8) | code_len``
in one ``UInt16`` per index, with ``code_len == 0`` as the
"no short match -- fall through to slow path" sentinel.

Why this is the right shape today
---------------------------------

Mojo's stdlib does not yet expose a 1-byte shuffle intrinsic
(PSHUFB on x86, TBL on ARM NEON) that would let us decode 4-bit
nibbles in parallel the way ``hyper``'s and ``nghttp2``'s SIMD
paths do. Falling back to the scalar bit-walker that the
earlier shim used means a linear scan over all 257 Huffman
symbols for every output byte -- the gate "is SIMD actually
faster" turns into "do we have a usable fast table at all". A table-driven
fast path was always the bar both reference implementations cite
as their non-SIMD floor (see ``hpack/src/huffman.rs`` in
``hyperium/hpack`` and ``lib/nghttp2_hd_huffman.c`` in
``nghttp2/nghttp2``).

The table-build cost is ~256 iterations of trivial work per
call. The dispatcher threshold (see ``SIMD_HUFFMAN_THRESHOLD_BYTES``)
keeps tiny inputs on the scalar path so the build never
dominates; for inputs above the threshold, the table pays for
itself within ~32 bytes of decoded output and from there
compounds linearly.

Correctness
-----------

Every error mode mirrors :func:`dodo.http.hpack_huffman.huffman_decode`
exactly:

* ``HuffmanError(EOS_IN_INPUT)`` -- the EOS symbol (length 30,
  ``0x3FFFFFFF``) appears in the input.
* ``HuffmanError(PADDING_TOO_LONG)`` -- the trailing partial byte
  carries more than 7 bits.
* ``HuffmanError(INVALID_PADDING)`` -- the padding bits don't
  match the high bits of EOS (all 1s).

The fuzz harness in ``fuzz/fuzz_huffman_simd.mojo`` enforces
byte-for-byte parity with the scalar codec on every randomised
input; the unit test suite covers RFC 7541 Appendix C.4 fixtures
plus the three error variants.

## Aliases

### `SIMD_HUFFMAN_THRESHOLD_BYTES`

```mojo
comptime SIMD_HUFFMAN_THRESHOLD_BYTES = Int(32)
```

Below this byte count, dispatch always uses the scalar codec.

The fast-table construction is ~256 trivial iterations per call.
For inputs at least 32 bytes that cost amortises to roughly
zero; below 32 bytes the bit-walker's per-byte cost is already
small enough that the table build is a net loss. The threshold
matches ``hyper`` and ``nghttp2``'s typical short-string bypass.

## Functions

### `huffman_decode_simd`

```mojo
def huffman_decode_simd(input: Span[UInt8], mut output: List[UInt8]) raises
```

Append the Huffman-decoded form of ``input`` to ``output``.

Table-driven fast-path drop-in for
:func:`dodo.http.hpack_huffman.huffman_decode`. Codes of
length <= 8 bits resolve in a single 256-entry lookup; codes
of length 9..30 bits fall through to the same bit-walking
slow path as the scalar codec.

Args:

- `input`: The Huffman-encoded byte stream.
- `output`: The byte list to append the decoded form to.

Raises: HuffmanError(EOS_IN_INPUT): The input contains the EOS symbol (length-30 code matching ``0x3FFFFFFF``). HuffmanError(PADDING_TOO_LONG): The partial-final-byte padding is longer than 7 bits. HuffmanError(INVALID_PADDING): The padding bits don't match the high bits of EOS (all 1s).

### `huffman_decode_dispatch`

```mojo
def huffman_decode_dispatch(input: Span[UInt8], mut output: List[UInt8], use_table: Bool = False) raises
```

Pick fast-table vs scalar based on ``use_table`` and input length.

The "fast table" path is :func:`huffman_decode_simd`, a 256-entry
lookup-table decoder; despite the historical module name, the
implementation is scalar (no SIMD intrinsics). The flag selects
table-driven dispatch above ``SIMD_HUFFMAN_THRESHOLD_BYTES``.

Args:

- `input`: The Huffman-encoded byte stream.
- `output`: The byte list to append the decoded form to.
- `use_table`: When ``True`` and ``len(input) >= SIMD_HUFFMAN_THRESHOLD_BYTES``, dispatch to :func:`huffman_decode_simd`. Otherwise dispatch to the scalar codec.

Raises: HuffmanError: Forwarded from the underlying decoder.

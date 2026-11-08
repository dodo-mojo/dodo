# `dodo.json.cpu.simd_clmul`

## Functions

### `prefix_xor64`

```mojo
def prefix_xor64(x: UInt64) -> UInt64
```

Per-bit prefix XOR over 64 bits.

Equivalent to `clmul(x, ~UInt64(0)).low_64()` (one PCLMULQDQ on x86
or one PMULL on ARM64 with CLMUL). The shift-based form below
compiles to six `xor`+`shl` pairs, ~6 cycles on a modern OoO core
-- well within the per-chunk budget for 64-byte stage 1 work
units, and free of any ISA feature gating.

### `find_escape_mask64`

```mojo
def find_escape_mask64(backslash: UInt64, mut prev_escape: UInt64) -> UInt64
```

Returns the bit-mask of bytes that are escaped within this chunk.

`prev_escape` carries the "byte 0 of this chunk is escaped by a
backslash from the previous chunk" flag (0 or 1). After the call,
`prev_escape` is updated to be the carry into the NEXT chunk -- 1
iff this chunk ended with a backslash whose escape lands on byte 0
of the chunk after.

Mirrors simdjson's `json_escape_scanner::next`.

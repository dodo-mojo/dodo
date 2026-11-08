# `dodo.json.cpu.stage1`

## Aliases

### `SIMD_WIDTH`

```mojo
comptime SIMD_WIDTH = Int(64)
```

Bytes processed per SIMD iteration. 64 lets us pack each per-chunk classifier output into a single uint64, which is exactly the width both the prefix-XOR and the simdjson escape-scanner work on natively.

## Functions

### `parse_structural_simd`

```mojo
def parse_structural_simd(input: String) -> StructuralIndex
```

Build a structural index using a branchless SIMD scan.

Output is byte-for-byte identical to
`stage1_scalar.parse_structural_scalar(input)` -- the equivalence is
enforced by `tests/test_stage1_equivalence.mojo`, including a
full-document run against the benchmark corpora.

The expensive per-marker questions ("is this `\` an escape,
is this `"` already escaped, is this `,` inside a string?")
become branchless bit-twiddling on the per-chunk uint64 masks,
leaving just one loop -- iterating set bits in the final emit
mask with `count_trailing_zeros`.

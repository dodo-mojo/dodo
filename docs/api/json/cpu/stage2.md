# `dodo.json.cpu.stage2`

## Functions

### `parse_two_pass_tape`

```mojo
def parse_two_pass_tape[force_scalar: Bool = False](var input: String) raises -> Document
```

End-to-end stage 1 + stage 2 parse that emits a `Document`.

Parameters:

- `force_scalar`: When False (default), use the SIMD stage 1 implementation (`stage1.parse_structural_simd`); on the benchmark corpora SIMD is ~1.2x faster than the scalar walker. When True, use the scalar oracle -- useful for differential testing and for inputs small enough that the SIMD chunk loop never runs (n < 32). Both produce identical output (enforced by `tests/test_stage1_equivalence.mojo`); this is purely a performance switch.

Args:

- `input`: JSON input. The returned `Document` owns this string, so its bytes can back zero-copy string slices on the tape.

Returns: Owned `Document` with the root at `Document.root()`.

### `parse_into_document`

```mojo
def parse_into_document(var input: String, index: StructuralIndex) raises -> Document
```

Build a `Document` (tape + side pools) by walking the structural index over `input`. The returned document owns `input`.

Args:

- `input`: Original JSON bytes.
- `index`: Output of stage 1. Borrowed immutably -- `positions` is read in place, no copy on entry.

Returns: Owned `Document` whose root entry is the last tape slot.

# `dodo.json.cpu`

The CPU parser: a two-pass stage 1 + stage 2 walker.

Stage 1 finds the structural positions (SIMD by default, scalar with
``force_scalar=True``; both give the same index). Stage 2 walks that
index and emits a ``Document`` tape, whose root comes back wrapped as a
``Value`` view.

## Modules

- [`dodo.json.cpu.number_parse`](number_parse.md)
- [`dodo.json.cpu.simd_clmul`](simd_clmul.md)
- [`dodo.json.cpu.stage1`](stage1.md)
- [`dodo.json.cpu.stage1_scalar`](stage1_scalar.md)
- [`dodo.json.cpu.stage2`](stage2.md)
- [`dodo.json.cpu.validate`](validate.md)

## Functions

### `parse_cpu_native_tape`

```mojo
def parse_cpu_native_tape[force_scalar: Bool = False](var s: String) raises -> Value
```

Parse ``s`` into a tape-backed ``Value`` view of the document root.

Reads (``is_*``, ``*_value``, ``__getitem__``, ...) hit the tape
directly; a mutation materialises an owned tree and rebuilds the
document.

Parameters:

- `force_scalar`: Use the scalar stage 1 instead of the SIMD one.

Args:

- `s`: JSON input. The returned ``Value``'s document owns it.

Returns: A ``Value`` view of the document root.

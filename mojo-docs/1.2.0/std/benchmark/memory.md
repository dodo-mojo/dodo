# `std.benchmark.memory`

Provides memory barrier utilities for preventing compiler optimizations.

This module includes the `clobber_memory()` function which acts as a memory
fence to prevent the compiler from reordering or eliminating memory operations.
This is essential for accurate benchmarking when memory access patterns need to
be preserved exactly as written.

## Functions

### `clobber_memory`

```mojo
def clobber_memory()
```

Forces all pending memory writes to be flushed to memory.

This ensures that the compiler does not optimize away memory writes if it
deems them to be not necessary. In effect, this operation acts as a barrier
to memory reads and writes.

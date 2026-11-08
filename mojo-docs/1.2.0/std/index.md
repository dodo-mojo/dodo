# `std`

All the data types, structs, traits, functions, and other APIs included with Mojo.

The standard library provides nearly everything you'll need for
writing Mojo programs, including basic data types like
[`Int`](../std/simd.md#int) and
[`SIMD`](../std/simd.md#simd), collection types like
[`List`](../std/collections/list.md#list), reusable
[algorithms](../std/algorithm/index.md), and modules to support
[GPU programming](https://max.modular.com/api/mojo/max/gpu/).

## Packages

- [`std.algorithm`](algorithm/index.md): High performance data operations including vectorization, functional map, and tiling.
- [`std.atomic`](atomic/index.md): Atomic operations and memory orderings.
- [`std.base64`](base64/index.md): Binary data encoding: base64 and base16 encode/decode functions.
- [`std.benchmark`](benchmark/index.md): Performance benchmarking: statistical analysis and detailed reports.
- [`std.bit`](bit/index.md): Bitwise operations: manipulation, counting, rotation, and power-of-two utilities.
- [`std.builtin`](builtin/index.md): Language foundation: built-in types, traits, and fundamental operations.
- [`std.collections`](collections/index.md): Core data types: List, Dict, Set, Optional, String, and other collections.
- [`std.compile`](compile/index.md): Runtime function compilation and introspection: assembly, IR, linkage, metadata.
- [`std.complex`](complex/index.md): Complex numbers: SIMD types, scalar types, and operations.
- [`std.documentation`](documentation/index.md): Documentation built-ins: decorators and utilities for doc generation.
- [`std.ffi`](ffi/index.md): Foreign function interface (FFI) for calling C code and loading libraries.
- [`std.format`](format/index.md): Provides formatting traits for converting types to text.
- [`std.hash`](hash/index.md): Cryptographic and non-cryptographic hashing with customizable algorithms.
- [`std.io`](io/index.md): Core I/O operations: console input/output, file handling, writing traits.
- [`std.iter`](iter/index.md): Iteration traits and utilities: Iterable, IterableOwned, Iterator, enumerate, zip, map.
- [`std.itertools`](itertools/index.md): Iterator tools for lazy sequence generation and transformation.
- [`std.logger`](logger/index.md): Logging with configurable severity levels.
- [`std.math`](math/index.md): Math functions and constants: trig, exponential, logarithmic, and special functions.
- [`std.memory`](memory/index.md): Low-level memory management: pointers, allocations, address spaces.
- [`std.net`](net/index.md): Provides networking support.
- [`std.origin`](origin/index.md): Defines Mojo's origin types.
- [`std.os`](os/index.md): OS interface layer: environment, filesystem, process control.
- [`std.pathlib`](pathlib/index.md): Filesystem path manipulation and navigation.
- [`std.prelude`](prelude/index.md): Standard library prelude: fundamental types, traits, and operations auto-imported.
- [`std.pwd`](pwd/index.md): Password database lookups for user account information.
- [`std.python`](python/index.md): Python interoperability: import packages and modules, call functions, type conversion.
- [`std.random`](random/index.md): Pseudorandom number generation with uniform and normal distributions.
- [`std.reflection`](reflection/index.md): Compile-time reflection utilities for introspecting Mojo types and functions.
- [`std.runtime`](runtime/index.md): Runtime services: runtime initialization and worker-thread queries.
- [`std.stat`](stat/index.md): File type constants and detection from stat system calls.
- [`std.subprocess`](subprocess/index.md): Execute external processes and commands.
- [`std.sys`](sys/index.md): System runtime: I/O, hardware info, intrinsics, compile-time utils.
- [`std.tempfile`](tempfile/index.md): Manage temporary files and directories: create, locate, and cleanup.
- [`std.testing`](testing/index.md): Unit testing: Assertions (equal, true, raises) and test suites.
- [`std.time`](time/index.md): Timing operations: monotonic clocks, performance counters, sleep, time_function.
- [`std.traits`](traits/index.md): Core object-lifetime and value-semantics traits.
- [`std.utils`](utils/index.md): General utils: indexing, variants, static tuples, and thread synchronization.

## Modules

- [`std.simd`](simd.md): Implements SIMD primitives and abstractions.

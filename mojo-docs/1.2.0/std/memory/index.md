# `std.memory`

Low-level memory management: pointers, allocations, address spaces.

The `memory` package provides primitives for direct memory manipulation and
pointer operations. It offers multiple pointer types with varying safety
guarantees, from reference-counted smart pointers to raw unsafe pointers, along
with functions for memory operations and allocation. This package enables
systems programming and interfacing with external code requiring explicit
memory control.

Use this package for performance-critical code requiring manual memory control,
interfacing with C libraries, implementing custom data structures, or accessing
specialized memory. Most code should prefer higher-level collections and
automatic memory management.

## Modules

- [`std.memory.address_space`](address_space.md): Implements `AddressSpace`, the memory address space of a pointer.
- [`std.memory.alloc`](alloc.md): Implements layout-aware memory allocation and deallocation.
- [`std.memory.arc_pointer`](arc_pointer.md): Reference-counted smart pointers.
- [`std.memory.maybe_uninit`](maybe_uninit.md): Implements `MaybeUninit`, a wrapper for memory that may or may not be initialized.
- [`std.memory.memory`](memory.md): Defines functions for memory manipulations.
- [`std.memory.owned_pointer`](owned_pointer.md): Implements `OwnedPointer`, a safe, single-ownership smart pointer.
- [`std.memory.pointer`](pointer.md): Implements `Pointer`, Mojo's primary pointer type for indirect memory access.
- [`std.memory.stack_allocation`](stack_allocation.md): Defines the `unsafe_stack_allocation` function for stack-based memory allocation.
- [`std.memory.unsafe`](unsafe.md): Provides utility functions for unsafe manipulation of SIMD values.
- [`std.memory.unsafe_pointer`](unsafe_pointer.md): Defines `UnsafePointer` as a backward-compatible name for `Pointer`.

# `std.builtin`

Language foundation: built-in types, traits, and fundamental operations.

The `builtin` package provides the core types, traits, and operations that form
the foundation of the Mojo language. It defines fundamental types like integers,
booleans, and strings, essential traits for type behavior (`Copyable`, `Movable`,
`Comparable`), and basic operations used throughout all Mojo code. Most symbols
from this package are automatically available without explicit imports through
the prelude.

This package is implicitly imported. It
defines the core vocabulary of Mojo programming that every developer uses
without thinking about imports. Library authors implement traits from this
package to integrate custom types with language features.

## Modules

- [`std.builtin.anytype`](anytype.md): Existential-type helpers built on `AnyType`, plus deprecated aliases for the traits that used to live in this module.
- [`std.builtin.bool`](bool.md): Implements the Bool class.
- [`std.builtin.breakpoint`](breakpoint.md): This module includes the builtin breakpoint function.
- [`std.builtin.builtin_slice`](builtin_slice.md): Implements slice.
- [`std.builtin.comparable`](comparable.md): Implements comparison and equality traits for Mojo types.
- [`std.builtin.constrained`](constrained.md): Implements compile-time constraint helpers used by trait conformance checks.
- [`std.builtin.debug_assert`](debug_assert.md): Implements run-time assertions.
- [`std.builtin.device_passable`](device_passable.md): Implements the `DevicePassable` trait for types transferable to accelerator devices.
- [`std.builtin.dtype`](dtype.md): Implements the DType class.
- [`std.builtin.enum_like`](enum_like.md): Defines the `EnumLike` trait used by enum-style pattern matching.
- [`std.builtin.error`](error.md): Implements the Error class.
- [`std.builtin.float_literal`](float_literal.md): Implements the FloatLiteral class.
- [`std.builtin.floatable`](floatable.md): Implements the `Floatable` and `FloatableRaising` traits.
- [`std.builtin.format_int`](format_int.md): Provides the `hex` and `bin` functions.
- [`std.builtin.globals`](globals.md): Utilities for working with global constants.
- [`std.builtin.identifiable`](identifiable.md): Defines the Identifiable trait for identity-based comparisons.
- [`std.builtin.inline_level`](inline_level.md): Provides the levels the `@inline` decorator accepts.
- [`std.builtin.int`](int.md): Implements the Int class.
- [`std.builtin.int_literal`](int_literal.md): Implements the IntLiteral class.
- [`std.builtin.len`](len.md): Provides the `len()` function and its associated traits.
- [`std.builtin.none`](none.md): Defines the builtin `NoneType`.
- [`std.builtin.range`](range.md): Defines Mojo's built-in `range()` function.
- [`std.builtin.rebind`](rebind.md): Implements type rebind/trait downcast.
- [`std.builtin.reversed`](reversed.md): Provides the `reversed` function for reverse iteration over collections.
- [`std.builtin.simd_length`](simd_length.md): Implements `SIMDLength`, which is a wrapper around the MLIR `index` type.
- [`std.builtin.sort`](sort.md): Implements the built-in `sort` function.
- [`std.builtin.string_literal`](string_literal.md): Implements the StringLiteral struct.
- [`std.builtin.swap`](swap.md): Implements the built-in `swap` function.
- [`std.builtin.tuple`](tuple.md): Implements the Tuple type.
- [`std.builtin.type_aliases`](type_aliases.md): Defines some type aliases.
- [`std.builtin.value`](value.md): Defines `Defaultable`, `RegisterPassable`, and `TrivialRegisterPassable`, plus deprecated aliases for the value-semantics traits that used to live in this module.
- [`std.builtin.variadics`](variadics.md): Implements the VariadicList, ParameterList and VariadicPack types.

# `std.traits`

Core object-lifetime and value-semantics traits.

The `traits` package defines the stabilized traits that describe how Mojo
values are created, copied, moved, and destroyed: `AnyType`, `Deinitable`,
`Movable`, `Copyable`, and `ImplicitlyCopyable`. These traits are Mojo
built-ins and are automatically imported into every Mojo program through the
prelude.

## Modules

- [`std.traits.anytype`](anytype.md): Defines `AnyType`, the most basic trait that all Mojo types extend by default.
- [`std.traits.copyable`](copyable.md): Defines `Copyable` and `ImplicitlyCopyable`, the traits for types whose value can be copied.
- [`std.traits.deinitable`](deinitable.md): Defines `Deinitable`, the trait for types with lifetime management through destructors.
- [`std.traits.movable`](movable.md): Defines `Movable`, the trait for types whose value can be moved.

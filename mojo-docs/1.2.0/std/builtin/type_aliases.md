# `std.builtin.type_aliases`

Defines some type aliases.

These are Mojo built-ins, so you don't need to import them.

## Aliases

### `Never`

```mojo
comptime Never = Never
```

A type that can never have an instance constructed, used as a function result by functions that never return.

### `EllipsisType`

```mojo
comptime EllipsisType = __mlir_type.`!lit.ellipsis`
```

The type of the `...` literal.

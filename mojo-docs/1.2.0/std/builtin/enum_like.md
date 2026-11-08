# `std.builtin.enum_like`

Defines the `EnumLike` trait used by enum-style pattern matching.

## Aliases

### `KGENString`

```mojo
comptime KGENString = __mlir_type.`!kgen.string`
```

The MLIR string type used for enum case names.

## Traits

### `EnumLike`

```mojo
trait EnumLike
```

A type with named, mutually exclusive alternatives.

`__enum` declarations synthesize this conformance. Hand-written types
(notably `Optional`) may also conform so pattern matching can treat their
alternatives as cases, such as `case .Some(x):` / `case .None:`.

By default, the declared alternatives cover every value. An open enum sets
`_enum_is_exhaustive` to `False` when other values may exist. Payload type
`NoneType` means the case has no associated value.

Inherits from: `AnyType`

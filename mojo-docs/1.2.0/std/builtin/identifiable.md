# `std.builtin.identifiable`

Defines the Identifiable trait for identity-based comparisons.

This module provides the `Identifiable` trait, which enables types to support
identity comparison using the `is` and `is not` operators. Identity comparison
checks if two values refer to the same object, distinct from equality
comparison which checks if two values have the same content.

## Traits

### `Identifiable`

```mojo
trait Identifiable
```

The Identifiable trait denotes a type with an identity which can be compared with other instances of itself.

Inherits from: `AnyType`

#### `Identifiable.__is__`

```mojo
def __is__(self, rhs: Self) -> Bool
```

Define whether `self` has the same identity as `rhs`.

Args:

- `rhs`: The right hand side of the comparison.

Returns: True if `self` is `rhs`.

#### `Identifiable.__isnot__`

```mojo
def __isnot__(self, rhs: Self) -> Bool
```

Define whether `self` has a different identity than `rhs`.

Args:

- `rhs`: The right hand side of the comparison.

Returns: True if `self` is not `rhs`.

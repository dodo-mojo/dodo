# `std.builtin.simd_length`

Implements `SIMDLength`, which is a wrapper around the MLIR `index` type.

## Structs

### `SIMDLength`

```mojo
struct SIMDLength
```

Represents a type appropriate for the length of a simd vector.

Note: Typically you should use Int instead.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Indexer`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

#### `SIMDLength.__init__`

```mojo
def __init__(value: IntLiteral, /) -> Self
```

Construct SIMDLength from the given IntLiteral value.

Args:

- `value`: The init value.

```mojo
def __init__[T: Indexer](value: T) -> Self
```

Construct a SIMDLength from the given Indexer.

Parameters:

- `T`: The type of the init value.

Args:

- `value`: The init value.

```mojo
def __init__(value: Int, /) -> Self
```

Construct a SIMDLength from the given Int.

Args:

- `value`: The init value.

#### `SIMDLength.__neg__`

```mojo
def __neg__(self) -> Self
```

Return -self.

Returns: The -self value.

#### `SIMDLength.__lt__`

```mojo
def __lt__(self, rhs: Self) -> Bool
```

Compare this SIMDLength to the RHS using LT comparison.

Args:

- `rhs`: The other SIMDLength to compare against.

Returns: True if this SIMDLength is less-than the RHS SIMDLength and False otherwise.

#### `SIMDLength.__le__`

```mojo
def __le__(self, rhs: Self) -> Bool
```

Compare this SIMDLength to the RHS using LE comparison.

Args:

- `rhs`: The other SIMDLength to compare against.

Returns: True if this SIMDLength is less-or-equal than the RHS SIMDLength and False otherwise.

#### `SIMDLength.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compare this SIMDLength to the RHS using EQ comparison.

Args:

- `rhs`: The other SIMDLength to compare against.

Returns: True if this SIMDLength is equal to the RHS SIMDLength and False otherwise.

#### `SIMDLength.__ne__`

```mojo
def __ne__(self, rhs: Self) -> Bool
```

Compare this Int to the RHS using NE comparison.

Args:

- `rhs`: The other Int to compare against.

Returns: True if this Int is non-equal to the RHS Int and False otherwise.

#### `SIMDLength.__gt__`

```mojo
def __gt__(self, rhs: Self) -> Bool
```

Compare this SIMDLength to the RHS using GT comparison.

Args:

- `rhs`: The other SIMDLength to compare against.

Returns: True if this SIMDLength is greater than the RHS SIMDLength and False otherwise.

#### `SIMDLength.__ge__`

```mojo
def __ge__(self, rhs: Self) -> Bool
```

Compare this SIMDLength to the RHS using GE comparison.

Args:

- `rhs`: The other SIMDLength to compare against.

Returns: True if this SIMDLength is greater-or-equal than the RHS SIMDLength and False otherwise.

#### `SIMDLength.__add__`

```mojo
def __add__(self, rhs: Self) -> Self
```

Return `self + rhs`.

Args:

- `rhs`: The value to add.

Returns: `self + rhs` value.

#### `SIMDLength.__sub__`

```mojo
def __sub__(self, rhs: Self) -> Self
```

Return `self - rhs`.

Args:

- `rhs`: The value to subtract.

Returns: `self - rhs` value.

#### `SIMDLength.__mul__`

```mojo
def __mul__(self, rhs: Self) -> Self
```

Return `self * rhs`.

Args:

- `rhs`: The value to multiply with.

Returns: `self * rhs` value.

#### `SIMDLength.__truediv__`

```mojo
def __truediv__(self, rhs: Self) -> Self
```

Return the result of the division of `self` and `rhs`.

Performs truncating division (toward zero) for integers.

Args:

- `rhs`: The value to divide on.

Returns: `self / rhs` value.

#### `SIMDLength.__pow__`

```mojo
def __pow__(self, exp: Self) -> Self
```

Return the value raised to the power of the given exponent.

Computes the power of an integer using the Russian Peasant Method.

Args:

- `exp`: The exponent value.

Returns: The value of `self` raised to the power of `exp`.

#### `SIMDLength.__rshift__`

```mojo
def __rshift__(self, rhs: Self) -> Self
```

Return `self >> rhs`.

Args:

- `rhs`: The value to shift with.

Returns: `self >> rhs`.

#### `SIMDLength.__and__`

```mojo
def __and__(self, rhs: Self) -> Self
```

Return `self & rhs`.

Args:

- `rhs`: The RHS value.

Returns: `self & rhs`.

#### `SIMDLength.__imul__`

```mojo
def __imul__(mut self, rhs: Self)
```

Compute self*rhs and save the result in self.

Args:

- `rhs`: The RHS value.

#### `SIMDLength.__irshift__`

```mojo
def __irshift__(mut self, rhs: Self)
```

Compute `self >> rhs` and save the result in self.

Args:

- `rhs`: The RHS value.

#### `SIMDLength.__mlir_index__`

```mojo
def __mlir_index__(self) -> __mlir_type.index
```

Convert to index.

Returns: The corresponding __mlir_type.index value.

#### `SIMDLength.is_power_of_two`

```mojo
def is_power_of_two(self) -> Bool
```

Check if the integer is a (non-zero) power of two.

Returns: True if the integer is a power of two, False otherwise.

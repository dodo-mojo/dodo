# `std.builtin.int_literal`

Implements the IntLiteral class.

## Structs

### `IntLiteral`

```mojo
struct IntLiteral[value: __mlir_type.`!pop.int_literal`]
```

This type represents a static integer literal value with infinite precision.  This type is a compile-time construct which stores its value as a parameter.  It is typically materialized into other types (like `Int`) for use at runtime.  This compile-time representation allows for arbitrary precision constants that would overflow on Int and other fixed precision integer types.

Parameters:

- `value`: The underlying integer value.

Implemented traits: `AnyType`, `Boolable`, `Ceilable`, `Copyable`, `Defaultable`, `Deinitable`, `Floorable`, `ImplicitlyCopyable`, `Indexer`, `Intable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Truncable`, `Writable`

#### `IntLiteral.__init__`

```mojo
def __init__() -> Self
```

Constructor for any value.

#### `IntLiteral.__bool__`

```mojo
def __bool__(self) -> Bool
```

Convert this IntLiteral to Bool.

Returns: False Bool value if the value is equal to 0 and True otherwise.

#### `IntLiteral.__neg__`

```mojo
def __neg__(self) -> IntLiteral[(0 - value)]
```

Return -self.

Returns: The -self value.

#### `IntLiteral.__pos__`

```mojo
def __pos__(self) -> Self
```

Return +self.

Returns: The +self value.

#### `IntLiteral.__invert__`

```mojo
def __invert__(self) -> IntLiteral[(value ^ -1)]
```

Return ~self.

Returns: The ~self value.

#### `IntLiteral.__lt__`

```mojo
def __lt__(self, rhs: IntLiteral) -> Bool
```

Compare this IntLiteral to the RHS using LT comparison.

Args:

- `rhs`: The other IntLiteral to compare against.

Returns: True if this IntLiteral is less-than the RHS IntLiteral and False otherwise.

#### `IntLiteral.__le__`

```mojo
def __le__(self, rhs: IntLiteral) -> Bool
```

Compare this IntLiteral to the RHS using LE comparison.

Args:

- `rhs`: The other IntLiteral to compare against.

Returns: True if this IntLiteral is less-or-equal than the RHS IntLiteral and False otherwise.

#### `IntLiteral.__eq__`

```mojo
def __eq__(self, rhs: IntLiteral) -> Bool
```

Compare this IntLiteral to the RHS using EQ comparison.

Args:

- `rhs`: The other IntLiteral to compare against.

Returns: True if this IntLiteral is equal to the RHS IntLiteral and False otherwise.

#### `IntLiteral.__ne__`

```mojo
def __ne__(self, rhs: IntLiteral) -> Bool
```

Compare this IntLiteral to the RHS using NE comparison.

Args:

- `rhs`: The other IntLiteral to compare against.

Returns: True if this IntLiteral is non-equal to the RHS IntLiteral and False otherwise.

#### `IntLiteral.__gt__`

```mojo
def __gt__(self, rhs: IntLiteral) -> Bool
```

Compare this IntLiteral to the RHS using GT comparison.

Args:

- `rhs`: The other IntLiteral to compare against.

Returns: True if this IntLiteral is greater-than the RHS IntLiteral and False otherwise.

#### `IntLiteral.__ge__`

```mojo
def __ge__(self, rhs: IntLiteral) -> Bool
```

Compare this IntLiteral to the RHS using GE comparison.

Args:

- `rhs`: The other IntLiteral to compare against.

Returns: True if this IntLiteral is greater-or-equal than the RHS IntLiteral and False otherwise.

#### `IntLiteral.__add__`

```mojo
def __add__(self, rhs: IntLiteral) -> IntLiteral[(value + rhs.value)]
```

Return `self + rhs`.

Args:

- `rhs`: The value to add.

Returns: `self + rhs` value.

```mojo
def __add__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<add #pop.int_to_float_literal<value>, *"rhs.value`2x">]
```

Return `self + rhs`.

Args:

- `rhs`: The value to add.

Returns: `self + rhs` value.

#### `IntLiteral.__sub__`

```mojo
def __sub__(self, rhs: IntLiteral) -> IntLiteral[(value - rhs.value)]
```

Return `self - rhs`.

Args:

- `rhs`: The value to subtract.

Returns: `self - rhs` value.

```mojo
def __sub__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<sub #pop.int_to_float_literal<value>, *"rhs.value`2x">]
```

Return `self - rhs`.

Args:

- `rhs`: The value to subtract.

Returns: `self - rhs` value.

#### `IntLiteral.__mul__`

```mojo
def __mul__(self, rhs: IntLiteral) -> IntLiteral[(value * rhs.value)]
```

Return `self * rhs`.

Args:

- `rhs`: The value to multiply with.

Returns: `self * rhs` value.

```mojo
def __mul__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<mul #pop.int_to_float_literal<value>, *"rhs.value`2x">]
```

Return `self * rhs`.

Args:

- `rhs`: The value to multiply with.

Returns: `self * rhs` value.

#### `IntLiteral.__truediv__`

```mojo
def __truediv__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<truediv #pop.int_to_float_literal<value>, *"rhs.value`2x">]
```

Return `self / rhs`.

Args:

- `rhs`: The value to divide with.

Returns: `self / rhs` value.

#### `IntLiteral.__floordiv__`

```mojo
def __floordiv__(self, rhs: IntLiteral) -> IntLiteral[(value // rhs.value)]
```

Return `self // rhs`.

Args:

- `rhs`: The value to divide with.

Returns: `self // rhs` value.

#### `IntLiteral.__mod__`

```mojo
def __mod__(self, rhs: IntLiteral) -> IntLiteral[(value % rhs.value)]
```

Return the remainder of self divided by rhs.

Args:

- `rhs`: The value to divide on.

Returns: The remainder of dividing self by rhs.

#### `IntLiteral.__pow__`

```mojo
def __pow__(self, exp: IntLiteral) -> IntLiteral[(value ** exp.value)]
```

Return the value raised to the power of the given exponent.

Args:

- `exp`: The exponent value.

Returns: The value of `self` raised to the power of `exp`.

#### `IntLiteral.__lshift__`

```mojo
def __lshift__(self, rhs: IntLiteral) -> IntLiteral[(value << rhs.value)]
```

Return `self << rhs`.

Args:

- `rhs`: The value to shift with.

Returns: `self << rhs`.

#### `IntLiteral.__rshift__`

```mojo
def __rshift__(self, rhs: IntLiteral) -> IntLiteral[(value >> rhs.value)]
```

Return `self >> rhs`.

Args:

- `rhs`: The value to shift with.

Returns: `self >> rhs`.

#### `IntLiteral.__and__`

```mojo
def __and__(self, rhs: IntLiteral) -> IntLiteral[(value & rhs.value)]
```

Return `self & rhs`.

Args:

- `rhs`: The RHS value.

Returns: `self & rhs`.

#### `IntLiteral.__or__`

```mojo
def __or__(self, rhs: IntLiteral) -> IntLiteral[(value | rhs.value)]
```

Return `self | rhs`.

Args:

- `rhs`: The RHS value.

Returns: `self | rhs`.

#### `IntLiteral.__xor__`

```mojo
def __xor__(self, rhs: IntLiteral) -> IntLiteral[(value ^ rhs.value)]
```

Return `self ^ rhs`.

Args:

- `rhs`: The RHS value.

Returns: `self ^ rhs`.

#### `IntLiteral.__int__`

```mojo
def __int__(self) -> Int
```

Convert from IntLiteral to Int.

Returns: The value as an integer of platform-specific width.

#### `IntLiteral.__ceil__`

```mojo
def __ceil__(self) -> Self
```

Return the ceiling of the IntLiteral value, which is itself.

Returns: The IntLiteral value itself.

#### `IntLiteral.__floor__`

```mojo
def __floor__(self) -> Self
```

Return the floor of the IntLiteral value, which is itself.

Returns: The IntLiteral value itself.

#### `IntLiteral.__trunc__`

```mojo
def __trunc__(self) -> Self
```

Return the truncated of the IntLiteral value, which is itself.

Returns: The IntLiteral value itself.

#### `IntLiteral.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the IntLiteral in string form.

Args:

- `writer`: The Writer to write the value to.

#### `IntLiteral.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the IntLiteral in repr form.

Args:

- `writer`: The Writer to write the value to.

#### `IntLiteral.__ceildiv__`

```mojo
def __ceildiv__(self, denominator: IntLiteral) -> IntLiteral[(0 - (value // (0 - denominator.value)))]
```

Return the rounded-up result of dividing self by denominator.

Args:

- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

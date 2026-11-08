# `std.builtin.float_literal`

Implements the FloatLiteral class.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `FloatLiteral`

```mojo
struct FloatLiteral[value: __mlir_type.`!pop.float_literal`]
```

Mojo floating point literal type.

Parameters:

- `value`: The underlying infinite precision floating point value.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Floatable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `nan = nan`: Not a number (NaN) value.
- `infinity = inf`: Positive infinity value.
- `negative_infinity = -inf`: Negative infinity value.
- `negative_zero = -0.0`: Negative zero value.

#### `FloatLiteral.__init__`

```mojo
def __init__() -> Self
```

Create a FloatLiteral for any parameter value.

```mojo
def __init__(_value: IntLiteral) -> FloatLiteral[#pop.int_to_float_literal<*"_value.value`2x">]
```

Convert an IntLiteral to a FloatLiteral value.

Args:

- `_value`: The IntLiteral value.

#### `FloatLiteral.__bool__`

```mojo
def __bool__(self) -> Bool
```

A FloatLiteral value is true if it is non-zero.

Returns: True if non-zero.

#### `FloatLiteral.__neg__`

```mojo
def __neg__(self) -> FloatLiteral[#pop.float_literal_bin<mul value, #pop.float_literal<-1|1>>]
```

Return the negation of the FloatLiteral value.

Returns: The negated FloatLiteral value.

#### `FloatLiteral.__lt__`

```mojo
def __lt__(self, rhs: FloatLiteral) -> Bool
```

Less than comparison.

Args:

- `rhs`: The value to compare.

Returns: True if this value is less than `rhs`.

#### `FloatLiteral.__le__`

```mojo
def __le__(self, rhs: FloatLiteral) -> Bool
```

Less than or equal to comparison.

Args:

- `rhs`: The value to compare.

Returns: True if this value is less than or equal to `rhs`.

#### `FloatLiteral.__eq__`

```mojo
def __eq__(self, rhs: FloatLiteral) -> Bool
```

Compare for equality.

Args:

- `rhs`: The value to compare.

Returns: True if they are equal.

#### `FloatLiteral.__ne__`

```mojo
def __ne__(self, rhs: FloatLiteral) -> Bool
```

Compare for inequality.

Args:

- `rhs`: The value to compare.

Returns: True if they are not equal.

#### `FloatLiteral.__gt__`

```mojo
def __gt__(self, rhs: FloatLiteral) -> Bool
```

Greater than comparison.

Args:

- `rhs`: The value to compare.

Returns: True if this value is greater than `rhs`.

#### `FloatLiteral.__ge__`

```mojo
def __ge__(self, rhs: FloatLiteral) -> Bool
```

Greater than or equal to comparison.

Args:

- `rhs`: The value to compare.

Returns: True if this value is greater than or equal to `rhs`.

#### `FloatLiteral.__add__`

```mojo
def __add__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<add value, *"rhs.value`2x">]
```

Add two FloatLiterals.

Args:

- `rhs`: The value to add.

Returns: The sum of the two values.

#### `FloatLiteral.__sub__`

```mojo
def __sub__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<sub value, *"rhs.value`2x">]
```

Subtract two FloatLiterals.

Args:

- `rhs`: The value to subtract.

Returns: The difference of the two values.

#### `FloatLiteral.__mul__`

```mojo
def __mul__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<mul value, *"rhs.value`2x">]
```

Multiply two FloatLiterals.

Args:

- `rhs`: The value to multiply.

Returns: The product of the two values.

#### `FloatLiteral.__truediv__`

```mojo
def __truediv__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<truediv value, *"rhs.value`2x">]
```

Divide two FloatLiterals.

Args:

- `rhs`: The value to divide.

Returns: The quotient of the two values.

#### `FloatLiteral.__floordiv__`

```mojo
def __floordiv__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<floordiv value, *"rhs.value`2x">]
```

Returns self divided by rhs, rounded down to the nearest integer.

Args:

- `rhs`: The divisor value.

Returns: `floor(self / rhs)` value.

#### `FloatLiteral.__mod__`

```mojo
def __mod__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<sub value, #pop.float_literal_bin<mul #pop.float_literal_bin<floordiv value, *"rhs.value`2x">, *"rhs.value`2x">>]
```

Return the remainder of self divided by rhs.

Args:

- `rhs`: The value to divide on.

Returns: The remainder of dividing self by rhs.

#### `FloatLiteral.__radd__`

```mojo
def __radd__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<add *"rhs.value`2x", value>]
```

Reversed addition operator.

Args:

- `rhs`: The value to add.

Returns: The sum of this and the given value.

#### `FloatLiteral.__rsub__`

```mojo
def __rsub__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<sub *"rhs.value`2x", value>]
```

Reversed subtraction operator.

Args:

- `rhs`: The value to subtract from.

Returns: The result of subtracting this from the given value.

#### `FloatLiteral.__rmul__`

```mojo
def __rmul__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<mul *"rhs.value`2x", value>]
```

Reversed multiplication operator.

Args:

- `rhs`: The value to multiply.

Returns: The product of the given number and this.

#### `FloatLiteral.__rtruediv__`

```mojo
def __rtruediv__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<truediv *"rhs.value`2x", value>]
```

Reversed division.

Args:

- `rhs`: The value to be divided by this.

Returns: The result of dividing the given value by this.

#### `FloatLiteral.__rfloordiv__`

```mojo
def __rfloordiv__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<floordiv *"rhs.value`2x", value>]
```

Returns rhs divided by self, rounded down to the nearest integer.

Args:

- `rhs`: The value to be divided by self.

Returns: `floor(rhs / self)` value.

#### `FloatLiteral.__rmod__`

```mojo
def __rmod__(self, rhs: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<sub *"rhs.value`2x", #pop.float_literal_bin<mul #pop.float_literal_bin<floordiv *"rhs.value`2x", value>, value>>]
```

Return the remainder of rhs divided by self.

Args:

- `rhs`: The value to divide on.

Returns: The remainder of dividing rhs by self.

#### `FloatLiteral.is_nan`

```mojo
def is_nan(self) -> Bool
```

Return whether the FloatLiteral is nan.

Since `nan == nan` is False, this provides a way to check for nan-ness.

Returns: True, if the value is nan, False otherwise.

#### `FloatLiteral.is_neg_zero`

```mojo
def is_neg_zero(self) -> Bool
```

Return whether the FloatLiteral is negative zero.

Since `FloatLiteral.negative_zero == 0.0` is True, this provides a way
to check if the FloatLiteral is negative zero.

Returns: True, if the value is negative zero, False otherwise.

#### `FloatLiteral.__int_literal__`

```mojo
def __int_literal__(self) -> IntLiteral[#pop.float_to_int_literal<value>]
```

Casts the floating point value to an IntLiteral. If there is a fractional component, then the value is truncated towards zero.

Eg. `(4.5).__int_literal__()` returns `4`, and `(-3.7).__int_literal__()`
returns `-3`.

Returns: The value as an integer.

#### `FloatLiteral.__int__`

```mojo
def __int__(self) -> Int
```

Converts the FloatLiteral value to an Int. If there is a fractional component, then the value is truncated towards zero.

Eg. `(4.5).__int__()` returns `4`, and `(-3.7).__int__()` returns `-3`.

Returns: The value as an integer.

#### `FloatLiteral.__float__`

```mojo
def __float__(self) -> Float64
```

Converts the FloatLiteral to a concrete Float64.

Returns: The Float value.

#### `FloatLiteral.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the FloatLiteral in string form.

Args:

- `writer`: The Writer to write the value to.

#### `FloatLiteral.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the FloatLiteral in repr form.

Args:

- `writer`: The Writer to write the value to.

#### `FloatLiteral.__ceildiv__`

```mojo
def __ceildiv__(self, denominator: FloatLiteral) -> FloatLiteral[#pop.float_literal_bin<mul #pop.float_literal_bin<floordiv value, #pop.float_literal_bin<mul *"denominator.value`2x", #pop.float_literal<-1|1>>>, #pop.float_literal<-1|1>>]
```

Return the rounded-up result of dividing self by denominator.

Args:

- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

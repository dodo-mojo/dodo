# `std.builtin.bool`

Implements the Bool class.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `Bool`

```mojo
struct Bool
```

The primitive Bool scalar value used in Mojo.

Implemented traits: `AnyType`, `Boolable`, `Comparable`, `ConvertibleFromPython`, `Copyable`, `Defaultable`, `Deinitable`, `EnumLike`, `Equatable`, `Floatable`, `Hashable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `MIN = False`: The minimum value of a Bool.
- `MAX = True`: The maximum value of a Bool.

#### `Bool.__init__`

```mojo
def __init__() -> Self
```

Construct a default, `False` Bool.

```mojo
def __init__[T: Boolable, //](value: T) -> Self
```

Set the bool representation of the object.

Parameters:

- `T`: The type of the object.

Args:

- `value`: The object to get the bool representation of.

```mojo
def __init__(value: None) -> Self
```

Set the bool representation of the `None` type to `False`.

Args:

- `value`: The object to get the bool representation of.

```mojo
def __init__(value: Scalar[DType.bool]) -> Self
```

Convert a scalar SIMD value to a Bool.

Args:

- `value`: The scalar value.

#### `Bool.__bool__`

```mojo
def __bool__(self) -> Self
```

Convert to Bool.

Returns: This value.

#### `Bool.__invert__`

```mojo
def __invert__(self) -> Self
```

Inverts the Bool value.

Returns: True if the object is false and False otherwise.

#### `Bool.__lt__`

```mojo
def __lt__(self, rhs: Self) -> Self
```

Compare this Bool to RHS using less-than comparison.

Args:

- `rhs`: The rhs of the operation.

Returns: True if self is False and rhs is True.

#### `Bool.__le__`

```mojo
def __le__(self, rhs: Self) -> Self
```

Compare this Bool to RHS using less-than-or-equal comparison.

Args:

- `rhs`: The rhs of the operation.

Returns: True if self is False and rhs is True or False.

#### `Bool.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Self
```

Compare this Bool to RHS.

Performs an equality comparison between the Bool value and the argument.
This method gets invoked when a user uses the `==` infix operator.

Args:

- `rhs`: The rhs value of the equality statement.

Returns: True if the two values match and False otherwise.

#### `Bool.__ne__`

```mojo
def __ne__(self, rhs: Self) -> Self
```

Compare this Bool to RHS.

Performs a non-equality comparison between the Bool value and the
argument. This method gets invoked when a user uses the `!=` infix
operator.

Args:

- `rhs`: The rhs value of the non-equality statement.

Returns: False if the two values do match and True otherwise.

#### `Bool.__gt__`

```mojo
def __gt__(self, rhs: Self) -> Self
```

Compare this Bool to RHS using greater-than comparison.

Args:

- `rhs`: The rhs of the operation.

Returns: True if self is True and rhs is False.

#### `Bool.__ge__`

```mojo
def __ge__(self, rhs: Self) -> Self
```

Compare this Bool to RHS using greater-than-or-equal comparison.

Args:

- `rhs`: The rhs of the operation.

Returns: True if self is True and rhs is True or False.

#### `Bool.__and__`

```mojo
def __and__(self, rhs: Self) -> Self
```

Returns `self & rhs`.

Bitwise and's the Bool value with the argument. This method gets invoked
when a user uses the `and` infix operator.

Args:

- `rhs`: The right hand side of the `and` statement.

Returns: `self & rhs`.

#### `Bool.__or__`

```mojo
def __or__(self, rhs: Self) -> Self
```

Returns `self | rhs`.

Bitwise or's the Bool value with the argument. This method gets invoked
when a user uses the `or` infix operator.

Args:

- `rhs`: The right hand side of the `or` statement.

Returns: `self | rhs`.

#### `Bool.__xor__`

```mojo
def __xor__(self, rhs: Self) -> Self
```

Returns `self ^ rhs`.

Bitwise Xor's the Bool value with the argument. This method gets invoked
when a user uses the `^` infix operator.

Args:

- `rhs`: The right hand side of the `xor` statement.

Returns: `self ^ rhs`.

#### `Bool.__rand__`

```mojo
def __rand__(self, lhs: Self) -> Self
```

Returns `lhs & self`.

Args:

- `lhs`: The left hand side of the `and` statement.

Returns: `lhs & self`.

#### `Bool.__ror__`

```mojo
def __ror__(self, lhs: Self) -> Self
```

Returns `lhs | self`.

Args:

- `lhs`: The left hand side of the `or` statement.

Returns: `lhs | self`.

#### `Bool.__rxor__`

```mojo
def __rxor__(self, lhs: Self) -> Self
```

Returns `lhs ^ self`.

Args:

- `lhs`: The left hand side of the `xor` statement.

Returns: `lhs ^ self`.

#### `Bool.__iand__`

```mojo
def __iand__(mut self, rhs: Self)
```

Computes `self & rhs` and store the result in `self`.

Args:

- `rhs`: The right hand side of the `and` statement.

#### `Bool.__ixor__`

```mojo
def __ixor__(mut self, rhs: Self)
```

Computes `self ^ rhs` and stores the result in `self`.

Args:

- `rhs`: The right hand side of the `xor` statement.

#### `Bool.__ior__`

```mojo
def __ior__(mut self, rhs: Self)
```

Computes `self | rhs` and store the result in `self`.

Args:

- `rhs`: The right hand side of the `or` statement.

#### `Bool.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this boolean to the provided Writer.

Args:

- `writer`: The object to write to.

#### `Bool.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes the repr of this boolean to a writer.

The repr of a boolean is the same as its string representation:
`True` or `False`.

Args:

- `writer`: The object to write to.

#### `Bool.__int__`

```mojo
def __int__(self) -> Int
```

Convert this Bool to an integer.

Returns: 1 if the Bool is True, 0 otherwise.

#### `Bool.__float__`

```mojo
def __float__(self) -> Float64
```

Convert this Bool to a float.

Returns: 1.0 if True else 0.0 otherwise.

#### `Bool.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H)
```

Updates hasher with the underlying bytes.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

## Traits

### `Boolable`

```mojo
trait Boolable
```

The `Boolable` trait describes a type that can be explicitly converted to a `Bool` or evaluated as a boolean expression in `if` or `while` conditions.

This trait requires the type to implement the `__bool__()` method. For
example:

```mojo
struct Foo(Boolable):
    var val: Bool

    def __bool__(self) -> Bool:
        return self.val
```

Inherits from: `AnyType`

#### `Boolable.__bool__`

```mojo
def __bool__(self) -> Bool
```

Get the boolean representation of the value.

Returns: The boolean representation of the value.

## Functions

### `any`

```mojo
def any[IterableType: Iterable](iterable: IterableType) -> Bool where conforms_to(IterableType.IteratorType[False, iterable, iterable].Element, Boolable & Deinitable)
```

Checks if **all** elements in the list are truthy.

Parameters:

- `IterableType`: The type of the iterable containing `Boolable` items.

Args:

- `iterable`: The iterable to check.

Returns: `True` if **any** element in the list is truthy, `False` otherwise.

```mojo
def any(value: SIMD) -> Bool
```

Checks if **any** element in the simd vector is truthy.

Args:

- `value`: The simd vector to check.

Returns: `True` if **any** element in the simd vector is truthy, `False` otherwise.

### `all`

```mojo
def all[IterableType: Iterable](iterable: IterableType) -> Bool where conforms_to(IterableType.IteratorType[False, iterable, iterable].Element, Boolable & Deinitable)
```

Checks if **all** elements in the list are truthy.

Parameters:

- `IterableType`: The type of the iterable containing `Boolable` items.

Args:

- `iterable`: The iterable to check.

Returns: `True` if **all** elements in the iterable are truthy, `False` otherwise.

```mojo
def all(value: SIMD) -> Bool
```

Checks if **all** elements in the simd vector are truthy.

Args:

- `value`: The simd vector to check.

Returns: `True` if **all** elements in the simd vector are truthy, `False` otherwise.

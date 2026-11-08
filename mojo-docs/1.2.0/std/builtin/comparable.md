# `std.builtin.comparable`

Implements comparison and equality traits for Mojo types.

## Traits

### `Equatable`

```mojo
trait Equatable
```

A type which can be compared for equality with other instances of itself.

The `Equatable` trait has a default implementation of `__eq__()` that uses
reflection to compare all fields. This means simple structs can conform to
`Equatable` without implementing any methods:

```mojo
@fieldwise_init
struct Point(Equatable):
    var x: Int
    var y: Int

var p1 = Point(1, 2)
var p2 = Point(1, 2)
print(p1 == p2)  # True
```

All fields must conform to `Equatable`. Override `__eq__()` for custom
equality semantics.

Note: The default implementation performs memberwise equality comparison.
This may not be appropriate for types containing floating-point fields
(due to NaN semantics) or types requiring custom equality logic.

Note: The default reflection-based implementation iterates over all fields
at compile time. For mutually recursive types (e.g., struct `A` has a field
of type `List[B]` and struct `B` has a field of type `A`), this creates an
infinite monomorphization cycle that causes the compiler to hang. To fix
this, provide an explicit `__eq__()` implementation for at least one type
in the cycle.

Inherits from: `AnyType`

#### `Equatable.__eq__`

```mojo
def __eq__(self, other: Self, /) -> Bool
```

Define whether two instances of the object are equal to each other.

The default implementation uses reflection to compare all fields for
equality. All fields must conform to `Equatable`.

Args:

- `other`: Another instance of the same type.

Returns: True if the instances are equal according to the type's definition of equality, False otherwise.

#### `Equatable.__ne__`

```mojo
def __ne__(self, other: Self, /) -> Bool
```

Define whether two instances of the object are not equal to each other.

Args:

- `other`: Another instance of the same type.

Returns: True if the instances are not equal according to the type's definition of equality, False otherwise.

### `Comparable`

```mojo
trait Comparable
```

A type which can be compared for order with other instances of itself.

Implementers of this trait must define the `__lt__` and `__eq__` methods.

The default implementations of the default comparison methods can be
potentially inefficient for types where comparison is expensive. For such
types, it is recommended to override all the default implementations.

Inherits from: `AnyType`, `Equatable`

#### `Comparable.__lt__`

```mojo
def __lt__(self, rhs: Self) -> Bool
```

Define whether `self` is less than `rhs`.

Args:

- `rhs`: The value to compare with.

Returns: True if `self` is less than `rhs`.

#### `Comparable.__le__`

```mojo
def __le__(self, rhs: Self) -> Bool
```

Define whether `self` is less than or equal to `rhs`.

Args:

- `rhs`: The value to compare with.

Returns: True if `self` is less than or equal to `rhs`.

#### `Comparable.__gt__`

```mojo
def __gt__(self, rhs: Self) -> Bool
```

Define whether `self` is greater than `rhs`.

Args:

- `rhs`: The value to compare with.

Returns: True if `self` is greater than `rhs`.

#### `Comparable.__ge__`

```mojo
def __ge__(self, rhs: Self) -> Bool
```

Define whether `self` is greater than or equal to `rhs`.

Args:

- `rhs`: The value to compare with.

Returns: True if `self` is greater than or equal to `rhs`.

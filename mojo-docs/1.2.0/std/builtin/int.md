# `std.builtin.int`

Implements the Int class.

These are Mojo built-ins, so you don't need to import them.

## Traits

### `Indexer`

```mojo
trait Indexer
```

The `Indexer` trait is used for types that can index into a collection or pointer. The type returned is the underlying __mlir_type.index, enabling types like `SIMD` to not have to be converted to an `Int` first.

Inherits from: `AnyType`

#### `Indexer.__mlir_index__`

```mojo
def __mlir_index__(self) -> __mlir_type.index
```

Convert to index.

Returns: The corresponding __mlir_type.index value.

### `Intable`

```mojo
trait Intable
```

The `Intable` trait describes a type that can be converted to an Int.

Any type that conforms to `Intable` or
[`IntableRaising`](../../std/builtin/int.md#intableraising) can construct an
`Int`.

This trait requires the type to implement the `__int__()` method. For
example:

```mojo
@fieldwise_init
struct Foo(Intable):
    var i: Int

    def __int__(self) -> Int:
        return self.i
```

Now you can construct an `Int`:

```mojo
from std.testing import assert_equal

foo = Foo(42)
assert_equal(Int(foo), 42)
```

**Note:** If the `__int__()` method can raise an error, use the
[`IntableRaising`](../../std/builtin/int.md#intableraising) trait
instead.

Inherits from: `AnyType`

#### `Intable.__int__`

```mojo
def __int__(self) -> Int
```

Get the integral representation of the value.

Returns: The integral representation of the value.

### `IntableRaising`

```mojo
trait IntableRaising
```

The `IntableRaising` trait describes a type can be converted to an Int, but the conversion might raise an error.

Any type that conforms to [`Intable`](../../std/builtin/int.md#intable)
or `IntableRaising` can construct an `Int`.

This trait requires the type to implement the `__int__()` method, which can
raise an error. For example:

```mojo
@fieldwise_init
struct Foo(IntableRaising):
    var i: Int

    def __int__(self) raises -> Int:
        return self.i
```

Now you can construct an `Int`:

```mojo
from std.testing import assert_equal

foo = Foo(42)
assert_equal(Int(foo), 42)
```

Inherits from: `AnyType`

#### `IntableRaising.__int__`

```mojo
def __int__(self) raises -> Int
```

Get the integral representation of the value.

Returns: The integral representation of the type.

Raises: If the type does not have an integral representation.

## Functions

### `index`

```mojo
def index[T: Indexer](idx: T, /) -> Int
```

Returns the value of `__mlir_index__` for the given value.

Parameters:

- `T`: A type conforming to the `Indexer` trait.

Args:

- `idx`: The value.

Returns: An `__mlir_type` representing the index value.

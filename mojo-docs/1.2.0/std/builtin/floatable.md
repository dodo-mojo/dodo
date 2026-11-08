# `std.builtin.floatable`

Implements the `Floatable` and `FloatableRaising` traits.

These are Mojo built-ins, so you don't need to import them.

## Traits

### `Floatable`

```mojo
trait Floatable
```

The `Floatable` trait describes a type that can be converted to a Float64.

This trait requires the type to implement the `__float__()` method.

For example:

```mojo
@fieldwise_init
struct Foo(Floatable):
    var i: Float64

    def __float__(self) -> Float64:
        return self.i
```

A `Foo` can now be converted to a `Float64`:

```mojo
var f = Float64(Foo(5.5))
```

**Note:** If the `__float__()` method can raise an error, use
the [`FloatableRaising`](../../std/builtin/floatable.md#floatableraising)
trait instead.

Inherits from: `AnyType`

#### `Floatable.__float__`

```mojo
def __float__(self) -> Float64
```

Get the float point representation of the value.

Returns: The float point representation of the value.

### `FloatableRaising`

```mojo
trait FloatableRaising
```

The `FloatableRaising` trait describes a type that can be converted to a Float64, but the conversion might raise an error (e.g.: a string).

This trait requires the type to implement the `__float__()` method, which
can raise an error.

For example:

```mojo
from std.utils import Variant

@fieldwise_init
struct MaybeFloat(FloatableRaising):
    var value: Variant[Float64, NoneType]

    def __float__(self) raises -> Float64:
        if self.value.isa[NoneType]():
            raise "Float expected"
        return self.value[Float64]
```

A `MaybeFloat` can now be converted to `Float64`:

```mojo
from std.utils import Variant

@fieldwise_init
struct MaybeFloat(FloatableRaising):
    var value: Variant[Float64, NoneType]

    def __float__(self) raises -> Float64:
        if self.value.isa[NoneType]():
            raise "Float expected"
        return self.value[Float64]

try:
    print(Float64(MaybeFloat(4.6)))
except:
    print("error occurred")
```

Inherits from: `AnyType`

#### `FloatableRaising.__float__`

```mojo
def __float__(self) raises -> Float64
```

Get the float point representation of the value.

Returns: The float point representation of the value.

Raises: If the type does not have a float point representation.

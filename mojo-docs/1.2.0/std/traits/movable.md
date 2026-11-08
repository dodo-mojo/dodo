# `std.traits.movable`

Defines `Movable`, the trait for types whose value can be moved.

This is a Mojo built-in, so you don't need to import it.

## Aliases

### `IsTriviallyMovable`

```mojo
comptime IsTriviallyMovable[T: AnyType] = conforms_to(T, TrivialRegisterPassable) if conforms_to(T, TrivialRegisterPassable) else T.__move_ctor_is_trivial if conforms_to(T, Movable) else conforms_to(T, Movable)
```

Indicates whether `T` is `Movable` with a trivial move initializer.

A move initializer is trivial when the compiler generates it and all of
`T`'s fields are themselves trivially movable — the value can be moved by
copying its bits to a new location with no additional side effects.
Evaluates to `False` for non-`Movable` types.

## Traits

### `Movable`

```mojo
trait Movable
```

The Movable trait denotes a type whose value can be moved.

Implement the `Movable` trait on `Foo` which requires the
`def __init__(out self, *, deinit move: Self)` method:

```mojo
struct Foo(Movable):
    def __init__(out self):
        pass

    def __init__(out self, *, deinit move: Self):
        print("moving")
```

You can now use the ^ suffix to transfer owned values instead of copying:

```mojo
def return_foo[T: Movable](var foo: T) -> T:
    return foo^

var foo = Foo()
var res = return_foo(foo^)
```

```plaintext
moving
```

Inherits from: `AnyType`

#### `Movable.__init__`

```mojo
def __init__(out self, *, deinit move: Self)
```

Create a new instance of the value by moving the value of another.

Args:

- `move`: The value to move.

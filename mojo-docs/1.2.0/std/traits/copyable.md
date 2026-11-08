# `std.traits.copyable`

Defines `Copyable` and `ImplicitlyCopyable`, the traits for types whose value can be copied.

These are Mojo built-ins, so you don't need to import them.

## Aliases

### `IsTriviallyCopyable`

```mojo
comptime IsTriviallyCopyable[T: AnyType] = conforms_to(T, TrivialRegisterPassable) if conforms_to(T, TrivialRegisterPassable) else T.__copy_ctor_is_trivial if conforms_to(T, Copyable) else conforms_to(T, Copyable)
```

Indicates whether `T` is `Copyable` with a trivial copy initializer.

A copy initializer is trivial when the compiler generates it and all of
`T`'s fields are themselves trivially copyable — the value can be copied by
duplicating its bits to a new location with no additional side effects.
Evaluates to `False` for non-`Copyable` types.

## Traits

### `Copyable`

```mojo
trait Copyable
```

The Copyable trait denotes a type whose value can be explicitly copied.

Example implementing the `Copyable` trait on `Foo`, which requires the
`def __init__(out self,*, copy: Self)` method:

```mojo
struct Foo(Copyable):
    var s: String

    def __init__(out self, s: String):
        self.s = s

    def __init__(out self, *, copy: Self):
        print("copying value")
        self.s = copy.s
```

You can now copy objects inside a generic function:

```mojo
def copy_return[T: Copyable](foo: T) -> T:
    var copy = foo.copy()
    return copy^

var foo = Foo("test")
var res = copy_return(foo)
```

```plaintext
copying value
```

Inherits from: `AnyType`, `Movable`

#### `Copyable.__init__`

```mojo
def __init__(out self, *, copy: Self)
```

Create a new instance of the value by copying an existing one.

Args:

- `copy`: The value to copy.

#### `Copyable.copy`

```mojo
def copy(self) -> Self
```

Explicitly construct a copy of self, a convenience method for `Self(copy=self)` when the type is inconvenient to write out.

Overriding this method is not allowed.

Returns: A copy of this value.

### `ImplicitlyCopyable`

```mojo
trait ImplicitlyCopyable
```

A marker trait to permit compiler to insert implicit calls to the copy constructor in order to make a copy of the object when needed.

Conforming a type to `ImplicitlyCopyable` gives the Mojo language permission
to implicitly insert a call to that types copy constructor whenever a borrowed
instance of the type is passed or assigned where an owned value is required.

Types that are expensive to copy, or where implicit copying could mask a
logic error, typically should not be `ImplicitlyCopyable`.

The `ImplicitlyCopyable` trait is a marker trait, meaning that it does not
require a type to provide any additional methods or associated aliases to
conform to this trait. However, all `ImplicitlyCopyable` types are required
to conform to `Copyable`, which ensures there is only one definition for the
logic of how a type is copied.

**Note:** `ImplicitlyCopyable` should only be used to mark structs that may
be copied implicitly. It should not be used as a trait bound
(`T: ImplicitlyCopyable`) on functions or types, except in special
circumstances. Generic code that may perform copies should always use the
more general `T: Copyable` bound. This ensures that generic code is usable
with all types that are copyable, regardless of whether they opt-in to
implicit copying.

**Examples:**

A type can opt-in to implicit copying by conforming to `ImplicitlyCopyable`
(in the example below, the compiler also synthesizes a default field-wise
copy constructor, as the user didn't provide a definition):

```mojo
@fieldwise_init
struct Point(ImplicitlyCopyable):
    var x: Int
    var y: Int

def main():
    var p = Point(5, 10)

    # Perform an implicit copy of `p`.
    var p2 = p
```

Inherits from: `AnyType`, `Copyable`, `Movable`

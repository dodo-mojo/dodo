# `std.builtin.len`

Provides the `len()` function and its associated traits.

These are Mojo built-ins, so you don't need to import them.

## Traits

### `Sized`

```mojo
trait Sized
```

The `Sized` trait describes a type that has an integer length (such as a string or array).

Any type that conforms to `Sized` or
[`SizedRaising`](../../std/builtin/len.md#sizedraising) works with the
built-in [`len()`](../../std/builtin/len.md#len) function.

The `Sized` trait requires a type to implement the `__len__()`
method. For example:

```mojo
@fieldwise_init
struct Foo(Sized):
    var length: Int

    def __len__(self) -> Int:
        return self.length
```

You can pass an instance of `Foo` to the `len()` function to get its
length:

```mojo
@fieldwise_init
struct Foo(Sized):
    var length: Int

    def __len__(self) -> Int:
        return self.length

var foo = Foo(42)
print(len(foo) == 42)
```

```plaintext
True
```

**Note:** If the `__len__()` method can raise an error, use the
[`SizedRaising`](../../std/builtin/len.md#sizedraising) trait instead.

Inherits from: `AnyType`

#### `Sized.__len__`

```mojo
def __len__(self) -> Int
```

Get the length of the type.

Returns: The length of the type.

### `SizedRaising`

```mojo
trait SizedRaising
```

The `SizedRaising` trait describes a type that has an integer length, which might raise an error if the length can't be determined.

Any type that conforms to [`Sized`](../../std/builtin/len.md#sized) or
`SizedRaising` works with the built-in
[`len()`](../../std/builtin/len.md#len) function.

The `SizedRaising` trait requires a type to implement the `__len__()`
method, which can raise an error. For example:

```mojo
@fieldwise_init
struct Foo(SizedRaising):
    var length: Int

    def __len__(self) raises -> Int:
        if self.length < 0:
            raise Error("Length is negative")
        return self.length
```

You can pass an instance of `Foo` to the `len()` function to get its
length:

```mojo
@fieldwise_init
struct Foo(SizedRaising):
    var length: Int

    def __len__(self) raises -> Int:
        if self.length < 0:
            raise Error("Length is negative")
        return self.length

def main() raises:
    var foo = Foo(42)
    print(len(foo) == 42)
```

```plaintext
True
```

Inherits from: `AnyType`

#### `SizedRaising.__len__`

```mojo
def __len__(self) raises -> Int
```

Get the length of the type.

Returns: The length of the type.

Raises: If the length cannot be computed.

## Functions

### `len`

```mojo
def len[T: Sized](value: T) -> Int
```

Get the length of a value.

Parameters:

- `T`: The Sized type.

Args:

- `value`: The object to get the length of.

Returns: The length of the object.

```mojo
def len[T: SizedRaising](value: T) raises -> Int
```

Get the length of a value.

Parameters:

- `T`: The Sized type.

Args:

- `value`: The object to get the length of.

Returns: The length of the object.

Raises: If the length cannot be computed.

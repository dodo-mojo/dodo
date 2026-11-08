# `std.traits.deinitable`

Defines `Deinitable`, the trait for types with lifetime management through destructors.

This is a Mojo built-in, so you don't need to import it.

## Aliases

### `IsTriviallyDeinitable`

```mojo
comptime IsTriviallyDeinitable[T: AnyType] = conforms_to(T, TrivialRegisterPassable) if conforms_to(T, TrivialRegisterPassable) else T.__del__is_trivial if conforms_to(T, Deinitable) else conforms_to(T, Deinitable)
```

Indicates whether `T` is `Deinitable` with a trivial deinitializer.

A deinitializer is trivial when the compiler generates it and all of `T`'s
fields are themselves trivially destructible meaning `__deinit__` is a no-op.
Evaluates to `False` for non-`Deinitable` types.

## Traits

### `Deinitable`

```mojo
trait Deinitable
```

A trait for types that require lifetime management through destructors.

The `Deinitable` trait is fundamental to Mojo's memory
management system. It indicates that a type has a destructor that needs to
be called when instances go out of scope. This is essential for types that
own resources like memory, file handles, or other system resources that need
proper cleanup.

By default, all Mojo types implement `Deinitable`, unless they
opt-in to required explicit named destructor methods using
`not Deinitable`, or conditionally with `Deinitable where <cond>`.

Key aspects:

- Any type with an implicit `__deinit__()` destructor must implement this trait
- The destructor (`__deinit__`) is called automatically when an instance's
  lifetime ends
- Composition of types with implicit destructors automatically get an
  implicit destructor

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout, Allocation

struct ResourceOwner(Deinitable):
    var allocation: Allocation[Int]

    def __init__(out self, size: Int):
        self.allocation = alloc(Layout[Int](count=size))

    def __deinit__(deinit self):
        # Clean up owned resources
        dealloc(self.allocation^)
```

Best practices:

- Implement this trait when your type owns resources that need cleanup
- Ensure the destructor properly frees all owned resources
- Consider using a `not Deinitable` conformance on types that should
  never be deleted implicitly.
- Use composition to automatically handle nested resource cleanup

Inherits from: `AnyType`

#### `Deinitable.__deinit__`

```mojo
def __deinit__(deinit self)
```

Destroys the instance and cleans up any owned resources.

This method is called automatically when an instance's lifetime ends. It receives
an owned value and should perform all necessary cleanup operations like:
- Freeing allocated memory
- Closing file handles
- Releasing system resources
- Cleaning up any other owned resources

The instance is considered dead after this method completes, regardless of
whether any explicit cleanup was performed.

## Functions

### `deinit`

```mojo
def deinit[T: Deinitable](var value: T, /)
```

Extends a value's lifetime up to this call, then deinitializes it.

Mojo deinitializes a value at its last use, not at the end of its enclosing
scope. If nothing in the code reads `value` again after some earlier
point, that earlier point *is* its last use, and its deinitializer runs
there. This function is a way to explicitly extend the lifetime of that
value until this point exactly.

```mojo
from std.testing import assert_equal

struct AddOne[origin: MutOrigin]:
    var n: Pointer[Int, Self.origin]

    def __init__(out self, ref[Self.origin] n: Int):
        self.ptr = Pointer(to=n)

    def __deinit__(deinit self):
        self.n[] += 1

def main() raises:
    var n = 0
    var add_one = AddOne(n)
    assert_equal(n, 0)

    # `add_one` is never used, so without the `deinit()` call below, its
    # deinitializer would run immediately after construction, causing
    # `n` to equal `1` and triggering the `assert_equal` to raise an error.
    deinit(add_one^)
    assert_equal(n, 1)
```

Parameters:

- `T`: The type of the value to destroy. Must conform to `Deinitable`.

Args:

- `value`: The value whose lifetime to extend and then end.

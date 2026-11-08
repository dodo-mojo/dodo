# `std.memory.memory`

Defines functions for memory manipulations.

You can import these APIs from the `memory` package. For example:

```mojo
from std.memory import unsafe_memcmp
```

## Functions

### `unsafe_memcmp`

```mojo
def unsafe_memcmp[type: AnyType, address_space: AddressSpace](s1: Pointer[type, address_space=address_space], s2: Pointer[type, address_space=address_space], count: Int) -> Int
```

Compares two buffers. Both strings are assumed to be of the same length.

Parameters:

- `type`: The element type.
- `address_space`: The address space of the pointer.

Args:

- `s1`: The first buffer address.
- `s2`: The second buffer address.
- `count`: The number of elements in the buffers.

Returns: Returns 0 if the bytes strings are identical, 1 if s1 > s2, and -1 if s1 < s2. The comparison is performed by the first different byte in the byte strings.

### `unsafe_memcpy`

```mojo
def unsafe_memcpy[T: AnyType](*, dest: Pointer[T], src: Pointer[T], count: Int)
```

Copy `count * size_of[T]()` bytes from src to dest.

The dest and src memory must **not** overlap. For potentially
overlapping memory regions, use `unsafe_memmove`.

Safety:
`dest` and `src` must be valid for at least `count * size_of[T]()`
bytes.

Parameters:

- `T`: The element type.

Args:

- `dest`: The destination pointer.
- `src`: The source pointer.
- `count`: The number of elements to copy.

### `unsafe_memmove`

```mojo
def unsafe_memmove[T: AnyType](*, dest: Pointer[T], src: Pointer[T], count: Int)
```

Copy `count * size_of[T]()` bytes from src to dest.

Unlike `unsafe_memcpy`, the memory regions are allowed to overlap.

Parameters:

- `T`: The element type.

Args:

- `dest`: The destination pointer.
- `src`: The source pointer.
- `count`: The number of elements to copy.

### `memmove`

```mojo
def memmove[T: AnyType](*, dest: Pointer[T], src: Pointer[T], count: Int)
```

**Deprecated:** 'memmove' is deprecated, use 'unsafe_memmove' instead

Copy `count * size_of[T]()` bytes from src to dest.

Unlike `memcpy`, the memory regions are allowed to overlap.

Parameters:

- `T`: The element type.

Args:

- `dest`: The destination pointer.
- `src`: The source pointer.
- `count`: The number of elements to copy.

### `unsafe_memset`

```mojo
def unsafe_memset(ptr: Pointer[address_space=ptr.address_space], value: UInt8, count: Int)
```

Fills memory with the given value.

Prefer the safe, bounds-carrying `Span.fill()` (for example,
`my_span.fill(value)` on a `Span[Byte]`), which works in every address
space. This raw entry point fills at byte granularity, so unlike
`Span.fill()` it applies to elements of any type, including types that
cannot cross an address-space boundary as a value.

Args:

- `ptr`: Pointer to the beginning of the memory block to fill.
- `value`: The value to fill with.
- `count`: Number of elements to fill (in elements, not bytes).

### `unsafe_memset_zero`

```mojo
def unsafe_memset_zero(ptr: Pointer[address_space=ptr.address_space], count: Int)
```

Fills memory with zeros.

Prefer the safe, bounds-carrying `Span.fill(0)`, which works in every
address space. This raw entry point fills at byte granularity, so unlike
`Span.fill()` it applies to elements of any type, including types that
cannot cross an address-space boundary as a value.

Args:

- `ptr`: Pointer to the beginning of the memory block to fill.
- `count`: Number of elements to fill (in elements, not bytes).

```mojo
def unsafe_memset_zero[dtype: DType, //, *, count: Int](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space])
```

Fills memory with zeros.

Parameters:

- `dtype`: The element type.
- `count`: Number of elements to fill (in elements, not bytes).

Args:

- `ptr`: Pointer to the beginning of the memory block to fill.

### `is_trivially_movable`

```mojo
def is_trivially_movable[T: Movable]() -> Bool
```

**Deprecated:** 'is_trivially_movable' is deprecated, use 'IsTriviallyMovable' instead

Returns whether `T` has a trivial move constructor.

A move constructor is trivial when the compiler generates it and all of
`T`'s fields are themselves trivially movable. In practice this means the
value can be moved by copying its bits to a new location without any
additional side effects.

Parameters:

- `T`: The type to check.

Returns: `True` if `T` has a trivial move constructor.

### `is_trivially_copyable`

```mojo
def is_trivially_copyable[T: Copyable]() -> Bool
```

**Deprecated:** 'is_trivially_copyable' is deprecated, use 'IsTriviallyCopyable' instead

Returns whether `T` has a trivial copy constructor.

A copy constructor is trivial when the compiler generates it and all of
`T`'s fields are themselves trivially copyable. In practice this means the
value can be copied by duplicating its bits to a new location without any
additional side effects.

Parameters:

- `T`: The type to check.

Returns: `True` if `T` has a trivial copy constructor.

### `is_trivially_deletable`

```mojo
def is_trivially_deletable[T: AnyType]() -> Bool
```

**Deprecated:** 'is_trivially_deletable' is deprecated, use 'IsTriviallyDeinitable' instead

Returns whether `T` has a trivial destructor.

A destructor is trivial when the compiler generates it and all of `T`'s
fields are themselves trivially destructible. In practice this means
`__deinit__` is a no-op. A non-`Deinitable` (linear) type returns `False`

Parameters:

- `T`: The type to check.

Returns: `True` if `T` has a trivial destructor.

### `unsafe_uninit_move_n`

```mojo
def unsafe_uninit_move_n[T: Movable, //, *, overlapping: Bool](*, dest: Pointer[T], src: Pointer[T], count: Int)
```

Move `count` values from `src` into memory at `dest`.

This function transfers ownership of `count` values from the source memory
to the destination memory. After this call, the source values should be
treated as uninitialized, and the destination values are valid and
initialized.

For types with trivial move constructors, this is optimized to a single
`unsafe_memcpy` (or `unsafe_memmove` when `overlapping=True`) operation.
Otherwise, it manually moves each element.

The destination memory is treated as a raw span of bits to write to. Any
existing values at `dest` are silently overwritten without being destroyed.
For types with non-trivial destructors, this can cause memory leaks. Call
`unsafe_destroy_n()` on the destination region first if it contains
initialized values that need cleanup. For trivial types like `Int`, this is
not a concern.

Safety:

- `dest` must point to a valid memory region with space for at least
    `count` elements of type `T`.
- `src` must point to a valid memory region containing at least `count`
    **initialized** elements of type `T`.
- If `overlapping=False`, the `src` and `dest` memory regions must **not**
    overlap. Overlapping regions with `overlapping=False` is undefined
    behavior.

Parameters:

- `T`: The type of values to move, which must be `Movable`.
- `overlapping`: If False, the function assumes `src` and `dest` do not overlap and uses `unsafe_memcpy`. If True, the function handles an overlap safely, walking the elements back-to-front when `dest` sits above `src`.

Args:

- `dest`: Pointer to the destination memory region.
- `src`: Pointer to the source memory region. Must point to initialized values.
- `count`: The number of elements to move.

### `unsafe_uninit_copy_n`

```mojo
def unsafe_uninit_copy_n[T: Copyable, //, *, overlapping: Bool](*, dest: Pointer[T], src: Pointer[T], count: Int)
```

Copy `count` values from `src` into memory at `dest`.

This function creates copies of `count` values from the source memory in the
destination memory. After this call, both source and destination values are
valid and initialized.

For types with trivial copy constructors, this is optimized to a single
`unsafe_memcpy` (or `unsafe_memmove` when `overlapping=True`) operation.
Otherwise, it calls `unsafe_write()` on each element.

The destination memory is treated as a raw span of bits to write to. Any
existing values at `dest` are silently overwritten without being destroyed.
For types with non-trivial destructors, this can cause memory leaks. Call
`unsafe_destroy_n()` on the destination region first if it contains
initialized values that need cleanup. For trivial types like `Int`, this is
not a concern.

Safety:

- `dest` must point to a valid memory region with space for at least
    `count` elements of type `T`.
- `src` must point to a valid memory region containing at least `count`
    **initialized** elements of type `T`.
- If `overlapping=False`, the `src` and `dest` memory regions must **not**
    overlap. Overlapping regions with `overlapping=False` is undefined
    behavior.

Parameters:

- `T`: The type of values to copy, which must be `Copyable`.
- `overlapping`: If False, the function assumes `src` and `dest` do not overlap and uses `unsafe_memcpy`. If True, the function handles an overlap safely, walking the elements back-to-front when `dest` sits above `src`.

Args:

- `dest`: Pointer to the destination memory region.
- `src`: Pointer to the source memory region. Must point to initialized values.
- `count`: The number of elements to copy.

### `unsafe_destroy_n`

```mojo
def unsafe_destroy_n[T: Deinitable](pointer: Pointer[T], count: Int)
```

Destroy `count` initialized values at `pointer`.

This function runs the destructor for each of the `count` values, leaving
the memory uninitialized.

For types with trivial destructors, this is a no-op and generates no code.
Otherwise, it calls `unsafe_deinit_pointee()` on each element.

Safety:

- `pointer` must point to a valid memory region containing at least `count`
    **initialized** elements of type `T`.
- After this call, the values at `pointer[0:count]` are uninitialized and
    must not be read or destroyed again until re-initialized.

Parameters:

- `T`: The type of values to destroy, which must be `Deinitable`.

Args:

- `pointer`: Pointer to the memory region containing values to destroy.
- `count`: The number of elements to destroy.

### `forget_deinit`

```mojo
def forget_deinit[T: AnyType](var value: T)
```

Takes ownership and skips running `__deinit__` deinitializers.

This is a low-level operation, and should not be used unless necessary.
Consider if refactoring to avoid needing this function would be more
appropriate.

This operation is not considered unsafe, as Mojo can not guarantee in
general that destructors will eventually be run.

Note: Take care to use `^` to transfer when passing `ImplicitlyCopyable`
values to `forget_deinit()`, to avoid forgetting a copy instead of the
original value.

Example:

```mojo
from std.memory import forget_deinit

@fieldwise_init
struct Noisy:
    def __deinit__(deinit self):
        print("@ Noisy.__deinit__: Noisy is being deleted!")

def main():
    var noisy = Noisy()

    # No deletion message is printed
    forget_deinit(noisy^)
```

This will skip the destructor for the "root" `value` object and all of
it's fields, recursively. Example:

```mojo
from std.memory import forget_deinit

@fieldwise_init
struct Parent:
    var child: Child

    def __deinit__(deinit self):
        print("@ Parent.__deinit__")

@fieldwise_init
struct Child(Movable):
    def __deinit__(deinit self):
        print("@ Child.__deinit__")

def main():
    var parent = Parent(Child())

    # Neither Parent.__deinit__ nor Child.__deinit__ is called.
    forget_deinit(parent^)
```

Parameters:

- `T`: The type of the value to discard without running a deinitializer.

Args:

- `value`: The value to discard without running a deinitializer.

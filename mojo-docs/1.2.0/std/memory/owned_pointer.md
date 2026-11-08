# `std.memory.owned_pointer`

Implements `OwnedPointer`, a safe, single-ownership smart pointer.

You can import these APIs from the `memory` package. For example:

```mojo
from std.memory import OwnedPointer
```

## Structs

### `OwnedPointer`

```mojo
struct OwnedPointer[T: AnyType]
```

A safe, owning, smart pointer.

This smart pointer is designed for cases where there is clear ownership
of the underlying data, and restricts access to it through the origin
system such that no more than one mutable alias for the underlying data
may exist.

For a comparison with other pointer types, see [Intro to
pointers](../../manual/pointers/index.md) in the Mojo Manual.

Parameters:

- `T`: The type to be stored in the `OwnedPointer`. When `T` is not `Deinitable`, the `OwnedPointer` has no implicit destructor and must be consumed with `into_inner()` (for a `Movable` `T`) or `unsafe_take_allocation()`.

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `RegisterPassable`, `Writable`

#### `OwnedPointer.__init__`

```mojo
def __init__[_T: Movable](var value: _T) -> OwnedPointer[_T]
```

Construct a new `OwnedPointer` by moving the passed value into a new backing allocation.

Parameters:

- `_T`: The type of the data to store. It is restricted to `Movable` here to allow efficient move construction.

Args:

- `value`: The value to move into the `OwnedPointer`.

```mojo
def __init__[_T: Copyable](*, copy_value: _T) -> OwnedPointer[_T]
```

Construct a new `OwnedPointer` by explicitly copying the passed value into a new backing allocation.

Parameters:

- `_T`: The type of the data to store, which must be `Copyable`.

Args:

- `copy_value`: The value to explicitly copy into the `OwnedPointer`.

```mojo
def __init__[_T: Copyable, U: NoneType = None](value: _T) -> OwnedPointer[_T]
```

Construct a new `OwnedPointer` by copying the passed value into a new backing allocation.

Parameters:

- `_T`: The type of the data to store.
- `U`: A dummy type parameter, to lower the selection priority of this ctor.

Args:

- `value`: The value to copy into the `OwnedPointer`.

```mojo
def __init__[_T: Copyable](*, other: OwnedPointer[_T]) -> OwnedPointer[_T]
```

Construct a new `OwnedPointer` by explicitly copying the value from another `OwnedPointer`.

Parameters:

- `_T`: The type of the data to store.

Args:

- `other`: The `OwnedPointer` to copy.

```mojo
def __init__(*, unsafe_from_raw_pointer: Pointer[T, MutUntrackedOrigin]) -> Self
```

Construct a new `OwnedPointer` by taking ownership of the provided `Pointer`.

Safety:

This function is unsafe as the provided `Pointer` must be initialize with a single valid `T`
initially allocated with this `OwnedPointer`'s backing allocator.
This function is unsafe as other memory problems can arise such as a double-free if this function
is called twice with the same pointer or a user manually deallocates the same data.

After using this constructor, the `Pointer` is assumed to be owned by this `OwnedPointer`.
In particular, the destructor method will call `T.__deinit__` and `dealloc`.

Args:

- `unsafe_from_raw_pointer`: The `Pointer` to take ownership of.

```mojo
def __init__(*, unsafe_from_opaque_pointer: Pointer[NoneType]) -> Self
```

Construct a new `OwnedPointer` by taking ownership of the provided `Pointer`.

Safety:

This function is unsafe as the provided `OpaquePointer` must be initialize with a single valid `T`
initially allocated with this `OwnedPointer`'s backing allocator.
This function is unsafe as other memory problems can arise such as a double-free if this function
is called twice with the same pointer or a user manually deallocates the same data.

After using this constructor, the `Pointer` is assumed to be owned by this `OwnedPointer`.
In particular, the destructor method will call `T.__deinit__` and `dealloc`.

Args:

- `unsafe_from_opaque_pointer`: The `OpaquePointer` to take ownership of.

#### `OwnedPointer.__deinit__`

```mojo
def __deinit__(deinit self) where conforms_to(T, Deinitable)
```

Destroy the `OwnedPointer`, running the destructor of its value.

Constraints: `T` must be `Deinitable`. When it is not, the
`OwnedPointer` has no implicit destructor and must be consumed
with `into_inner()` (for a `Movable` `T`) or
`unsafe_take_allocation()`.

#### `OwnedPointer.__getitem__`

```mojo
def __getitem__(ref self) -> ref[self_is_mut["value"]] T
```

Returns a reference to the pointers's underlying data with parametric mutability.

Returns: A reference to the data underlying the `OwnedPointer`.

#### `OwnedPointer.ptr`

```mojo
def ptr[origin: Origin[mut=origin.mut], //](ref[origin.mut] self) -> Pointer[T, origin]
```

Returns a pointer to the `OwnedPointer`'s contents.

Parameters:

- `origin`: The origin of the pointer.

Returns: A pointer to the `OwnedPointer`'s contents.

#### `OwnedPointer.into_inner`

```mojo
def into_inner(deinit self) -> T where conforms_to(T, Movable)
```

Move the value within the `OwnedPointer` out of it, consuming the `OwnedPointer` in the process.

Returns: The data that is (was) backing the `OwnedPointer`.

#### `OwnedPointer.unsafe_take_allocation`

```mojo
def unsafe_take_allocation(deinit self) -> Allocation[T]
```

Take ownership of the heap allocation backing this `OwnedPointer`.

Safety:

The pointee is handed over still initialized, and deallocating the
storage does not run its destructor. Destroy it yourself before
deallocating if `T` needs it.

The returned `Allocation` is an explicitly destroyed handle, so the
compiler requires the caller to consume it: pass it to `dealloc`, or
take the raw pointer with `unsafe_leak()`.

Returns: The `Allocation` that owns the backing storage.

#### `OwnedPointer.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Writable)
```

Formats this pointer's value to the provided Writer.

Constraints: `T` must conform to Writable.

Args:

- `writer`: The object to write to.

#### `OwnedPointer.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(T, Writable)
```

Write the string representation of the `OwnedPointer`.

Constraints: `T` must conform to Writable.

Args:

- `writer`: The object to write to.

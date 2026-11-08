# `std.memory.arc_pointer`

Reference-counted smart pointers.

You can import these APIs from the `memory` package. For example:

```mojo
from std.memory import ArcPointer
```

## Structs

### `ArcPointer`

```mojo
struct ArcPointer[T: Deinitable & Movable]
```

Atomic reference-counted pointer.

This smart pointer owns an instance of `T` indirectly managed on the heap.
This pointer is copyable, including across threads, maintaining a reference
count to the underlying data.

When you initialize an `ArcPointer` with a value, it allocates memory and
moves the value into the allocated memory. Copying an instance of an
`ArcPointer` increments the reference count. Destroying an instance
decrements the reference count. When the reference count reaches zero,
`ArcPointer` destroys the value and frees its memory.

This pointer itself is thread-safe using atomic accesses to reference count
the underlying data, but references returned to the underlying data are not
thread-safe.

Subscripting an `ArcPointer` (`arc[]`) returns a mutable reference to the
stored value. Use `ptr()` to get an immutable pointer to the stored
value. Accessing the private fields of an `ArcPointer` is unsafe and may
result in memory errors.

For a comparison with other pointer types, see [Intro to
pointers](../../manual/pointers/index.md) in the Mojo Manual.

Examples:

```mojo
from std.memory import ArcPointer
var p = ArcPointer(4)
var p2 = p
p2[]=3
print(3 == p[])
```

Parameters:

- `T`: The type of the stored value.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `Identifiable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Writable`

Aliases:

- `WeakPointer = WeakPointer[T]`: Convenience alias: `WeakPointer[T]` for this `ArcPointer[T]`.

#### `ArcPointer.__init__`

```mojo
def __init__(var value: T) -> Self
```

Construct a new thread-safe, reference-counted smart pointer, and move the value into heap memory managed by the new pointer.

Args:

- `value`: The value to manage.

```mojo
def __init__(*, unsafe_from_raw_pointer: Pointer[_ArcPointerInner[T], MutUntrackedOrigin]) -> Self
```

Constructs an `ArcPointer` from a raw pointer.

**Safety:**

The `unsafe_from_raw_pointer` argument *must* have been obtained from a
call to `ArcPointer.unsafe_take_allocation` (via `unsafe_leak()`). Any
other pointer may result in undefined behaviour.

**Example:**

```mojo
from std.memory import ArcPointer

var initial_arc = ArcPointer[Int](42)
var raw_ptr = initial_arc^.unsafe_take_allocation().unsafe_leak()

# The following will ensure the data is properly destroyed and deallocated.
var restored_arc = ArcPointer(unsafe_from_raw_pointer=raw_ptr)
```

Args:

- `unsafe_from_raw_pointer`: A raw pointer to the control block, obtained from `ArcPointer.unsafe_take_allocation().unsafe_leak()`.

```mojo
def __init__(*, copy: Self) -> Self
```

Copy an existing reference. Increment the refcount to the object.

Args:

- `copy`: The existing reference.

```mojo
def __init__(*, _inner: Pointer[_ArcPointerInner[T], MutUntrackedOrigin]) -> Self
```

Internal: construct from an already-incremented inner pointer.

Args:

- `_inner`: The inner control-block pointer. The strong refcount must already account for this new `ArcPointer`.

#### `ArcPointer.__deinit__`

```mojo
def __deinit__(deinit self)
```

Delete the smart pointer.

Decrement the reference count for the stored value. If there are no more
references, delete the object and free its memory.

#### `ArcPointer.__getitem__`

```mojo
def __getitem__[self_life: ImmOrigin](ref[T] self) -> ref[T] T
```

Returns a mutable reference to the managed value.

Parameters:

- `self_life`: The origin of self.

Returns: A reference to the managed value.

#### `ArcPointer.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool where conforms_to(T, Equatable)
```

Returns True if the two `ArcPointer` instances hold equal values.

Delegates to the underlying value's `__eq__` method, so two
`ArcPointer` instances holding equal values compare equal even if
they are separate allocations. This is consistent with `__hash__`.

Args:

- `rhs`: The other `ArcPointer`.

Returns: True if the managed values are equal, False otherwise.

#### `ArcPointer.__is__`

```mojo
def __is__(self, rhs: Self) -> Bool
```

Returns True if the two `ArcPointer` instances point at the same object.

Args:

- `rhs`: The other `ArcPointer`.

Returns: True if the two `ArcPointers` instances point at the same object and False otherwise.

#### `ArcPointer.ptr`

```mojo
def ptr[origin: Origin[mut=origin.mut], //](ref[origin.mut] self) -> Pointer[T, origin_of(origin)]
```

Returns an immutable pointer to the managed value.

An `ArcPointer` may be shared across threads, so this always returns
an immutable pointer to prevent data races, regardless of whether
`self` is borrowed mutably. Use `[]` for mutable access to the
managed value.

Parameters:

- `origin`: The origin of the pointer.

Returns: An immutable pointer to the managed value.

#### `ArcPointer.count`

```mojo
def count(self) -> UInt64
```

Returns the current strong reference count.

Returns: The current number of strong references to the pointee.

#### `ArcPointer.weak_count`

```mojo
def weak_count(self) -> UInt64
```

Returns the current number of `Weak` pointers, excluding the implicit weak reference held by all strong pointers.

Returns: The number of outstanding `Weak` pointers to this allocation.

#### `ArcPointer.unsafe_take_allocation`

```mojo
def unsafe_take_allocation(deinit self) -> Allocation[_ArcPointerInner[T]]
```

Consume this `ArcPointer`, returning the owning handle to its allocation.

**Safety:**

This does not decrement the strong reference count, so the payload stays
alive. To avoid leaking memory, pass the handle's raw pointer back to
`ArcPointer(unsafe_from_raw_pointer=handle^.unsafe_leak())`, which
restores the `ArcPointer` and its reference-counting bookkeeping.

Returns: The `Allocation` that owns the reference-counted control block backing this `ArcPointer`.

#### `ArcPointer.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H) where conforms_to(T, Hashable)
```

Hash the managed value.

Delegates to the underlying value's `__hash__` method, so two
`ArcPointer` instances holding equal values produce the same hash.
This is consistent with `__eq__`.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance to update.

#### `ArcPointer.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Writable)
```

Formats this pointer's value to the provided Writer.

Constraints: T must conform to Writable.

Args:

- `writer`: The object to write to.

#### `ArcPointer.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(T, Writable)
```

Write the string representation of the `ArcPointer`.

Constraints: T must conform to Writable.

Args:

- `writer`: The object to write to.

### `WeakPointer`

```mojo
struct WeakPointer[T: Deinitable & Movable]
```

Non-owning atomic reference to an `ArcPointer`'s allocation.

A `WeakPointer` may _not_ be directly subscripted to dereference
to the value it conceptually points to.

Instead, a `WeakPointer` may be `.try_upgrade()`ed into an `ArcPointer[T]` if there is
at least one `ArcPointer[T]` for the value still live.

This may be used for self-referential structures, such as doubly
linked lists or trees with parent refs, to avoid creating ownership
cycles that would leak if dropped.

If all `ArcPointer[T]` to a value are dropped but `WeakPointer[T]` remain,
the value will be destroyed. After this point, `.try_upgrade()`ing a `WeakPointer[T]`
to that value will always return `None`.

Parameters:

- `T`: The type of the stored value.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`

#### `WeakPointer.__init__`

```mojo
def __init__() -> Self
```

Create a null WeakPointer, with _no_ inner. This can be used for transient construction states for self-referential structures.

```mojo
def __init__(*, downgrade: ArcPointer[T]) -> Self
```

Creates a new `Weak` pointer from an associated `ArcPointer`.

Args:

- `downgrade`: The value that this creates a WeakPointer referring to.

Returns: A new `Weak` pointer sharing this allocation.

```mojo
def __init__(*, copy: Self) -> Self
```

Increment the weak count and share the allocation.

Args:

- `copy`: The existing `WeakPointer` to share an allocation with.

#### `WeakPointer.__deinit__`

```mojo
def __deinit__(deinit self)
```

Decrement the weak count and free the allocation if last.

#### `WeakPointer.try_upgrade`

```mojo
def try_upgrade(self) -> Optional[ArcPointer[T]]
```

Attempts to obtain a strong reference.

Returns: An `ArcPointer` sharing the allocation, or `None` if the payload has already been destroyed (strong count reached 0).

#### `WeakPointer.strong_count`

```mojo
def strong_count(self) -> UInt64
```

Returns the current strong count, or 0 if the payload is gone.

Returns: The current number of strong references to the allocation.

#### `WeakPointer.weak_count`

```mojo
def weak_count(self) -> UInt64
```

Returns an approximate count of `WeakPointer`s to this shared value.

This can be off by one in the presence of concurrent activity.

Returns: The approximate number of outstanding `WeakPointer`s.

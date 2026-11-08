# `std.atomic.atomic`

Implements the `Atomic` struct.

You can import these APIs from the `atomic` package. For example:

```mojo
from std.atomic import Atomic
```

## Structs

### `Ordering`

```mojo
struct Ordering
```

Represents the memory ordering for atomic operations.

The class provides a set of constants that represent different memory
orderings for atomic operations.

Attributes:
    NOT_ATOMIC: Not atomic.
    UNORDERED: Unordered.
    RELAXED: Relaxed.
    ACQUIRE: Acquire.
    RELEASE: Release.
    ACQUIRE_RELEASE: Acquire-release.
    SEQUENTIAL: Sequentially consistent.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `NOT_ATOMIC = Ordering(UInt8(0))`: Not atomic.
- `UNORDERED = Ordering(UInt8(1))`: Unordered.
- `RELAXED = Ordering(UInt8(2))`: Relaxed.
- `ACQUIRE = Ordering(UInt8(3))`: Acquire.
- `RELEASE = Ordering(UInt8(4))`: Release.
- `ACQUIRE_RELEASE = Ordering(UInt8(5))`: Acquire-release.
- `SEQUENTIAL = Ordering(UInt8(6))`: Sequentially consistent.

#### `Ordering.__init__`

```mojo
def __init__(value: UInt8) -> Self
```

Constructs a new Ordering object.

Args:

- `value`: The value of the memory ordering.

#### `Ordering.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Compares two Ordering objects for equality.

Args:

- `other`: The other Ordering object to compare with.

Returns: True if the objects are equal, False otherwise.

#### `Ordering.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

Compares two Ordering objects for inequality.

Args:

- `other`: The other Ordering object to compare with.

Returns: True if the objects are not equal, False otherwise.

#### `Ordering.as_string_slice`

```mojo
def as_string_slice(self) -> StaticString
```

Returns a string slice representation of an `Ordering`.

Returns: A string slice representation of this ordering.

#### `Ordering.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the string representation of this `Ordering` to a writer.

Args:

- `writer`: The object to write to.

#### `Ordering.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this `Ordering` to a writer.

Args:

- `writer`: The object to write to.

### `Atomic`

```mojo
struct Atomic[T: Deinitable & Movable, *, scope: StringSpan[ImmStaticOrigin] = StringSpan("")]
```

Represents a value with atomic operations.

The class provides atomic `add` and `sub` methods for mutating the value.

Parameters:

- `T`: The underlying type of the Atomic.
- `scope`: The memory synchronization scope.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Atomic.__init__`

```mojo
def __init__(out self, var value: T)
```

Constructs a new atomic value.

Args:

- `value`: Initial value represented as `Scalar[dtype]` type.

#### `Atomic.__iadd__`

```mojo
def __iadd__[dtype: DType, //](mut self: Atomic[Scalar[dtype], scope=self.scope], rhs: Scalar[dtype])
```

Performs atomic in-place add.

Atomically replaces the current value with the result of arithmetic
addition of the value and arg. That is, it performs atomic
post-increment. The operation is a read-modify-write operation. Memory
is affected according to the value of order which is sequentially
consistent.

Args:

- `rhs`: Value to add.

#### `Atomic.__isub__`

```mojo
def __isub__[dtype: DType, //](mut self: Atomic[Scalar[dtype], scope=self.scope], rhs: Scalar[dtype])
```

Performs atomic in-place sub.

Atomically replaces the current value with the result of arithmetic
subtraction of the value and arg. That is, it performs atomic
post-decrement. The operation is a read-modify-write operation. Memory
is affected according to the value of order which is sequentially
consistent.

Args:

- `rhs`: Value to subtract.

#### `Atomic.load`

```mojo
def load[dtype: DType, //, *, ordering: Ordering = Ordering.SEQUENTIAL](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space]) -> Scalar[dtype] where Bool(identical(T, Scalar[dtype]))
```

Loads the current value from the atomic.

Parameters:

- `ordering`: The memory ordering of the load.

Args:

- `ptr`: A pointer to the atomic value.

Returns: The current value of the atomic.

```mojo
def load[dtype: DType, //, *, ordering: Ordering = Ordering.SEQUENTIAL](self: Atomic[Scalar[dtype], scope=self.scope]) -> Scalar[dtype]
```

Loads the current value from the atomic.

Parameters:

- `ordering`: The memory ordering of the load.

Returns: The current value of the atomic.

#### `Atomic.fetch_add`

```mojo
def fetch_add[dtype: DType, //, *, ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space], rhs: Scalar[dtype]) -> Scalar[dtype] where Bool(identical(T, Scalar[dtype]))
```

Performs atomic in-place add.

Atomically replaces the current value with the result of arithmetic
addition of the value and arg. That is, it performs atomic
post-increment. The operation is a read-modify-write operation. Memory
is affected according to the value of order which is sequentially
consistent.

Parameters:

- `ordering`: The memory ordering.

Args:

- `ptr`: The source pointer.
- `rhs`: Value to add.

Returns: The original value before addition.

```mojo
def fetch_add[dtype: DType, //, *, ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL](mut self: Atomic[Scalar[dtype], scope=self.scope], rhs: Scalar[dtype]) -> Scalar[dtype]
```

Performs atomic in-place add.

Atomically replaces the current value with the result of arithmetic
addition of the value and arg. That is, it performs atomic
post-increment. The operation is a read-modify-write operation. Memory
is affected according to the value of order which is sequentially
consistent.

Parameters:

- `ordering`: The memory ordering.

Args:

- `rhs`: Value to add.

Returns: The original value before addition.

#### `Atomic.store`

```mojo
def store[dtype: DType, //, *, ordering: Ordering = Ordering.SEQUENTIAL](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space], value: Scalar[dtype]) where Bool(identical(T, Scalar[dtype]))
```

Performs an atomic store.

Parameters:

- `ordering`: The memory ordering of the store.

Args:

- `ptr`: The destination pointer.
- `value`: The value to store.

```mojo
def store[dtype: DType, //, *, ordering: Ordering = Ordering.SEQUENTIAL](mut self: Atomic[Scalar[dtype], scope=self.scope], value: Scalar[dtype])
```

Performs an atomic store.

Parameters:

- `ordering`: The memory ordering of the store.

Args:

- `value`: The value to store.

#### `Atomic.fetch_sub`

```mojo
def fetch_sub[dtype: DType, //, *, ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL](mut self: Atomic[Scalar[dtype], scope=self.scope], rhs: Scalar[dtype]) -> Scalar[dtype]
```

Performs atomic in-place sub.

Atomically replaces the current value with the result of arithmetic
subtraction of the value and arg. That is, it performs atomic
post-decrement. The operation is a read-modify-write operation. Memory
is affected according to the value of order which is sequentially
consistent.

Parameters:

- `ordering`: The memory ordering.

Args:

- `rhs`: Value to subtract.

Returns: The original value before subtraction.

#### `Atomic.compare_exchange`

```mojo
def compare_exchange[dtype: DType, *, success_ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL, failure_ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL, weak: Bool = False](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space], mut expected: Scalar[dtype], desired: Scalar[dtype]) -> Bool where Bool(identical(T, Scalar[dtype]))
```

Atomically compares the value in ptr with that of the expected value. If the values are equal, then the ptr value is replaced with the desired value and True is returned. Otherwise, False is returned and the expected value is rewritten with the ptr value.

Parameters:

- `dtype`: The `DType` of the atomic value.
- `success_ordering`: The memory ordering for the success case.
- `failure_ordering`: The memory ordering for the failure case.
- `weak`: Allows the comparison to fail spuriously even when `ptr` equals `expected`. Only safe inside a retry loop.

Args:

- `ptr`: The source pointer.
- `expected`: The expected value.
- `desired`: The desired value.

Returns: True if ptr == expected and ptr was updated to desired. False otherwise.

```mojo
def compare_exchange[dtype: DType, //, *, success_ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL, failure_ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL, weak: Bool = False](mut self: Atomic[Scalar[dtype], scope=self.scope], mut expected: Scalar[dtype], desired: Scalar[dtype]) -> Bool
```

Atomically compares the self value with that of the expected value. If the values are equal, then the self value is replaced with the desired value and True is returned. Otherwise, False is returned and the expected value is rewritten with the self value.

Parameters:

- `success_ordering`: The memory ordering for the success case.
- `failure_ordering`: The memory ordering for the failure case.
- `weak`: Allows the comparison to fail spuriously even when `self` equals `expected`. Only safe inside a retry loop.

Args:

- `expected`: The expected value.
- `desired`: The desired value.

Returns: True if self == expected and self was updated to desired. False otherwise.

#### `Atomic.max`

```mojo
def max[dtype: DType, //, *, ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space], rhs: Scalar[dtype]) where Bool(identical(T, Scalar[dtype]))
```

Performs atomic in-place max on the pointer.

Atomically replaces the current value pointer to by `ptr` by the result
of max of the value and arg. The operation is a read-modify-write
operation. The operation is a read-modify-write operation perform
according to sequential consistency semantics.

Constraints: The input type must be either integral or floating-point type.

Parameters:

- `ordering`: The memory ordering.

Args:

- `ptr`: The source pointer.
- `rhs`: Value to max.

```mojo
def max[dtype: DType, //, *, ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL](mut self: Atomic[Scalar[dtype], scope=self.scope], rhs: Scalar[dtype])
```

Performs atomic in-place max.

Atomically replaces the current value with the result of max of the
value and arg. The operation is a read-modify-write operation perform
according to sequential consistency semantics.

Constraints: The input type must be either integral or floating-point type.

Parameters:

- `ordering`: The memory ordering.

Args:

- `rhs`: Value to max.

#### `Atomic.min`

```mojo
def min[dtype: DType, //, *, ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space], rhs: Scalar[dtype]) where Bool(identical(T, Scalar[dtype]))
```

Performs atomic in-place min on the pointer.

Atomically replaces the current value pointer to by `ptr` by the result
of min of the value and arg. The operation is a read-modify-write
operation. The operation is a read-modify-write operation perform
according to sequential consistency semantics.

Constraints: The input type must be either integral or floating-point type.

Parameters:

- `ordering`: The memory ordering.

Args:

- `ptr`: The source pointer.
- `rhs`: Value to min.

```mojo
def min[dtype: DType, //, *, ordering: Ordering = Ordering.RELAXED if is_apple_gpu() else Ordering.SEQUENTIAL](mut self: Atomic[Scalar[dtype], scope=self.scope], rhs: Scalar[dtype])
```

Performs atomic in-place min.

Atomically replaces the current value with the result of min of the
value and arg. The operation is a read-modify-write operation. The
operation is a read-modify-write operation perform according to
sequential consistency semantics.

Constraints: The input type must be either integral or floating-point type.

Parameters:

- `ordering`: The memory ordering.

Args:

- `rhs`: Value to min.

## Functions

### `fence`

```mojo
def fence[ordering: Ordering = Ordering.SEQUENTIAL, *, scope: StringSpan[ImmStaticOrigin] = StringSpan("")]()
```

Creates an atomic fence.

Fences create synchronization between themselves and atomic operations or
fences in other thread without an explicit load or store to an atomic
variable. The fence prevents reordering of certain types of memory
operations around it as specified by the ordering parameter.

Parameters:

- `ordering`: The memory ordering for the fence.
- `scope`: The memory synchronization scope.

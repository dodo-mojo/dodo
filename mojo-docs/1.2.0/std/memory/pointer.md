# `std.memory.pointer`

Implements `Pointer`, Mojo's primary pointer type for indirect memory access.

`Pointer` is safe when constructed from and used to access an existing
value. It also provides `unsafe_`-prefixed methods for working with
dynamically-allocated or uninitialized memory; the caller is responsible
for tracking initialization state and memory ownership.

You can import these APIs from the `memory` package. For example:

```mojo
from std.memory import Pointer
```

## Aliases

### `MutPointer`

```mojo
comptime MutPointer[T: AnyType, origin: MutOrigin, *, address_space: AddressSpace = .GENERIC] = Pointer[T, origin, address_space=address_space]
```

A mutable pointer.

### `ImmPointer`

```mojo
comptime ImmPointer[T: AnyType, origin: ImmOrigin, *, address_space: AddressSpace = .GENERIC] = Pointer[T, origin, address_space=address_space]
```

An immutable pointer.

### `OptionalPointer`

```mojo
comptime OptionalPointer[mut: Bool, //, T: AnyType, origin: Origin[mut=mut], *, address_space: AddressSpace = .GENERIC] = Optional[Pointer[T, origin, address_space=address_space]]
```

An optional (nullable) `Pointer`.

### `OptionalMutPointer`

```mojo
comptime OptionalMutPointer[T: AnyType, origin: MutOrigin, *, address_space: AddressSpace = .GENERIC] = Optional[Pointer[T, origin, address_space=address_space]]
```

An optional (nullable) mutable `Pointer`.

### `OptionalImmPointer`

```mojo
comptime OptionalImmPointer[T: AnyType, origin: ImmOrigin, *, address_space: AddressSpace = .GENERIC] = Optional[Pointer[T, origin, address_space=address_space]]
```

An optional (nullable) immutable `Pointer`.

### `OpaquePointer`

```mojo
comptime OpaquePointer[mut: Bool, //, origin: Origin[mut=mut], *, address_space: AddressSpace = .GENERIC] = Pointer[NoneType, origin, address_space=address_space]
```

An opaque pointer, equivalent to the C `(const) void*` type.

### `MutOpaquePointer`

```mojo
comptime MutOpaquePointer[origin: MutOrigin, *, address_space: AddressSpace = .GENERIC] = Pointer[NoneType, origin, address_space=address_space]
```

A mutable opaque pointer, equivalent to the C `void*` type.

### `ImmOpaquePointer`

```mojo
comptime ImmOpaquePointer[origin: ImmOrigin, *, address_space: AddressSpace = .GENERIC] = Pointer[NoneType, origin, address_space=address_space]
```

An immutable opaque pointer, equivalent to the C `const void*` type.

## Structs

### `Pointer`

```mojo
struct Pointer[mut: Bool, //, T: AnyType, origin: Origin[mut=mut], *, address_space: AddressSpace = .GENERIC]
```

`Pointer` represents an indirect reference to one or more values of type `T` consecutively in memory, and can refer to uninitialized memory.

Constructing a `Pointer` to an existing value (`Pointer(to=value)`) and
dereferencing it (`ptr[]`) are safe operations: the pointer keeps the
ownership linkage to the original value, so Mojo can track its lifetime.
Working with dynamically-allocated or uninitialized memory is unsafe.
Those operations are named with an `unsafe_` prefix, or take an
`unsafe_`-prefixed keyword argument, and require the caller to track
initialization state and memory ownership manually.

Important things to know:

- This pointer is non-nullable by design. To model a nullable pointer,
  use `Optional[Pointer[...]]`, which shares the same layout (the null
  address is the `None` niche) so it remains zero-overhead.
- It does not own existing memory. `alloc()` returns an `Allocation`
  that owns heap-allocated memory; get a `Pointer` to it with
  `.unsafe_ptr()`, and release the memory by passing the `Allocation`
  to `dealloc()`.
- For simple read/write access, use `ptr.unsafe_offset(i)[]` or
  `ptr[unsafe_offset=i]` where `i` is the offset size.
- For SIMD operations on numeric data, use `Pointer[Scalar[.xxx]]`
  with `unsafe_load[dtype=DType.xxx]()` and
  `unsafe_store[dtype=DType.xxx]()`.

Key APIs:

- `unsafe_offset(i)`: Pointer arithmetic. Returns a new pointer shifted by
  `i` elements. No bounds checking.
- `[]` or `[unsafe_offset=i]`: Dereference to a reference of the pointee
  (or at offset `i`). Only valid if the memory at that location is
  initialized.
- `unsafe_load()`: Loads `width` elements starting at `offset` (default 0)
  as `SIMD[dtype, width]` from `Pointer[Scalar[dtype]]`. Pass
  `alignment` when data is not naturally aligned.
- `unsafe_store()`: Stores `val: SIMD[dtype, width]` at `offset` into
  `Pointer[Scalar[dtype]]`. Requires a mutable pointer.
- `unsafe_deinit_pointee()` / `unsafe_take_pointee()`:
  Explicitly end the lifetime of the current pointee, or move it out,
  taking ownership.
- `unsafe_write()` / `unsafe_write_move_from()`:
  Initialize a pointee that is currently uninitialized, by moving an
  existing value into it (pass the argument as `copy=` to copy instead),
  or by moving from another pointee.
  Use these to manage lifecycles when working with uninitialized memory.

For more information see [Using
pointers](../../manual/pointers/using-pointers.md) in the Mojo Manual. For a
comparison with other pointer types, see [Intro to
pointers](../../manual/pointers/index.md).

Examples:

Element-wise store and load (width = 1):

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Float32](count=4))
var ptr = allocation.unsafe_ptr()
for i in range(4):
    ptr.unsafe_store(i, Float32(i))
var v = ptr.unsafe_load(2)
print(v[0])  # => 2.0
dealloc(allocation^)
```

Vectorized store and load (width = 4):

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int32](count=8))
var ptr = allocation.unsafe_ptr()
var vec = SIMD[.int32, 4](1, 2, 3, 4)
ptr.unsafe_store(0, vec)
var out = ptr.unsafe_load[width=4](0)
print(out)  # => [1, 2, 3, 4]
dealloc(allocation^)
```

Pointer arithmetic and dereference:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int32](count=3))
var ptr = allocation.unsafe_ptr()
ptr.unsafe_offset(0)[] = 10  # offset by 0, then dereference to write
ptr.unsafe_offset(1)[] = 20  # offset by 1, then dereference to write
ptr[unsafe_offset=2] = 30  # equivalent offset/dereference via brackets
var second = ptr[unsafe_offset=1]  # reads the element at index 1
print(second, ptr[unsafe_offset=2])  # => 20 30
dealloc(allocation^)
```

Point to a value on the stack:

```mojo
var foo: Int = 123
var ptr = Pointer(to=foo)
print(ptr[])  # => 123
# Don't call `unsafe_free()` because the value was not heap-allocated
# Mojo will destroy it when the `foo` lifetime ends
```

Model a nullable pointer with `Optional`:

`Pointer` is non-nullable by design, so nullability must be modeled
explicitly with `Optional[Pointer[T, origin]]`. This keeps the same
layout as `Optional` stores the null address as its `None` niche, so there
is no overhead compared to a raw pointer.

```mojo
from std.memory.alloc import alloc, dealloc, Layout, ThinAllocation
from std.random import random_float64

comptime layout = Layout[Int].single()

# A field that may or may not point to a heap-allocated Int.
var maybe_ptr: Optional[Pointer[Int, MutUntrackedOrigin]] = None

# Maybe populate it later. `Optional` stores a raw pointer, so leak
# the allocation and later pair it back with its layout to free it.
if random_float64() > 0.5:
    maybe_ptr = alloc(layout).unsafe_leak()

# Unwrap the pointer only if it is present.
if case .Some(ptr) = maybe_ptr:
    ptr.write(42)
    print(ptr[])  # => 42
    dealloc(
        ThinAllocation(unsafe_owned_ptr=ptr).unsafe_with_layout(
            layout
        )
    )
```

If you instead need a non-null placeholder for a field that will be
populated on demand (for example, a buffer that is allocated lazily),
use `Pointer.unsafe_dangling()`. Note that `unsafe_dangling()` is
not a null sentinel — it returns an aligned but dangling address, so
types that lazily allocate must track initialization separately.

Parameters:

- `mut`: Whether the origin is mutable.
- `T`: The type the pointer points to.
- `origin`: The origin of the memory being addressed.
- `address_space`: The address space associated with the `Pointer` allocated memory.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Deinitable`, `DevicePassable`, `Equatable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `UnsafeCustomNicheStorage`, `UnsafeNicheable`, `UnsafeSingleNicheable`, `Writable`

Aliases:

- `device_type = Pointer[T, origin, address_space=address_space]`: DeviceBuffer dtypes are remapped to Pointer when passed to accelerator devices.

#### `Pointer.__init__`

```mojo
def __init__(*, unsafe_from_address: Int) -> Self
```

Create a pointer from a raw address.

Safety:
Creating a pointer from a raw address is inherently unsafe as the
caller must ensure the address is valid before writing to it, and
that the memory is initialized before reading from it. The caller
must also ensure the pointer's origin and mutability is valid for
the address, failure to do may result in undefined behavior.

Args:

- `unsafe_from_address`: The raw address to create a pointer from.

```mojo
def __init__(*, ref[origin, address_space] to: T) -> Self
```

Constructs a Pointer from a reference to a value.

Args:

- `to`: The value to construct a pointer to.

```mojo
def __init__(other: Pointer[address_space=other.address_space]) -> Pointer[other.T, origin_of(other.origin), address_space=other.address_space]
```

Implicitly casts a mutable pointer to immutable.

Args:

- `other`: The mutable pointer to cast from.

```mojo
def __init__[U: Deinitable, //](*, ref[origin] unchecked_downcast_value: PythonObject) -> Pointer[U, origin]
```

Downcast a `PythonObject` known to contain a Mojo object to a pointer.

This operation is only valid if the provided Python object contains
an initialized Mojo object of matching type.

Parameters:

- `U`: Pointee type that can be destroyed implicitly (without deinitializer arguments).

Args:

- `unchecked_downcast_value`: The Python object to downcast from.

#### `Pointer.__getitem__`

```mojo
def __getitem__(self) -> ref[origin, address_space] T
```

Return a reference to the underlying data.

Returns: A reference to the value.

```mojo
def __getitem__[I: Indexer](self, *, unsafe_offset: I) -> ref[origin, address_space] T
```

Return a reference to the underlying data, offset by the given index.

Safety:

- The pointer does not track the bounds of the memory it points
  into, so this does not check whether `unsafe_offset` (in elements
  of `T`) keeps the result within those bounds. `self` offset by
  `unsafe_offset` must point to a valid, initialized element of
  `T`; an out-of-bounds `unsafe_offset` is undefined behavior.

Parameters:

- `I`: A type that can be used as an index.

Args:

- `unsafe_offset`: The offset index.

Returns: An offset reference.

#### `Pointer.__lt__`

```mojo
def __lt__(self, rhs: Pointer[T, address_space=address_space]) -> Bool
```

Returns True if this pointer represents a lower address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a lower address and False otherwise.

```mojo
def __lt__(self, rhs: Self) -> Bool
```

Returns True if this pointer represents a lower address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a lower address and False otherwise.

#### `Pointer.__le__`

```mojo
def __le__(self, rhs: Pointer[T, address_space=address_space]) -> Bool
```

Returns True if this pointer represents a lower than or equal    address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a lower address and False otherwise.

```mojo
def __le__(self, rhs: Self) -> Bool
```

Returns True if this pointer represents a lower than or equal    address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a lower address and False otherwise.

#### `Pointer.__eq__`

```mojo
def __eq__(self, rhs: Pointer[T, address_space=address_space]) -> Bool
```

Returns True if the two pointers are equal.

Args:

- `rhs`: The value of the other pointer.

Returns: True if the two pointers are equal and False otherwise.

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Returns True if the two pointers are equal.

Args:

- `rhs`: The value of the other pointer.

Returns: True if the two pointers are equal and False otherwise.

#### `Pointer.__ne__`

```mojo
def __ne__(self, rhs: Pointer[T, address_space=address_space]) -> Bool
```

Returns True if the two pointers are not equal.

Args:

- `rhs`: The value of the other pointer.

Returns: True if the two pointers are not equal and False otherwise.

```mojo
def __ne__(self, rhs: Self) -> Bool
```

Returns True if the two pointers are not equal.

Args:

- `rhs`: The value of the other pointer.

Returns: True if the two pointers are not equal and False otherwise.

#### `Pointer.__gt__`

```mojo
def __gt__(self, rhs: Pointer[T, address_space=address_space]) -> Bool
```

Returns True if this pointer represents a higher address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a higher than or equal address and False otherwise.

```mojo
def __gt__(self, rhs: Self) -> Bool
```

Returns True if this pointer represents a higher address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a higher than or equal address and False otherwise.

#### `Pointer.__ge__`

```mojo
def __ge__(self, rhs: Pointer[T, address_space=address_space]) -> Bool
```

Returns True if this pointer represents a higher than or equal    address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a higher than or equal address and False otherwise.

```mojo
def __ge__(self, rhs: Self) -> Bool
```

Returns True if this pointer represents a higher than or equal    address than rhs.

Args:

- `rhs`: The value of the other pointer.

Returns: True if this pointer represents a higher than or equal address and False otherwise.

#### `Pointer.__merge_with__`

```mojo
def __merge_with__[other_type: AnyStruct[Pointer[T, other_type.origin, address_space=address_space]]](self) -> Pointer[T, origin_of(origin, other_type.origin), address_space=address_space]
```

Returns a pointer merged with the specified `other_type`.

Parameters:

- `other_type`: The type of the pointer to merge with.

Returns: A pointer merged with the specified `other_type`.

#### `Pointer.__int__`

```mojo
def __int__(self) -> Int
```

Returns the pointer address as an integer.

Returns: The address of the pointer as an Int.

#### `Pointer.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this pointer address to the provided Writer.

Args:

- `writer`: The object to write to.

#### `Pointer.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the string representation of the Pointer.

Args:

- `writer`: The object to write to.

#### `Pointer.get_type_name`

```mojo
def get_type_name() -> String
```

Gets this type name, for use in error messages when handing arguments to kernels. TODO: This will go away soon, when we get better error messages for kernel calls.

Returns: This name of the type.

#### `Pointer.unsafe_offset`

```mojo
def unsafe_offset[I: Indexer](self, offset: I, /) -> Self
```

Return a pointer at an offset from the current one.

Safety:

- The pointer does not track the bounds of the memory it points
  into, so this does not check whether `offset` (in elements of
  `T`) keeps the result within those bounds. Computing an
  out-of-bounds pointer is not itself unsafe, but dereferencing
  (loading from, storing to, or indexing) the result is undefined
  behavior unless it is back within bounds.

Parameters:

- `I`: A type that can be used as an index.

Args:

- `offset`: The offset index.

Returns: An offset pointer.

#### `Pointer.offset_from`

```mojo
def offset_from(self, other: Pointer[T, address_space=address_space]) -> Int
```

Returns the signed distance from `other` to `self` in elements of `T` (not bytes), such that `other.unsafe_offset(result)` produces a pointer equal to `self`.

Safety:

- Both pointers must point into the same allocation (or one past
  its end); the distance between pointers into unrelated
  allocations is not meaningful.
- The byte distance between the two pointers must be an exact
  multiple of `size_of[T]()`. Violating this is undefined
  behavior.

Examples:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int32](count=4))
var ptr = allocation.unsafe_ptr()
var end = ptr.unsafe_offset(3)
print(end.offset_from(ptr))  # => 3
print(ptr - end)  # => -3
dealloc(allocation^)
```

Constraints: The pointee type `T` must not be zero-sized.

Args:

- `other`: The pointer to measure the distance from.

Returns: The signed element distance from `other` to `self`.

#### `Pointer.unsafe_dangling`

```mojo
def unsafe_dangling() -> Self
```

Creates a new `Pointer` that is dangling, but well-aligned.

This is useful for initializing types which lazily allocate.

Note that the address of the returned pointer may potentially be that
of a valid pointer, which means this must not be used as a "not yet
initialized" sentinel value. Types that lazily allocate must track
initialization by some other means.

Safety:

- The returned pointer does not point to any valid storage. Reading
  from or writing through it is undefined behavior until it has been
  reassigned to point at real, live memory.

Example:

```mojo
var ptr = Pointer[Int, MutUntrackedOrigin].unsafe_dangling()
# Important: don't try to access the value of `ptr` without
# initializing it first! The pointer is not null but isn't valid either!
```

Returns: A dangling but well-aligned `Pointer`.

#### `Pointer.swap_pointees`

```mojo
def swap_pointees[U: Movable](self: Pointer[U], other: Pointer[U])
```

Swap the values at the pointers.

This function assumes that `self` and `other` _may_ overlap in memory.
If that is not the case, or when references are available, you should
use `builtin.swap` instead.

Safety:
- `self` and `other` must both point to valid, initialized instances
  of `T`.

Parameters:

- `U`: The type the pointers point to, which must be `Movable`.

Args:

- `other`: The other pointer to swap with.

#### `Pointer.unsafe_as_noalias`

```mojo
def unsafe_as_noalias(self) -> Self
```

Cast the pointer to a new pointer that is known not to locally alias any other pointer. In other words, the pointer transitively does not comptime any other memory value declared in the local function context.

This information is relayed to the optimizer. If the pointer does
locally alias another memory value, the behaviour is undefined.

Safety:

- The pointer must not locally alias any other pointer reachable in
  the current function context. The optimizer trusts this assertion
  without checking it, so reads and writes through an aliasing
  pointer become undefined behavior.

Returns: A noalias pointer.

#### `Pointer.unsafe_load`

```mojo
def unsafe_load[dtype: DType, //, width: Int = Int(1), *, alignment: Int = align_of[dtype](), volatile: Bool = False, invariant: Bool = _default_invariant[mut](), non_temporal: Bool = False](self: Pointer[Scalar[dtype], address_space=self.address_space]) -> SIMD[dtype, width]
```

Loads `width` elements from the value the pointer points to.

Use `alignment` to specify minimal known alignment in bytes; pass a
smaller value (such as 1) if loading from packed/unaligned memory. The
`volatile`/`invariant` flags control reordering and common-subexpression
elimination semantics for special cases.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int32](count=8))
var p = allocation.unsafe_ptr()
p.unsafe_store(0, SIMD[.int32, 4](1, 2, 3, 4))
var v = p.unsafe_load[width=4]()
print(v)  # => [1, 2, 3, 4]
dealloc(allocation^)
```

Safety:

- The pointer does not track how many elements it points to, so
  `self` must point to `width` contiguous, initialized elements of
  `dtype`. This is not checked — passing a `width` larger than the
  number of valid elements reads past the end of them, which is
  undefined behavior.
- The address must satisfy `alignment` bytes of alignment.

Constraints: The width and alignment must be positive integer values.

Parameters:

- `dtype`: The data type of the SIMD vector.
- `width`: The number of elements to load.
- `alignment`: The minimal alignment (bytes) of the address.
- `volatile`: Whether the operation is volatile.
- `invariant`: Whether the load is from invariant memory.
- `non_temporal`: Whether the load has no temporal locality (streaming).

Returns: The loaded SIMD vector.

```mojo
def unsafe_load[dtype: DType, //, width: Int = Int(1), *, alignment: Int = align_of[dtype](), volatile: Bool = False, invariant: Bool = _default_invariant[mut](), non_temporal: Bool = False](self: Pointer[Scalar[dtype], address_space=self.address_space], offset: Scalar) -> SIMD[dtype, width]
```

Loads the value the pointer points to with the given offset.

Safety:

- `self` offset by `offset` elements must point to `width`
  contiguous, initialized elements of `dtype`. This is not checked —
  an out-of-bounds `offset`, or a `width` larger than the number of
  valid elements, is undefined behavior.
- The resulting address must satisfy `alignment` bytes of alignment.

Constraints: The width and alignment must be positive integer values.
The offset must be an integer.

Parameters:

- `dtype`: The data type of SIMD vector elements.
- `width`: The size of the SIMD vector.
- `alignment`: The minimal alignment of the address.
- `volatile`: Whether the operation is volatile or not.
- `invariant`: Whether the memory is load invariant.
- `non_temporal`: Whether the load has no temporal locality (streaming).

Args:

- `offset`: The offset to load from.

Returns: The loaded value.

```mojo
def unsafe_load[I: Indexer, dtype: DType, //, width: Int = Int(1), *, alignment: Int = align_of[dtype](), volatile: Bool = False, invariant: Bool = _default_invariant[mut](), non_temporal: Bool = False](self: Pointer[Scalar[dtype], address_space=self.address_space], offset: I) -> SIMD[dtype, width]
```

Loads the value the pointer points to with the given offset.

Safety:

- `self` offset by `offset` elements must point to `width`
  contiguous, initialized elements of `dtype`. This is not checked —
  an out-of-bounds `offset`, or a `width` larger than the number of
  valid elements, is undefined behavior.
- The resulting address must satisfy `alignment` bytes of alignment.

Constraints: The width and alignment must be positive integer values.

Parameters:

- `I`: A type that can be used as an index.
- `dtype`: The data type of SIMD vector elements.
- `width`: The size of the SIMD vector.
- `alignment`: The minimal alignment of the address.
- `volatile`: Whether the operation is volatile or not.
- `invariant`: Whether the memory is load invariant.
- `non_temporal`: Whether the load has no temporal locality (streaming).

Args:

- `offset`: The offset to load from.

Returns: The loaded value.

#### `Pointer.unsafe_store`

```mojo
def unsafe_store[I: Indexer, dtype: DType, //, width: SIMDLength = 1, *, alignment: Int = align_of[dtype](), volatile: Bool = False, non_temporal: Bool = False](self: Pointer[Scalar[dtype], address_space=self.address_space], offset: I, val: SIMD[dtype, width])
```

Stores a single element value at the given offset.

Safety:

- `self` offset by `offset` elements must point to writable memory
  for `width` contiguous elements of `dtype`. This is not checked —
  an out-of-bounds `offset`, or a `width` larger than the number of
  valid elements, is undefined behavior.
- The resulting address must satisfy `alignment` bytes of alignment.

Constraints: The width and alignment must be positive integer values.
The offset must be integer.

Parameters:

- `I`: A type that can be used as an index.
- `dtype`: The data type of SIMD vector elements.
- `width`: The size of the SIMD vector.
- `alignment`: The minimal alignment of the address.
- `volatile`: Whether the operation is volatile or not.
- `non_temporal`: Whether the store has no temporal locality (streaming).

Args:

- `offset`: The offset to store to.
- `val`: The value to store.

```mojo
def unsafe_store[dtype: DType, offset_type: DType, //, width: Int = Int(1), *, alignment: Int = align_of[dtype](), volatile: Bool = False, non_temporal: Bool = False](self: Pointer[Scalar[dtype], address_space=self.address_space], offset: Scalar[offset_type], val: SIMD[dtype, width])
```

Stores a single element value at the given offset.

Safety:

- `self` offset by `offset` elements must point to writable memory
  for `width` contiguous elements of `dtype`. This is not checked —
  an out-of-bounds `offset`, or a `width` larger than the number of
  valid elements, is undefined behavior.
- The resulting address must satisfy `alignment` bytes of alignment.

Constraints: The width and alignment must be positive integer values.

Parameters:

- `dtype`: The data type of SIMD vector elements.
- `offset_type`: The data type of the offset value.
- `width`: The size of the SIMD vector.
- `alignment`: The minimal alignment of the address.
- `volatile`: Whether the operation is volatile or not.
- `non_temporal`: Whether the store has no temporal locality (streaming).

Args:

- `offset`: The offset to store to.
- `val`: The value to store.

```mojo
def unsafe_store[dtype: DType, //, width: SIMDLength = 1, *, alignment: Int = align_of[dtype](), volatile: Bool = False, non_temporal: Bool = False](self: Pointer[Scalar[dtype], address_space=self.address_space], val: SIMD[dtype, width])
```

Stores a single element value `val` at element offset 0.

Specify `alignment` when writing to packed/unaligned memory. Requires a
mutable pointer. For writing at an element offset, use the overloads
that accept an index or scalar offset.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Float32](count=4))
var p = allocation.unsafe_ptr()
var vec = SIMD[.float32, 4](1.0, 2.0, 3.0, 4.0)
p.unsafe_store(vec)
var out = p.unsafe_load[width=4]()
print(out)  # => [1.0, 2.0, 3.0, 4.0]
dealloc(allocation^)
```

Safety:

- `self` must point to writable memory for `width` contiguous
  elements of `dtype`. This is not checked — passing a `width`
  larger than the number of valid elements writes past the end of
  them, which is undefined behavior.
- The address must satisfy `alignment` bytes of alignment.

Constraints: The width and alignment must be positive integer values.

Parameters:

- `dtype`: The data type of SIMD vector elements.
- `width`: The number of elements to store.
- `alignment`: The minimal alignment (bytes) of the address.
- `volatile`: Whether the operation is volatile.
- `non_temporal`: Whether the store has no temporal locality (streaming).

Args:

- `val`: The SIMD value to store.

#### `Pointer.unsafe_strided_load`

```mojo
def unsafe_strided_load[dtype: DType, S: Intable, //, width: Int](self: Pointer[Scalar[dtype], address_space=self.address_space], stride: S) -> SIMD[dtype, width]
```

Performs a strided load of the SIMD vector.

Safety:

- This reads `width` elements from `self`, each `stride` elements
  apart. Every element read must be an initialized `dtype` value.
  This is not checked, so an out-of-bounds `stride` or `width` is
  undefined behavior.

Parameters:

- `dtype`: DType of returned SIMD value.
- `S`: The Intable type of the stride.
- `width`: The SIMD width.

Args:

- `stride`: The stride between loads.

Returns: A vector which is stride loaded.

#### `Pointer.unsafe_strided_store`

```mojo
def unsafe_strided_store[dtype: DType, S: Intable, //, width: SIMDLength = 1](self: Pointer[Scalar[dtype], address_space=self.address_space], val: SIMD[dtype, width], stride: S)
```

Performs a strided store of the SIMD vector.

Safety:

- This writes the `width` elements of `val` to `self`, each `stride`
  elements apart. Every location written must be writable memory
  for `dtype`. This is not checked, so an out-of-bounds `stride` or
  `width` is undefined behavior.

Parameters:

- `dtype`: DType of `val`, the SIMD value to store.
- `S`: The Intable type of the stride.
- `width`: The SIMD width.

Args:

- `val`: The SIMD value to store.
- `stride`: The stride between stores.

#### `Pointer.unsafe_gather`

```mojo
def unsafe_gather[dtype: DType, //, *, width: SIMDLength = 1, alignment: Int = align_of[dtype]()](self: Pointer[Scalar[dtype], address_space=self.address_space], offset: SIMD[width], mask: SIMD[.bool, width] = SIMD(fill=True), default: SIMD[dtype, width] = 0) -> SIMD[dtype, width]
```

Gathers a SIMD vector from offsets of the current pointer.

This method loads from memory addresses calculated by appropriately
shifting the current pointer according to the `offset` SIMD vector,
or takes from the `default` SIMD vector, depending on the values of
the `mask` SIMD vector.

If a mask element is `True`, the respective result element is given
by the current pointer and the `offset` SIMD vector; otherwise, the
result element is taken from the `default` SIMD vector.

Safety:

- This reads from `self` offset by each active lane's `offset`
  element (the lanes where `mask` is `True`). Each of those
  locations must be an initialized `dtype` element. This is not
  checked, so an out-of-bounds `offset` on an active lane is
  undefined behavior. Lanes where `mask` is `False` are never read,
  so their `offset` can be anything.
- The resulting addresses must satisfy `alignment` bytes of
  alignment.

Constraints: The offset type must be an integral type.
The alignment must be a power of two integer value.

Parameters:

- `dtype`: DType of the return SIMD.
- `width`: The SIMD width.
- `alignment`: The minimal alignment of the address.

Args:

- `offset`: The SIMD vector of offsets to gather from.
- `mask`: The SIMD vector of boolean values, indicating for each element whether to load from memory or to take from the `default` SIMD vector.
- `default`: The SIMD vector providing default values to be taken where the `mask` SIMD vector is `False`.

Returns: The SIMD vector containing the gathered values.

#### `Pointer.unsafe_scatter`

```mojo
def unsafe_scatter[dtype: DType, //, *, width: SIMDLength = 1, alignment: Int = align_of[dtype]()](self: Pointer[Scalar[dtype], address_space=self.address_space], offset: SIMD[width], val: SIMD[dtype, width], mask: SIMD[.bool, width] = SIMD(fill=True))
```

Scatters a SIMD vector into offsets of the current pointer.

This method stores at memory addresses calculated by appropriately
shifting the current pointer according to the `offset` SIMD vector,
depending on the values of the `mask` SIMD vector.

If a mask element is `True`, the respective element in the `val` SIMD
vector is stored at the memory address defined by the current pointer
and the `offset` SIMD vector; otherwise, no action is taken for that
element in `val`.

If the same offset is targeted multiple times, the values are stored
in the order they appear in the `val` SIMD vector, from the first to
the last element.

Safety:

- This writes to `self` offset by each active lane's `offset`
  element (the lanes where `mask` is `True`). Each of those
  locations must be writable memory for a `dtype` element. This is
  not checked, so an out-of-bounds `offset` on an active lane is
  undefined behavior. Lanes where `mask` is `False` are never
  written, so their `offset` can be anything.
- The resulting addresses must satisfy `alignment` bytes of
  alignment.

Constraints: The offset type must be an integral type.
The alignment must be a power of two integer value.

Parameters:

- `dtype`: DType of `value`, the result SIMD buffer.
- `width`: The SIMD width.
- `alignment`: The minimal alignment of the address.

Args:

- `offset`: The SIMD vector of offsets to scatter into.
- `val`: The SIMD vector containing the values to be scattered.
- `mask`: The SIMD vector of boolean values, indicating for each element whether to store at memory or not.

#### `Pointer.unsafe_free`

```mojo
def unsafe_free(self: Pointer[T, address_space=self.address_space])
```

Frees the memory referenced by the pointer.

#### `Pointer.unsafe_bitcast`

```mojo
def unsafe_bitcast[U: AnyType](self) -> Pointer[U, origin, address_space=address_space]
```

Bitcasts a Pointer to a different type.

Safety:

- This does not check that `U` is compatible with the pointee type
  in size, alignment, or bit layout. Reading or writing through the
  returned pointer is undefined behavior unless the memory it
  points to actually holds (or is being written as) a valid `U`.

Parameters:

- `U`: The target type.

Returns: A new Pointer object with the specified type and the same address, as the original Pointer.

#### `Pointer.mut_cast`

```mojo
def mut_cast[target_mut: Bool](self) -> Pointer[T, origin_of(origin), address_space=address_space]
```

**Deprecated:** `mut_cast` is deprecated in favor of explicitly specifying a mutability on the pointer type (`ImmPointer` or `MutPointer`). If a mutability cast is truly needed (this should almost always be avoided), use `unsafe_mut_cast` instead.

Changes the mutability of a pointer.

This is a safe way to change the mutability of a pointer with an
unbounded mutability. This function will emit a compile time error if
you try to cast an immutable pointer to mutable.

Parameters:

- `target_mut`: Mutability of the destination pointer.

Returns: A pointer with the same type, origin and address space as the original pointer, but with the newly specified mutability.

#### `Pointer.unsafe_mut_cast`

```mojo
def unsafe_mut_cast[target_mut: Bool](self) -> Pointer[T, origin_of(origin), address_space=address_space]
```

Changes the mutability of a pointer.

If you are unconditionally casting the mutability to `False`, use
`as_imm` instead.
If you are casting to mutable or a parameterized mutability, prefer
using the safe `mut_cast` method instead.

Safety:
Casting the mutability of a pointer is inherently very unsafe.
Improper usage can lead to undefined behavior. Consider restricting
types to their proper mutability at the function signature level.
For example, taking a `Pointer[T, mut=True, ...]` as an
argument over an unbound `Pointer[T, ...]` is preferred.

Parameters:

- `target_mut`: Mutability of the destination pointer.

Returns: A pointer with the same type, origin and address space as the original pointer, but with the newly specified mutability.

#### `Pointer.unsafe_origin_cast`

```mojo
def unsafe_origin_cast[target_origin: Origin[mut=mut]](self) -> Pointer[T, target_origin, address_space=address_space]
```

Changes the origin of a pointer.

If you are unconditionally casting the origin to an `UnsafeAnyOrigin`,
use `as_unsafe_any_origin` instead.

Safety:
Casting the origin of a pointer is inherently very unsafe.
Improper usage can lead to undefined behavior or unexpected variable
destruction. Considering parameterizing the origin at the function
level to avoid unnecessary casts.

Parameters:

- `target_origin`: Origin of the destination pointer.

Returns: A pointer with the same type, mutability and address space as the original pointer, but with the newly specified origin.

#### `Pointer.as_imm`

```mojo
def as_imm(self) -> Pointer[T, origin_of(origin), address_space=address_space]
```

Changes the mutability of a pointer to immutable.

Unlike `unsafe_mut_cast`, this function is always safe to use as casting
from (im)mutable to immutable is always safe.

Returns: A pointer with the mutability set to immutable.

#### `Pointer.as_unsafe_any_origin`

```mojo
def as_unsafe_any_origin(self) -> Pointer[T, SomeUnsafeAnyOrigin, address_space=address_space]
```

Casts the origin of a pointer to `UnsafeAnyOrigin`.

Safety:

It is **always** preferred to maintain a concrete origin values instead of
using `UnsafeAnyOrigin`. Casting to `UnsafeAnyOrigin` is an inherently unsafe
operation that will silently extend unrelated lifetimes and turn off
exclusivity checking.

Returns: A pointer with the origin set to `UnsafeAnyOrigin`.

#### `Pointer.unsafe_address_space_cast`

```mojo
def unsafe_address_space_cast[target_address_space: AddressSpace = address_space](self) -> Pointer[T, origin, address_space=target_address_space]
```

Casts an Pointer to a different address space.

Safety:

- This does not check that the pointer's address is actually valid
  within `target_address_space`. Dereferencing the returned pointer
  is undefined behavior unless the address is one the target
  address space can legally access (for example, casting a
  `GENERIC` host pointer to a GPU-only address space and then
  dereferencing it).

Parameters:

- `target_address_space`: The address space of the result.

Returns: A new Pointer object with the same type and the same address, as the original Pointer and the new address space.

#### `Pointer.unsafe_deinit_pointee`

```mojo
def unsafe_deinit_pointee(self) where mut and (address_space == AddressSpace.GENERIC) and conforms_to(T, Deinitable)
```

Destroys the pointed-to value.

This is equivalent to `_ = self.unsafe_take_pointee()` but doesn't
require `Movable` and is more efficient because it doesn't invoke a
move constructor.

Safety:

- This runs the pointee's deinitializer and leaves the pointee
  memory uninitialized. Subsequent reads of this pointer are
  invalid until a new valid value is written using an
  `unsafe_write()` method.
- `self` must point to a valid, initialized instance of `T`.
  Calling this on a pointer to uninitialized memory is undefined
  behavior.

#### `Pointer.unsafe_deinit_pointee_with`

```mojo
def unsafe_deinit_pointee_with(self, deinit_func: T, /) where mut and (address_space == AddressSpace.GENERIC)
```

Destroys the pointed-to value using a user-provided deinitializer function.

This can be used to destroy non-`Deinitable` values in-place
without moving.

Safety:

- This runs `deinit_func` on the pointee and leaves the pointee
  memory uninitialized. Subsequent reads of this pointer are
  invalid until a new valid value is written using an
  `unsafe_write()` method.
- `self` must point to a valid, initialized instance of
  `Self.T`. Calling this on a pointer to uninitialized memory
  is undefined behavior.

Args:

- `deinit_func`: A function that takes ownership of the pointee value for the purpose of deinitializing it.

#### `Pointer.unsafe_take_pointee`

```mojo
def unsafe_take_pointee(self) -> T where mut and (address_space == AddressSpace.GENERIC) and conforms_to(T, Movable)
```

Move the value at the pointer out, leaving it uninitialized.

This performs a _consuming_ move, ending the origin of the value stored
in this pointer memory location. Subsequent reads of this pointer are
not valid. If a new valid value is stored using `unsafe_write()`, then
reading from this pointer becomes valid again.

Safety:

- `self` must point to a valid, initialized instance of `Self.T`.
  Calling this on a pointer to uninitialized memory is undefined
  behavior.
- This moves the pointee out without running its destructor and
  leaves the pointee memory uninitialized. Subsequent reads of this
  pointer are invalid until a new valid value is written using an
  `unsafe_write()` method.

Returns: The value at the pointer.

#### `Pointer.unsafe_write`

```mojo
def unsafe_write(self, *, init_with: T) where mut and (address_space == AddressSpace.GENERIC)
```

Initializes the pointee in place using the value returned by `f`.

The value returned by `init_with` is constructed directly into the pointer's
memory location rather than being constructed elsewhere and then
moved, so `Self.T` does not need to be `Movable`.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

@fieldwise_init
struct Pinned(not Movable):
    var value: Int

var allocation = alloc(Layout[Pinned].single())
var ptr = allocation.unsafe_ptr()
ptr.unsafe_write(init_with=lambda () -> Pinned: Pinned(7))
print(ptr[].value)  # => 7
ptr.unsafe_deinit_pointee()
dealloc(allocation^)
```

Safety:

- `self` must point to writable memory for `Self.T` that does not
  currently hold a valid, live value. Writing into memory that
  already holds one overwrites it without running its destructor,
  leaking any resources it owned.

Args:

- `init_with`: A function that constructs and returns the value to emplace.

```mojo
def unsafe_write(self, var value: T, /) where mut and (address_space == AddressSpace.GENERIC) and conforms_to(T, Movable)
```

Write `value` into the pointer location, moving from `value`.

The pointer memory location is assumed to contain uninitialized data,
and consequently the current contents of this pointer are not
deinitialized before writing `value`.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[String].single())
var ptr = allocation.unsafe_ptr()
ptr.unsafe_write("foo")
print(ptr[])  # => foo
ptr.unsafe_deinit_pointee()
dealloc(allocation^)
```

If `Self.T` is trivially deinitializable (for example, `Int`), prefer
`write()` instead: it overwrites safely, since there's no
destructor that a previous value could leak.

Safety:

- `self` must point to writable memory for `Self.T` that does not
  currently hold a valid, live value. Writing into memory that
  already holds one overwrites it without running its destructor,
  leaking any resources it owned.

Args:

- `value`: The value to emplace.

```mojo
def unsafe_write(self, *, copy: T) where mut and (address_space == AddressSpace.GENERIC) and conforms_to(T, Copyable)
```

Write a copy of `copy` into the pointer location.

The pointer memory location is assumed to contain uninitialized data,
and consequently the current contents of this pointer are not deinitialized
before writing the copy.

When compared to calling the positional `unsafe_write()` overload with
a value you copied yourself, this avoids an extra move on the callee
side.

Safety:

- `self` must point to writable memory for `Self.T` that does not
  currently hold a valid, live value. Writing into memory that
  already holds one overwrites it without running its destructor,
  leaking any resources it owned.

Args:

- `copy`: The value to copy.

#### `Pointer.write`

```mojo
def write[U: Movable, //](self: Pointer[U], var value: U, /) where self.origin.mut and conforms_to(U, TrivialRegisterPassable) if conforms_to(U, TrivialRegisterPassable) else U.__del__is_trivial if conforms_to(U, Deinitable) else conforms_to(U, Deinitable)
```

Write `value` into the pointer location, moving from `value`.

Unlike `unsafe_write()`, this is safe to call even when the pointee
already holds a live value: `U` is constrained to be trivially
deinitializable, so there's no destructor to skip and overwriting
a previous value can't leak a resource.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int].single())
var ptr = allocation.unsafe_ptr()
ptr.write(41)
ptr.write(42)  # OK: overwriting is safe, `Int` has no destructor.
print(ptr[])  # => 42
dealloc(allocation^)
```

Parameters:

- `U`: The type the pointer points to, which must be `Movable` and trivially deinitializable.

Args:

- `value`: The value to emplace.

#### `Pointer.unsafe_write_move_from`

```mojo
def unsafe_write_move_from(self, src: Pointer[T]) where mut and (address_space == AddressSpace.GENERIC) and src.origin.mut and conforms_to(T, Movable)
```

Moves the value `src` points to into the memory location pointed to by `self`.

The `self` pointer memory location is assumed to contain uninitialized
data prior to this assignment, and consequently the current contents of
this pointer are not destructed before writing the value from the `src`
pointer.

Ownership of the value is logically transferred from `src` into `self`'s
pointer location.

After this call, the `src` pointee value should be treated as
uninitialized data. Subsequent reads of or destructor calls on the `src`
pointee value are invalid, unless and until a new valid value has been
written into the `src` pointer's memory location using an
`unsafe_write()` method.

This transfers the value out of `src` and into `self` using at most one
move constructor call.

Example:

```mojo
from std.memory.alloc import alloc, dealloc, Layout

var a_allocation = alloc(Layout[String].single())
var b_allocation = alloc(Layout[String].single())
var a_ptr = a_allocation.unsafe_ptr()
var b_ptr = b_allocation.unsafe_ptr()

# Initialize A pointee
a_ptr.unsafe_write("foo")

# Perform the move
b_ptr.unsafe_write_move_from(a_ptr)

# Clean up
b_ptr.unsafe_deinit_pointee()
dealloc(a_allocation^)
dealloc(b_allocation^)
```

Safety:

* `src` must point to a valid, initialized instance of `Self.T`.
* `self` must point to writable memory for `Self.T`. The pointee
  contents of `self` should be uninitialized; if `self` was previously
  written with a valid value, that value will be overwritten and its
  destructor will NOT be run.

Args:

- `src`: Source pointer that the value will be moved from.

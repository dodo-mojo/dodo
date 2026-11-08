# `std.collections.span`

Implements the `Span` type.

You can import these APIs from the `memory` module. For example:

```mojo
from std.collections import Span
```

## Aliases

### `MutSpan`

```mojo
comptime MutSpan[T: AnyType, origin: MutOrigin, *, address_space: AddressSpace = .GENERIC] = Span[T, origin, address_space=address_space]
```

A span providing mutable access to its elements.

### `ImmSpan`

```mojo
comptime ImmSpan[T: AnyType, origin: ImmOrigin, *, address_space: AddressSpace = .GENERIC] = Span[T, origin, address_space=address_space]
```

A span providing read-only access to its elements.

## Structs

### `Span`

```mojo
struct Span[mut: Bool, //, T: AnyType, origin: Origin[mut=mut], *, address_space: AddressSpace = .GENERIC]
```

A non-owning view of contiguous data.

Parameters:

- `mut`: Whether the span is mutable.
- `T`: The type of the elements in the span.
- `origin`: The origin of the Span.
- `address_space`: The address space of the data the span views.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `Hashable`, `ImplicitlyCopyable`, `Iterable`, `IterableOwned`, `Movable`, `RegisterPassable`, `Sized`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `Immutable = Span[T, origin_of(_mlir_origin), address_space=address_space]`: The immutable version of the `Span`.
- `IteratorType = _SpanIter[T(Copyable), origin]`: The iterator type for this `Span`.
- `IteratorOwnedType = _SpanIter[T(Copyable), origin]`: The owned iterator type for this `Span`.
- `device_type = Span[T, origin, address_space=address_space]`: The device-side type for this `Span`.

#### `Span.__init__`

```mojo
def __init__() -> Self
```

Create an empty / zero-length span.

```mojo
def __init__(*, unsafe_ptr: Pointer[T, origin, address_space=address_space], length: Int) -> Self
```

Unsafe construction from a pointer and length.

Args:

- `unsafe_ptr`: The underlying pointer of the span.
- `length`: The length of the view.

```mojo
def __init__(ref[origin] list: List[T]) -> Self
```

Construct a `Span` from a `List`.

Args:

- `list`: The list to which the span refers.

```mojo
def __init__(ref[origin, address_space] array: Array[T]) -> Self
```

Construct a `Span` from an `Array`.

Args:

- `array`: The array to which the span refers.

#### `Span.__bool__`

```mojo
def __bool__(self) -> Bool
```

Check if a span is non-empty.

Returns: True if a span is non-empty, False otherwise.

#### `Span.__getitem__`

```mojo
def __getitem__(self, idx: Int, /) -> ref[origin, address_space] T
```

Gets the span element at the given index.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

```mojo
def __getitem__(self, idx: T) -> ref[origin, address_space] T
```

Gets the span element at the given index.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

```mojo
def __getitem__(self, idx: IntLiteral) -> ref[origin, address_space] T
```

Gets the span element at the given index.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

```mojo
def __getitem__(self, slc: ContiguousSlice) -> Self
```

Get a new span from a slice of the current span.

Aborts if `slc`'s start or end index is out of bounds (valid range is
`0` to `len(self)`, inclusive), or if start is greater than end.
Negative indices are not supported and always abort.

Args:

- `slc`: The slice specifying the range of the new subslice.

Returns: A new span that points to the same data as the current span.

#### `Span.__eq__`

```mojo
def __eq__(self: Span[T], rhs: Span[T]) -> Bool where conforms_to(T, Equatable)
```

Verify if span is equal to another span.

Args:

- `rhs`: The span to compare against.

Returns: True if the spans are equal in length and contain the same elements, False otherwise.

#### `Span.__ne__`

```mojo
def __ne__(self: Span[T], rhs: Span[T]) -> Bool where conforms_to(T, Equatable)
```

Verify if span is not equal to another span.

Args:

- `rhs`: The span to compare against.

Returns: True if the spans are not equal in length or contents, False otherwise.

#### `Span.__contains__`

```mojo
def __contains__[dtype: DType, //](self: Span[Scalar[dtype], address_space=self.address_space], value: Scalar[dtype]) -> Bool
```

Verify if a given value is present in the Span.

Parameters:

- `dtype`: The DType of the scalars stored in the Span.

Args:

- `value`: The value to find.

Returns: True if the value is contained in the list, False otherwise.

```mojo
def __contains__(self: Span[T], value: T) -> Bool where conforms_to(T, Equatable)
```

Verify if a given value is present in the span.

Performs a linear scan over all elements comparing with `==`.

Args:

- `value`: The value to find.

Returns: True if the value is contained in the span, False otherwise.

#### `Span.get_type_name`

```mojo
def get_type_name() -> String
```

Gets this type's name, for use in error messages when handing arguments to kernels.

Returns: This type's name.

#### `Span.__iter__`

```mojo
def __iter__(var self) -> Self.IteratorOwnedType where (address_space == AddressSpace.GENERIC)
```

Consume the span and return an iterator over its elements.

Returns: An iterator over the elements of the span.

```mojo
def __iter__(ref self) -> _SpanIter[T(Copyable), origin] where (address_space == AddressSpace.GENERIC)
```

Get an iterator over the elements of the `Span`.

Returns: An iterator over the elements of the `Span`.

#### `Span.__reversed__`

```mojo
def __reversed__(self) -> _SpanIter[T(Copyable), origin, False] where (address_space == AddressSpace.GENERIC)
```

Iterate backwards over the `Span`.

Returns: A reversed iterator of the `Span` elements.

#### `Span.__len__`

```mojo
def __len__(self) -> Int
```

Returns the length of the span. This is a known constant value.

Returns: The size of the span.

#### `Span.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Writable) and (address_space == AddressSpace.GENERIC)
```

Write this span to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Span.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(T, Writable) and (address_space == AddressSpace.GENERIC)
```

Write this span to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Span.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H) where conforms_to(T, Hashable) and (address_space == AddressSpace.GENERIC)
```

Updates hasher with the hash of each element in the span.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `Span.as_imm`

```mojo
def as_imm(self) -> Self.Immutable
```

Return an immutable version of this `Span`.

Returns: An immutable version of the same `Span`.

#### `Span.unsafe_get`

```mojo
def unsafe_get(self, idx: T) -> ref[origin, address_space] T
```

Get a reference to the element at `index` without bounds checking.

Safety:
- This function does not do bounds checking and assumes the provided
index is in: [0, len(self)). Not upholding this contract will result
in undefined behavior.
- This function does not support wraparound for negative indices.

Args:

- `idx`: The index of the element to get.

Returns: A reference to the element at the specified index.

#### `Span.unsafe_ptr`

```mojo
def unsafe_ptr(self) -> Pointer[T, origin, address_space=address_space]
```

Retrieves a pointer to the underlying memory, or a dangling pointer if the span doesn't point to anything.

You should use the `len` of this `Span` to determine if the pointer
is valid for reads and writes.

Returns: The pointer to the underlying memory.

#### `Span.as_ref`

```mojo
def as_ref(self) -> Pointer[T, origin, address_space=address_space]
```

Gets a `Pointer` to the first element of this span.

Returns: A `Pointer` pointing at the first element of this span.

#### `Span.copy_from`

```mojo
def copy_from(self: Span[T], other: Span[T]) where conforms_to(T, Copyable & Deinitable)
```

Performs an element wise copy from all elements of `other` into all elements of `self`.

Args:

- `other`: The `Span` to copy all elements from.

#### `Span.fill`

```mojo
def fill(self, value: T) where mut and conforms_to(T, Copyable & Deinitable) if (address_space == AddressSpace.GENERIC) else (address_space == AddressSpace.GENERIC) or conforms_to(T, TrivialRegisterPassable)
```

Fill the memory that a span references with a given value.

Constraints: The span must be mutable. A register-passable element type works in
any address space. All other element types require the span
to view the default (generic) address space.

Args:

- `value`: The value to assign to each element.

#### `Span.unsafe_swap_elements`

```mojo
def unsafe_swap_elements(self: Span[T], a: Int, b: Int) where conforms_to(T, Movable)
```

Swap the values at indices `a` and `b` without performing bounds checking.

Safety:
- Both `a` and `b` must be in: [0, len(self)).

Args:

- `a`: The first element's index.
- `b`: The second element's index.

#### `Span.swap_elements`

```mojo
def swap_elements(self: Span[T], a: Int, b: Int) raises where conforms_to(T, Movable)
```

Swap the values at indices `a` and `b`.

Args:

- `a`: The first argument index.
- `b`: The second argument index.

Raises: If a or b are larger than the length of the span.

#### `Span.__merge_with__`

```mojo
def __merge_with__[other_type: AnyStruct[Span[T, other_type.origin, address_space=address_space]]](self) -> Span[T, origin_of(origin, other_type.origin), address_space=address_space]
```

Returns a pointer merged with the specified `other_type`.

Parameters:

- `other_type`: The type of the pointer to merge with.

Returns: A pointer merged with the specified `other_type`.

#### `Span.reverse`

```mojo
def reverse[dtype: DType, //](self: Span[Scalar[dtype]])
```

Reverse the elements of the `Span` inplace.

Parameters:

- `dtype`: The DType of the scalars the `Span` stores.

#### `Span.apply`

```mojo
def apply[dtype: DType, //](self: Span[Scalar[dtype]], func: T)
```

Apply the function to the `Span` inplace.

Parameters:

- `dtype`: The DType.

Args:

- `func`: The function to evaluate.

```mojo
def apply[dtype: DType, //](self: Span[Scalar[dtype]], func: T, *, cond: T)
```

Apply the function to the `Span` inplace where the condition is `True`.

Parameters:

- `dtype`: The DType.

Args:

- `func`: The function to evaluate.
- `cond`: The condition to apply the function.

#### `Span.count`

```mojo
def count[dtype: DType, //, F: def[w: SIMDLength](v: SIMD[dtype, w]) -> SIMD[.bool, w]](self: Span[Scalar[dtype], address_space=self.address_space], func: F) -> Int
```

Count the amount of times the function returns `True`.

Parameters:

- `dtype`: The DType.
- `F`: The function type to evaluate.

Args:

- `func`: The function value to evaluate.

Returns: The amount of times the function returns `True`.

#### `Span.unsafe_subspan`

```mojo
def unsafe_subspan(self, *, offset: Int, length: Int) -> Self
```

Returns a subspan of the current span.

Safety:
This function does not do bounds checking and assumes the current
span contains the specified subspan.

Args:

- `offset`: The starting offset of the subspan (self._data + offset).
- `length`: The length of the new subspan.

Returns: A new span representing the specified subspan.

#### `Span.binary_search_by`

```mojo
def binary_search_by[func: def(T) thin -> Int](self: Span[T]) -> Optional[Int]
```

Finds an element using binary search with a custom comparison function.

The comparison function should return:
- A negative value if the element is less than the target
- Zero if the element matches the target
- A positive value if the element is greater than the target

Notes:
This function assumes that `self` is sorted according to the ordering
defined by `func`. If not sorted, the result is unspecified.

Example:
```mojo
var data: List[String] = ["a", "bb", "ccc"]
var span = Span(data)

# Search for "bb"
def cmp(elem: String) -> Int:
    if elem < "bb":
        return -1
    elif elem > "bb":
        return 1
    else:
        return 0

var index = span.binary_search_by[cmp]()
if case .Some(i) = index:
    print("Found at index: ", i)
else:
    print("Not found")
```

Parameters:

- `func`: A function that takes an element and returns an Int representing the comparison result.

Returns: Returns the index of the matching element if found, None otherwise.

```mojo
def binary_search_by[FuncType: def(T) -> Int](self: Span[T], func: FuncType) -> Optional[Int]
```

Finds an element using binary search with a custom comparison function.

The comparison function should return:
- A negative value if the element is less than the target
- Zero if the element matches the target
- A positive value if the element is greater than the target

Notes:
This function assumes that `self` is sorted according to the ordering
defined by `func`. If not sorted, the result is unspecified.

Example:
```mojo
def main():
    var data: List[String] = ["a", "bb", "ccc"]
    var span = Span(data)

    # Search for "bb"
    def cmp(elem: String) {} -> Int:
        if elem < "bb":
            return -1
        elif elem > "bb":
            return 1
        else:
            return 0

    var index = span.binary_search_by(cmp)
    if case .Some(i) = index:
        print("Found at index: ", i)
    else:
        print("Not found")
```

Parameters:

- `FuncType`: The type of the supplied function.

Args:

- `func`: A function that takes an element and returns an Int representing the comparison result.

Returns: Returns the index of the matching element if found, None otherwise.

#### `Span.unsafe_deinit_elements`

```mojo
def unsafe_deinit_elements[U: Deinitable](self: Span[U])
```

Destroys every element, leaving the memory uninitialized.

Each element's deinitializer runs in place, in index order, so the
storage behind the span can be reused or released without moving
anything out of it.

Safety:

- Every element must hold a live `U`. Deinitializing an element that
  was never initialized, or that was already deinitialized, is
  undefined behavior.
- The elements are left uninitialized. Reading them, or deinitializing
  them a second time, is undefined behavior.

Parameters:

- `U`: The span's element type.

#### `Span.unsafe_deinit_elements_with`

```mojo
def unsafe_deinit_elements_with[U: AnyType](self: Span[U], f: T, /)
```

Destroys every element by passing it to `f`, leaving the memory uninitialized.

This is the `Deinitable`-free counterpart to `unsafe_deinit_elements`:
each element is handed to `f` as an owned value, in index order, so a
span of elements that have no destructor of their own can still be
torn down. `U` is unconstrained, so this works for element types that
are neither `Deinitable` nor `Movable`.

Safety:

- Every element must hold a live `U`. Deinitializing an element that
  was never initialized, or that was already deinitialized, is
  undefined behavior.
- The elements are left uninitialized. Reading them, or deinitializing
  them a second time, is undefined behavior.

Parameters:

- `U`: The span's element type.

Args:

- `f`: The function that consumes, and is responsible for disposing of, each element.

#### `Span.unsafe_assume_init`

```mojo
def unsafe_assume_init[U: AnyType](self: Span[MaybeUninit[U]]) -> Span[U, self.origin]
```

Reinterprets this span as a span of initialized `U` elements.

Safety:

- Every element must hold a live `U`. Reading an element that was never
  initialized is undefined behavior.

Examples:

```mojo
var storage = Array[MaybeUninit[Int], 3]()
var uninit = Span(storage)
for i in range(len(uninit)):
    uninit[i].write(i + 1)

# SAFETY: the loop above wrote every element.
print(uninit.unsafe_assume_init()) # [1, 2, 3]
```

Parameters:

- `U`: The type held by this span's `MaybeUninit` elements.

Returns: A span of the same length over the same memory, typed as `U`.

#### `Span.unsafe_init_with`

```mojo
def unsafe_init_with[U: AnyType](self: Span[MaybeUninit[U]], f: T, /) -> Span[U, self.origin]
```

Initializes every element with the result of `f(i)`.

Safety:

- Writing over an element does not destroy what it held, so an
  element already holding a live `U` leaks whatever that `U` owns.
  Deinitialize those first.

Examples:

```mojo
var storage = Array[MaybeUninit[Int], 5]()
var squares = Span(storage).unsafe_init_with(
    lambda (i: Int) -> Int: i * i
)
print(squares) # [0, 1, 4, 9, 16]
```

Parameters:

- `U`: The type held by this span's `MaybeUninit` elements.

Args:

- `f`: A function called with each index in `[0, len(self))`, whose result is written to that position.

Returns: A span over the newly initialized elements, covering all of `self`.

#### `Span.unsafe_init_copy_from`

```mojo
def unsafe_init_copy_from[U: Copyable](self: Span[MaybeUninit[U]], copy_from: Span[U], /) -> Span[U, self.origin]
```

Initializes every element with a copy of the matching `copy_from` element.

Aborts if `copy_from` is not the same length as `self`.

Safety:

- Writing over an element does not destroy what it held, so an
  element already holding a live `U` leaks whatever that `U` owns.
  Deinitialize those first.

Examples:

```mojo
var source: Array[Int, 3] = [1, 2, 3]
var storage = Array[MaybeUninit[Int], 3]()
var copied = Span(storage).unsafe_init_copy_from(source)
print(copied) # [1, 2, 3]
```

Parameters:

- `U`: The type held by this span's `MaybeUninit` elements.

Args:

- `copy_from`: The elements to copy, of the same length as `self`.

Returns: A span over the newly initialized elements, covering all of `self`.

#### `Span.unsafe_init_move_from`

```mojo
def unsafe_init_move_from[U: Movable](self: Span[MaybeUninit[U]], move_from: Span[U], /) -> Span[U, self.origin]
```

Initializes every element by moving out of the matching `move_from` element.

Aborts if `move_from` is not the same length as `self`.

Safety:

- Writing over an element does not destroy what it held, so an
  element already holding a live `U` leaks whatever that `U` owns.
  Deinitialize those first.
- Every element of `move_from` is left uninitialized. Reading them, or
  letting their owner destroy them, is undefined behavior.

Examples:

```mojo
var source: Array[String, 2] = ["a", "b"]
var storage = Array[MaybeUninit[String], 2]()
var moved = Span(storage).unsafe_init_move_from(source)
print(moved) # ["a", "b"]
# `source` now holds two uninitialized elements.
```

Parameters:

- `U`: The type held by this span's `MaybeUninit` elements.

Args:

- `move_from`: The elements to move out of, of the same length as `self`.

Returns: A span over the newly initialized elements, covering all of `self`.

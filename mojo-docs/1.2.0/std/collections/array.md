# `std.collections.array`

Provides a fixed-size array implementation with compile-time size checking.

The `Array` type represents a fixed-size sequence of homogeneous elements
where the size is determined at compile time. It provides efficient memory
layout and bounds checking while maintaining type safety.  The `Array`
type is part of the `prelude` module and therefore does not need to be imported
in order to use it.

Examples:

```mojo
# Create an array of 3 integers
var arr = [1, 2, 3]

# Access elements
print(arr[0])  # Prints 1

# Fill with a value
var filled = Array[Int, 5](fill=42)
```

## Structs

### `Array`

```mojo
struct Array[T: AnyType, length: Int]
```

A fixed-size sequence of homogeneous elements where size is a constant expression.

Array provides a fixed-size array implementation with compile-time
size checking. The array size is determined at compile time and cannot be
changed.

Examples:

```mojo
# Create array of 3 integers
var arr = [1, 2, 3]

# Create array filled with value
var filled = Array[Int, 5](fill=42)

# Create array of defaulted elements
var defaulted = Array[Int, 5]()  # [0, 0, 0, 0, 0]

# Access elements
print(arr[0])  # Prints 1
```

Notes:
When the element type is `Comparable`, `Array` is too and orders
**lexicographically**: elements compare pairwise and the first differing
pair decides the result.

Parameters:

- `T`: The type of the elements in the array. May be any type (`AnyType`). Move construction (including list-literal construction) requires `Movable`; copy and `fill=` construction and iteration additionally require `Copyable`; these are enforced via conditional `where` clauses.
- `length`: The number of elements in the array. Must be a positive integer constant.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `Equatable`, `Hashable`, `Iterable`, `IterableOwned`, `Movable`, `Sized`, `Writable`

Aliases:

- `type = __mlir_type.`!pop.array<to_builtin(:scalar<index> #lit.struct.extract<:!lit.struct<@std::@simd::@SIMD<:!lit.struct<@std::@builtin::@dtype::@DType> {:dtype index}, :!lit.struct<@std::@builtin::@simd_length::@SIMDLength> {1}>> length, "_mlir_value">), :trait<@std::@traits::@anytype::@AnyType> T>``: The underlying MLIR array type.
- `device_type = Array[T(DevicePassable).device_type(Movable) if conforms_to(T, DevicePassable) else T, length]`: The device-side type for this array.
- `IteratorType = _ArrayIter[T(Copyable), length, iterable_origin]`: The iterator type for this array.
- `IteratorOwnedType = _ArrayIterOwned[T(Deinitable & Movable), length]`: The owned iterator type for this array.

#### `Array.__init__`

```mojo
def __init__(out self, *, uninitialized: Bool)
```

Create an Array with uninitialized memory.

Examples:

```mojo
var uninitialized_array = Array[Int, 10](uninitialized=True)
```

Notes:
This constructor is unsafe and should be used with caution. The
array elements will be uninitialized and accessing them before
initialization is undefined behavior.

Args:

- `uninitialized`: A boolean to indicate if the array should be initialized. Always set to `True` (it's not actually used inside the constructor).

```mojo
def __init__(out self, *, var unsafe_assume_initialized: Array[MaybeUninit[T], length]) where conforms_to(T, Movable)
```

Constructs an `Array` from an `Array` of `MaybeUninit`.

Warning:
This is an unsafe constructor. Only use it if you are certain all
elements are properly initialized.

Notes:
This constructor assumes all elements in the input array are
initialized. Using uninitialized elements results in undefined
behavior, even for types that are valid for any bit pattern
(e.g. `Int` or `Float`).

Args:

- `unsafe_assume_initialized`: The array of `MaybeUninit` elements. All elements must be initialized.

```mojo
def __init__(out self) where conforms_to(T, Defaultable)
```

Constructs an array with each element set to its default value.

Examples:

```mojo
var arr = Array[Int, 5]()  # [0, 0, 0, 0, 0]
```

```mojo
def __init__(out self, *, fill: T) where conforms_to(T, Copyable)
```

Constructs an array where each element is initialized to the supplied value.

Examples:

```mojo
var filled = Array[Int, 5](fill=42)  # [42, 42, 42, 42, 42]
```

Args:

- `fill`: The element value to fill each index with.

```mojo
def __init__(out self, *, fill_with_unrolled: T)
```

Constructs an array by calling `fill_with_unrolled[i]()` for each index `i`.

Usually prefer the `fill_with` initializer. `fill_with_unrolled` unrolls
the entire initialization loop, which on a large array hurts compile
time and doesn't always lead to the best runtime performance.

Examples:

```mojo
var simd = SIMD[.uint32, 4](10, 20, 30, 40)
var extracted = Array[UInt32, 4](
    fill_with_unrolled=lambda[i: Int]() -> UInt32: simd[i]
)
# [10, 20, 30, 40]
```

Args:

- `fill_with_unrolled`: A function parameterized on each index in `[0, length)`, whose result is written to that position.

```mojo
def __init__(out self, *, fill_with: T)
```

Constructs an array by calling `fill_with(i)` for each index `i`.

Examples:

```mojo
var squares = Array[Int, 5](fill_with=lambda (i: Int) -> Int: i * i)
# [0, 1, 4, 9, 16]
```

Args:

- `fill_with`: A function called with each index in `[0, length)`, whose result is written to that position.

```mojo
def __init__[*, __literal_size__: Int](out self: Array[T, __literal_size__], var *elems: T, *, __list_literal__: NoneType) where conforms_to(T, Movable)
```

Constructs an array from a variadic list of elements.

Examples:

```mojo
var arr = [1, 2, 3]
```

Parameters:

- `__literal_size__`: Infer the literal size from the list-literal.

Args:

- `*elems`: The elements to initialize the array with. Must match the array size.
- `__list_literal__`: Tell Mojo to use this method for list literals.

```mojo
def __init__(out self, *, copy: Self) where conforms_to(T, Copyable)
```

Copy constructs the array from another array.

Examples:

```mojo
var arr = [1, 2, 3]
var copy = arr.copy()  # Creates new array [1, 2, 3]
```

Args:

- `copy`: The array to copy from.

```mojo
def __init__(out self, *, deinit move: Self) where conforms_to(T, Movable)
```

Move constructs the array from another array.

Notes:
Moves the elements from the source array into this array.

Args:

- `move`: The array to move from.

#### `Array.__deinit__`

```mojo
def __deinit__(deinit self) where conforms_to(T, Deinitable)
```

Destroys the array's elements.

#### `Array.__getitem__`

```mojo
def __getitem__(ref self, idx: Int, /) -> ref[length] T
```

Gets a reference to the element at the given index.

Notes:
This method provides array-style indexing access to elements in the
Array. The index is bounds-checked at runtime.

Args:

- `idx`: The index to access (0 to len-1).

Returns: A reference to the element at the specified index.

```mojo
def __getitem__(ref self, idx: T) -> ref[length] T
```

Gets a reference to the element at the given index.

Examples:

```mojo
var arr = [1, 2, 3]
print(arr[0])            # Prints 1 - first element
print(arr[1])            # Prints 2 - second element
print(arr[len(arr) - 1]) # Prints 3 - last element
```

Notes:
This method provides array-style indexing access to elements in the
Array. The index is bounds-checked at runtime.

Args:

- `idx`: The index to access (0 to len-1).

Returns: A reference to the element at the specified index.

```mojo
def __getitem__(ref self, slc: ContiguousSlice, /) -> Span[T, origin_of(self)]
```

Gets a span over the elements at the specified slice positions.

Aborts if `slc`'s start or end index is out of bounds (valid range is
`0` to `len(self)`, inclusive).

Examples:

```mojo
var arr = [1, 2, 3, 4]
var middle = arr[1:3]
print(middle[0], middle[1])  # Prints 2 3
```

Args:

- `slc`: The slice specifying the range of elements.

Returns: A span over the specified slice of the array.

#### `Array.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool where conforms_to(T, Comparable)
```

Compares two arrays lexicographically for less-than ordering.

Args:

- `other`: The other array to compare against.

Returns: True if `self` sorts before `other` lexicographically, comparing elements pairwise so the first differing pair decides the result.

#### `Array.__le__`

```mojo
def __le__(self, other: Self) -> Bool where conforms_to(T, Comparable)
```

Compares two arrays lexicographically for less-than-or-equal ordering.

Args:

- `other`: The other array to compare against.

Returns: True if `self` sorts before or equal to `other` lexicographically.

#### `Array.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where conforms_to(T, Equatable)
```

Compares two arrays for equality.

Args:

- `other`: The other array to compare against.

Returns: True if all elements are equal, False otherwise.

#### `Array.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool where conforms_to(T, Equatable)
```

Compares two arrays for inequality.

Args:

- `other`: The other array to compare against.

Returns: True if any elements are not equal, False otherwise.

#### `Array.__gt__`

```mojo
def __gt__(self, other: Self) -> Bool where conforms_to(T, Comparable)
```

Compares two arrays lexicographically for greater-than ordering.

Args:

- `other`: The other array to compare against.

Returns: True if `self` sorts after `other` lexicographically, comparing elements pairwise so the first differing pair decides the result.

#### `Array.__ge__`

```mojo
def __ge__(self, other: Self) -> Bool where conforms_to(T, Comparable)
```

Compares two arrays lexicographically for greater-than-or-equal ordering.

Args:

- `other`: The other array to compare against.

Returns: True if `self` sorts after or equal to `other` lexicographically.

#### `Array.__contains__`

```mojo
def __contains__(self, value: T) -> Bool where conforms_to(T, Equatable)
```

Tests if a value is present in the array using the `in` operator.

Examples:

```mojo
var arr = [1, 2, 3]
print(3 in arr)  # Prints True - value exists
print(4 in arr)  # Prints False - value not found
```

Notes:
This method enables using the `in` operator to check if a value
exists in the array. It performs a linear search comparing each
element for equality with the given value. The element type must
implement the `Equatable` trait to support equality comparison.

Args:

- `value`: The value to search for.

Returns: True if the value is found in any position in the array, False otherwise.

#### `Array.get_type_name`

```mojo
def get_type_name() -> String
```

Gets the name of the host type (the one implementing this trait).

Returns: The host type's name.

#### `Array.deinit_with`

```mojo
def deinit_with(deinit self, deinit_func: T, /)
```

Consumes this array and deinitializes its elements using the provided closure.

This can be used to deinitialize an `Array` of
non-`Deinitable` values.

Args:

- `deinit_func`: The deinitializing closure called on each array element.

#### `Array.__getitem_param__`

```mojo
def __getitem_param__[idx: Int, /](ref self) -> ref[idx] T
```

Gets a reference to the element at the given index with compile-time bounds checking.

Examples:

```mojo
var arr = [1, 2, 3]
print(arr[0])            # Prints 1 - first element
print(arr[1])            # Prints 2 - second element
print(arr[len(arr) - 1]) # Prints 3 - last element
```

Notes:
This overload provides array-style indexing with compile-time bounds
checking. The index must be a compile-time constant value.

Parameters:

- `idx`: The compile-time constant index to access (0 to len-1).

Returns: A reference to the element at the specified index.

```mojo
def __getitem_param__[idx: T](ref self) -> ref[idx] T
```

Gets a reference to the element at the given index with compile-time bounds checking.

Examples:

```mojo
var arr = [1, 2, 3]
print(arr[0])            # Prints 1 - first element
print(arr[1])            # Prints 2 - second element
print(arr[len(arr) - 1]) # Prints 3 - last element
```

Notes:
This overload provides array-style indexing with compile-time bounds
checking. The index must be a compile-time constant value.

Parameters:

- `idx`: The compile-time constant index to access (0 to len-1).

Returns: A reference to the element at the specified index.

#### `Array.concat`

```mojo
def concat(deinit self, deinit rhs: Array[T], out result: Array[T, (length + rhs.length)]) where conforms_to(T, Movable)
```

Concatenates this array with another array.

Both arrays are consumed and their elements are moved into the
result.

Examples:

```mojo
var a = [1, 2]
var b = [3, 4, 5]
var c = a^.concat(b^)  # [1, 2, 3, 4, 5]
```

Args:

- `rhs`: The array whose elements follow this array's elements in the result.

Returns: An array of length `Self.length + rhs.length` containing the elements of `self` followed by the elements of `rhs`.

#### `Array.__len__`

```mojo
def __len__(self) -> Int
```

Returns the length of the array.

Examples:

```mojo
var arr = [1, 2, 3]
print(len(arr))  # Prints 3
```

Notes:
The length is a compile-time constant value determined by the
`length` parameter used when creating the array.

Returns: The size of the array as an Int.

#### `Array.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H) where conforms_to(T, Hashable)
```

Hashes the elements of the array using the given hasher.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `Array.unsafe_get`

```mojo
def unsafe_get(ref self, idx: T) -> ref[length] T
```

Gets a reference to an element without bounds checking.

Examples:

```mojo
var arr = [1, 2, 3]
print(arr.unsafe_get(0))  # Prints 1
```

Warning:
This is an unsafe method. No bounds checking is performed.
Using an invalid index will cause undefined behavior.
Negative indices are not supported.

Notes:
This is an unsafe method that skips bounds checking for performance.
Users should prefer `__getitem__` instead for safety.

Args:

- `idx`: The index of the element to get. Must be non-negative and in bounds. Using an invalid index will cause undefined behavior.

Returns: A reference to the element at the given index.

#### `Array.unsafe_ptr`

```mojo
def unsafe_ptr[origin: Origin[mut=origin.mut], address_space: AddressSpace, //](ref[length, origin_of(origin)] self) -> Pointer[T, origin, address_space=address_space]
```

Gets an unsafe pointer to the underlying array storage.

Examples:

```mojo
var arr = [1, 2, 3]
var ptr = arr.unsafe_ptr()
print(ptr[0])  # Prints 1
```

Warning:
This is an unsafe method. The returned pointer:
- Becomes invalid if the array is moved
- Must not be used to access memory outside array bounds
- Must be refreshed after any operation that could move the array

Notes:
Returns a raw pointer to the array's memory that can be used for
direct memory access. The pointer inherits mutability from the array
reference.

Parameters:

- `origin`: The origin of the reference to self.
- `address_space`: The address space of the array.

Returns: A `Pointer` to the underlying array storage. The pointer's mutability matches that of the array reference.

#### `Array.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Writable)
```

Writes the Array representation to a Writer.

Args:

- `writer`: The object to write to.

#### `Array.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(T, Writable)
```

Writes the repr representation of this Array to a Writer.

Args:

- `writer`: The object to write to.

#### `Array.__iter__`

```mojo
def __iter__(var self) -> _ArrayIterOwned[T(Deinitable & Movable), length] where conforms_to(T, Deinitable & Movable)
```

Consume the array and return an iterator over its elements.

Returns: An iterator that owns the array's elements.

```mojo
def __iter__(ref self) -> _ArrayIter[T(Copyable), length, origin_of(self)]
```

Iterate over elements of the array, returning immutable references.

Returns: An iterator of immutable references to the array elements.

#### `Array.__reversed__`

```mojo
def __reversed__(ref self) -> _ArrayIter[T(Copyable), length, origin_of(self), False] where conforms_to(T, Copyable)
```

Iterate over elements of the array in reverse order, returning immutable references.

Returns: An iterator of immutable references to the array elements in reverse order.

#### `Array.repeat`

```mojo
def repeat[n: Int](deinit self, out result: Array[T, (length * n)]) where conforms_to(T, Copyable) and (n > Int(0))
```

Repeats this array's elements the given number of times.

Examples:

```mojo
var a = [1, 2].repeat[3]()  # Array[Int, 6](1, 2, 1, 2, 1, 2)
```

Parameters:

- `n`: The number of repetitions. Must be greater than 0.

Returns: An array of length `Self.length * rhs` containing the elements of `self` repeated `rhs` times.

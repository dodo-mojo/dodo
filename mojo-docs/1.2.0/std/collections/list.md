# `std.collections.list`

Defines the List type.

These APIs are imported automatically, just like builtins.

## Structs

### `List`

```mojo
struct List[T: AnyType, /]
```

A dynamically-allocated and resizable list.

This is Mojo's primary dynamic array implementation, meaning the list can
grow and shrink in size at runtime. However, all elements in a `List` must
be the same type `T`, determined at compile time.

You can create a `List` in several ways:

```mojo
# Empty list
var empty_list = List[Int]()

# With pre-allocated capacity
var preallocated = List[String](capacity=100)

# With initial size and fill value
var filled = List[Float64](length=10, fill=0.0)

# With initial values and inferred type (Int).
# The `List` annotation is needed otherwise this creates a fixed-size `Array`.
var numbers: List = [1, 2, 3, 4, 5]
```

Be aware of the following characteristics:

- **Type safety**: All elements must be the same type `T`, determined at
  compile time. This is more restrictive than Python's lists but it
  improves performance:

  ```mojo
  var int_list: List = [1, 2, 3]        # List[Int]
  var str_list: List = ["a", "b", "c"]  # List[String]
  # var mixed: List = [1, "hello"]      # Error! All elements must be same type
  ```

  However, you can get around this by defining your list type as
  [`Variant`](../../std/utils/variant.md#variant). This is a discriminated
  union type, meaning it can store any number of different types that can
  vary at runtime.

- **Value semantics:** A `List` is value semantic by default, so
  assignment creates a deep copy of all elements:

  ```mojo
  var list1: List = [1, 2, 3]
  var list2 = list1.copy()        # Deep copy
  list2.append(4)
  print(list1)   # => [1, 2, 3]
  print(list2)   # => [1, 2, 3, 4]
  ```

  This is different from Python, where assignment creates a reference to
  the same list. For more information, read about [value
  semantics](../../manual/values/value-semantics.md).

- **Reference iteration uses immutable references**: When iterating a list
  by reference, you get immutable references to the actual elements, unless
  you specify `ref`:

  ```mojo
  var numbers: List = [10, 20, 30]

  # Default behavior creates immutable (read-only) references:
  # for num in numbers:
  #     num += 1  # error: expression must be mutable

  # Using `ref` gets mutable (read-write) references
  for ref num in numbers:
      num += 1  # Modifies the original elements
  print(numbers)  # => [11, 21, 31]
  ```

- **Owned iteration consumes the list**: Using the transfer sigil (`^`)
  moves the list into the loop, yielding each element by value. The
  original list is no longer accessible after the loop:

  ```mojo
  var names: List = ["alice", "bob"]
  for x in names^:
      # `x` is an owned `String` value.
      print(x)
  # `names` is consumed and can no longer be used here
  ```

- **Out of bounds access**: Accessing elements with invalid indices will
  abort:

  ```mojo
  var my_list: List = [1, 2, 3]
  print(my_list[5])  # Aborts with an Assert Error: index 5 is
                     # out of bounds, valid range is 0 to 2
  ```

  For safe access, you should manually check bounds or use methods that
  handle errors gracefully:

  ```mojo
  var my_list: List = [1, 2, 3]
  if 5 < len(my_list):
      print(my_list[5])  # Safe: check bounds first
  else:
      print("Index out of bounds")

  # Some methods like index() raise exceptions
  try:
      var idx = my_list.index(99)  # Raises ValueError if not found
      print("Found at index:", idx)
  except:
      print("Value not found in list")
  ```

Examples:

```mojo
var my_list: List = [10, 20, 30]

# Add elements
my_list.append(40)           # [10, 20, 30, 40]
my_list.insert(1, 15)        # [10, 15, 20, 30, 40]
my_list.extend([50, 60])     # [10, 15, 20, 30, 40, 50, 60]

# Access elements
print(my_list[0])                # 10 (first element)
print(my_list[len(my_list) - 1]) # 60 (last element)
my_list[1] = 25                  # Modify element: [10, 25, 20, 30, 40, 50, 60]

# Remove elements
print(my_list.pop())      # Removes and returns last element (60)
print(my_list.pop(2))     # Removes element at index 2 (20)

# List properties
print('len:', len(my_list))          # Current number of elements
print('cap:', my_list.capacity())    # Current allocated capacity

# Multiply a list
var pair: List = [1, 2]
var repeated = pair * 3
print(repeated)    # [1, 2, 1, 2, 1, 2]

# Iterate over a list:
var fruits: List = ["apple", "banana", "orange"]

# Iterate by reference (immutable)
for fruit in fruits:
    print(fruit)

# Iterate backwards by reference
for fruit in reversed(fruits):
    print(fruit)

# Iterate by index
for i in range(len(fruits)):
    print(i, fruits[i])

# Iterate by ownership (consumes the list)
var temps: List = ["a", "b", "c"]
for x in temps^:
    print(x)
# `temps` is no longer accessible here

# Concatenate with + and +=
fruits += ["mango"]
var more_fruits = fruits + ["grape", "kiwi"]
print(more_fruits)
```

Parameters:

- `T`: The type of elements stored in the list.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Equatable`, `Hashable`, `Iterable`, `IterableOwned`, `Movable`, `Sized`, `Writable`

Aliases:

- `IteratorType = _ListIter[T(Copyable), iterable_origin]`: The iterator type for this list.
- `IteratorOwnedType = _ListIterOwned[T(Deinitable & Movable)]`: The owned iterator type for this list.

#### `List.__init__`

```mojo
def __init__(out self)
```

Constructs an empty list.

```mojo
def __init__(out self, *, capacity: Int)
```

Constructs a list with the given capacity.

Args:

- `capacity`: The requested capacity of the list.

```mojo
def __init__(out self, *, length: Int, fill: T) where conforms_to(T, Copyable)
```

Constructs a list with the given length.

Args:

- `length`: The requested length of the list.
- `fill`: The element to fill each element of the list.

```mojo
def __init__(out self, *, length: Int, fill_with: T)
```

Constructs a list by calling `fill_with(i)` for each index `i`.

Examples:

```mojo
var squares = List(length=5, fill_with=lambda (i: Int) -> Int: i * i)
# [0, 1, 4, 9, 16]
```

Args:

- `length`: The requested length of the list.
- `fill_with`: A function called with each index in `[0, length)`, whose result is written to that position.

```mojo
def __init__(out self, var *values: T, *, __list_literal__: NoneType) where conforms_to(T, Movable)
```

Constructs a list from the given values.

Args:

- `*values`: The values to populate the list with.
- `__list_literal__`: Tell Mojo to use this method for list literals.

```mojo
def __init__[IterableType: Iterable](out self: List[IterableType.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)].Element], ref iterable: IterableType) where conforms_to(IterableType.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)].Element, Copyable)
```

Constructs a list from an iterable of values.

Parameters:

- `IterableType`: The type of the `iterable` argument.

Args:

- `iterable`: The iterable of values to populate the list with.

```mojo
def __init__(out self, *, unsafe_uninit_length: Int)
```

Construct a list with the specified length, with uninitialized memory. This is unsafe, as it relies on the caller initializing the elements with unsafe operations, not assigning over the uninitialized data.

Args:

- `unsafe_uninit_length`: The number of elements to allocate.

```mojo
def __init__(out self, *, copy: Self) where conforms_to(T, Copyable)
```

Creates a deep copy of the given list.

Args:

- `copy`: The list to copy.

#### `List.__deinit__`

```mojo
def __deinit__(deinit self) where conforms_to(T, Deinitable)
```

Destroy all elements in the list and free its memory.

#### `List.__bool__`

```mojo
def __bool__(self) -> Bool
```

Checks whether the list has any elements or not.

Returns: `False` if the list is empty, `True` if there is at least one element.

#### `List.__getitem__`

```mojo
def __getitem__(self, slice: StridedSlice) -> Self where conforms_to(T, Copyable)
```

Gets the sequence of elements at the specified positions.

Args:

- `slice`: A slice that specifies positions of the new list.

Returns: A new list containing the list at the specified slice.

```mojo
def __getitem__(ref self, slice: ContiguousSlice) -> Span[T, origin_of(self["element"])]
```

Gets the sequence of elements at the specified positions.

Aborts if `slice`'s start or end index is out of bounds (valid range
is `0` to `len(self)`, inclusive), or if start is greater than end.
Negative indices are not supported and always abort.

Args:

- `slice`: A slice the specifies the positions of the new list.

Returns: A span over the specified slice.

```mojo
def __getitem__(ref self, idx: IntLiteral, /) -> ref[self_is_mut["element"]] T
```

Gets the list element at the given index.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

```mojo
def __getitem__(ref self, idx: Int, /) -> ref[self_is_mut["element"]] T
```

Gets the list element at the given index.

Unlike when subscripting using slices negative indices are
considered out of bounds. They will be checked in the same situations
as "off the end" indexing.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

```mojo
def __getitem__(ref self, idx: T) -> ref[self_is_mut["element"]] T
```

Gets the list element at the given index.

Unlike when subscripting using slices negative indices are
considered out of bounds. They will be checked in the same situations
as "off the end" indexing.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

#### `List.__eq__`

```mojo
def __eq__(self, other: Self, /) -> Bool where conforms_to(T, Equatable)
```

Checks if two lists are equal.

Examples:

```mojo
var x = [1, 2, 3]
var y = [1, 2, 3]
print("x and y are equal" if x == y else "x and y are not equal")
```

Args:

- `other`: The list to compare with.

Returns: True if the lists are equal, False otherwise.

#### `List.__contains__`

```mojo
def __contains__(self, value: T, /) -> Bool where conforms_to(T, Equatable)
```

Verify if a given value is present in the list.

Examples:

```mojo
var x = [1, 2, 3]
print("x contains 3" if 3 in x else "x does not contain 3")
```

Args:

- `value`: The value to find.

Returns: True if the value is contained in the list, False otherwise.

#### `List.__add__`

```mojo
def __add__(self, var other: Self) -> Self where conforms_to(T, Copyable)
```

Concatenates self with other and returns the result as a new list.

Args:

- `other`: List whose elements will be combined with the elements of self.

Returns: The newly created list.

#### `List.__mul__`

```mojo
def __mul__(self, x: Int) -> Self where conforms_to(T, Copyable & Deinitable)
```

Multiplies the list by x and returns a new list.

Args:

- `x`: The multiplier number.

Returns: The new list.

#### `List.__iadd__`

```mojo
def __iadd__(mut self, var other: Self, /) where conforms_to(T, Copyable)
```

Appends the elements of other into self.

Args:

- `other`: List whose elements will be appended to self.

#### `List.__imul__`

```mojo
def __imul__(mut self, x: Int) where conforms_to(T, Copyable & Deinitable) and Bool(conforms_to(T, Deinitable) and conforms_to(T, Copyable))
```

Appends the original elements of this list x-1 times or clears it if x is <= 0.

```mojo
var a: List = [1, 2]
a *= 2 # a = [1, 2, 1, 2]
```

Args:

- `x`: The multiplier number.

#### `List.deinit_with`

```mojo
def deinit_with(deinit self, deinit_func: T, /)
```

Consumes this list and deinitializes its values using the provided closure.

This can be used to destroy a `List` of non-`Deinitable` values.

Args:

- `deinit_func`: The deinitializing closure called on each `List` element.

#### `List.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H) where conforms_to(T, Hashable)
```

Updates hasher with the hash of each element in the list.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `List.__iter__`

```mojo
def __iter__(var self) -> _ListIterOwned[T(Deinitable & Movable)] where conforms_to(T, Deinitable & Movable)
```

Consume `self`, returning an owned iterator over its elements.

Returns: An iterator of owned elements.

```mojo
def __iter__(ref self) -> _ListIter[T(Copyable), origin_of(self)]
```

Iterate over elements of the list, returning immutable references.

Returns: An iterator of immutable references to the list elements.

#### `List.__reversed__`

```mojo
def __reversed__(ref self) -> _ListIter[T(Copyable), origin_of(self), False] where conforms_to(T, Copyable)
```

Iterate backwards over the list, returning immutable references.

Returns: A reversed iterator of immutable references to the list elements.

#### `List.__len__`

```mojo
def __len__(self) -> Int
```

Gets the number of elements in the list.

Returns: The number of elements in the list.

#### `List.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Writable)
```

Write this list to a `Writer`.

Args:

- `writer`: The object to write to.

#### `List.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(T, Writable)
```

Write this list to a `Writer`.

Args:

- `writer`: The object to write to.

#### `List.byte_length`

```mojo
def byte_length(self) -> Int
```

Gets the byte length of the List (`len(self) * size_of[T]()`).

Returns: The byte length of the List (`len(self) * size_of[T]()`).

#### `List.capacity`

```mojo
def capacity(self) -> Int
```

Gets the number of elements that can fit in the list without resizing.

Examples:

```mojo
var my_list: List = [1, 2, 3]
print(my_list.capacity())  # Current allocated capacity
```

Returns: The amount of elements that can fit in the list without resizing it.

#### `List.append`

```mojo
def append(mut self, var value: T, /) where conforms_to(T, Movable)
```

Appends a value to this list.

Notes:
If there is no capacity left, resizes to twice the current capacity.
Except for 0 capacity where it sets 1.

Examples:

```mojo
var list: List = [1, 2, 3, 4, 5]
list.append(6)
print(list) # [1, 2, 3, 4, 5, 6]
```

Args:

- `value`: The value to append.

#### `List.insert`

```mojo
def insert(mut self, i: Int, var value: T, /) where conforms_to(T, Movable)
```

Inserts a value to the list at the given index. `a.insert(len(a), value)` is equivalent to `a.append(value)`.

Examples:

```mojo
var list: List = ["one", "three"]
list.insert(1, "two")
print(list) # ['one', 'two', 'three']
```

Args:

- `i`: The index for the value. Must be in the range `[0, len(self)]`.
- `value`: The value to insert.

#### `List.extend`

```mojo
def extend(mut self, var other: Self) where conforms_to(T, Movable)
```

Extends this list by consuming the elements of `other`.

Examples:

```mojo
var list: List = ["one", "two", "three"]
var more: List = ["four", "five"]
list.extend(more^) # more's values are consumed
# print(more)      # Error: use of initialized value
print(list)        # ['one', 'two', 'three', 'four', 'five']
```

Args:

- `other`: List whose elements will be added in order at the end of this list.

```mojo
def extend(mut self, elements: Span[T]) where conforms_to(T, Copyable)
```

Extend this list by copying elements from a `Span`.

The resulting list will have the length `len(self) + len(elements)`.

Examples:

```mojo
var numbers: List = [1, 2, 3]
var more: List = [4, 5, 6]
numbers.extend(Span(more))
print(numbers)   # [1, 2, 3, 4, 5, 6]
```

Args:

- `elements`: The elements to copy into this list.

```mojo
def extend[dtype: DType, //](mut self: List[Scalar[dtype]], value: SIMD[dtype])
```

Extends this list with the elements of a vector.

Notes:
If there is no capacity left, resizes to `len(self) + value.length`.

Examples:

```mojo
from std.collections import List

var numbers: List[Int64] = [1, 2]
var more = SIMD[.int64, 2](3, 4)
numbers.extend(more)
print(numbers) # [SIMD[DType.int64, 1](1), SIMD[DType.int64, 1](2),
               #  SIMD[DType.int64, 1](3), SIMD[DType.int64, 1](4)]
```

Parameters:

- `dtype`: The DType.

Args:

- `value`: The value to append.

```mojo
def extend[dtype: DType, //](mut self: List[Scalar[dtype]], value: SIMD[dtype], *, count: Int)
```

Extends this list with `count` number of elements from a vector.

Notes:
If there is no capacity left, resizes to `len(self) + count`.

Examples:

```mojo
from std.collections import List

var numbers: List[Int64] = [1, 2]
var more = SIMD[.int64, 4](3, 4, 5, 6)
numbers.extend(more, count=2)
print(numbers) # [SIMD[DType.int64, 1](1), SIMD[DType.int64, 1](2),
               #  SIMD[DType.int64, 1](3), SIMD[DType.int64, 1](4)]
```

Parameters:

- `dtype`: The DType.

Args:

- `value`: The value to append.
- `count`: The amount of items to append. Must be less than or equal to `value.length`.

#### `List.pop`

```mojo
def pop(mut self) -> T where conforms_to(T, Movable)
```

Pops the last value from the list.

Examples:

```mojo
var numbers: List = ["1", "2", "3", "4", "5"]
var value = numbers.pop(); print(value)   # 5
print("length", len(numbers))             # length 4
```

Returns: The popped value.

```mojo
def pop(mut self, i: Int) -> T where conforms_to(T, Movable)
```

Pops a value from the list at the given index.

Examples:

```mojo
var numbers: List = ["1", "2", "3", "4", "5"]
var value = numbers.pop(2); print(value)  # 3
print(numbers)                            # ['1', '2', '4', '5']
```

Args:

- `i`: The index of the value to pop.

Returns: The popped value.

#### `List.reserve`

```mojo
def reserve(mut self, capacity: Int) where conforms_to(T, Movable)
```

Reserves the requested capacity.

Notes:
If the current capacity is greater or equal, this is a no-op.
Otherwise, the storage is reallocated and the date is moved.

Args:

- `capacity`: The new capacity.

#### `List.resize`

```mojo
def resize(mut self, length: Int, fill: T) where conforms_to(T, Copyable & Deinitable)
```

Resizes the list to the given new length.

Notes:
If the new length is smaller than the current one, elements at the end
are discarded. If the new length is larger than the current one, the
list is appended with new values elements up to the requested length.

Examples:

```mojo
var list: List = ["z", "y", "x", "w"]
list.resize(3, "v")
print(list)                  # ['z', 'y', 'x']
list.resize(6, "v")
print(list)                  # ['z', 'y', 'x', 'v', 'v', 'v']
```

Args:

- `length`: The new length.
- `fill`: The value to use to populate new elements.

```mojo
def resize(mut self, *, unsafe_uninit_length: Int) where conforms_to(T, Deinitable & Movable)
```

Resizes the list to the given new size leaving any new elements uninitialized.

If the new size is smaller than the current one, elements at the end
are discarded. If the new size is larger than the current one, the
list is extended and the new elements are left uninitialized.

Examples:

```mojo
var list: List = [1, 2, 3]
list.resize(unsafe_uninit_length=5) # Indices 3 and 4 are uninitialized memory
print(len(list))                    # 5
list[3] = 10; list[4] = 20
print(list)                         # [1, 2, 3, 10, 20]
```

Args:

- `unsafe_uninit_length`: The new size.

#### `List.shrink`

```mojo
def shrink(mut self, new_length: Int) where conforms_to(T, Deinitable)
```

Resizes to the given new length which must be <= the current size.

Notes:
With no new value provided, the new length must be smaller than or
equal to the current one. Elements at the end are discarded.

Calls abort() if the new length is larger than the current length.

Examples:

```mojo
var numbers: List = [1, 2, 3, 4, 5, 6]
numbers.shrink(2); print(numbers) # [1, 2]
# numbers.shrink(8)               # Error: new size is bigger than current
```

Args:

- `new_length`: The new length.

#### `List.reverse`

```mojo
def reverse(mut self) where conforms_to(T, Movable)
```

Reverses the elements of the list.

Examples:

```mojo
var list: List = ["o", "l", "l", "e", "H"]
list.reverse()
print("".join(list)) # Hello
```

#### `List.try_index`

```mojo
def try_index(ref self, value: T, start: Int = Int(0), stop: Optional[Int] = None) -> Optional[Int] where conforms_to(T, Equatable)
```

Returns the index of the first occurrence of a value in a list restricted by the range given the start and stop bounds.

Examples:

```mojo
var my_list: List = [1, 2, 3]
print(my_list.index(2)) # prints `1`
```

Args:

- `value`: The value to search for.
- `start`: The starting index of the search, treated as a slice index (defaults to 0).
- `stop`: The ending index of the search, treated as a slice index (defaults to None, which means the end of the list).

Returns: The index of the first occurrence of the value in the list or `None` if the value is not found.

#### `List.index`

```mojo
def index(ref self, value: T, start: Int = Int(0), stop: Optional[Int] = None) raises -> Int where conforms_to(T, Equatable)
```

Returns the index of the first occurrence of a value in a list restricted by the range given the start and stop bounds.

Examples:

```mojo
var my_list: List = [1, 2, 3]
print(my_list.index(2)) # prints `1`
```

Args:

- `value`: The value to search for.
- `start`: The starting index of the search, treated as a slice index (defaults to 0).
- `stop`: The ending index of the search, treated as a slice index (defaults to None, which means the end of the list).

Returns: The index of the first occurrence of the value in the list.

Raises: ValueError: If the value is not found in the list.

#### `List.clear`

```mojo
def clear(mut self) where conforms_to(T, Deinitable)
```

Clears the elements in the list.

Examples:

```mojo
var list: List = ["o", "l", "l", "e", "H"]
print(len(list))  # 5
list.clear()
print(len(list))  # 0
```

#### `List.unsafe_take_allocation`

```mojo
def unsafe_take_allocation(mut self) -> Allocation[T]
```

Take ownership of the underlying storage from the list.

Safety:

The list's elements are handed over still initialized, and deallocating
the storage does not run their destructors. Destroy any initialized
elements yourself (for example with `unsafe_destroy_n`) before
deallocating if `T` needs it.

A list that never allocated has no storage to hand over, so the
returned `Allocation` wraps a dangling pointer and a `Layout` with a
`count` of zero. Check `layout().count()` before deallocating it.

Examples:

```mojo
from std.collections import List
from std.memory.alloc import dealloc

var list: List[Int64] = [1, 2, 3, 4]
var allocation = list.unsafe_take_allocation() # list is now empty
var ptr = allocation.unsafe_ptr()
for idx in range(4):
    print(ptr[unsafe_offset=idx], end=" ")
print() # Output: 1 2 3 4
# Free the storage.
dealloc(allocation^)
```

Returns: The `Allocation` that owns the list's backing storage, carrying the `Layout` it was allocated with.

#### `List.unsafe_get`

```mojo
def unsafe_get(ref self, idx: Int) -> ref[self_is_mut["element"]] T
```

Get a reference to an element of self without checking index bounds.

Notes:
Users should consider using `__getitem__` instead of this method as
it is unsafe. If an index is out of bounds, this method will not
abort, it will be considered undefined behavior.

Note that there is no wraparound for negative indices, caution is
advised. Using negative indices is considered undefined behavior.
Never use `my_list.unsafe_get(-1)` to get the last element of the
list. Instead, do `my_list.unsafe_get(len(my_list) - 1)`.

Args:

- `idx`: The index of the element to get.

Returns: A reference to the element at the given index.

#### `List.unsafe_set`

```mojo
def unsafe_set(mut self, idx: Int, var value: T) where conforms_to(T, Deinitable & Movable)
```

Write a value to a given location without checking index bounds.

Notes:
Users should consider using `my_list[idx] = value` instead of this
method as it is unsafe. If an index is out of bounds, this method
will not abort, it will be considered undefined behavior.

Note that there is no wraparound for negative indices, caution is
advised. Using negative indices is considered undefined behavior.
Never use `my_list.unsafe_set(-1, value)` to set the last element of
the list. Instead, do `my_list.unsafe_set(len(my_list) - 1, value)`.

Args:

- `idx`: The index of the element to set.
- `value`: The value to set.

#### `List.count`

```mojo
def count(self, value: T) -> Int where conforms_to(T, Equatable)
```

Counts the number of occurrences of a value in the list.

Examples:

```mojo
var list: List = ["a", "b", "c", "b", "b", "a", "c"]
print(list.count("b")) # 3
```

Args:

- `value`: The value to count.

Returns: The number of occurrences of the value in the list.

#### `List.swap_elements`

```mojo
def swap_elements(mut self, elt_idx_1: Int, elt_idx_2: Int) where conforms_to(T, Movable)
```

Swaps elements at the specified indexes if they are different.

Examples:

```mojo
var my_list: List = [1, 2, 3]
my_list.swap_elements(0, 2)
print(my_list) # 3, 2, 1
```

Notes:
This is useful because `swap(my_list[i], my_list[j])` cannot be
supported by Mojo, because a mutable alias may be formed.

Args:

- `elt_idx_1`: The index of one element.
- `elt_idx_2`: The index of the other element.

#### `List.unsafe_ptr`

```mojo
def unsafe_ptr[origin: Origin[mut=origin.mut], //](ref[origin.mut] self) -> Pointer[T, origin]
```

Retrieves a pointer to the underlying memory, or a dangling pointer if the `List` has not yet allocated.

You should use the `len` of this `List` to determine if the pointer
is valid for reads and writes.

Parameters:

- `origin`: The origin of the `List`.

Returns: The pointer to the underlying memory.

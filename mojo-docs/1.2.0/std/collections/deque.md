# `std.collections.deque`

Defines the Deque type.

You can import these APIs from the `collections` package.

Examples:

```mojo
from std.collections import Deque
```

## Structs

### `Deque`

```mojo
struct Deque[ElementType: Movable]
```

Implements a double-ended queue.

It supports pushing and popping from both ends in O(1) time resizing the
underlying storage as needed.

Parameters:

- `ElementType`: The type of the elements in the deque. Must implement `Movable`. A `Deque` is implicitly destructible only when `ElementType` is `Deinitable`; otherwise drain it with `deinit_with()`.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `Iterable`, `IterableOwned`, `Movable`, `Sized`, `Writable`

Aliases:

- `IteratorType = _DequeIter[ElementType(Copyable & Deinitable), iterable_origin]`: The iterator type for this deque.
- `IteratorOwnedType = _DequeIterOwned[ElementType(Deinitable & Movable)]`: The owned iterator type for this deque.
- `default_capacity = Int(64)`: The default capacity of the deque: must be the power of 2.

#### `Deque.__init__`

```mojo
def __init__(out self, *, var elements: Optional[List[ElementType]] = None, capacity: Int = Int(64), min_capacity: Int = Int(64), maxlen: Int = Int(-1), shrink: Bool = True) where conforms_to(ElementType, Deinitable)
```

Constructs a deque.

Constraints: `ElementType` must be `Deinitable`. A `maxlen`-bounded
deque can destroy evicted elements, and the `elements` overflow is
destroyed during the initial fill. To build a deque of
non-`Deinitable` elements, use the variadic constructor.

Args:

- `elements`: The optional list of initial deque elements.
- `capacity`: The initial capacity of the deque.
- `min_capacity`: The minimum allowed capacity of the deque when shrinking.
- `maxlen`: The maximum allowed capacity of the deque when growing.
- `shrink`: Should storage be de-allocated when not needed.

```mojo
def __init__(out self, var *values: ElementType, *, __list_literal__: NoneType = None)
```

Constructs a deque from the given values.

Args:

- `*values`: The values to populate the deque with.
- `__list_literal__`: Tell Mojo to use this method for list literals.

```mojo
def __init__(out self, *, copy: Self) where conforms_to(ElementType, Copyable)
```

Creates a deep copy of the given deque.

Args:

- `copy`: The deque to copy.

#### `Deque.__deinit__`

```mojo
def __deinit__(deinit self) where conforms_to(ElementType, Deinitable)
```

Destroys all elements in the deque and frees its memory.

#### `Deque.__bool__`

```mojo
def __bool__(self) -> Bool
```

Checks whether the deque has any elements or not.

Returns: `False` if the deque is empty, `True` if there is at least one element.

#### `Deque.__getitem__`

```mojo
def __getitem__(ref self, idx: IntLiteral) -> ref[self_is_mut["element"]] ElementType
```

Gets the deque element at the given index.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

```mojo
def __getitem__(ref self, idx: Int) -> ref[self_is_mut["element"]] ElementType
```

Gets the deque element at the given index.

Args:

- `idx`: The index of the element.

Returns: A reference to the element at the given index.

#### `Deque.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where conforms_to(ElementType, Equatable)
```

Checks if two deques are equal.

Args:

- `other`: The deque to compare with.

Returns: `True` if the deques are equal, `False` otherwise.

#### `Deque.__contains__`

```mojo
def __contains__(self, value: ElementType) -> Bool where conforms_to(ElementType, Equatable)
```

Verify if a given value is present in the deque.

Args:

- `value`: The value to find.

Returns: True if the value is contained in the deque, False otherwise.

#### `Deque.__add__`

```mojo
def __add__(self, other: Self) -> Self where conforms_to(ElementType, Copyable & Deinitable)
```

Concatenates self with other and returns the result as a new deque.

Args:

- `other`: Deque whose elements will be appended to the elements of self.

Returns: The newly created deque with the properties of `self`.

#### `Deque.__mul__`

```mojo
def __mul__(self, n: Int) -> Self where conforms_to(ElementType, Copyable & Deinitable)
```

Concatenates `n` deques of `self` and returns a new deque.

Args:

- `n`: The multiplier number.

Returns: The new deque.

#### `Deque.__iadd__`

```mojo
def __iadd__(mut self, other: Self) where conforms_to(ElementType, Copyable & Deinitable)
```

Appends the elements of other deque into self.

Args:

- `other`: Deque whose elements will be appended to self.

#### `Deque.__imul__`

```mojo
def __imul__(mut self, n: Int) where conforms_to(ElementType, Copyable & Deinitable)
```

Concatenates self `n` times in place.

Args:

- `n`: The multiplier number.

#### `Deque.deinit_with`

```mojo
def deinit_with(deinit self, deinit_func: T, /)
```

Consumes this deque and deinitializes its elements using the provided closure.

This can be used to destroy a `Deque` of non-`Deinitable`
values.

Args:

- `deinit_func`: The deinitializing closure called on each `Deque` element.

#### `Deque.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H) where conforms_to(ElementType, Hashable)
```

Updates hasher with the hash of each element in the deque.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `Deque.__iter__`

```mojo
def __iter__(var self) -> _DequeIterOwned[ElementType(Deinitable & Movable)] where conforms_to(ElementType, Deinitable)
```

Consume the deque and return an iterator over its elements.

Returns: An iterator that owns the deque's elements.

```mojo
def __iter__(ref self) -> _DequeIter[ElementType(Copyable & Deinitable), origin_of(self)]
```

Iterates over elements of the deque, returning the references.

Returns: An iterator of the references to the deque elements.

#### `Deque.__reversed__`

```mojo
def __reversed__(ref self) -> _DequeIter[ElementType(Copyable & Deinitable), origin_of(self), False] where conforms_to(ElementType, Copyable & Deinitable)
```

Iterate backwards over the deque, returning the references.

Returns: A reversed iterator of the references to the deque elements.

#### `Deque.__len__`

```mojo
def __len__(self) -> Int
```

Gets the number of elements in the deque.

Returns: The number of elements in the deque.

#### `Deque.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(ElementType, Writable)
```

Writes `my_deque.__str__()` to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Deque.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(ElementType, Writable)
```

Writes the repr representation of this deque to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Deque.append`

```mojo
def append(mut self, var value: ElementType) where conforms_to(ElementType, Deinitable)
```

Appends a value to the right side of the deque.

Constraints: `ElementType` must be `Deinitable`, because a bounded
(`maxlen`) deque destroys the evicted element.

Args:

- `value`: The value to append.

#### `Deque.appendleft`

```mojo
def appendleft(mut self, var value: ElementType) where conforms_to(ElementType, Deinitable)
```

Appends a value to the left side of the deque.

Constraints: `ElementType` must be `Deinitable`, because a bounded
(`maxlen`) deque destroys the evicted element.

Args:

- `value`: The value to append.

#### `Deque.clear`

```mojo
def clear(mut self) where conforms_to(ElementType, Deinitable)
```

Removes all elements from the deque leaving it with length 0.

Resets the underlying storage capacity to `_min_capacity`.

#### `Deque.count`

```mojo
def count(self, value: ElementType) -> Int where conforms_to(ElementType, Equatable)
```

Counts the number of occurrences of a `value` in the deque.

Args:

- `value`: The value to count.

Returns: The number of occurrences of the value in the deque.

#### `Deque.extend`

```mojo
def extend(mut self, var values: List[ElementType]) where conforms_to(ElementType, Deinitable)
```

Extends the right side of the deque by consuming elements of the list argument.

Args:

- `values`: List whose elements will be added at the right side of the deque.

#### `Deque.extendleft`

```mojo
def extendleft(mut self, var values: List[ElementType]) where conforms_to(ElementType, Deinitable)
```

Extends the left side of the deque by consuming elements from the list argument.

Acts as series of left appends resulting in reversed order of elements in the list argument.

Args:

- `values`: List whose elements will be added at the left side of the deque.

#### `Deque.index`

```mojo
def index(self, value: ElementType, start: Int = Int(0), stop: Optional[Int] = None) raises -> Int where conforms_to(ElementType, Equatable)
```

Returns the index of the first occurrence of a `value` in a deque restricted by the range given the `start` and `stop` bounds.

Args:

- `value`: The value to search for.
- `start`: The starting index of the search, treated as a slice index (defaults to 0).
- `stop`: The ending index of the search, treated as a slice index (defaults to None, which means the end of the deque).

Returns: The index of the first occurrence of the value in the deque.

Raises: ValueError: If the value is not found in the deque.

#### `Deque.insert`

```mojo
def insert(mut self, idx: Int, var value: ElementType) raises where conforms_to(ElementType, Deinitable)
```

Inserts the `value` into the deque at position `idx`.

Args:

- `idx`: The position to insert the value into.
- `value`: The value to insert.

Raises: IndexError: If deque is already at its maximum size.

#### `Deque.remove`

```mojo
def remove(mut self, value: ElementType) raises where conforms_to(ElementType, Equatable & Deinitable)
```

Removes the first occurrence of the `value`.

Args:

- `value`: The value to remove.

Raises: ValueError: If the value is not found in the deque.

#### `Deque.peek`

```mojo
def peek(self) raises -> ElementType where conforms_to(ElementType, Copyable)
```

Inspect the last (rightmost) element of the deque without removing it.

Returns: The last (rightmost) element of the deque.

Raises: IndexError: If the deque is empty.

#### `Deque.peekleft`

```mojo
def peekleft(self) raises -> ElementType where conforms_to(ElementType, Copyable)
```

Inspect the first (leftmost) element of the deque without removing it.

Returns: The first (leftmost) element of the deque.

Raises: IndexError: If the deque is empty.

#### `Deque.pop`

```mojo
def pop(mut self) raises -> ElementType
```

Removes and returns the element from the right side of the deque.

Returns: The popped value.

Raises: IndexError: If the deque is empty.

#### `Deque.popleft`

```mojo
def popleft(mut self) raises -> ElementType
```

Removes and returns the element from the left side of the deque.

Returns: The popped value.

Raises: IndexError: If the deque is empty.

#### `Deque.reverse`

```mojo
def reverse(mut self)
```

Reverses the elements of the deque in-place.

#### `Deque.rotate`

```mojo
def rotate(mut self, n: Int = Int(1))
```

Rotates the deque by `n` steps.

If `n` is positive, rotates to the right.
If `n` is negative, rotates to the left.

Args:

- `n`: Number of steps to rotate the deque (defaults to 1).

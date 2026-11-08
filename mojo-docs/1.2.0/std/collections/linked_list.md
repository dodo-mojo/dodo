# `std.collections.linked_list`

Implements a doubly-linked list data structure.

This module provides the `LinkedList` type, a doubly-linked list where each
element points to both the next and previous elements. This structure enables
efficient insertion and deletion at any position, though random access requires
traversal. The implementation includes iterator support for forward and reverse
traversal.

## Structs

### `Node`

```mojo
struct Node[T: Movable]
```

A node in a linked list data structure.

Parameters:

- `T`: The type of element stored in the node.

Fields:

- `value` (`T`): The value stored in this node.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Node.__init__`

```mojo
def __init__(out self, var value: T, prev: Optional[Optional[Pointer[Self, MutUntrackedOrigin]]], next: Optional[Optional[Pointer[Self, MutUntrackedOrigin]]])
```

Initialize a new Node with the given value and optional prev/next pointers.

Args:

- `value`: The value to store in this node.
- `prev`: Optional pointer to the previous node.
- `next`: Optional pointer to the next node.

#### `Node.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Writable)
```

Write this node's value to the given writer.

Args:

- `writer`: The writer to write the value to.

### `LinkedList`

```mojo
struct LinkedList[ElementType: Movable]
```

A doubly-linked list implementation.

A doubly-linked list is a data structure where each element points to both
the next and previous elements, allowing for efficient insertion and deletion
at any position.

Parameters:

- `ElementType`: The type of elements stored in the list. Must implement the `Movable` trait.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Equatable`, `Hashable`, `Iterable`, `IterableOwned`, `Movable`, `Sized`, `Writable`

Aliases:

- `IteratorType = _LinkedListIter[ElementType(Copyable), iterable_origin]`: The iterator type for this linked list.
- `IteratorOwnedType = _LinkedListIterOwned[ElementType(Deinitable & Movable)]`: The owned iterator type for this linked list.

#### `LinkedList.__init__`

```mojo
def __init__(out self)
```

Initialize an empty linked list.

Notes:
Time Complexity: O(1).

```mojo
def __init__(out self, var *elements: ElementType, *, __list_literal__: NoneType = None)
```

Initialize a linked list with the given elements.

Notes:
Time Complexity: O(n) in len(elements).

Args:

- `*elements`: Variable number of elements to initialize the list with.
- `__list_literal__`: Tell Mojo to use this method for list literals.

```mojo
def __init__(out self, *, copy: Self) where conforms_to(ElementType, Copyable)
```

Initialize this list as a copy of another list.

Notes:
Time Complexity: O(n) in len(elements).

Args:

- `copy`: The list to copy from.

#### `LinkedList.__deinit__`

```mojo
def __deinit__(deinit self) where conforms_to(ElementType, Deinitable)
```

Clean up the list by freeing all nodes.

Notes:
Time Complexity: O(n) in len(self).

#### `LinkedList.__bool__`

```mojo
def __bool__(self) -> Bool
```

Check if the list is non-empty.

Notes:
Time Complexity: O(1).

Returns: True if the list has elements, False otherwise.

#### `LinkedList.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where conforms_to(ElementType, Equatable)
```

Checks if the two lists are equal.

Notes:
Time Complexity: O(n) in min(len(self), len(other)) compares.

Args:

- `other`: The list to compare to.

Returns: Whether the lists are equal.

#### `LinkedList.__contains__`

```mojo
def __contains__(self, value: ElementType) -> Bool where conforms_to(ElementType, Equatable)
```

Checks if the list contains `value`.

Notes:
Time Complexity: O(n) in len(self) compares.

Args:

- `value`: The value to search for in the list.

Returns: Whether the list contains `value`.

#### `LinkedList.deinit_with`

```mojo
def deinit_with(deinit self, deinit_func: T, /)
```

Consume the list, deinitializing each element with a closure.

Use this to tear down a `LinkedList` whose elements are not
`Deinitable`.

Notes:
Time Complexity: O(n) in len(self).

Args:

- `deinit_func`: A closure called once per element to deinitialize it.

#### `LinkedList.append`

```mojo
def append(mut self, var value: ElementType)
```

Add an element to the end of the list.

Notes:
Time Complexity: O(1).

Args:

- `value`: The value to append.

#### `LinkedList.prepend`

```mojo
def prepend(mut self, var value: ElementType)
```

Add an element to the beginning of the list.

Notes:
Time Complexity: O(1).

Args:

- `value`: The value to prepend.

#### `LinkedList.reverse`

```mojo
def reverse(mut self)
```

Reverse the order of elements in the list.

Notes:
Time Complexity: O(n) in len(self).

#### `LinkedList.pop`

```mojo
def pop(mut self) raises -> ElementType
```

Remove and return the last element of the list.

Notes:
Time Complexity: O(1).

Returns: The last element in the list.

Raises: If the operation fails.

```mojo
def pop[I: Indexer & Deinitable, //](mut self, var i: I) raises -> ElementType
```

Remove the ith element of the list, counting from the tail if given a negative index.

Notes:
Time Complexity: O(n) in len(self).

Parameters:

- `I`: The type of index to use.

Args:

- `i`: The index of the element to get.

Returns: Ownership of the indicated element.

Raises: If the operation fails.

#### `LinkedList.maybe_pop`

```mojo
def maybe_pop(mut self) -> Optional[ElementType]
```

Removes the tail of the list and returns it, if it exists.

Notes:
Time Complexity: O(1).

Returns: The tail of the list, if it was present.

```mojo
def maybe_pop[I: Indexer & Deinitable, //](mut self, var i: I) -> Optional[ElementType]
```

Remove the ith element of the list, counting from the tail if given a negative index.

Notes:
Time Complexity: O(n) in len(self).

Parameters:

- `I`: The type of index to use.

Args:

- `i`: The index of the element to get.

Returns: The element, if it was found.

#### `LinkedList.clear`

```mojo
def clear(mut self) where conforms_to(ElementType, Deinitable)
```

Removes all elements from the list.

Notes:
Time Complexity: O(n) in len(self).

#### `LinkedList.insert`

```mojo
def insert[I: Indexer](mut self, idx: I, var elem: ElementType)
```

Insert an element `elem` into the list at index `idx`.

Notes:
Time Complexity: O(n) in len(self).

Parameters:

- `I`: The type of index to use.

Args:

- `idx`: The index to insert `elem` at. Must be in the range `[0, len(self)]`.
- `elem`: The item to insert into the list.

#### `LinkedList.extend`

```mojo
def extend(mut self, deinit other: Self)
```

Extends the list with another.

Notes:
Time Complexity: O(1).

Args:

- `other`: The list to append to this one.

#### `LinkedList.count`

```mojo
def count(self, elem: ElementType) -> Int where conforms_to(ElementType, Equatable)
```

Count the occurrences of `elem` in the list.

Notes:
Time Complexity: O(n) in len(self) compares.

Args:

- `elem`: The element to search for.

Returns: The number of occurrences of `elem` in the list.

#### `LinkedList.index`

```mojo
def index(self, value: ElementType) raises -> Int where conforms_to(ElementType, Equatable)
```

Returns the index of the first occurrence of a value in the list.

Notes:
Unlike Python's `list.index()`, this method does not accept
`start`/`stop` parameters.

Time Complexity: O(n) in len(self).

Args:

- `value`: The value to search for.

Returns: The index of the first occurrence of the value in the list.

Raises: ValueError: If the value is not found in the list.

#### `LinkedList.__hash__`

```mojo
def __hash__(self, mut hasher: T) where conforms_to(ElementType, Hashable)
```

Hash the elements of this list.

Args:

- `hasher`: The hasher instance.

#### `LinkedList.get_nth`

```mojo
def get_nth[I: Indexer](ref self, idx: I) -> ref[self_is_mut["element"]] ElementType
```

Get the element at the specified index.

Notes:
Time Complexity: O(n/2) in len(self).

Parameters:

- `I`: The type of index to use.

Args:

- `idx`: The index of the element to get.

Returns: A reference to the element at the specified index.

#### `LinkedList.__len__`

```mojo
def __len__(self) -> Int
```

Get the number of elements in the list.

Notes:
Time Complexity: O(1).

Returns: The number of elements in the list.

#### `LinkedList.__iter__`

```mojo
def __iter__(var self) -> _LinkedListIterOwned[ElementType(Deinitable & Movable)] where conforms_to(ElementType, Deinitable)
```

Consume the linked list and return an iterator over its elements.

Notes:
Time Complexity:
- O(1) for iterator construction.
- O(n) in len(self) for a complete iteration of the list.

Returns: An iterator that owns the linked list's elements.

```mojo
def __iter__(ref self) -> _LinkedListIter[ElementType(Copyable), origin_of(self)]
```

Iterate over elements of the list, returning immutable references.

Notes:
Time Complexity:
- O(1) for iterator construction.
- O(n) in len(self) for a complete iteration of the list.

Returns: An iterator of immutable references to the list elements.

#### `LinkedList.__reversed__`

```mojo
def __reversed__(ref self) -> _LinkedListIter[ElementType(Copyable), origin_of(self), False] where conforms_to(ElementType, Copyable)
```

Iterate backwards over the list, returning immutable references.

Notes:
Time Complexity:
- O(1) for iterator construction.
- O(n) in len(self) for a complete iteration of the list.

Returns: A reversed iterator of immutable references to the list elements.

#### `LinkedList.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(ElementType, Writable)
```

Write the list to the given writer.

Args:

- `writer`: The writer to write the list to.

#### `LinkedList.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(ElementType, Writable)
```

Write the repr representation of this LinkedList to a Writer.

Args:

- `writer`: The writer to write to.

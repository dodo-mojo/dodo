# `std.collections.set`

Implements the  Set datatype.

## Structs

### `Set`

```mojo
struct Set[T: KeyElement, H: Defaultable & Hasher & Deinitable = AHasher[SIMD[.uint64, 4](0)]]
```

A set data type.

O(1) average-case amortized add, remove, and membership check.

```mojo
from std.collections import Set

var set = { 1, 2, 3 }
print(len(set))  # 3
set.add(4)

for element in set:
    print(element)

set -= Set[Int](3, 4, 5)
print(set == Set[Int](1, 2))  # True
print(set | Set[Int](0, 1) == Set[Int](0, 1, 2))  # True
var element = set.pop()
print(len(set))  # 1
```

Parameters:

- `T`: The element type of the set. Must implement `KeyElement` (i.e. `Movable & Hashable & Equatable`). Methods that fundamentally need to copy elements (`union`, `intersection`, `__or__`, iteration, ...) are conditionally available via `where conforms_to(T, Copyable)` clauses. When `T` is not `Deinitable`, the set has no implicit destructor and must be torn down with `deinit_with()`.
- `H`: The type of the hasher used to hash keys.

Implemented traits: `AnyType`, `Boolable`, `Comparable`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `Iterable`, `IterableOwned`, `Movable`, `Sized`, `Writable`

Aliases:

- `IteratorType = _DictKeyIter[T(Equatable & Hashable & Copyable), NoneType, H, iterable_origin]`: The iterator type for this set.
- `IteratorOwnedType = _DictKeyIterOwned[T(Equatable & Hashable & Deinitable & Movable), NoneType, H]`: The owned iterator type for this set.

#### `Set.__init__`

```mojo
def __init__(out self)
```

Construct an empty set.

```mojo
def __init__(out self, *ts: T, *, __set_literal__: NoneType = None) where conforms_to(T, Copyable & Deinitable)
```

Construct a set from initial elements.

Args:

- `*ts`: Variadic of elements to add to the set.
- `__set_literal__`: Tell Mojo to use this method for set literals.

```mojo
def __init__(out self, elements: List[T]) where conforms_to(T, Copyable & Deinitable)
```

Construct a set from a List of elements.

Args:

- `elements`: A vector of elements to add to the set.

#### `Set.__bool__`

```mojo
def __bool__(self) -> Bool
```

Whether the set is non-empty or not.

Returns: True if the set is non-empty, False if it is empty.

#### `Set.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool where True if conforms_to(T, Copyable) else conforms_to(T, Copyable)
```

Overloads the < operator for strict subset comparison of sets.

Args:

- `other`: The set to compare against for the strict subset relationship.

Returns: True if the set is a strict subset of the `other` set, False otherwise.

#### `Set.__le__`

```mojo
def __le__(self, other: Self) -> Bool where True if conforms_to(T, Copyable) else conforms_to(T, Copyable)
```

Overloads the <= operator for sets. Works like as `issubset` method.

Args:

- `other`: Another Set instance to check against.

Returns: True if this set is a subset of the `other` set, False otherwise.

#### `Set.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where True if conforms_to(T, Copyable) else conforms_to(T, Copyable)
```

Set equality.

Args:

- `other`: Another Set instance to check equality against.

Returns: True if the sets contain the same elements and False otherwise.

#### `Set.__gt__`

```mojo
def __gt__(self, other: Self) -> Bool where True if conforms_to(T, Copyable) else conforms_to(T, Copyable)
```

Overloads the > operator for strict superset comparison of sets.

Args:

- `other`: The set to compare against for the strict superset relationship.

Returns: True if the set is a strict superset of the `other` set, False otherwise.

#### `Set.__ge__`

```mojo
def __ge__(self, other: Self) -> Bool where True if conforms_to(T, Copyable) else conforms_to(T, Copyable)
```

Overloads the >= operator for sets. Works like as `issuperset` method.

Args:

- `other`: Another Set instance to check against.

Returns: True if this set is a superset of the `other` set, False otherwise.

#### `Set.__contains__`

```mojo
def __contains__(self, t: T) -> Bool
```

Whether or not the set contains an element.

Args:

- `t`: The element to check membership in the set.

Returns: Whether or not the set contains the element.

#### `Set.__sub__`

```mojo
def __sub__(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

Set subtraction.

Args:

- `other`: Another Set instance to subtract from this one.

Returns: A new set containing elements of this set, but not containing any elements which were in the `other` set.

#### `Set.__and__`

```mojo
def __and__(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

The set intersection operator.

Args:

- `other`: Another Set instance to intersect with this one.

Returns: A new set containing only the elements which appear in both this set and the `other` set.

#### `Set.__or__`

```mojo
def __or__(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

The set union operator.

Args:

- `other`: Another Set instance to union with this one.

Returns: A new set containing any elements which appear in either this set or the `other` set.

#### `Set.__xor__`

```mojo
def __xor__(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

Overloads the ^ operator for sets. Works like as `symmetric_difference` method.

Args:

- `other`: The set to find the symmetric difference with.

Returns: A new set containing the symmetric difference of the two sets.

#### `Set.__isub__`

```mojo
def __isub__(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

In-place set subtraction.

Updates the set to remove any elements from the `other` set.

Args:

- `other`: Another Set instance to subtract from this one.

#### `Set.__iand__`

```mojo
def __iand__(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

In-place set intersection.

Updates the set to contain only the elements which are already in
the set and are also contained in the `other` set.

Args:

- `other`: Another Set instance to intersect with this one.

#### `Set.__ixor__`

```mojo
def __ixor__(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

Overloads the ^= operator. Works like as `symmetric_difference_update` method.

Updates the set with the symmetric difference of itself and another set.

Args:

- `other`: The set to find the symmetric difference with.

#### `Set.__ior__`

```mojo
def __ior__(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

In-place set union.

Updates the set to contain all elements in the `other` set
as well as keeping all elements it already contained.

Args:

- `other`: Another Set instance to union with this one.

#### `Set.deinit_with`

```mojo
def deinit_with(deinit self, deinit_func: T, /)
```

Consume the set, deinitializing each element with a closure.

Use this to tear down a `Set` whose element type is not
`Deinitable`.

Args:

- `deinit_func`: A closure called once per element to destroy it.

#### `Set.__len__`

```mojo
def __len__(self) -> Int
```

The size of the set.

Returns: The number of elements in the set.

#### `Set.__hash__`

```mojo
def __hash__(self, mut hasher: T) where True if conforms_to(T, Copyable) else conforms_to(T, Copyable)
```

Updates hasher with the underlying values.

The update is order independent, so s1 == s2 -> hash(s1) == hash(s2).

Args:

- `hasher`: The hasher instance.

#### `Set.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(T, Copyable & Writable)
```

Write this set to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Set.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(T, Copyable & Writable)
```

Write this set to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Set.__iter__`

```mojo
def __iter__(deinit self) -> Self.IteratorOwnedType where conforms_to(T, Deinitable)
```

Consume the set and iterate over its elements.

Constraints: `T` must be `Deinitable`; consuming iteration drops the
backing dictionary's value slots in place.

Returns: An iterator that owns the set's elements.

```mojo
def __iter__(ref self) -> _DictKeyIter[T(Equatable & Hashable & Copyable), NoneType, H, origin_of(self)]
```

Iterate over elements of the set, returning immutable references.

Returns: An iterator of immutable references to the set elements.

#### `Set.add`

```mojo
def add(mut self, var t: T) where conforms_to(T, Deinitable)
```

Add an element to the set.

Constraints: `T` must be `Deinitable`; adding a duplicate discards the
incoming element in place.

Args:

- `t`: The element to add to the set.

#### `Set.insert`

```mojo
def insert(mut self, var t: T) -> Optional[T]
```

Insert an element, returning any displaced equal element.

Unlike `add`, a displaced equal element is moved out and returned
rather than destroyed in place, so this works when `T` is not
`Deinitable`. The caller owns the returned element.

Args:

- `t`: The element to insert into the set.

Returns: The previously-present equal element if one was displaced, otherwise an empty `Optional`.

#### `Set.remove`

```mojo
def remove(mut self, t: T) raises where conforms_to(T, Deinitable)
```

Remove an element from the set.

Constraints: `T` must be `Deinitable`; the removed element is destroyed
in place.

Args:

- `t`: The element to remove from the set.

Raises: If the element isn't in the set to remove.

#### `Set.pop`

```mojo
def pop(mut self) raises -> T
```

Remove any one item from the set, and return it.

As an implementation detail this will remove the last item
according to insertion order.

Returns: The element which was removed from the set.

Raises: If the set is empty.

#### `Set.union`

```mojo
def union(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

Set union.

Args:

- `other`: Another Set instance to union with this one.

Returns: A new set containing any elements which appear in either this set or the `other` set.

#### `Set.intersection`

```mojo
def intersection(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

Set intersection.

Args:

- `other`: Another Set instance to intersect with this one.

Returns: A new set containing only the elements which appear in both this set and the `other` set.

#### `Set.difference`

```mojo
def difference(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

Set difference.

Args:

- `other`: Another Set instance to find the difference with this one.

Returns: A new set containing elements that are in this set but not in the `other` set.

#### `Set.update`

```mojo
def update(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

In-place set update.

Updates the set to contain all elements in the `other` set
as well as keeping all elements it already contained.

Args:

- `other`: Another Set instance to union with this one.

#### `Set.intersection_update`

```mojo
def intersection_update(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

In-place set intersection update.

Updates the set by retaining only elements found in both this set and the `other` set,
removing all other elements. The result is the intersection of this set with `other`.

Args:

- `other`: Another Set instance to intersect with this one.

#### `Set.difference_update`

```mojo
def difference_update(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

In-place set subtraction.

Updates the set by removing all elements found in the `other` set,
effectively keeping only elements that are unique to this set.

Args:

- `other`: Another Set instance to subtract from this one.

#### `Set.issubset`

```mojo
def issubset(self, other: Self) -> Bool where conforms_to(T, Copyable)
```

Check if this set is a subset of another set.

Args:

- `other`: Another Set instance to check against.

Returns: True if this set is a subset of the `other` set, False otherwise.

#### `Set.isdisjoint`

```mojo
def isdisjoint(self, other: Self) -> Bool where conforms_to(T, Copyable)
```

Check if this set is disjoint with another set.

Args:

- `other`: Another Set instance to check against.

Returns: True if this set is disjoint with the `other` set, False otherwise.

#### `Set.issuperset`

```mojo
def issuperset(self, other: Self) -> Bool where conforms_to(T, Copyable)
```

Check if this set is a superset of another set.

Args:

- `other`: Another Set instance to check against.

Returns: True if this set is a superset of the `other` set, False otherwise.

#### `Set.symmetric_difference`

```mojo
def symmetric_difference(self, other: Self) -> Self where conforms_to(T, Copyable & Deinitable)
```

Returns the symmetric difference of two sets.

Args:

- `other`: The set to find the symmetric difference with.

Returns: A new set containing the symmetric difference of the two sets.

#### `Set.symmetric_difference_update`

```mojo
def symmetric_difference_update(mut self, other: Self) where conforms_to(T, Copyable & Deinitable)
```

Updates the set with the symmetric difference of itself and another set.

Args:

- `other`: The set to find the symmetric difference with.

#### `Set.discard`

```mojo
def discard(mut self, value: T) where conforms_to(T, Deinitable)
```

Remove a value from the set if it exists. Pass otherwise.

Constraints: `T` must be `Deinitable`; a removed element is destroyed
in place.

Args:

- `value`: The element to remove from the set.

#### `Set.clear`

```mojo
def clear(mut self) where conforms_to(T, Deinitable)
```

Removes all elements from the set.

This method modifies the set in-place, removing all of its elements.
After calling this method, the set will be empty.

Constraints: `T` must be `Deinitable`, since every element is destroyed
in place.

#### `Set.clear_with`

```mojo
def clear_with(mut self, destroy_func: T, /)
```

Remove all elements, disposing each with a closure.

The closure counterpart of `clear`: instead of destroying each element
in place, it hands each element to `destroy_func`. Use this to clear a
`Set` whose element type is not `Deinitable`. The set's
capacity is retained.

Args:

- `destroy_func`: A closure called once per element to destroy it.

# `std.collections.counter`

Defines the `Counter` type.

Import these APIs from the `collections` package:

```mojo
from std.collections import Counter

```

Counters provide convenient tallying objects that use a dictionary to
store keys and their counts. They offer the full functionality of
counted sets, also called bags or multisets, and extend that model by
supporting negative counts.

## Structs

### `Counter`

```mojo
struct Counter[V: Equatable & Hashable & Copyable & Deinitable, H: Defaultable & Hasher & Deinitable = AHasher[SIMD[.uint64, 4](0)]]
```

A container for counting hashable items.

In other languages, similar types to counters include bags, counted sets,
and multisets, although their semantics are normally closer to sets (adding,
removing, intersecting, unions, etc) rather than increasing and decreasing
counts. Mojo's `Counter` follows Python's model, and adds math versatility by
supporting negative counts.

The value type must implement the `KeyElement` trait and be `Copyable`, as
its values are stored in a dictionary as keys and the API copies elements
extensively (e.g., `most_common`, `subtract`, merge ops). The keys' uniform
value type must be hashable for use in the
underlying dictionary.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String]("a", "a", "a", "b", "b", "c", "d", "c", "c")
print(counter["a"]) # prints 3
print(counter["b"]) # prints 2
```

Parameters:

- `V`: The value type to be counted. Must be `KeyElement` and `Copyable`.
- `H`: The type of the hasher in the underlying dictionary.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Equatable`, `Iterable`, `IterableOwned`, `Movable`, `Sized`, `Writable`

Aliases:

- `IteratorType = _DictKeyIter[V, Int, H, iterable_origin]`: The iterator type for this counter.
- `IteratorOwnedType = _DictKeyIterOwned[V, Int, H]`: The owned iterator type for this counter.

#### `Counter.__init__`

```mojo
def __init__(out self)
```

Create a new, empty `Counter` object.

```mojo
def __init__(out self, var *values: V)
```

Create a new `Counter` from a list of values.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String]("a", "a", "a", "b", "b", "c", "d", "c", "c")
print(counter["a"])  # print 3
print(counter["b"])  # print 2
```

Note:
A counter is not limited to the values used in this initial list.
You may add new keys as needed or remove them with clear or one
of the `pop` calls.

Args:

- `*values`: A list of values to count.

```mojo
def __init__[IterableType: Iterable](out self, ref iterable: IterableType) where Bool(identical(IterableType.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)].Element, V))
```

Create a `Counter` from an iterable of values.

Each value produced by the iterable is tallied, so the resulting
`Counter` maps every distinct value to the number of times it appeared.

Example:

```mojo
from std.collections import Counter

var counter = Counter(["a", "a", "a", "b", "b", "c", "d", "c", "c"])
print(counter["a"]) # prints 3
print(counter["b"]) # prints 2

# Any iterable works, e.g. the bytes of a string:
var by_byte = Counter(String("aaabbaacdd").bytes())
print(by_byte[Byte(ord("a"))]) # prints 5
```

Parameters:

- `IterableType`: The type of the `iterable` argument.

Args:

- `iterable`: The iterable of values to count.

#### `Counter.__bool__`

```mojo
def __bool__(self) -> Bool
```

Check if the `Counter` is empty or not.

Returns: `False` if the `Counter` is empty, `True` otherwise.

#### `Counter.__getitem__`

```mojo
def __getitem__(self, key: V) -> Int
```

Get the count of a key.

Args:

- `key`: The key to get the count of.

Returns: The count of the key.

#### `Counter.__setitem__`

```mojo
def __setitem__(mut self, value: V, count: Int)
```

Set a value in the keyword `Counter` by key.

Args:

- `value`: The value to associate with the specified count.
- `count`: The count to store in the `Counter`.

#### `Counter.__neg__`

```mojo
def __neg__(self) -> Self
```

Subtract from an empty `Counter`. Strips positive and zero counts, and flips the sign on negative counts.

Returns: A new `Counter` with stripped counts and negative counts.

#### `Counter.__pos__`

```mojo
def __pos__(self) -> Self
```

Return a shallow copy of the `Counter`, stripping non-positive counts.

Returns: A shallow copy of the `Counter`.

#### `Counter.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Check if all counts agree. Missing counts are treated as zero.

Args:

- `other`: The other `Counter` to compare to.

Returns: `True` if the two `Counter`s are equal, `False` otherwise.

#### `Counter.__contains__`

```mojo
def __contains__(self, key: V) -> Bool
```

Check if a given key is in the `Counter` or not.

Args:

- `key`: The key to check.

Returns: `True` if there key exists in the `Counter`, `False` otherwise.

#### `Counter.__add__`

```mojo
def __add__(self, other: Self) -> Self
```

Add counts from two `Counter`s.

Args:

- `other`: The other `Counter` to add to this `Counter`.

Returns: A new `Counter` with the counts from both `Counter`s added together.

#### `Counter.__sub__`

```mojo
def __sub__(self, other: Self) -> Self
```

Subtract counts, but keep only results with positive counts.

Args:

- `other`: The other `Counter` to subtract from this `Counter`.

Returns: A new `Counter` with the counts from the other `Counter` subtracted from this `Counter`.

#### `Counter.__and__`

```mojo
def __and__(self, other: Self) -> Self
```

Intersection: keep common elements with the minimum count.

Args:

- `other`: The other `Counter` to intersect with.

Returns: A new `Counter` with the common elements and the minimum count of the two `Counter`s.

#### `Counter.__or__`

```mojo
def __or__(self, other: Self) -> Self
```

Union: keep all elements with the maximum count.

Args:

- `other`: The other `Counter` to union with.

Returns: A new `Counter` with all elements and the maximum count of the two `Counter`s.

#### `Counter.__iadd__`

```mojo
def __iadd__(mut self, other: Self)
```

Add counts from another `Counter` to this `Counter`.

Args:

- `other`: The other `Counter` to add to this `Counter`.

#### `Counter.__isub__`

```mojo
def __isub__(mut self, other: Self)
```

Subtract counts from another `Counter` from this `Counter`, but keep only results with positive counts.

Args:

- `other`: The other `Counter` to subtract from this `Counter`.

#### `Counter.__iand__`

```mojo
def __iand__(mut self, other: Self)
```

Intersection: keep common elements with the minimum count.

Args:

- `other`: The other `Counter` to intersect with.

#### `Counter.__ior__`

```mojo
def __ior__(mut self, other: Self)
```

Union: keep all elements with the maximum count.

Args:

- `other`: The other `Counter` to union with.

#### `Counter.fromkeys`

```mojo
def fromkeys(keys: List[V], value: Int) -> Self
```

Create a new `Counter` from a list of keys and a default value.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String].fromkeys(["a", "b", "c"], 1)
print(counter["a"]) # output: 1
```

Args:

- `keys`: The keys to create the `Counter` from.
- `value`: The default value to associate with each key. Must be non-negative.

Returns: A new `Counter` with the count of each passed key set to `value`.

#### `Counter.__iter__`

```mojo
def __iter__(deinit self) -> Self.IteratorOwnedType
```

Consume the counter and iterate over its keys.

Returns: An iterator that owns the counter's keys.

```mojo
def __iter__(ref self) -> _DictKeyIter[V, Int, H, origin_of(self)]
```

Iterate over the `Counter`'s keys as immutable references.

Returns: An iterator of immutable references to the `Counter` values.

#### `Counter.__len__`

```mojo
def __len__(self) -> Int
```

Returns the number of elements currently stored in the `Counter`.

Returns: The number of elements in the `Counter`.

#### `Counter.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(V, Writable)
```

Write this `Counter` to a writer.

Constraints: `V` must conform to `Writable`.

Args:

- `writer`: The object to write to.

#### `Counter.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(V, Writable)
```

Write the repr of this `Counter` to a writer.

Constraints: `V` must conform to `Writable`.

Args:

- `writer`: The object to write to.

#### `Counter.le`

```mojo
def le(self, other: Self) -> Bool
```

Check if all counts are less than or equal to those in the other `Counter`.

Note that since we check that _all_ counts satisfy the condition, this
comparison does not make `Counter`s totally ordered.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3, 3])
var other = Counter[Int].fromkeys([1, 2, 3], 10)
print(counter.le(other)) # output: True
counter[3] += 20
print(counter.le(other)) # output: False
```

Args:

- `other`: The other `Counter` to compare to.

Returns: `True` if all counts are less than or equal to the other `Counter`, `False` otherwise.

#### `Counter.lt`

```mojo
def lt(self, other: Self) -> Bool
```

Check if all counts are less than those in the other `Counter`.

Note that since we check that _all_ counts satisfy the condition, this
comparison does not make `Counter`s totally ordered.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3])
var other = Counter[Int].fromkeys([1, 2, 3], 3)
print(counter.lt(other)) # output: True
counter[1] += 1
print(counter.lt(other)) # output: False
```

Args:

- `other`: The other `Counter` to compare to.

Returns: `True` if all counts are less than in the other `Counter`, `False` otherwise.

#### `Counter.gt`

```mojo
def gt(self, other: Self) -> Bool
```

Check if all counts are greater than those in the other `Counter`.

Note that since we check that _all_ counts satisfy the condition, this
comparison does not make `Counter`s totally ordered.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3])
var other = Counter[Int].fromkeys([1, 2, 3], 3)
print(other.gt(counter)) # output: True
counter[1] += 1
print(other.gt(counter)) # output: False
```

Args:

- `other`: The other `Counter` to compare to.

Returns: `True` if all counts are greater than in the other `Counter`, `False` otherwise.

#### `Counter.ge`

```mojo
def ge(self, other: Self) -> Bool
```

Check if all counts are greater than or equal to those in the other `Counter`.

Note that since we check that _all_ counts satisfy the condition, this
comparison does not make `Counter`s totally ordered.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3, 3])
var other = Counter[Int].fromkeys([1, 2, 3], 10)
print(other.ge(counter)) # output: True
counter[3] += 20
print(other.ge(counter)) # output: False
```

Args:

- `other`: The other `Counter` to compare to.

Returns: `True` if all counts are greater than or equal to the other `Counter`, `False` otherwise.

#### `Counter.get`

```mojo
def get(self, value: V) -> Optional[Int]
```

Get a value from the `Counter`.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String].fromkeys(["a", "b", "c"], 1)
print(counter.get("a").or_else(0)) # output: 1
print(counter.get("d").or_else(0)) # output: 0
```

Args:

- `value`: The value to search for in the `Counter`.

Returns: An optional value containing a copy of the value if it was present, otherwise an empty `Optional`.

```mojo
def get(self, value: V, default: Int) -> Int
```

Get a value from the `Counter`.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String].fromkeys(["a", "b", "c"], 1)
print(counter.get("a", default=0)) # output: 1
print(counter.get("d", default=0)) # output: 0
```

Args:

- `value`: The value to search for in the `Counter`.
- `default`: Default count to return.

Returns: A copy of the value if it was present, otherwise default.

#### `Counter.pop`

```mojo
def pop(mut self, value: V) raises -> Int
```

Remove a value from the `Counter` by value.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String].fromkeys(["a", "b", "c"], 1)
print(counter.get("b").or_else(0)) # output: 1
try:
    var count = counter.pop("b")
    print(count) # output: 1
    print(counter.get("b").or_else(0)) # output: 0
except e:
    print(e) # KeyError if the key was not in the counter
```

Args:

- `value`: The value to remove from the `Counter`.

Returns: The value associated with the key, if it was in the `Counter`.

Raises: "KeyError" if the key was not present in the `Counter`.

```mojo
def pop(mut self, value: V, var default: Int) -> Int
```

Remove a value from the `Counter` by value.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String].fromkeys(["a", "b", "c"], 1)
var count = counter.pop("b", default=100)
print(count) # output: 1
count = counter.pop("not-a-key", default=0)
print(count) # output 0
```

Args:

- `value`: The value to remove from the `Counter`.
- `default`: Optionally provide a default value to return if the value was not found instead of raising.

Returns: The value associated with the key, if it was in the `Counter`. If it wasn't, return the provided default value instead.

#### `Counter.keys`

```mojo
def keys(ref self) -> _DictKeyIter[V, Int, H, origin_of(self._data)]
```

Iterate over the `Counter`'s keys as immutable references.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String].fromkeys(["d", "b", "a", "c"], 1)
var key_list = List[String]()
for key in counter.keys():
    key_list.append(key)
sort(key_list[:])
print(key_list) # output: ['a', 'b', 'c', 'd']
```

Returns: An iterator of immutable references to the `Counter` keys.

#### `Counter.values`

```mojo
def values(ref self) -> _DictValueIter[V, Int, H, origin_of(self._data)]
```

Iterate over the `Counter`'s values as references.

Example:

```mojo
from std.collections import Counter

# Construct `counter`
var counter = Counter[Int]([1, 2, 3, 1, 2, 1, 1, 1, 2, 5, 2, 9])

# Find most populous key
var max_count: Int = Int.MIN
for count in counter.values():
    if count > max_count:
        max_count = count

# Max count is the five ones
print(max_count) # output: 5
```

Returns: An iterator of references to the `Counter` values.

#### `Counter.items`

```mojo
def items(ref self) -> _DictEntryIter[V, Int, H, origin_of(self._data)]
```

Iterate over the `Counter`'s entries as immutable references.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 1, 1, 1, 2, 2])
for count in counter.items():
    print(count.key, count.value)
# output: 1 5
# output: 2 4
```

Returns: An iterator of immutable references to the `Counter` entries.

#### `Counter.clear`

```mojo
def clear(mut self)
```

Remove all elements from the `Counter`.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 1, 1, 1, 2, 2])
print(counter.total()) # output: 9 (5 ones + 4 twos)
counter.clear() # Removes both entries
print(counter.total()) # output: 0
```

#### `Counter.popitem`

```mojo
def popitem(mut self) raises -> CountTuple[V]
```

Remove and return an arbitrary (key, value) pair from the `Counter`. Useful for destructively iterating over the `Counter`. Returns in LIFO order.

Example:

```mojo
from std.collections import Counter

var counter = Counter[String].fromkeys(["a", "b", "c"], 5)
try:
    var tuple = counter.popitem()
    print(tuple._value, tuple._count)
    # output: probably c 5 since that was last in
except e:
    print(e) # KeyError if the key was not in the counter
```

Returns: A `CountTuple` containing the key and value of the removed item.

Raises: "KeyError" if the `Counter` is empty.

#### `Counter.total`

```mojo
def total(self) -> Int
```

Return the total of all counts in the `Counter`.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 1, 1, 1, 2, 2])
print(counter.total()) # output: 9 (5 ones + 4 twos)
counter.clear() # Removes both entries
print(counter.total()) # output: 0
```

Returns: The total of all counts in the `Counter`.

#### `Counter.most_common`

```mojo
def most_common(self, n: Int) -> List[CountTuple[V]]
```

Return a list of the `n` most common elements and their counts from the most common to the least.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3, 3, 1, 1, 1, 6, 6, 2, 2, 7])
for tuple in counter.most_common(2):
    print(tuple._value, tuple._count)
    # output: 1 5
    # output: 2 4
```

Args:

- `n`: The number of most common elements to return.

Returns: A list of the `n` most common elements and their counts. If the counter has fewer than `n` unique elements, all of them are returned; if `n` is negative, the list is empty.

#### `Counter.elements`

```mojo
def elements(self) -> List[V]
```

Return an iterator over elements repeating each as many times as its count.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3, 3, 1, 1, 1, 6, 6, 2, 2, 7])
print(counter.elements())
# output: [1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 6, 6, 7]
```

Returns: An iterator over the elements in the `Counter`.

#### `Counter.update`

```mojo
def update(mut self, other: Self)
```

Update the `Counter`, like `Dict.update()` but add counts instead of replacing them.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3, 3])
var other = Counter[Int].fromkeys([1, 2, 3], 10)
print(counter[1]) # output: 2
counter.update(other)
print(counter[1]) # output: 12
```

Args:

- `other`: The `Counter` to update this `Counter` with.

#### `Counter.subtract`

```mojo
def subtract(mut self, other: Self)
```

Subtract counts. Both inputs and outputs may be zero or negative.

Example:

```mojo
from std.collections import Counter

var counter = Counter[Int]([1, 2, 1, 2, 3, 3, 3])
var other = Counter[Int].fromkeys([1, 2, 3], 10)
print(counter[1]) # output: 2
counter.subtract(other)
print(counter[1]) # output: -8
```

Args:

- `other`: The `Counter` to subtract from this `Counter`.

### `CountTuple`

```mojo
struct CountTuple[V: Equatable & Hashable & Copyable & Deinitable]
```

A tuple representing a value and its count in a `Counter`.

Parameters:

- `V`: The value in the `Counter`.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Deinitable`, `Equatable`, `Movable`

#### `CountTuple.__init__`

```mojo
def __init__(out self, value: V, count: Int)
```

Create a new `CountTuple`.

Args:

- `value`: The value in the `Counter`.
- `count`: The count of the value in the `Counter`.

#### `CountTuple.__getitem__`

```mojo
def __getitem__(self, idx: Int) -> Variant[V, Int]
```

Get an element in the `CountTuple`.

Args:

- `idx`: The element to return.

Returns: The value if `idx` is `0` and the count if `idx` is `1`.

#### `CountTuple.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool
```

Compare two `CountTuple`s by count, then by value.

Args:

- `other`: The other `CountTuple` to compare to.

Returns: `True` if this `CountTuple` is less than the other, `False` otherwise.

#### `CountTuple.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Compare two `CountTuple`s for equality.

Args:

- `other`: The other `CountTuple` to compare to.

Returns: `True` if the two `CountTuple`s are equal, `False` otherwise.

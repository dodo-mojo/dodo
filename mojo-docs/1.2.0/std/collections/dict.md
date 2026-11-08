# `std.collections.dict`

Defines `Dict`, a collection that stores key-value pairs.

Dict provides an efficient, O(1) amortized
average-time complexity for insert, lookup, and removal of dictionary elements.
It uses a Swiss Table implementation with SIMD group probing for fast lookups:

- Performance and size are heavily optimized for small dictionaries, but can
  scale to large dictionaries.

- Insertion order is implicitly preserved. Iteration over keys, values, and
  items have a deterministic order based on insertion.

- For more information on the Mojo `Dict` type, see the
  [Mojo `Dict` manual](../../manual/types.md#dict). To learn more about using
  Python dictionaries from Mojo, see
  [Python types in Mojo](../../manual/python/types.md#python-types-in-mojo).

Key elements only need to be `Movable & Hashable & Equatable`. Methods that
fundamentally need to copy keys (`copy`, `update`, `__or__`, `fromkeys`,
iteration, ...) are conditionally available via
`where conforms_to(K, Copyable)` clauses.

Value elements only need to be `Movable & Deinitable`. Methods that
fundamentally need to copy values (`copy`, `find`, `get`, `update`, `__or__`,
`fromkeys`, iteration, ...) are conditionally available via
`where conforms_to(V, Copyable)` clauses.

See the `Dict` docs for more details.

## Aliases

### `KeyElement`

```mojo
comptime KeyElement = Equatable & Hashable & Movable
```

A trait composition for types which implement all requirements of dictionary keys. Dict keys must minimally be `Movable`, `Hashable`, and `Equatable`. Methods that copy keys (e.g. `update`, `fromkeys`, iteration) are conditionally available when the key type also conforms to `Copyable`.

### `DictEntry`

```mojo
comptime DictEntry = SwissTableEntry[_, _, _]
```

Store a key-value pair entry inside a dictionary.

This is a comptime alias for `SwissTableEntry` for backwards compatibility.

## Structs

### `DictKeyError`

```mojo
struct DictKeyError[K: KeyElement]
```

A custom error type for Dict lookups that fail.

Parameters:

- `K`: The key type of the elements in the dictionary.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `DictKeyError.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the error and the key to the writer.

Args:

- `writer`: The writer to write to.

#### `DictKeyError.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the error to the writer.

Args:

- `writer`: The writer to write to.

### `EmptyDictError`

```mojo
struct EmptyDictError
```

A custom error type for when a `Dict` is empty.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `EmptyDictError.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the error to the writer.

Args:

- `writer`: The writer to write to.

#### `EmptyDictError.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the error to the writer.

Args:

- `writer`: The writer to write to.

### `Dict`

```mojo
struct Dict[K: KeyElement, V: Movable, H: Defaultable & Hasher & Deinitable = AHasher[SIMD[.uint64, 4](0)]]
```

A container that stores key-value pairs.

The `Dict` type is Mojo's primary associative collection, similar to
Python's `dict` (dictionary). Unlike a `List`, which stores elements by
index, a `Dict` stores values associated with unique keys, which enables
fast lookups, insertions, and deletions.

You can create a `Dict` in several ways:

```mojo
# Empty dictionary
var empty_dict = Dict[String, Int]()

# Dictionary literal syntax
var scores = {"Alice": 95, "Bob": 87, "Charlie": 92}

# Pre-allocated capacity
var large_dict = Dict[String, Int](capacity=64)

# From separate key and value lists
var keys = ["red", "green", "blue"]
var values = [255, 128, 64]
var colors = Dict[String, Int]()
for key, value in zip(keys, values):
    colors[String(key)] = value # cast list iterator to key-type
```

Be aware of the following characteristics:

- **Type safety**: Both keys and values must be homogeneous types,
determined at compile time. This is more restrictive than Python
dictionaries but provides better performance:

  ```mojo
  var string_to_int = {"count": 42}     # Dict[String, Int]
  var int_to_string = {1: "one"}        # Dict[Int, String]
  # var mixed = {"key": 1, 2: "val"}   # Error! Keys must be same type
  ```

  However, you can get around this by defining your dictionary key and/or
  value type as [`Variant`](../../std/utils/variant.md#variant). This is
  a discriminated union type, meaning it can store any number of different
  types that can vary at runtime.

- **Insertion order**: Iteration over keys, values, and items follows
  insertion order. Updating an existing key's value does not change its
  position. This matches the ordering guarantee of Python's `dict`.

- **Value semantics**: A `Dict` is value semantic by default. Copying a
  `Dict` creates a deep copy of all key-value pairs. To avoid accidental
  copies, `Dict` is not implicitly copyable—you must explicitly copy it
  using the `.copy()` method.

  ```mojo
  var dict1 = {"a": 1, "b": 2}
  # var dict2 = dict1  # Error: Dict is not implicitly copyable
  var dict2 = dict1.copy()  # Deep copy
  dict2["c"] = 3
  print(dict1)   # => {"a": 1, "b": 2}
  print(dict2)   # => {"a": 1, "b": 2, "c": 3}
  ```

  This is different from Python, where assignment creates a reference to
  the same dictionary. For more information, read about [value
  semantics](../../manual/values/value-semantics.md).

- **Iteration uses immutable references**: When iterating over keys, values,
  or items, you get immutable references unless you specify `ref` or `var`:

  ```mojo
  var inventory = {"apples": 10, "bananas": 5}

  # Default behavior creates immutable (read-only) references:
  # for value in inventory.values():
  #     value += 1  # error: expression must be mutable

  # Using `ref` gets mutable (read-write) references
  for ref value in inventory.values():
      value += 1  # Modify inventory values in-place
  print(inventory)  # => {"apples": 11, "bananas": 6}

  # Using `var` gets an owned copy of the value
  for var key in inventory.keys():
      inventory[key] += 1  # Modify inventory values in-place
  print(inventory)  # => {"apples": 12, "bananas": 7}
  ```

  Note that indexing into a `Dict` with a key that's a reference to the
  key owned by the `Dict` produces a confusing error related to
  [argument exclusivity](../../manual/values/ownership.md#argument-exclusivity).
  Using `var key` in the previous example creates an owned copy of the key,
  avoiding the error.

- **KeyError handling**: Directly accessing values with the `[]` operator
  will raise `DictKeyError` if the key is not found:

  ```mojo
  var phonebook = {"Alice": "555-0101", "Bob": "555-0102"}
  # print(phonebook["Charlie"])  # => DictKeyError
  ```

  For safe access, you should instead use `get()`:

  ```mojo
  var phonebook = {"Alice": "555-0101", "Bob": "555-0102"}
  var phone = phonebook.get("Charlie")
  print(phone) if phone else print('phone not found')
  ```

Examples:

```mojo
var phonebook = {"Alice": "555-0101", "Bob": "555-0102"}

# Add/update entries
phonebook["Charlie"] = "555-0103"    # Add new entry
phonebook["Alice"] = "555-0199"      # Update existing entry

# Access directly (unsafe and raises DictKeyError if key not found)
print(phonebook["Alice"])            # => 555-0199

# Access safely
var phone = phonebook.get("David")   # Returns Optional type
print(phone.or_else("phone not found!"))

# Access safely with default value
phone = phonebook.get("David", "555-0000")
print(phone)               # => '555-0000'

# Check for keys
if "Bob" in phonebook:
    print("Found Bob")

# Remove (pop) entries
print(phonebook.pop("Charlie"))         # Remove and return: "555-0103"
print(phonebook.pop("Unknown", "N/A"))  # Pop with default

# Iterate over a dictionary
for key in phonebook.keys():
    print("Key:", key)

for value in phonebook.values():
    print("Value:", value)

for item in phonebook.items():
    print(item.key, "=>", item.value)

for var key in phonebook:
    print(key, "=>", phonebook[key])

# Number of key-value pairs
print('len:', len(phonebook))        # => len: 2

# Dictionary operations
var backup = phonebook.copy()        # Explicit copy
phonebook.clear()                    # Remove all entries

# Merge dictionaries
var more_numbers = {"David": "555-0104", "Eve": "555-0105"}
backup.update(more_numbers)          # Merge in-place
var combined = backup | more_numbers # Create new merged dict
print(combined)
```

Parameters:

- `K`: The type of keys stored in the dictionary.
- `V`: The type of values stored in the dictionary.
- `H`: The type of hasher used to hash the keys.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Equatable`, `Hashable`, `Iterable`, `IterableOwned`, `Movable`, `Sized`, `Writable`

Aliases:

- `IteratorType = _DictKeyIter[K(Equatable & Hashable & Copyable), V(Copyable), H, iterable_origin]`: The iterator type for this dictionary.
- `IteratorOwnedType = _DictKeyIterOwned[K(Equatable & Hashable & Deinitable & Movable), V(Deinitable & Movable), H]`: The owned iterator type for this dictionary.

#### `Dict.__init__`

```mojo
def __init__(out self)
```

Initialize an empty dictionary.

```mojo
def __init__(out self, *, capacity: Int)
```

Initialize an empty dictionary with a pre-reserved capacity.

The capacity is defined by `next_power_of_two(ceildiv(capacity * 8, 7))`
(minimum 16) to satisfy internal layout requirements. The usable
capacity before resizing is `7 // 8` of the rounded value.

Examples:

```mojo
var x = Dict[Int, Int](capacity=1000)
# Actual capacity is 2048; can hold 1792 entries without resizing.
```

Args:

- `capacity`: The requested minimum number of slots.

```mojo
def __init__(out self, var keys: List[K], var values: List[V], __dict_literal__: NoneType) where conforms_to(K, Copyable & Deinitable) and conforms_to(V, Copyable & Deinitable)
```

Constructs a dictionary from the given keys and values.

Args:

- `keys`: The list of keys to build the dictionary with.
- `values`: The corresponding values to pair with the keys.
- `__dict_literal__`: Tell Mojo to use this method for dict literals.

```mojo
def __init__(out self, *, copy: Self) where conforms_to(K, Copyable) and conforms_to(V, Copyable)
```

Copy an existing dictionary.

Args:

- `copy`: The existing dict.

#### `Dict.__bool__`

```mojo
def __bool__(self) -> Bool
```

Check if the dictionary is empty or not.

Returns: `False` if the dictionary is empty, `True` if there is at least one element.

#### `Dict.__getitem__`

```mojo
def __getitem__(ref self, ref key: K) raises -> ref[V["value"]] V
```

Retrieve a value out of the dictionary.

Args:

- `key`: The key to retrieve.

Returns: The value associated with the key, if it's present.

Raises: `DictKeyError` if the key isn't present.

#### `Dict.__setitem__`

```mojo
def __setitem__(mut self, var key: K, var value: V) where conforms_to(K, Deinitable) and conforms_to(V, Deinitable)
```

Set a value in the dictionary by key.

Constraints: Both `K` and `V` must be `Deinitable`. Assigning to an
existing key destroys the displaced entry in place.

Args:

- `key`: The key to associate with the specified value.
- `value`: The data to store in the dictionary.

#### `Dict.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where conforms_to(K, Copyable) and conforms_to(V, Equatable)
```

Checks if two dictionaries are equal.

Two dictionaries are equal if they contain the same keys and the
corresponding values are equal.

Args:

- `other`: The dictionary to compare with.

Returns: True if the dictionaries are equal, False otherwise.

#### `Dict.__contains__`

```mojo
def __contains__(self, key: K) -> Bool
```

Check if a given key is in the dictionary or not.

Args:

- `key`: The key to check.

Returns: True if the key exists in the dictionary, False otherwise.

#### `Dict.__or__`

```mojo
def __or__(self, other: Self) -> Self where conforms_to(K, Copyable & Deinitable) and conforms_to(V, Copyable & Deinitable)
```

Merge self with other and return the result as a new dict.

Args:

- `other`: The dictionary to merge with.

Returns: The result of the merge.

#### `Dict.__ior__`

```mojo
def __ior__(mut self, other: Self) where conforms_to(K, Copyable & Deinitable) and conforms_to(V, Copyable & Deinitable)
```

Merge self with other in place.

Args:

- `other`: The dictionary to merge with.

#### `Dict.fromkeys`

```mojo
def fromkeys[Keys: Iterable](ref keys: Keys, value: V) -> Self where conforms_to(K, Deinitable) if Bool(identical(Keys.IteratorType[keys_is_mut, origin_of(keys), origin_of(keys)].Element, K)) else Bool(identical(Keys.IteratorType[keys_is_mut, origin_of(keys), origin_of(keys)].Element, K)) and conforms_to(V, Copyable & Deinitable)
```

Create a new dictionary with keys from a borrowed iterable and values set to value.

Selected when the iterable is passed by reference, leaving the source
intact.

Example:

```mojo
var keys: Array[String, 3] = ["a", "b", "c"]
var dict = Dict.fromkeys(keys, 0)
print(dict)  # => {"a": 0, "b": 0, "c": 0}
```

Parameters:

- `Keys`: The type of the borrowed iterable of keys.

Args:

- `keys`: The keys to set.
- `value`: The value to set.

Returns: The new dictionary.

```mojo
def fromkeys[Keys: IterableOwned](var keys: Keys, value: V) -> Self where conforms_to(K, Deinitable) if Bool(identical(Keys.IteratorOwnedType.Element, K)) else Bool(identical(Keys.IteratorOwnedType.Element, K)) and conforms_to(V, Copyable & Deinitable)
```

Create a new dictionary with keys from an owned iterable and values set to value.

Selected when the iterable is transferred with `keys^`.

Example:

```mojo
var keys = ["a", "b", "c"]
var dict = Dict.fromkeys(keys^, 0)
print(dict)  # => {"a": 0, "b": 0, "c": 0}
```

Parameters:

- `Keys`: The type of the owned iterable of keys.

Args:

- `keys`: The keys to set.
- `value`: The value to set.

Returns: The new dictionary.

#### `Dict.deinit_with`

```mojo
def deinit_with(deinit self, deinit_func: T, /)
```

Consume the dictionary, deinitializing each key/value pair with a closure.

Use this to tear down a `Dict` whose keys or values are not
`Deinitable`.

Args:

- `deinit_func`: A closure called once per entry to destroy its key and value.

#### `Dict.insert`

```mojo
def insert(mut self, var key: K, var value: V) -> Optional[SwissTableEntry[K, V, H]]
```

Insert a key/value pair, returning the displaced entry if the key was already present.

Unlike `__setitem__`, the displaced key and value are moved out and
returned (never destroyed in place), so this works when `K` or `V` is
linear (non-`Deinitable`). The caller is responsible for
disposing of the returned entry.

Args:

- `key`: The key to associate with the value.
- `value`: The value to store.

Returns: The previous entry if `key` was already present, otherwise an empty `Optional`.

#### `Dict.__iter__`

```mojo
def __iter__(var self) -> _DictKeyIterOwned[K(Equatable & Hashable & Deinitable & Movable), V(Deinitable & Movable), H] where conforms_to(K, Equatable & Hashable & Deinitable & Movable) and conforms_to(V, Deinitable & Movable)
```

Consume the dictionary and iterate over its keys.

Returns: An iterator that owns the dictionary's keys.

```mojo
def __iter__(ref self) -> _DictKeyIter[K(Equatable & Hashable & Copyable), V(Copyable), H, origin_of(self)]
```

Iterate over the dict's keys as immutable references.

Returns: An iterator of immutable references to the dictionary keys.

#### `Dict.__reversed__`

```mojo
def __reversed__(ref self) -> _DictKeyIter[K(Equatable & Hashable & Copyable), V(Copyable), H, origin_of(self), False] where conforms_to(K, Equatable & Hashable & Copyable) and conforms_to(V, Copyable)
```

Iterate backwards over the dict keys, returning immutable references.

Returns: A reversed iterator of immutable references to the dict keys.

#### `Dict.__len__`

```mojo
def __len__(self) -> Int
```

The number of elements currently stored in the dictionary.

Returns: The number of elements currently stored in the dictionary.

#### `Dict.__hash__`

```mojo
def __hash__[H2: Hasher](self, mut hasher: H2) where conforms_to(K, Copyable) and conforms_to(V, Hashable)
```

Hashes the dictionary using the given hasher.

The hash is order-independent: two dictionaries with the same key-value
pairs will have the same hash regardless of insertion order.

Parameters:

- `H2`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `Dict.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(K, Writable) if conforms_to(K, Copyable) else conforms_to(K, Copyable) and conforms_to(V, Writable)
```

Write this `Dict` to the writer.

Args:

- `writer`: The value to write to.

#### `Dict.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(K, Writable) if conforms_to(K, Copyable) else conforms_to(K, Copyable) and conforms_to(V, Writable)
```

Write this `Dict`'s representation to the writer.

Args:

- `writer`: The value to write to.

#### `Dict.find`

```mojo
def find(self, key: K) -> Optional[V] where conforms_to(V, Copyable)
```

Find a value in the dictionary by key.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
var value = my_dict.find("a")
print(value)  # => 1
var missing_value = my_dict.find("c")
print(missing_value)  # => None
```

Args:

- `key`: The key to search for in the dictionary.

Returns: An optional value containing a copy of the value if it was present, otherwise an empty Optional.

#### `Dict.get`

```mojo
def get(self, key: K) -> Optional[V] where conforms_to(V, Copyable)
```

Get a value from the dictionary by key.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
var value = my_dict.get("a")
print(value)  # => 1

var missing_value = my_dict.get("c")
print(missing_value)  # => -1

from std.testing import assert_true
assert_true(my_dict["a"] == my_dict.get("a").or_else(Int.MAX))
```

Args:

- `key`: The key to search for in the dictionary.

Returns: An optional value containing a copy of the value if it was present, otherwise an empty Optional.

```mojo
def get(self, key: K, var default: V) -> V where conforms_to(V, Copyable & Deinitable)
```

Get a value from the dictionary by key.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
var value = my_dict.get("a", Int.MAX)
print(value)  # => 1

var missing_value = my_dict.get("c", -1)
print(missing_value)  # => -1

from std.testing import assert_true
assert_true(my_dict["a"] == my_dict.get("a", Int.MAX))
```

Args:

- `key`: The key to search for in the dictionary.
- `default`: Default value to return.

Returns: A copy of the value if it was present, otherwise default.

#### `Dict.pop`

```mojo
def pop(mut self, key: K, var default: V) -> V where conforms_to(K, Deinitable) and conforms_to(V, Deinitable)
```

Remove a value from the dictionary by key.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
var value = my_dict.pop("a", 99)
print(value)  # => 1
var missing_value = my_dict.pop("c", 99)
print(missing_value)  # => 99
```

Constraints: Both `K` and `V` must be `Deinitable`. Removing an entry
discards its key and returns only the value; the unused `default` is
also discarded when the key is found. Use `popitem()` to retrieve
both key and value.

Args:

- `key`: The key to remove from the dictionary.
- `default`: A default value to return if the key was not found instead of raising.

Returns: The value associated with the key, if it was in the dictionary. If it wasn't, return the provided default value instead.

```mojo
def pop(mut self, ref key: K) raises -> V where conforms_to(K, Deinitable)
```

Remove a value from the dictionary by key.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
var value = my_dict.pop("a", 99)
print(value)  # => 1
var missing_value = my_dict.pop("c", 99)
print(missing_value)  # => 99
```

Constraints: `K` must be `Deinitable`. Removing an entry discards its
key and returns only the value. Use `popitem()` to retrieve both.

Args:

- `key`: The key to remove from the dictionary.

Returns: The value associated with the key, if it was in the dictionary. Raises otherwise.

Raises: `DictKeyError` if the key was not present in the dictionary.

#### `Dict.popitem`

```mojo
def popitem(mut self) raises -> SwissTableEntry[K, V, H]
```

Remove and return a (key, value) pair from the dictionary.

Notes:
Pairs are returned in LIFO order. popitem() is useful to
destructively iterate over a dictionary, as often used in set
algorithms. If the dictionary is empty, calling popitem() raises a
EmptyDictError.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
print(len(my_dict))  # => 2

var item = my_dict.popitem()
print(item.key, item.value)  # => Either "b", 2 or "a", 1
print(len(my_dict))  # => 1
```

Returns: Last dictionary item

Raises: `EmptyDictError` if the dictionary is empty.

#### `Dict.keys`

```mojo
def keys(ref self) -> _DictKeyIter[K(Equatable & Hashable & Copyable), V(Copyable), H, origin_of(self)]
```

Iterate over the dict's keys as immutable references.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
for key in my_dict.keys():
    print(key) # prints a then b or b then a
    # All keys will be printed, but order is not guaranteed
```

Returns: An iterator of immutable references to the dictionary keys.

#### `Dict.values`

```mojo
def values(ref self) -> _DictValueIter[K(Equatable & Hashable & Copyable), V(Copyable), H, origin_of(self)] where conforms_to(K, Equatable & Hashable & Copyable) and conforms_to(V, Copyable)
```

Iterate over the dict's values as references.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
for value in my_dict.values():
    print(value) # prints 1 then 2 or 2 then 1
    # All values will be printed, but order is not guaranteed
```

Returns: An iterator of references to the dictionary values.

#### `Dict.items`

```mojo
def items(ref self) -> _DictEntryIter[K(Equatable & Hashable & Copyable), V(Copyable), H, origin_of(self)]
```

Iterate over the dict's entries as immutable references.

Examples:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2

for item in my_dict.items():
    print(item.key, item.value) # prints a 1 then b 2 or b 2 then a 1
    # All entries will be printed, but order is not guaranteed
```

Notes:
These can't yet be unpacked like Python dict items, but you can
access the key and value as attributes.

Returns: An iterator of immutable references to the dictionary entries.

#### `Dict.take_items`

```mojo
def take_items(mut self) -> _TakeDictEntryIter[K(Equatable & Hashable & Deinitable & Movable), V(Deinitable & Movable), H, origin_of(self)] where conforms_to(K, Equatable & Hashable & Deinitable & Movable) and conforms_to(V, Deinitable & Movable)
```

Iterate over the dict's entries and move them out of the dictionary effectively draining the dictionary.

Examples:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2

for entry in my_dict.take_items():
    print(entry.key, entry.value) # prints a 1 then b 2 or b 2 then a 1
    # All entries will be printed, but order is not guaranteed

print(len(my_dict))
# prints 0
```

Returns: An iterator of mutable references to the dictionary entries that moves them out of the dictionary.

#### `Dict.update`

```mojo
def update(mut self, other: Self, /) where conforms_to(K, Copyable & Deinitable) and conforms_to(V, Copyable & Deinitable)
```

Update the dictionary with the key/value pairs from other, overwriting existing keys.

Notes:
The argument must be positional only.

Example:

```mojo
var dict1 = Dict[String, Int]()
dict1["a"] = 1
dict1["b"] = 2
var dict2 = Dict[String, Int]()
dict2["b"] = 3
dict2["c"] = 4
dict1.update(dict2)
print(dict1)  # => {"a": 1, "b": 3, "c": 4}
```

Args:

- `other`: The dictionary to update from.

#### `Dict.clear`

```mojo
def clear(mut self) where conforms_to(K, Deinitable) and conforms_to(V, Deinitable)
```

Remove all elements from the dictionary.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2
print(len(my_dict))  # => 2
my_dict.clear()
print(len(my_dict))  # => 0
```

Constraints: Both `K` and `V` must be `Deinitable`, since every entry is
destroyed in place.

#### `Dict.clear_with`

```mojo
def clear_with(mut self, destroy_func: T, /)
```

Remove all elements, disposing each entry with a closure.

The closure counterpart of `clear`: instead of destroying each entry in
place, it hands the key and value to `destroy_func`. Use this to clear a
`Dict` whose keys or values are not `Deinitable`. The
dictionary's capacity is retained, so it can be reused without
reallocating.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2

var cleared = List[Int]()

def dispose(var key: String, var value: Int) {mut}:
    cleared.append(value)

my_dict.clear_with(dispose)
print(len(my_dict))     # => 0
print(len(cleared))     # => 2
```

Args:

- `destroy_func`: A closure called once per entry to dispose its key and value.

#### `Dict.setdefault`

```mojo
def setdefault(mut self, var key: K, var default: V) -> ref[self["value"]] V where conforms_to(K, Deinitable) and conforms_to(V, Deinitable)
```

Get a value from the dictionary by key, or set it to a default if it doesn't exist.

Example:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
var value1 = my_dict.setdefault("a", 99)
print(value1)  # => 1

var value2 = my_dict.setdefault("b", 99)
print(value2)  # => 99
print(my_dict)  # => {"a": 1, "b": 99}
```

Args:

- `key`: The key to search for in the dictionary.
- `default`: The default value to set if the key is not present.

Returns: The value associated with the key, or the default value if it wasn't present.

### `StringDict`

```mojo
struct StringDict[V: Movable]
```

Container used to pass owned variadic keyword arguments to functions.

This type mimics the interface of a dictionary with `String` keys, and
should be usable more-or-less like a dictionary. Notably, however, this type
should not be instantiated directly by users.

Parameters:

- `V`: The value type of the dictionary. Must be `Movable`. When `V` is not `Deinitable`, the dictionary has no implicit destructor and must be torn down with `deinit_with()`.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Iterable`, `Movable`, `Sized`, `Writable`

Aliases:

- `key_type = String`: The key type for this dictionary (always String).
- `IteratorType = _DictKeyIter[String, V(Copyable), Fnv1a, iterable_origin]`: The iterator type for this dictionary.

#### `StringDict.__init__`

```mojo
def __init__(out self)
```

Initialize an empty keyword dictionary.

#### `StringDict.__getitem__`

```mojo
def __getitem__(ref self, ref key: String) raises -> ref[self_is_mut._dict["value"]] V
```

Retrieve a value out of the keyword dictionary.

Args:

- `key`: The key to retrieve.

Returns: The value associated with the key, if it's present.

Raises: `DictKeyError` if the key isn't present.

```mojo
def __getitem__(ref self, key: StringSpan) raises -> ref[self_is_mut._dict["value"]] V
```

Retrieve a value by string view, without allocating a `String`.

Args:

- `key`: The key to retrieve, as a string view.

Returns: The value associated with the key, if it's present.

Raises: `DictKeyError` if the key isn't present.

#### `StringDict.__setitem__`

```mojo
def __setitem__(mut self, key: String, var value: V) where conforms_to(V, Deinitable)
```

Set a value in the keyword dictionary by key.

Constraints: `V` must be `Deinitable`, since assigning to an existing key
destroys the displaced value in place. To populate a keyword
dictionary with a linear `V`, use `insert()` instead.

Args:

- `key`: The key to associate with the specified value.
- `value`: The data to store in the dictionary.

#### `StringDict.__contains__`

```mojo
def __contains__(self, key: String) -> Bool
```

Check if a given key is in the keyword dictionary or not.

Args:

- `key`: The key to check.

Returns: True if there key exists in the keyword dictionary, False otherwise.

#### `StringDict.deinit_with`

```mojo
def deinit_with(deinit self, deinit_func: T, /)
```

Consume the dictionary, deinitializing each key/value pair with a closure.

Use this to tear down a keyword dictionary whose values are not
`Deinitable`.

Args:

- `deinit_func`: A closure called once per entry to destroy its key and value.

#### `StringDict.__len__`

```mojo
def __len__(self) -> Int
```

The number of elements currently stored in the keyword dictionary.

Returns: The number of elements currently stored in the keyword dictionary.

#### `StringDict.write_to`

```mojo
def write_to(self, mut writer: T) where conforms_to(V, Writable)
```

Write this `StringDict` to the writer.

Args:

- `writer`: The value to write to.

#### `StringDict.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T) where conforms_to(V, Writable)
```

Write this `StringDict`'s representation to the writer.

Args:

- `writer`: The value to write to.

#### `StringDict.find`

```mojo
def find(self, key: String) -> Optional[V] where conforms_to(V, Copyable)
```

Find a value in the keyword dictionary by key.

Args:

- `key`: The key to search for in the dictionary.

Returns: An optional value containing a copy of the value if it was present, otherwise an empty Optional.

#### `StringDict.insert`

```mojo
def insert(mut self, var key: String, var value: V) -> Optional[SwissTableEntry[String, V, Fnv1a]]
```

Insert a key/value pair, returning the displaced entry if the key was already present.

Unlike `__setitem__`, the displaced entry is moved out and returned
(never destroyed in place), so this works when `V` is linear
(non-`Deinitable`). The caller is responsible for disposing of
the returned entry.

Args:

- `key`: The key to associate with the value.
- `value`: The value to store.

Returns: The previous entry if `key` was already present, otherwise an empty `Optional`.

#### `StringDict.popitem`

```mojo
def popitem(mut self) raises -> SwissTableEntry[String, V, Fnv1a]
```

Remove and return a (key, value) pair from the dictionary.

The entry is moved out whole (nothing is destroyed in place), so this
works when `V` is linear. The caller is responsible for disposing of the
returned entry.

Returns: The removed entry.

Raises: `EmptyDictError` if the dictionary is empty.

#### `StringDict.pop`

```mojo
def pop(mut self, key: String, var default: V) -> V where conforms_to(V, Deinitable)
```

Remove a value from the dictionary by key.

Constraints: `V` must be `Deinitable`, since the unused `default` is
discarded in place when the key is found. To remove from a keyword
dictionary with a linear `V`, use `pop(key)` or `popitem()`.

Args:

- `key`: The key to remove from the dictionary.
- `default`: A default value to return if the key was not found instead of raising.

Returns: The value associated with the key, if it was in the dictionary. If it wasn't, return the provided default value instead.

```mojo
def pop(mut self, ref key: String) raises -> V
```

Remove a value from the dictionary by key.

Args:

- `key`: The key to remove from the dictionary.

Returns: The value associated with the key, if it was in the dictionary. Raises otherwise.

Raises: `DictKeyError` if the key was not present in the dictionary.

#### `StringDict.__iter__`

```mojo
def __iter__(ref self) -> _DictKeyIter[String, V(Copyable), Fnv1a, origin_of(self)]
```

Iterate over the keyword dict's keys as immutable references.

Returns: An iterator of immutable references to the dictionary keys.

#### `StringDict.keys`

```mojo
def keys(ref self) -> _DictKeyIter[String, V(Copyable), Fnv1a, origin_of(self._dict)]
```

Iterate over the keyword dict's keys as immutable references.

Returns: An iterator of immutable references to the dictionary keys.

#### `StringDict.values`

```mojo
def values(ref self) -> _DictValueIter[String, V(Copyable), Fnv1a, origin_of(self._dict)] where conforms_to(V, Copyable)
```

Iterate over the keyword dict's values as references.

Returns: An iterator of references to the dictionary values.

#### `StringDict.items`

```mojo
def items(ref self) -> _DictEntryIter[String, V(Copyable), Fnv1a, origin_of(self._dict)] where conforms_to(V, Copyable)
```

Iterate over the keyword dictionary's entries as immutable references.

Examples:

```mojo
var my_dict = Dict[String, Int]()
my_dict["a"] = 1
my_dict["b"] = 2

for e in my_dict.items():
    print(e.key, e.value)
```

Notes:
These can't yet be unpacked like Python dict items, but you can
access the key and value as attributes.

Returns: An iterator of immutable references to the dictionary entries.

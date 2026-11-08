# `std.collections.bitset`

Provides a compact set of non-negative integers backed by inline storage.

Optimized for space (1 bit per element) and speed (O(1) operations).
Offers set/clear/test/toggle and fast population count.

Example:
```mojo
from std.collections import BitSet

var bs = BitSet[128]()  # 128-bit set, all clear
bs.set(42)              # Mark value 42 as present.
if bs.test(42):         # Check membership.
    print("hit")        # Prints "hit".
bs.clear(42)            # Remove 42.
print(len(bs))          # Prints 0.
```

## Structs

### `BitSet`

```mojo
struct BitSet[size: Int]
```

A grow-only set storing non-negative integers efficiently using bits.

Each integer element is represented by a single bit within an array
of 64-bit words (`Int64`). This structure is optimized for:

*   **Compactness:** Uses 64 times less memory than `List[Bool]`.
*   **Speed:** Offers O(1) time complexity for `set`, `clear`, `test`,
    and `toggle` operations (single word load/store).

Ideal for applications like data-flow analysis, graph algorithms, or
any task requiring dense sets of small integers where memory and
lookup speed are critical.

Parameters:

- `size`: The maximum number of bits the bitset can store.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`, `Sized`, `Writable`

#### `BitSet.__init__`

```mojo
def __init__(out self)
```

Initializes an empty BitSet with zero capacity and size.

```mojo
def __init__(out self: BitSet[init.length], init: SIMD[.bool])
```

Initializes a BitSet with the given SIMD vector of booleans.

Args:

- `init`: A SIMD vector of booleans to initialize the bitset with.

```mojo
def __init__[other_size: Int, //, *, truncate: Bool = False](out self, *, resized_from: BitSet[other_size])
```

Initializes a BitSet by copying from a BitSet of a different size.

if `truncate` is `False`, this constructor will `debug_assert` that no
set bits are lost when narrowing. If `truncate` is `True`, the
constructor will silently drop any set bits at or above the new size.
When narrowing, bits at or above `size` are dropped; when widening, the
new high bits are cleared.

Parameters:

- `other_size`: The `size` of the source bitset.
- `truncate`: Whether or not to allow truncating set bits.

Args:

- `resized_from`: The BitSet to copy from.

```mojo
def __init__[other_size: Int, //](out self, *, resized_from: BitSet[other_size], truncate_set_bits: Tuple)
```

Initializes a BitSet by copying from a BitSet of a different size.

When narrowing, bits at or above `size` are dropped; when widening, the
new high bits are cleared.

Parameters:

- `other_size`: The `size` of the source bitset.

Args:

- `resized_from`: The BitSet to copy from.
- `truncate_set_bits`: A marker argument to disambiguate an overload.

#### `BitSet.__bool__`

```mojo
def __bool__(self) -> Bool
```

Checks if the bitset is non-empty (contains at least one set bit).

Returns: True if at least one bit is set, False otherwise.

#### `BitSet.__len__`

```mojo
def __len__(self) -> Int
```

Counts the total number of bits that are set to 1 in the bitset.

Uses the efficient `pop_count` intrinsic for each underlying word.
The complexity is proportional to the number of words used by the
bitset's capacity (`_words_size`), not the logical size (`len`).

Returns: The total count of set bits (population count).

#### `BitSet.set`

```mojo
def set(mut self, idx: Int)
```

Sets the bit at the specified index `idx` to 1.

If `idx` is greater than or equal to the current logical size,
the logical size is updated. Aborts if `idx` is negative or
greater than or equal to the compile-time `size`.

Args:

- `idx`: The non-negative index of the bit to set (must be < `size`).

#### `BitSet.clear`

```mojo
def clear(mut self, idx: Int)
```

Clears the bit at the specified index `idx` (sets it to 0).

Aborts if `idx` is negative or greater than or equal to the
compile-time `size`. Does not change the logical size.

Args:

- `idx`: The non-negative index of the bit to clear (must be < `size`).

#### `BitSet.toggle`

```mojo
def toggle(mut self, idx: Int)
```

Toggles (inverts) the bit at the specified index `idx`.

If the bit becomes 1 and `idx` is greater than or equal to the
current logical size, the logical size is updated. Aborts if `idx`
is negative or greater than or equal to the compile-time `size`.

Args:

- `idx`: The non-negative index of the bit to toggle (must be < `size`).

#### `BitSet.test`

```mojo
def test(self, idx: Int) -> Bool
```

Tests if the bit at the specified index `idx` is set (is 1).

Aborts if `idx` is negative or greater than or equal to the
compile-time `size`.

Args:

- `idx`: The non-negative index of the bit to test (must be < `size`).

Returns: True if the bit at `idx` is set, False otherwise.

#### `BitSet.test_range`

```mojo
def test_range[bit_value: Bool, *, lo: Int = Int(0), hi: Int = size, max_unroll: Int = Int(16)](self) -> Bool
```

Tests whether every bit in `[lo, hi)` equals `bit_value`.

With `lo`/`hi` known at compile time, the word indices, bit offsets,
and boundary masks all fold away. The two boundary words are masked
and checked scalar; the interior full words are checked in SIMD
batches. An empty range is vacuously true.

Parameters:

- `bit_value`: The value every in-range bit must have (1 if True, else 0).
- `lo`: The low bit index, inclusive.
- `hi`: The high bit index, exclusive.
- `max_unroll`: The maximum unroll factor for SIMD loops.

Returns: True if every bit in the range equals `bit_value`, False otherwise.

#### `BitSet.clear_all`

```mojo
def clear_all(mut self)
```

Clears all bits in the set, resetting the logical size to 0.

The allocated storage capacity remains unchanged. Equivalent to
re-initializing the set with `Self()`.

#### `BitSet.toggle_all`

```mojo
def toggle_all(mut self)
```

Toggles (inverts) all bits in the set up to the compile-time `size`.

#### `BitSet.set_all`

```mojo
def set_all(mut self)
```

Sets all bits in the set up to the compile-time `size`.

#### `BitSet.union`

```mojo
def union(self, other: Self) -> Self
```

Returns a new bitset that is the union of `self` and `other`.

Args:

- `other`: The bitset to union with.

Returns: A new bitset containing all elements from both sets.

#### `BitSet.intersection`

```mojo
def intersection(self, other: Self) -> Self
```

Returns a new bitset that is the intersection of `self` and `other`.

Args:

- `other`: The bitset to intersect with.

Returns: A new bitset containing only the elements present in both sets.

#### `BitSet.difference`

```mojo
def difference(self, other: Self) -> Self
```

Returns a new bitset that is the difference of `self` and `other`.

Args:

- `other`: The bitset to subtract from `self`.

Returns: A new bitset containing elements from `self` that are not in `other`.

#### `BitSet.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes a string representation of the set bits to the given writer. Outputs the indices of the set bits in ascending order, enclosed in curly braces and separated by commas (e.g., "{1, 5, 42}"). Uses efficient bitwise operations to find set bits without iterating through every possible bit.

Args:

- `writer`: The writer instance to output the representation to.

#### `BitSet.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the string representation of the `BitSet` to the writer.

Args:

- `writer`: The value to write to.

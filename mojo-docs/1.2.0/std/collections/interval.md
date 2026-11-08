# `std.collections.interval`

A self-balancing interval tree is a specialized binary search tree designed to efficiently store and query intervals.

It maintains intervals sorted by their low endpoints and augments each node with a
`max_high` attribute, representing the maximum high endpoint in its subtree. This
`max_high` value enables efficient overlap searching by pruning the search space.
Self-balancing mechanisms, such as Red-Black or AVL trees, ensure logarithmic time
complexity for operations.

Key Features:
  - Stores intervals (low, high).
  - Nodes ordered by `low` endpoints.
  - `max_high` attribute at each node for efficient overlap search.
  - Self-balancing (e.g., using Red-Black tree logic) for O(log n) operations.

Operations:
  - Insertion: O(log n) - Adds a new interval, maintaining balance and updating
    `max_high`.
  - Overlap Search: O(log n) - Finds intervals overlapping a query interval using
    `max_high` for pruning.
  - Deletion: O(log n) - Removes an interval, maintaining balance and updating
    `max_high`.

Space Complexity: O(n), where n is the number of intervals.

Use Cases:
  - Calendar scheduling
  - Computational geometry
  - Genomics
  - Database indexing
  - Resource allocation

In essence, this data structure provides a fast and efficient way to manage and
query interval data, particularly for finding overlaps.

## Structs

### `Interval`

```mojo
struct Interval[T: IntervalElement]
```

A half-open interval [start, end) that represents a range of values.

The interval includes the start value but excludes the end value.

Parameters:

- `T`: The type of the interval bounds.

Fields:

- `start` (`T`): The inclusive start of the interval.
- `end` (`T`): The exclusive end of the interval.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Sized`, `Writable`

#### `Interval.__init__`

```mojo
def __init__(out self, start: T, end: T)
```

Initialize an interval with start and end values.

Args:

- `start`: The starting value of the interval.
- `end`: The ending value of the interval. Must be greater than or equal to start.

```mojo
def __init__(out self, interval: Tuple[T, T], /)
```

Initialize an interval with a tuple of start and end values.

Args:

- `interval`: A tuple containing the start and end values.

```mojo
def __init__(out self, *, copy: Self)
```

Create a new instance of the interval by copying the values from an existing one.

Args:

- `copy`: The interval to copy values from.

#### `Interval.__bool__`

```mojo
def __bool__(self) -> Bool
```

Returns whether this interval is empty.

Returns: True if the interval is not empty (start < end), False otherwise.

#### `Interval.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool
```

Returns whether this interval is less than another interval.

Args:

- `other`: The interval to compare with.

Returns: True if this interval's start is less than the other interval's start.

#### `Interval.__le__`

```mojo
def __le__(self, other: Self) -> Bool
```

Returns whether this interval is less than or equal to another interval.

Args:

- `other`: The interval to compare with.

Returns: True if this interval's start is less than or equal to the other interval's start.

#### `Interval.__gt__`

```mojo
def __gt__(self, other: Self) -> Bool
```

Returns whether this interval is greater than another interval.

Args:

- `other`: The interval to compare with.

Returns: True if this interval's end is greater than the other interval's end.

#### `Interval.__ge__`

```mojo
def __ge__(self, other: Self) -> Bool
```

Returns whether this interval is greater than or equal to another interval.

Args:

- `other`: The interval to compare with.

Returns: True if this interval's end is greater than or equal to the other interval's end.

#### `Interval.__contains__`

```mojo
def __contains__(self, other: T) -> Bool
```

Returns whether a value is contained within this interval.

Args:

- `other`: The value to check.

Returns: True if the value is within the interval bounds, False otherwise.

```mojo
def __contains__(self, other: Self) -> Bool
```

Returns whether another interval is fully contained within this interval.

Args:

- `other`: The interval to check.

Returns: True if the other interval is fully contained within this interval, False otherwise.

#### `Interval.overlaps`

```mojo
def overlaps(self, other: Self) -> Bool
```

Returns whether this interval overlaps with another interval.

Args:

- `other`: The interval to check for overlap with.

Returns: True if the intervals overlap, False otherwise.

#### `Interval.union`

```mojo
def union(self, other: Self) -> Self
```

Returns the union of this interval and another interval.

Args:

- `other`: The interval to union with.

Returns: The union of this interval and the other interval.

#### `Interval.intersection`

```mojo
def intersection(self, other: Self) -> Self
```

Returns the intersection of this interval and another interval.

Args:

- `other`: The interval to intersect with.

Returns: The intersection of this interval and the other interval.

#### `Interval.__len__`

```mojo
def __len__(self) -> Int
```

Returns the length of this interval.

Returns: The difference between end and start values as an integer.

#### `Interval.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes this interval to a writer in the format '(start, end)'.

Args:

- `writer`: The writer to write the interval to.

### `IntervalTree`

```mojo
struct IntervalTree[T: IntervalElement, U: Comparable & Writable & Copyable & Deinitable]
```

An interval tree data structure for efficient range queries.

Parameters:

- `T`: The type of the interval bounds, must support subtraction, integer conversion, string conversion, comparison and collection operations.
- `U`: The type of the associated data, must support string conversion and collection operations.

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`, `Writable`

#### `IntervalTree.__init__`

```mojo
def __init__(out self)
```

Initializes an empty IntervalTree.

#### `IntervalTree.__deinit__`

```mojo
def __deinit__(deinit self)
```

Destructor that frees the interval tree's memory.

#### `IntervalTree.insert`

```mojo
def insert(mut self, interval: Tuple[T, T], data: U)
```

Insert a new interval into the tree using a tuple representation.

Args:

- `interval`: A tuple containing the start and end values of the interval.
- `data`: The data value to associate with this interval.

```mojo
def insert(mut self, interval: Interval[T], data: U)
```

Insert a new interval into the tree.

This method inserts a new interval and its associated data into the interval tree.
It maintains the binary search tree property based on interval start times and
updates the tree structure to preserve red-black tree properties.

Args:

- `interval`: The interval to insert into the tree.
- `data`: The data value to associate with this interval.

#### `IntervalTree.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes the interval tree to a writer.

Args:

- `writer`: The writer to write the interval tree to.

#### `IntervalTree.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this `IntervalTree` to a writer.

Args:

- `writer`: The object to write to.

#### `IntervalTree.depth`

```mojo
def depth(self) -> Int
```

Returns the depth of the interval tree.

Returns: The depth of the interval tree.

#### `IntervalTree.transplant`

```mojo
def transplant(mut self, mut u: Optional[Pointer[_IntervalNode[T, U], MutUntrackedOrigin]], mut v: Optional[Pointer[_IntervalNode[T, U], MutUntrackedOrigin]])
```

Transplants the subtree rooted at node u with the subtree rooted at node v.

Args:

- `u`: The node to transplant.
- `v`: The node to transplant to.

#### `IntervalTree.search`

```mojo
def search(self, interval: Tuple[T, T]) raises -> List[U]
```

Searches for intervals overlapping with the given tuple.

Args:

- `interval`: The interval tuple (start, end).

Returns: A list of data associated with overlapping intervals.

Raises: If the operation fails.

```mojo
def search(self, interval: Interval[T]) raises -> List[U]
```

Searches for intervals overlapping with the given interval.

Args:

- `interval`: The interval to search.

Returns: A list of data associated with overlapping intervals.

Raises: If the operation fails.

## Traits

### `IntervalElement`

```mojo
trait IntervalElement
```

The trait denotes a trait composition of the `Copyable`, `Writable`, `Intable`, and `Comparable` traits. Which is also subtractable.

Inherits from: `AnyType`, `Comparable`, `Copyable`, `Deinitable`, `Equatable`, `Intable`, `Movable`, `Writable`

#### `IntervalElement.__sub__`

```mojo
def __sub__(self, rhs: Self) -> Self
```

Subtracts rhs from self, must be implemented in concrete types.

Args:

- `rhs`: The value to subtract from self.

Returns: The result of subtracting rhs from self.

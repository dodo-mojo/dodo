# `std.iter`

Iteration traits and utilities: Iterable, IterableOwned, Iterator, enumerate, zip, map.

This package defines the core iteration protocol for Mojo through the
`Iterable`, `IterableOwned`, and `Iterator` traits. Types that conform to
these traits can be used with `for` loops and iteration utilities like
`enumerate()`, `zip()`, and `map()`.

The iteration protocol consists of three key traits:

- `Iterable`: Types that can produce an iterator by borrowing (`ref self`).
  The iterator borrows the collection and yields references or copies of
  elements without consuming the source.
- `IterableOwned`: Types that can produce an iterator by taking ownership
  (`var self`). The iterator consumes the collection, taking ownership of
  its elements.
- `Iterator`: Types that can produce a sequence of values one at a time.

Examples:

```mojo
from std.iter import enumerate, zip, map

# Enumerate with index
var items = ["a", "b", "c"]
for index, value in enumerate(items):
    print(index, value)

# Zip multiple iterables
var numbers = [1, 2, 3]
var letters = ["x", "y", "z"]
for num, letter in zip(numbers, letters):
    print(num, letter)

# Map a function over an iterable
var values = [1, 2, 3, 4]
for squared in map[lambda (x: Int) -> Int: x * x](values):
    print(squared)
```

## Structs

### `StopIteration`

```mojo
struct StopIteration
```

A custom error type for Iterator's that run out of elements.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

#### `StopIteration.write_to`

```mojo
def write_to(self, mut writer: T)
```

This always writes "StopIteration".

Args:

- `writer`: The writer to write to.

## Traits

### `Iterable`

```mojo
trait Iterable
```

Describes a type that can produce an iterator by borrowing.

Conforming types implement `__iter__(ref self)`, which borrows the
collection (immutably or mutably, depending on the call-site origin) and
returns an iterator whose elements may reference the source data. The
collection remains usable after iteration.

Inherits from: `AnyType`

Aliases:

- `IteratorType`: The iterator type returned when borrowing this collection.

#### `Iterable.__iter__`

```mojo
def __iter__(ref self) -> Self.IteratorType[self_is_mut, origin_of(self), origin_of(self)]
```

Borrows the collection and returns an iterator over its elements.

Returns: An iterator over the elements.

### `IterableOwned`

```mojo
trait IterableOwned
```

Describes a type that can produce an iterator by giving up ownership.

Conforming types implement `__iter__(var self)`, which takes the collection
by value and returns an iterator that owns the underlying data.

Use `IterableOwned` when the caller no longer needs the collection after
iteration, or when yielding owned elements is more natural (e.g. draining
a temporary result).

Inherits from: `AnyType`

Aliases:

- `IteratorOwnedType`: The iterator type returned when the collection is consumed.

#### `IterableOwned.__iter__`

```mojo
def __iter__(var self) -> Self.IteratorOwnedType
```

Consumes the collection and returns an iterator over its elements.

Returns: An iterator that owns the collection's elements.

### `Iterator`

```mojo
trait Iterator
```

The `Iterator` trait describes a type that can be used as an iterator, e.g. in a `for` loop.

Inherits from: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `Element`

#### `Iterator.__next__`

```mojo
def __next__(mut self) raises -> Self.Element
```

Returns the next element from the iterator.

Returns: The next element.

Raises: StopIteration if there are no more elements.

#### `Iterator.bounds`

```mojo
def bounds(self) -> Tuple[Int, Optional[Int]]
```

Returns bounds `[lower, upper]` for the remaining iterator length.

This helps collections pre-allocate memory when constructed from iterators.
The default implementation returns `(0, None)`.

Safety:

If the upper bound is not None, implementations must ensure that `lower <= upper`.
The bounds are hints only - iterators may not comply with them. Never omit safety
checks when using `bounds` to build collections.

Examples:

```mojo
from std.iter import Iterator

def preallocate[I: Iterator](mut iter: I) -> List[Int]:
    var lower, _upper = iter.bounds()
    # Pre-allocate based on estimated iterator length
    return List[Int](capacity=lower)
```

Returns: A tuple where the first element is the lower bound and the second is an optional upper bound (`None` means unknown or `upper > Int.MAX`).

#### `Iterator.nth`

```mojo
def nth(var self, n: Int) -> Optional[Self.Element]
```

Advances the iterator by `n` elements (destroying them) and returns the next element, or `None` if the iterator is exhausted first.

Examples:

```mojo
var l = [10, 20, 30, 40]
print(iter(l).nth(0).value())   # 10
print(iter(l).nth(3).value())   # 40
var missing = iter(l).nth(10)   # None
```

Constraints: `Self.Element` must conform to `Deinitable` so the
intermediate elements can be discarded.

Args:

- `n`: The 0-indexed position of the element to return. Must be non-negative.

Returns: The element at index `n`, or `None` if the iterator has fewer than `n + 1` remaining elements.

## Functions

### `iter`

```mojo
def iter(var iterable: T) -> T.IteratorOwnedType
```

Constructs an owned iterator from an iterable.

Args:

- `iterable`: The iterable to construct the iterator from.

Returns: An owned iterator for the given iterable.

```mojo
def iter[IterableType: Iterable](ref iterable: IterableType) -> IterableType.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)]
```

Constructs a borrowed iterator from an iterable.

Parameters:

- `IterableType`: The type of the iterable.

Args:

- `iterable`: The iterable to construct the iterator from.

Returns: A borrowed iterator for the given iterable.

### `next`

```mojo
def next[IteratorType: Iterator](mut iterator: IteratorType) raises -> IteratorType.Element
```

Advances the iterator and returns the next element.

Parameters:

- `IteratorType`: The type of the iterator.

Args:

- `iterator`: The iterator to advance.

Returns: The next element from the iterator.

Raises: StopIteration: If the iterator is exhausted.

### `empty`

```mojo
def empty[T: Movable]() -> _Empty[T]
```

Creates an iterator that yields nothing.

Parameters:

- `T`: Type of the iterator's notional elements.

Returns: An iterator that yields nothing.

### `once`

```mojo
def once[T: Deinitable & Movable, //](var element: T, /) -> _Once[T]
```

Creates an iterator that yields an element exactly once.

Parameters:

- `T`: The type of the element to be yielded exactly once.

Args:

- `element`: The element to be yielded exactly once.

Returns: An iterator that yields the specified element exactly once.

### `enumerate`

```mojo
def enumerate[IterableType: Iterable](ref iterable: IterableType, *, start: Int = Int(0)) -> _Enumerate[IterableType.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)]]
```

Returns an iterator that yields tuples of the index and the element of the original iterator.

Examples:

```mojo
var l = ["hey", "hi", "hello"]
for i, elem in enumerate(l):
    print(i, elem)
```

Parameters:

- `IterableType`: The type of the iterable.

Args:

- `iterable`: An iterable object (e.g., list, string, etc.).
- `start`: The starting index for enumeration (default is 0).

Returns: An enumerate iterator that yields tuples of `(index, element)`.

```mojo
def enumerate(var iterable: T, *, start: Int = Int(0)) -> _Enumerate[T.IteratorOwnedType]
```

Returns an iterator that yields tuples of the index and the element of the original iterator, consuming the iterable.

Args:

- `iterable`: An iterable object to consume and enumerate.
- `start`: The starting index for enumeration (default is 0).

Returns: An enumerate iterator that yields tuples of `(index, element)`.

### `zip`

```mojo
def zip[*Ts: Iterable](*iterables: *Ts.values, out res: _ZipIterator[iterables.origin, *#kgen.param_list.tabulate(len(Ts.values), [idx: __mlir_type.index] Ts.values[idx].IteratorType[False, origin_of(iterables.origin), iterables.origin])]) where True
```

Returns an iterator that yields tuples of the elements of the original iterables.

Examples:

```mojo
var l = ["hey", "hi", "hello"]
var l2 = [10, 20, 30]
for a, b in zip(l, l2):
    print(a, b)
```

Parameters:

- `*Ts`: The type of the iterables.

Args:

- `*iterables`: The iterables.

Returns: A zip iterator that yields tuples of elements from all iterables.

```mojo
def zip[*Ts: IterableOwned](var *iterables: *Ts.values, out res: _ZipIterator[MutUntrackedOrigin, *#kgen.param_list.tabulate(len(Ts.values), [idx: __mlir_type.index] Ts.values[idx].IteratorOwnedType)]) where True
```

Returns an iterator that yields tuples of the elements of the original iterables.

Examples:

```mojo
for a, b in zip(["hey", "hi", "hello"], [10, 20, 30]):
    print(a, b)
```

Parameters:

- `*Ts`: The type of the iterables.

Args:

- `*iterables`: The iterables.

Returns: A zip iterator that yields tuples of elements from all iterables.

### `map`

```mojo
def map[origin: ImmOrigin, IterableType: Iterable, ResultType: Copyable, //, function: def(var IterableType.IteratorType[False, origin_of(origin), origin].Element) thin -> ResultType](ref[origin] iterable: IterableType) -> _MapIterator[function]
```

Returns an iterator that applies `function` to each element of the input iterable.

Examples:

```mojo
var l = [1, 2, 3]
var m = map[lambda (x: Int) -> Int: x + 1](l)

# outputs:
# 2
# 3
# 4
for elem in m:
    print(elem)
```

Parameters:

- `origin`: The origin of the iterable.
- `IterableType`: The type of the iterable.
- `ResultType`: The return type of the function.
- `function`: The function to apply to each element.

Args:

- `iterable`: The iterable to map over.

Returns: A map iterator that yields the results of applying `function` to each element.

```mojo
def map[IterableType: IterableOwned, ResultType: Copyable, //, function: def(var IterableType.IteratorOwnedType.Element) thin -> ResultType](var iterable: IterableType) -> _MapIterator[function]
```

Returns an iterator that applies `function` to each element of the input iterable, consuming the iterable.

Parameters:

- `IterableType`: The type of the iterable.
- `ResultType`: The return type of the function.
- `function`: The function to apply to each element.

Args:

- `iterable`: The iterable to consume and map over.

Returns: A map iterator that yields the results of applying `function` to each element.

### `peekable`

```mojo
def peekable(ref iterable: T) -> _PeekableIterator[T.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)]] where conforms_to(T.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)].Element, Deinitable)
```

Returns a peekable iterator that can use the `peek` method to look ahead at the next element without advancing the iterator.

Args:

- `iterable`: The iterable to create a peekable iterator from.

Returns: A peekable iterator.

```mojo
def peekable(var iterable: T) -> _PeekableIterator[T.IteratorOwnedType] where conforms_to(T.IteratorOwnedType.Element, Deinitable)
```

Returns a peekable iterator that can use the `peek` method to look ahead at the next element without advancing the iterator, consuming the iterable.

Args:

- `iterable`: The iterable to consume and create a peekable iterator from.

Returns: A peekable iterator.

### `chain`

```mojo
def chain[*Ts: Iterable](*iterables: *Ts.values, out res: _ChainedIterator[*#kgen.param_list.tabulate(len(Ts.values), [idx: __mlir_type.index] Ts.values[idx].IteratorType[False, origin_of(iterables.origin), iterables.origin])]) where TypeList.all[comptime[Type: Iterable] Bool(identical(Type.IteratorType[False, origin_of(iterables.origin), iterables.origin].Element, Ts.values[0].IteratorType[False, origin_of(iterables.origin), iterables.origin].Element))]()
```

Chain multiple iterables that return the same type.

Parameters:

- `*Ts`: The iterator types.

Args:

- `*iterables`: The iterables.

Returns: The chained iterator.

```mojo
def chain[*Ts: IterableOwned](var *iterables: *Ts.values, out res: _ChainedIterator[*#kgen.param_list.tabulate(len(Ts.values), [idx: __mlir_type.index] Ts.values[idx].IteratorOwnedType)]) where TypeList.all[comptime[Type: IterableOwned] Bool(identical(Type.IteratorOwnedType.Element, Ts.values[0].IteratorOwnedType.Element))]()
```

Chain multiple iterables that return the same type.

Parameters:

- `*Ts`: The iterator types.

Args:

- `*iterables`: The iterables.

Returns: The chained iterator.

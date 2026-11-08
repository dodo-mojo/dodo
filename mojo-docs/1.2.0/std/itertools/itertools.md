# `std.itertools.itertools`

Provides iterator utilities for common iteration patterns.

This module includes functions for creating specialized iterators:

- `count()` - Creates an infinite counter with customizable start and step values
- `cycle()` - Cycles through an iterable indefinitely
- `drop_while()` - Drops elements while predicate is true, then yields the rest
- `product()` - Computes the Cartesian product of two, three, or four iterables
- `repeat()` - Repeats an element a specified number of times
- `drop()` - Drops the first n elements and yields the rest
- `take()` - Yields the first n elements
- `take_while()` - Yields elements while predicate is true

These utilities enable functional-style iteration patterns and composable iterator
operations.

## Functions

### `count`

```mojo
def count(start: Int = Int(0), step: Int = Int(1)) -> _CountIterator
```

Constructs an iterator that starts at the value `start` with a stride of `step`.

Args:

- `start`: The start of the iterator.
- `step`: The stride of the iterator.

Returns: The constructed iterator.

### `product`

```mojo
def product[IterableTypeA: Iterable, IterableTypeB: Iterable](ref iterable_a: IterableTypeA, ref iterable_b: IterableTypeB) -> _Product2[IterableTypeA.IteratorType[iterable_a_is_mut, origin_of(iterable_a), origin_of(iterable_a)], IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)](Iterator & Copyable)] where conforms_to(IterableTypeA.IteratorType[iterable_a_is_mut, origin_of(iterable_a), origin_of(iterable_a)].Element, Deinitable) and conforms_to(IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)], Iterator & Copyable)
```

Returns an iterator that yields tuples of the elements of the outer product of the iterables.

Examples:

```mojo
from std.itertools import product

var l = ["hey", "hi", "hello"]
var l2 = [10, 20, 30]
for a, b in product(l, l2):
    print(a, b)
```

Parameters:

- `IterableTypeA`: The type of the first iterable.
- `IterableTypeB`: The type of the second iterable.

Args:

- `iterable_a`: The first iterable.
- `iterable_b`: The second iterable.

Returns: A product iterator that yields outer product tuples of elements from both iterables.

```mojo
def product[IterableTypeA: Iterable, IterableTypeB: Iterable, IterableTypeC: Iterable](ref iterable_a: IterableTypeA, ref iterable_b: IterableTypeB, ref iterable_c: IterableTypeC) -> _Product3[IterableTypeA.IteratorType[iterable_a_is_mut, origin_of(iterable_a), origin_of(iterable_a)], IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)](Iterator & Copyable), IterableTypeC.IteratorType[iterable_c_is_mut, origin_of(iterable_c), origin_of(iterable_c)](Iterator & Copyable)] where conforms_to(IterableTypeC.IteratorType[iterable_c_is_mut, origin_of(iterable_c), origin_of(iterable_c)], Iterator & Copyable) if conforms_to(IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)], Iterator & Copyable) else conforms_to(IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)], Iterator & Copyable) and conforms_to(IterableTypeA.IteratorType[iterable_a_is_mut, origin_of(iterable_a), origin_of(iterable_a)].Element, Deinitable) and conforms_to(IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)].Element, Deinitable)
```

Returns an iterator that yields tuples of the elements of the outer product of three iterables.

Examples:

```mojo
from std.itertools import product

var l1 = [1, 2]
var l2 = [3, 4]
var l3 = [5, 6]
for a, b, c in product(l1, l2, l3):
    print(a, b, c)
```

Parameters:

- `IterableTypeA`: The type of the first iterable.
- `IterableTypeB`: The type of the second iterable.
- `IterableTypeC`: The type of the third iterable.

Args:

- `iterable_a`: The first iterable.
- `iterable_b`: The second iterable.
- `iterable_c`: The third iterable.

Returns: A product iterator that yields outer product tuples of elements from all three iterables.

```mojo
def product[IterableTypeA: Iterable, IterableTypeB: Iterable, IterableTypeC: Iterable, IterableTypeD: Iterable](ref iterable_a: IterableTypeA, ref iterable_b: IterableTypeB, ref iterable_c: IterableTypeC, ref iterable_d: IterableTypeD) -> _Product4[IterableTypeA.IteratorType[iterable_a_is_mut, origin_of(iterable_a), origin_of(iterable_a)], IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)](Iterator & Copyable), IterableTypeC.IteratorType[iterable_c_is_mut, origin_of(iterable_c), origin_of(iterable_c)](Iterator & Copyable), IterableTypeD.IteratorType[iterable_d_is_mut, origin_of(iterable_d), origin_of(iterable_d)](Iterator & Copyable)] where conforms_to(IterableTypeC.IteratorType[iterable_c_is_mut, origin_of(iterable_c), origin_of(iterable_c)], Iterator & Copyable) if conforms_to(IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)], Iterator & Copyable) else conforms_to(IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)], Iterator & Copyable) and conforms_to(IterableTypeD.IteratorType[iterable_d_is_mut, origin_of(iterable_d), origin_of(iterable_d)], Iterator & Copyable) and conforms_to(IterableTypeA.IteratorType[iterable_a_is_mut, origin_of(iterable_a), origin_of(iterable_a)].Element, Deinitable) and conforms_to(IterableTypeB.IteratorType[iterable_b_is_mut, origin_of(iterable_b), origin_of(iterable_b)].Element, Deinitable) and conforms_to(IterableTypeC.IteratorType[iterable_c_is_mut, origin_of(iterable_c), origin_of(iterable_c)].Element, Deinitable)
```

Returns an iterator that yields tuples of the elements of the outer product of four iterables.

Examples:

```mojo
from std.itertools import product

var l1 = [1, 2]
var l2 = [3, 4]
var l3 = [5, 6]
var l4 = [7, 8]
for a, b, c, d in product(l1, l2, l3, l4):
    print(a, b, c, d)
```

Parameters:

- `IterableTypeA`: The type of the first iterable.
- `IterableTypeB`: The type of the second iterable.
- `IterableTypeC`: The type of the third iterable.
- `IterableTypeD`: The type of the fourth iterable.

Args:

- `iterable_a`: The first iterable.
- `iterable_b`: The second iterable.
- `iterable_c`: The third iterable.
- `iterable_d`: The fourth iterable.

Returns: A product iterator that yields outer product tuples of elements from all four iterables.

```mojo
def product(var iterable_a: T, var iterable_b: T) -> _Product2[T.IteratorOwnedType, T.IteratorOwnedType(Iterator & Copyable)] where conforms_to(T.IteratorOwnedType, Iterator & Copyable) and conforms_to(T.IteratorOwnedType.Element, Deinitable)
```

Returns an iterator that yields tuples of the elements of the outer product of the iterables, consuming both iterables.

Args:

- `iterable_a`: The first iterable to consume.
- `iterable_b`: The second iterable to consume.

Returns: A product iterator that yields outer product tuples of elements from both iterables.

```mojo
def product(var iterable_a: T, var iterable_b: T, var iterable_c: T) -> _Product3[T.IteratorOwnedType, T.IteratorOwnedType(Iterator & Copyable), T.IteratorOwnedType(Iterator & Copyable)] where conforms_to(T.IteratorOwnedType, Iterator & Copyable) if conforms_to(T.IteratorOwnedType, Iterator & Copyable) else conforms_to(T.IteratorOwnedType, Iterator & Copyable) and conforms_to(T.IteratorOwnedType.Element, Deinitable) and conforms_to(T.IteratorOwnedType.Element, Deinitable)
```

Returns an iterator that yields tuples of the elements of the outer product of three iterables, consuming all three iterables.

Args:

- `iterable_a`: The first iterable to consume.
- `iterable_b`: The second iterable to consume.
- `iterable_c`: The third iterable to consume.

Returns: A product iterator that yields outer product tuples of elements from all three iterables.

```mojo
def product(var iterable_a: T, var iterable_b: T, var iterable_c: T, var iterable_d: T) -> _Product4[T.IteratorOwnedType, T.IteratorOwnedType(Iterator & Copyable), T.IteratorOwnedType(Iterator & Copyable), T.IteratorOwnedType(Iterator & Copyable)] where conforms_to(T.IteratorOwnedType, Iterator & Copyable) if conforms_to(T.IteratorOwnedType, Iterator & Copyable) else conforms_to(T.IteratorOwnedType, Iterator & Copyable) and conforms_to(T.IteratorOwnedType, Iterator & Copyable) and conforms_to(T.IteratorOwnedType.Element, Deinitable) and conforms_to(T.IteratorOwnedType.Element, Deinitable) and conforms_to(T.IteratorOwnedType.Element, Deinitable)
```

Returns an iterator that yields tuples of the elements of the outer product of four iterables, consuming all four iterables.

Args:

- `iterable_a`: The first iterable to consume.
- `iterable_b`: The second iterable to consume.
- `iterable_c`: The third iterable to consume.
- `iterable_d`: The fourth iterable to consume.

Returns: A product iterator that yields outer product tuples of elements from all four iterables.

### `cycle`

```mojo
def cycle[IterableType: Iterable](ref iterable: IterableType) -> _CycleIterator[IterableType.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)](Iterator & Copyable)] where conforms_to(IterableType.IteratorType[iterable_is_mut, origin_of(iterable), origin_of(iterable)], Iterator & Copyable)
```

Creates an iterator that cycles through an iterable indefinitely.

This function returns an iterator that yields elements from the input
iterable repeatedly in an infinite loop. The elements are yielded in
the same order as they appear in the original iterable.

This is a lazy implementation - no work is done at construction time.
The iterator keeps a copy of the original iterator and resets to it
when exhausted.

Examples:

```mojo
from std.itertools import cycle

# Cycle through a list
var colors = ["red", "green", "blue"]
var color_cycle = cycle(colors)

# Get 6 elements (cycles twice)
var count = 0
for color in color_cycle:
    print(color)
    count += 1
    if count >= 6:
        break
# Output: red, green, blue, red, green, blue
```

Parameters:

- `IterableType`: The type of the iterable.

Args:

- `iterable`: The iterable to cycle through.

Returns: An iterator that yields elements from the iterable forever.

```mojo
def cycle(var iterable: T) -> _CycleIterator[T.IteratorOwnedType(Iterator & Copyable)] where conforms_to(T.IteratorOwnedType, Iterator & Copyable)
```

Creates an iterator that cycles through an iterable indefinitely, consuming the iterable.

Args:

- `iterable`: The iterable to consume and cycle through.

Returns: An iterator that yields elements from the iterable forever.

### `take_while`

```mojo
def take_while[origin: ImmOrigin, IterableType: Iterable, //, predicate: def(IterableType.IteratorType[False, origin_of(origin), origin].Element) thin -> Bool](ref[origin] iterable: IterableType) -> _TakeWhileIterator[predicate] where conforms_to(IterableType.IteratorType[False, origin_of(origin), origin].Element, Deinitable)
```

Creates an iterator that yields elements while predicate returns True.

This function returns an iterator that yields elements from the input
iterable as long as the predicate function returns True for each element.
Once the predicate returns False, the iterator stops immediately and does
not yield any more elements.

Examples:

```mojo
from std.itertools import take_while

var nums = [1, 2, 3, 4, 5, 6, 7]
for num in take_while[lambda (x: Int) -> Bool: x < 5](nums):
    print(num)  # Prints: 1, 2, 3, 4
```

Parameters:

- `origin`: The origin of the iterable.
- `IterableType`: The type of the iterable.
- `predicate`: A function that takes an element and returns True if the element should be yielded.

Args:

- `iterable`: The iterable to take elements from.

Returns: An iterator that yields elements while predicate returns True.

```mojo
def take_while[IterableType: IterableOwned, //, predicate: def(IterableType.IteratorOwnedType.Element) thin -> Bool](var iterable: IterableType) -> _TakeWhileIterator[predicate] where conforms_to(IterableType.IteratorOwnedType.Element, Deinitable)
```

Creates an iterator that yields elements while predicate returns True, consuming the iterable.

Parameters:

- `IterableType`: The type of the iterable.
- `predicate`: A function that takes an element and returns True if the element should be yielded.

Args:

- `iterable`: The iterable to consume and take elements from.

Returns: An iterator that yields elements while predicate returns True.

### `drop_while`

```mojo
def drop_while[origin: ImmOrigin, IterableType: Iterable, //, predicate: def(IterableType.IteratorType[False, origin_of(origin), origin].Element) thin -> Bool](ref[origin] iterable: IterableType) -> _DropWhileIterator[predicate] where conforms_to(IterableType.IteratorType[False, origin_of(origin), origin].Element, Deinitable)
```

Creates an iterator that drops elements while predicate returns True.

This function returns an iterator that drops elements from the input
iterable as long as the predicate function returns True for each element.
Once the predicate returns False, the iterator starts yielding all
remaining elements unconditionally.

Examples:

```mojo
from std.itertools import drop_while

var nums = [1, 2, 3, 4, 5, 6, 1, 2]
for num in drop_while[lambda (x: Int) -> Bool: x < 5](nums):
    print(num)  # Prints: 5, 6, 1, 2
```

Parameters:

- `origin`: The origin of the iterable.
- `IterableType`: The type of the iterable.
- `predicate`: A function that takes an element and returns True if the element should be dropped.

Args:

- `iterable`: The iterable to drop elements from.

Returns: An iterator that drops elements while predicate returns True, then yields all remaining elements.

```mojo
def drop_while[IterableType: IterableOwned, //, predicate: def(IterableType.IteratorOwnedType.Element) thin -> Bool](var iterable: IterableType) -> _DropWhileIterator[predicate] where conforms_to(IterableType.IteratorOwnedType.Element, Deinitable)
```

Creates an iterator that drops elements while predicate returns True, consuming the iterable.

Parameters:

- `IterableType`: The type of the iterable.
- `predicate`: A function that takes an element and returns True if the element should be dropped.

Args:

- `iterable`: The iterable to consume and drop elements from.

Returns: An iterator that drops elements while predicate returns True, then yields all remaining elements.

### `repeat`

```mojo
def repeat[ElementType: Copyable & Deinitable](element: ElementType, *, times: Int) -> _RepeatIterator[ElementType]
```

Constructs an iterator that repeats the given element a specified number of times.

This function creates an iterator that returns the same element over and over
for the specified number of times.

Examples:

```mojo
from std.itertools import repeat

# Repeat a value 3 times
var it = repeat(42, times=3)
for val in it:
    print(val)  # Prints: 42, 42, 42

# Repeat a string 5 times
var str_it = repeat("hello", times=5)
for s in str_it:
    print(s)  # Prints: hello, hello, hello, hello, hello
```

Parameters:

- `ElementType`: The type of the element to repeat.

Args:

- `element`: The element to repeat.
- `times`: The number of times to repeat the element.

Returns: An iterator that repeats the element the specified number of times.

### `take`

```mojo
def take[origin: ImmOrigin, IterableType: Iterable, //](ref[origin] iterable: IterableType, count: Int) -> _TakeIterator[IterableType.IteratorType[False, origin_of(origin), origin]]
```

Creates an iterator that yields the first `count` elements.

This function returns an iterator that yields at most `count` elements
from the input iterable, then stops.

Examples:

```mojo
from std.itertools import take

var nums = [1, 2, 3, 4, 5]
for num in take(nums, 3):
    print(num)  # Prints: 1, 2, 3
```

Parameters:

- `origin`: The origin of the iterable.
- `IterableType`: The type of the iterable.

Args:

- `iterable`: The iterable to take elements from.
- `count`: The maximum number of elements to yield.

Returns: An iterator that yields at most `count` elements.

```mojo
def take[IterableType: IterableOwned, //](var iterable: IterableType, count: Int) -> _TakeIterator[IterableType.IteratorOwnedType]
```

Creates an iterator that yields the first `count` elements, consuming the iterable.

Parameters:

- `IterableType`: The type of the iterable.

Args:

- `iterable`: The iterable to consume and take elements from.
- `count`: The maximum number of elements to yield.

Returns: An iterator that yields at most `count` elements.

### `drop`

```mojo
def drop[origin: ImmOrigin, IterableType: Iterable, //](ref[origin] iterable: IterableType, count: Int) -> _DropIterator[IterableType.IteratorType[False, origin_of(origin), origin]] where conforms_to(IterableType.IteratorType[False, origin_of(origin), origin].Element, Deinitable)
```

Creates an iterator that drops the first `count` elements.

This function returns an iterator that drops the first `count` elements
from the input iterable, then yields all remaining elements.

Examples:

```mojo
from std.itertools import drop

var nums = [1, 2, 3, 4, 5]
for num in drop(nums, 2):
    print(num)  # Prints: 3, 4, 5
```

Parameters:

- `origin`: The origin of the iterable.
- `IterableType`: The type of the iterable.

Args:

- `iterable`: The iterable to drop elements from.
- `count`: The number of elements to drop.

Returns: An iterator that drops the first `count` elements.

```mojo
def drop[IterableType: IterableOwned, //](var iterable: IterableType, count: Int) -> _DropIterator[IterableType.IteratorOwnedType] where conforms_to(IterableType.IteratorOwnedType.Element, Deinitable)
```

Creates an iterator that drops the first `count` elements, consuming the iterable.

Parameters:

- `IterableType`: The type of the iterable.

Args:

- `iterable`: The iterable to consume and drop elements from.
- `count`: The number of elements to drop.

Returns: An iterator that drops the first `count` elements.

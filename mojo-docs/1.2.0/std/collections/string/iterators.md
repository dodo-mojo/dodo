# `std.collections.string.iterators`

Implements the iterators and related utilities for efficient string operations.

## Structs

### `CodepointSliceIter`

```mojo
struct CodepointSliceIter[origin: ImmOrigin, forward: Bool = True]
```

Iterator for `StringSlice` over substring slices containing a single Unicode codepoint.

The `forward` parameter only controls the behavior of the `__next__()`
method used for normal iteration. Calls to `next()` will always take an
element from the front of the iterator, and calls to `next_back()` will
always take an element from the end.

Parameters:

- `origin`: The origin of the underlying string data.
- `forward`: The iteration direction. `False` is backwards.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Iterable`, `Iterator`, `Movable`, `Sized`

Aliases:

- `IteratorType = CodepointSliceIter[origin, forward]`: The iterator type for this codepoint iterator.
- `Element = StringSpan[origin]`: The element type yielded by iteration.

#### `CodepointSliceIter.__iter__`

```mojo
def __iter__(ref self) -> Self
```

Iterate over the `StringSlice` yielding individual characters.

Returns: An iterator over the characters in the string slice.

#### `CodepointSliceIter.__next__`

```mojo
def __next__(mut self) raises -> StringSpan[origin]
```

Get the next codepoint in the underlying string slice.

This returns the next single-codepoint substring slice encoded in the
underlying string, and advances the iterator state.

If `forward` is set to `False`, this will return the next codepoint
from the end of the string.

This function will abort if this iterator has been exhausted.

Returns: The next character in the string.

Raises: `StopIteration` if the iterator has been exhausted.

#### `CodepointSliceIter.__len__`

```mojo
def __len__(self) -> Int
```

Returns the remaining length of this iterator in `Codepoint`s.

The value returned from this method indicates the number of subsequent
calls to `next()` that will return a value.

Returns: Number of codepoints remaining in this iterator.

#### `CodepointSliceIter.peek_next`

```mojo
def peek_next(self) -> Optional[StringSpan[origin]]
```

Check what the next single-codepoint slice in this iterator is, without advancing the iterator state.

Repeated calls to this method will return the same value.

**Examples:**

`peek_next()` does not advance the iterator, so repeated calls will
return the same value:

```mojo
from std.collections.string import Codepoint
from std.testing import assert_equal

var input = StringSlice("123")
var iter = input.codepoint_slices()

assert_equal(iter.peek_next().value(), "1")
assert_equal(iter.peek_next().value(), "1")
assert_equal(iter.peek_next().value(), "1")

# A call to `next()` return the same value as `peek_next()` had,
# but also advance the iterator.
assert_equal(iter.next().value(), "1")

# Later `peek_next()` calls will return the _new_ next character:
assert_equal(iter.peek_next().value(), "2")
```

Returns: The next codepoint slice in the underlying string, or None if the string is empty.

#### `CodepointSliceIter.peek_back`

```mojo
def peek_back(mut self) -> Optional[StringSpan[origin]]
```

Check what the last single-codepoint slice in this iterator is, without advancing the iterator state.

Repeated calls to this method will return the same value.

**Examples:**

`peek_back()` does not advance the iterator, so repeated calls will
return the same value:

```mojo
from std.collections.string import Codepoint
from std.testing import assert_equal

var input = StringSlice("123")
var iter = input.codepoint_slices()

# Repeated calls to `peek_back()` return the same value.
assert_equal(iter.peek_back().value(), "3")
assert_equal(iter.peek_back().value(), "3")
assert_equal(iter.peek_back().value(), "3")

# A call to `next_back()` return the same value as `peek_back()` had,
# but also advance the iterator.
assert_equal(iter.next_back().value(), "3")

# Later `peek_back()` calls will return the _new_ next character:
assert_equal(iter.peek_back().value(), "2")
```

Returns: The last codepoint slice in the underlying string, or None if the string is empty.

#### `CodepointSliceIter.next`

```mojo
def next(mut self) -> Optional[StringSpan[origin]]
```

Get the next codepoint slice in the underlying string slice, or None if the iterator is empty.

This returns the next single-codepoint substring encoded in the
underlying string, and advances the iterator state.

Returns: A character if the string is not empty, otherwise None.

#### `CodepointSliceIter.next_back`

```mojo
def next_back(mut self) -> Optional[StringSpan[origin]]
```

Get the last single-codepoint slice in this iterator is, or None if the iterator is empty.

This returns the last codepoint slice in this iterator, and advances
the iterator state.

Returns: The last codepoint slice in the underlying string, or None if the string is empty.

### `CodepointsIter`

```mojo
struct CodepointsIter[origin: ImmOrigin]
```

Iterator over the `Codepoint`s in a string slice, constructed by `StringSlice.codepoints()`.

Parameters:

- `origin`: Origin of the underlying string data.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Iterable`, `Iterator`, `Movable`, `Sized`

Aliases:

- `IteratorType = CodepointsIter[origin]`: The iterator type for this codepoint iterator.
- `Element = Codepoint`: The element type yielded by iteration.

#### `CodepointsIter.__next__`

```mojo
def __next__(mut self) raises -> Codepoint
```

Get the next codepoint in the underlying string slice.

This returns the next `Codepoint` encoded in the underlying string, and
advances the iterator state.

Returns: The next character in the string.

Raises: StopIteration: If the iterator is exhausted.

#### `CodepointsIter.__len__`

```mojo
def __len__(self) -> Int
```

Returns the remaining length of this iterator in `Codepoint`s.

The value returned from this method indicates the number of subsequent
calls to `next()` that will return a value.

Returns: Number of codepoints remaining in this iterator.

#### `CodepointsIter.peek_next`

```mojo
def peek_next(self) -> Optional[Codepoint]
```

Check what the next codepoint in this iterator is, without advancing the iterator state.

Repeated calls to this method will return the same value.

# Examples

`peek_next()` does not advance the iterator, so repeated calls will
return the same value:

```mojo
from std.collections.string import Codepoint
from std.testing import assert_equal

var input = StringSlice("123")
var iter = input.codepoints()

assert_equal(iter.peek_next().value(), Codepoint.ord("1"))
assert_equal(iter.peek_next().value(), Codepoint.ord("1"))
assert_equal(iter.peek_next().value(), Codepoint.ord("1"))

# A call to `next()` return the same value as `peek_next()` had,
# but also advance the iterator.
assert_equal(iter.next().value(), Codepoint.ord("1"))

# Later `peek_next()` calls will return the _new_ next character:
assert_equal(iter.peek_next().value(), Codepoint.ord("2"))
```

Returns: The next character in the underlying string, or None if the string is empty.

#### `CodepointsIter.next`

```mojo
def next(mut self) -> Optional[Codepoint]
```

Get the next codepoint in the underlying string slice, or None if the iterator is empty.

This returns the next `Codepoint` encoded in the underlying string, and
advances the iterator state.

Returns: A character if the string is not empty, otherwise None.

### `GraphemeSliceIter`

```mojo
struct GraphemeSliceIter[origin: ImmOrigin, forward: Bool = True]
```

Iterator over grapheme clusters in a string, yielding each cluster as a `StringSlice`.

A grapheme cluster is what a user would typically think of as a single
"character" on screen. This includes combining character sequences, emoji
with modifiers, flag sequences, and other multi-codepoint grapheme clusters
as defined by UAX #29.

The `forward` parameter only controls the behavior of the `__next__()`
method used for normal iteration. Calls to `next()` will always take an
element from the front of the iterator, and calls to `next_back()` will
always take an element from the end. Mixing `next()` and `next_back()`
on the same iterator is supported: they share the remaining byte range
but use independent state (forward iteration keeps incremental UAX #29
state; reverse iteration caches a safe restart boundary). This is safe
because forward priming only consults the codepoint at the start of the
remaining range, and `next_back()` shrinks the range from the end without
moving that start. A forward `next()` advances the front and invalidates
the cached reverse safe-start so the next reverse call recomputes it.

Note: `len()` is an O(n) operation that must scan all remaining bytes
to count grapheme boundaries. Avoid calling it in a loop; prefer
iterating with `for g in s.graphemes()` or calling `next()` until
`None`.

Note: Reverse iteration costs more per element than forward iteration.
The UAX #29 state machine is forward-scanning, so `next_back()` backs
up to a guaranteed grapheme boundary (typically a line break or the
start of the string) and forward-scans from there. The safe boundary
is cached across reverse calls (a forward `next()` invalidates the
cache), so per-call cost is dominated by forward-scan length: small
in text with frequent Control/CR/LF codepoints, growing with the
distance back to such a codepoint in long runs without them.

# TODO: Vectorize the existing scalar safe-ASCII fast path. Runs of
# safe-ASCII bytes (U+0020..U+007E) are already skipped one-by-one
# without entering the state machine; a SIMD check (e.g. `>= 0x20 &
# <= 0x7E`) could extend a run by a whole vector width per iteration.

Example:

```mojo
from std.testing import assert_equal
var text = String("cafe\u{0301}")  # "café" with combining accent
var count = 0
for grapheme in text.graphemes():
    count += 1
# count == 4: c, a, f, e + combining acute (2 codepoints, 1 grapheme)
assert_equal(count, 4)
```

Parameters:

- `origin`: The origin of the underlying string data.
- `forward`: The iteration direction. `False` is backwards.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Iterable`, `Iterator`, `Movable`, `Sized`

Aliases:

- `IteratorType = GraphemeSliceIter[origin, forward]`: The iterator type.
- `Element = StringSpan[origin]`: The element type yielded by iteration.

#### `GraphemeSliceIter.__iter__`

```mojo
def __iter__(ref self) -> Self
```

Return an iterator over grapheme clusters.

Returns: A copy of this iterator.

#### `GraphemeSliceIter.__next__`

```mojo
def __next__(mut self) raises -> StringSpan[origin]
```

Get the next grapheme cluster.

If `forward` is set to `False`, this will return the next grapheme
cluster from the end of the string.

Returns: The next grapheme cluster as a `StringSlice`.

Raises: `StopIteration` if the iterator has been exhausted.

#### `GraphemeSliceIter.__len__`

```mojo
def __len__(self) -> Int
```

Return the number of remaining grapheme clusters.

This is an O(n) operation that scans all remaining bytes to count
grapheme cluster boundaries.

Returns: The number of grapheme clusters remaining.

#### `GraphemeSliceIter.remaining_byte_length`

```mojo
def remaining_byte_length(self) -> Int
```

Returns the number of bytes not yet consumed by the iterator.

This is O(1): it reports the size of the remaining range without
scanning grapheme boundaries. Combined with the original byte length
of the source slice, callers can compute how many bytes the iterator
has produced so far without summing per-grapheme byte lengths.

Returns: The byte length of the iterator's remaining range.

#### `GraphemeSliceIter.next`

```mojo
def next(mut self) -> Optional[StringSpan[origin]]
```

Get the next grapheme cluster, or `None` if exhausted.

Returns: The next grapheme cluster as a `StringSlice`, or `None`.

#### `GraphemeSliceIter.peek_back`

```mojo
def peek_back(mut self) -> Optional[StringSpan[origin]]
```

Return the last grapheme cluster without advancing the iterator.

Repeated calls return the same value. The first reverse call (`peek_back`
or `next_back`) does the backward scan to find a safe restart boundary
and caches it; subsequent reverse calls reuse the cache and only pay
for the forward scan from that boundary.

Returns: The last grapheme cluster as a `StringSlice`, or `None` if the iterator is empty.

#### `GraphemeSliceIter.next_back`

```mojo
def next_back(mut self) -> Optional[StringSpan[origin]]
```

Get the last grapheme cluster in the underlying string, or `None` if the iterator is empty.

This consumes one grapheme from the end of the remaining range. It
does not share state with forward iteration (`next()`), so the two
can be interleaved freely.

The UAX #29 state machine is inherently forward-scanning, so
`next_back()` backs up to a guaranteed grapheme boundary — a
Control/CR/LF codepoint or the start of the string — and then
forward-scans from that boundary. The safe boundary, once found,
is cached and reused across subsequent reverse calls (a forward
`next()` invalidates the cache because it moves the front pointer).
Per-call cost is therefore dominated by the forward scan length:
roughly proportional to the distance from the most recent Control/
CR/LF codepoint to the cluster being returned. For text containing
line breaks or whitespace this is small; for long runs without
Control/CR/LF the forward scan extends back toward the start of
the string and the per-call cost grows accordingly.

Returns: The last grapheme cluster as a `StringSlice`, or `None`.

### `GraphemeIndicesIter`

```mojo
struct GraphemeIndicesIter[origin: ImmOrigin]
```

Iterator over grapheme clusters paired with their starting byte offset.

Each call to `__next__()` yields a `Tuple[Int, StringSlice[origin]]` where
the first element is the byte offset (relative to the original string)
at which the grapheme begins, and the second is the grapheme slice
itself.

Mirrors `str::grapheme_indices` from Rust's `unicode-segmentation` crate.
Useful for text editors and UIs that need to map cursor byte positions
back to grapheme boundaries.

Example:

```mojo
from std.testing import assert_equal
var s = StringSlice("abc")
var pairs = List[Tuple[Int, String]]()
for off, g in s.grapheme_indices():
    pairs.append((off, String(g)))
assert_equal(len(pairs), 3)
assert_equal(pairs[0][0], 0)
assert_equal(pairs[1][0], 1)
assert_equal(pairs[2][0], 2)
```

Parameters:

- `origin`: The origin of the underlying string data.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Iterable`, `Iterator`, `Movable`

Aliases:

- `IteratorType = GraphemeIndicesIter[origin]`: The iterator type for this grapheme indices iterator.
- `Element = Tuple[Int, StringSpan[origin]]`: The element type yielded by iteration.

#### `GraphemeIndicesIter.__iter__`

```mojo
def __iter__(ref self) -> Self
```

Iterate over the grapheme indices in the underlying string slice.

Returns: An iterator yielding `(byte_offset, grapheme)` pairs.

#### `GraphemeIndicesIter.__next__`

```mojo
def __next__(mut self) raises -> Tuple[Int, StringSpan[origin]]
```

Get the next `(byte_offset, grapheme)` pair.

Returns: The byte offset at which the next grapheme starts and the grapheme slice itself.

Raises: `StopIteration` if the iterator has been exhausted.

### `BytesIter`

```mojo
struct BytesIter[origin: ImmOrigin]
```

Iterator over the raw UTF-8 bytes of a string slice, constructed by `StringSlice.bytes()`.

Each call to `__next__()` yields the next `Byte` value from the underlying
UTF-8 encoded data. Unlike `CodepointsIter` and `GraphemeSliceIter`, this
iterator operates at the byte level and does not interpret multi-byte
UTF-8 sequences as codepoints or grapheme clusters.

Parameters:

- `origin`: The origin of the underlying string data.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Iterable`, `Iterator`, `Movable`, `Sized`

Aliases:

- `IteratorType = BytesIter[origin]`: The iterator type for this bytes iterator.
- `Element = Byte`: The element type yielded by iteration.

#### `BytesIter.__iter__`

```mojo
def __iter__(ref self) -> Self
```

Iterator over the underlying string's bytes.

Returns: This iterator.

#### `BytesIter.__next__`

```mojo
def __next__(mut self) raises -> Byte
```

Get the next byte in the underlying string slice.

Returns: The next byte in the string.

Raises: `StopIteration` if the iterator has been exhausted.

#### `BytesIter.bounds`

```mojo
def bounds(self) -> Tuple[Int, Optional[Int]]
```

Returns bounds `[lower, upper]` for the remaining iterator length.

Returns: The lower and upper bound of this iterator.

#### `BytesIter.__len__`

```mojo
def __len__(self) -> Int
```

Returns the remaining length of this iterator in bytes.

Returns: Number of bytes remaining in this iterator.

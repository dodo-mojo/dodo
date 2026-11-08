# `std.builtin.reversed`

Provides the `reversed` function for reverse iteration over collections.

These are Mojo built-ins, so you don't need to import them.

## Traits

### `ReversibleRange`

```mojo
trait ReversibleRange
```

The `ReversibleRange` trait describes a range that can be reversed.

Any type that conforms to `ReversibleRange` works with the builtin
[`reversed()`](../../std/builtin/reversed.md#reversed) functions.

The `ReversibleRange` trait requires the type to define the `__reversed__()`
method and a `ReversedType` iterator, so each conforming range can return
its own reversed iterator type instead of a single hard-coded one.

**Note**: iterators are currently non-raising.

Inherits from: `AnyType`

Aliases:

- `ReversedType`: The iterator type returned by `__reversed__()`.

#### `ReversibleRange.__reversed__`

```mojo
def __reversed__(self) -> Self.ReversedType
```

Get a reversed iterator for the type.

**Note**: iterators are currently non-raising.

Returns: The reversed iterator of the type.

## Functions

### `reversed`

```mojo
def reversed[T: ReversibleRange](value: T) -> T.ReversedType
```

Get a reversed iterator of the input range.

**Note**: iterators are currently non-raising.

Parameters:

- `T`: The type conforming to ReversibleRange.

Args:

- `value`: The range to get the reversed iterator of.

Returns: The reversed iterator of the range.

```mojo
def reversed[T: Copyable](ref value: List[T]) -> _ListIter[T, origin_of(value), False]
```

Get a reversed iterator of the input list.

**Note**: iterators are currently non-raising.

Parameters:

- `T`: The type of the elements in the list.

Args:

- `value`: The list to get the reversed iterator of.

Returns: The reversed iterator of the list.

```mojo
def reversed[T: Copyable, size: Int](ref value: Array[T, size]) -> _ArrayIter[T, size, origin_of(value), False]
```

Get a reversed iterator of the input array.

**Note**: iterators are currently non-raising.

Parameters:

- `T`: The type of the elements in the array.
- `size`: The size of the array.

Args:

- `value`: The array to get the reversed iterator of.

Returns: The reversed iterator of the array.

```mojo
def reversed[T: Copyable & Deinitable](ref value: Deque[T]) -> _DequeIter[T, origin_of(value), False]
```

Get a reversed iterator of the deque.

**Note**: iterators are currently non-raising.

Parameters:

- `T`: The type of the elements in the deque.

Args:

- `value`: The deque to get the reversed iterator of.

Returns: The reversed iterator of the deque.

```mojo
def reversed[K: Equatable & Hashable & Copyable, V: Copyable, H: Defaultable & Hasher & Deinitable](ref value: Dict[K, V, H]) -> _DictKeyIter[K, V, H, origin_of(value), False]
```

Get a reversed iterator of the input dict.

**Note**: iterators are currently non-raising.

Parameters:

- `K`: The type of the keys in the dict.
- `V`: The type of the values in the dict.
- `H`: The type of the hasher in the dict.

Args:

- `value`: The dict to get the reversed iterator of.

Returns: The reversed iterator of the dict keys.

```mojo
def reversed[dict_mutability: Bool, //, K: Equatable & Hashable & Copyable, V: Copyable, H: Defaultable & Hasher & Deinitable, dict_origin: Origin[mut=dict_mutability]](ref value: _DictValueIter[K, V, H, dict_origin]) -> _DictValueIter[K, V, H, dict_origin, False]
```

Get a reversed iterator of the input dict values.

**Note**: iterators are currently non-raising.

Parameters:

- `dict_mutability`: Whether the reference to the dict values is mutable.
- `K`: The type of the keys in the dict.
- `V`: The type of the values in the dict.
- `H`: The type of the hasher in the dict.
- `dict_origin`: The origin of the dict values.

Args:

- `value`: The dict values to get the reversed iterator of.

Returns: The reversed iterator of the dict values.

```mojo
def reversed[dict_mutability: Bool, //, K: Equatable & Hashable & Copyable, V: Copyable, H: Defaultable & Hasher & Deinitable, dict_origin: Origin[mut=dict_mutability]](ref value: _DictEntryIter[K, V, H, dict_origin]) -> _DictEntryIter[K, V, H, dict_origin, False]
```

Get a reversed iterator of the input dict items.

**Note**: iterators are currently non-raising.

Parameters:

- `dict_mutability`: Whether the reference to the dict items is mutable.
- `K`: The type of the keys in the dict.
- `V`: The type of the values in the dict.
- `H`: The type of the hasher in the dict.
- `dict_origin`: The origin of the dict items.

Args:

- `value`: The dict items to get the reversed iterator of.

Returns: The reversed iterator of the dict items.

```mojo
def reversed[T: Copyable](value: Span[T]) -> _SpanIter[T, value.origin, False]
```

Get a reversed iterator of the input Span.

**Note**: iterators are currently non-raising.

Parameters:

- `T`: The type of the elements in the Span.

Args:

- `value`: The Span to get the reversed iterator of.

Returns: The reversed iterator of the Span.

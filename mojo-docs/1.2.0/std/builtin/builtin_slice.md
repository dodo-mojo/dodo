# `std.builtin.builtin_slice`

Implements slice.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `Slice`

```mojo
struct Slice
```

Represents a slice expression.

Objects of this type are generated when slice syntax is used within square
brackets, e.g.:

```mojo
var lst: List[Int] = [0,1,2,3,4,5,6,7]

# Both are equivalent and result in a list: [].
var l1 = List(lst[6:])
var l2 = lst.__getitem__(Slice(6, len(lst)))
```

Fields:

- `start` (`Optional[Int]`): The starting index of the slice.
- `end` (`Optional[Int]`): The end index of the slice.
- `step` (`Optional[Int]`): The step increment value of the slice.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `Slice.__init__`

```mojo
def __init__(out self, start: Int, end: Int)
```

Construct slice given the start and end values.

Args:

- `start`: The start value.
- `end`: The end value.

```mojo
def __init__(out self, start: Optional[Int], end: Optional[Int], step: Optional[Int], __slice_literal__: NoneType = None)
```

Construct slice given the start, end and step values.

Args:

- `start`: The start value.
- `end`: The end value.
- `step`: The step value.
- `__slice_literal__`: Enables slice literal syntax.

#### `Slice.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Compare this slice to the other.

Args:

- `other`: The slice to compare to.

Returns: True if start, end, and step values of this slice match the corresponding values of the other slice and False otherwise.

#### `Slice.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write Slice string representation to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Slice.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write Slice string representation to a `Writer`.

Args:

- `writer`: The object to write to.

#### `Slice.indices`

```mojo
def indices(self, length: Int) -> Tuple[Int, Int, Int]
```

Returns a tuple of 3 integers representing the start, end, and step    of the slice if applied to a container of the given length.

Uses the target container length to normalize negative, out of bounds,
or None indices.

Negative indices are wrapped using the length of the container.
```mojo
s = slice(0, -1, 1)
i = s.indices(5) # returns (0, 4, 1)
```

None indices are defaulted to the start or the end of the container
based on whether `step` is positive or negative.
```mojo
s = slice(None, None, 1)
i = s.indices(5) # returns (0, 5, 1)
```

Out of bounds indices are clamped using the size of the container.
```mojo
s = slice(20)
i = s.indices(5) # returns (0, 5, 1)
```

Args:

- `length`: The length of the target container.

Returns: A tuple containing three integers for start, end, and step.

### `StridedSlice`

```mojo
struct StridedSlice
```

Represents a slice expression that has a stride.

This type is used to support different behavior for strided vs unstrided
slicing.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `StridedSlice.__init__`

```mojo
def __init__(out self, other: Slice)
```

Implicitly convert from a general slice.

Args:

- `other`: The other slice.

```mojo
def __init__(out self, start: Optional[Int], end: Optional[Int], stride: Int, __slice_literal__: NoneType = None)
```

Construct slice given start, end, and stride values.

Args:

- `start`: The start value.
- `end`: The end value.
- `stride`: The step value.
- `__slice_literal__`: Enables slice literal syntax.

#### `StridedSlice.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write StridedSlice string representation to a `Writer`.

Args:

- `writer`: The object to write to.

#### `StridedSlice.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write StridedSlice debug representation to a `Writer`.

Args:

- `writer`: The object to write to.

#### `StridedSlice.indices`

```mojo
def indices(self, length: Int) -> Tuple[Int, Int, Int]
```

Returns a tuple of 3 integers representing start, end, and step of the slice if applied to a container of given length.

Args:

- `length`: The length of the target container.

Returns: A tuple containing three integers for start, end, and step.

### `ContiguousSlice`

```mojo
struct ContiguousSlice
```

Represents a slice expression without a stride.

This type is used to support different behavior for strided vs unstrided
slicing.

Fields:

- `start` (`Optional[Int]`): The starting index of the slice.
- `end` (`Optional[Int]`): The end index of the slice.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `ContiguousSlice.__init__`

```mojo
def __init__(out self, start: Optional[Int], end: Optional[Int], stride: NoneType, __slice_literal__: NoneType = None)
```

Construct slice given the start and end values.

Args:

- `start`: The start value.
- `end`: The end value.
- `stride`: Always none. Disambiguates from slices with a stride.
- `__slice_literal__`: Enables slice literal syntax.

#### `ContiguousSlice.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write ContiguousSlice string representation to a `Writer`.

Args:

- `writer`: The object to write to.

#### `ContiguousSlice.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write ContiguousSlice debug representation to a `Writer`.

Args:

- `writer`: The object to write to.

#### `ContiguousSlice.indices`

```mojo
def indices(self, length: Int) -> Tuple[Int, Int]
```

Returns a tuple of 2 integers representing the start, and end of the slice if applied to a container of the given length.

Args:

- `length`: The length of the target container.

Returns: A tuple containing two integers for start and end.

## Functions

### `slice`

```mojo
def slice(end: Int) -> Slice
```

Construct slice given the end value.

Args:

- `end`: The end value.

Returns: The constructed slice.

```mojo
def slice(start: Int, end: Int) -> Slice
```

Construct slice given the start and end values.

Args:

- `start`: The start value.
- `end`: The end value.

Returns: The constructed slice.

```mojo
def slice(start: Optional[Int], end: Optional[Int], step: Optional[Int]) -> Slice
```

Construct a Slice given the start, end and step values.

Args:

- `start`: The start value.
- `end`: The end value.
- `step`: The step value.

Returns: The constructed slice.

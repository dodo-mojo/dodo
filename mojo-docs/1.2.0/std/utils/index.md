# `std.utils.index`

Implements `IndexList` which is commonly used to represent N-D indices.

You can import these APIs from the `utils` package. For example:

```mojo
from std.utils import IndexList
```

## Structs

### `IndexList`

```mojo
struct IndexList[size: Int, *, element_type: DType = .int64]
```

A base struct that implements size agnostic index functions.

Parameters:

- `size`: The size of the tuple.
- `element_type`: The underlying dtype of the integer element value.

Fields:

- `data` (`StaticTuple[Scalar[element_type], size]`): The underlying storage of the tuple value.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `Equatable`, `Hashable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Sized`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `device_type = IndexList[size, element_type=element_type]`: Indicate the type being used on accelerator devices.

#### `IndexList.__init__`

```mojo
def __init__() -> Self
```

Constructs a static int tuple of the given size.

```mojo
def __init__(data: StaticTuple[Scalar[element_type], size]) -> Self
```

Constructs a static int tuple of the given size.

Args:

- `data`: The StaticTuple to construct the IndexList from.

```mojo
def __init__[*Ts: Intable & Movable](elems: Tuple[*Ts.values]) -> Self
```

Constructs a static int tuple given a tuple of integers.

Parameters:

- `*Ts`: The element types of the input tuple (must be `Intable`).

Args:

- `elems`: The tuple to copy from.

```mojo
def __init__(*elems: Int, *, __list_literal__: NoneType = None) -> Self
```

Constructs a static int tuple given a set of arguments.

Args:

- `*elems`: The elements to construct the tuple.
- `__list_literal__`: Specifies that this constructor can be used for list literals.

```mojo
def __init__(fill: Int) -> Self
```

Constructs a static int tuple given a set of arguments.

Args:

- `fill`: The elem to splat into the tuple.

#### `IndexList.__getitem__`

```mojo
def __getitem__[I: Indexer](self, idx: I) -> Int
```

Gets an element from the tuple by index.

Parameters:

- `I`: A type that can be used as an index.

Args:

- `idx`: The element index.

Returns: The tuple element value.

#### `IndexList.__setitem__`

```mojo
def __setitem__(mut self, idx: Int, val: Int)
```

Sets an element in the tuple at the given index.

Args:

- `idx`: The element index.
- `val`: The value to store.

#### `IndexList.__lt__`

```mojo
def __lt__(self, rhs: Self) -> Bool
```

Compares this tuple to another tuple using LT comparison.

A tuple is less-than another tuple if all corresponding elements of lhs
is less than rhs.

Note: This is **not** a lexical comparison.

Args:

- `rhs`: Right hand side tuple.

Returns: The comparison result.

#### `IndexList.__le__`

```mojo
def __le__(self, rhs: Self) -> Bool
```

Compares this tuple to another tuple using LE comparison.

A tuple is less-or-equal than another tuple if all corresponding
elements of lhs is less-or-equal than rhs.

Note: This is **not** a lexical comparison.

Args:

- `rhs`: Right hand side tuple.

Returns: The comparison result.

#### `IndexList.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compares this tuple to another tuple for equality.

The tuples are equal if all corresponding elements are equal.

Args:

- `rhs`: The other tuple.

Returns: The comparison result.

#### `IndexList.__gt__`

```mojo
def __gt__(self, rhs: Self) -> Bool
```

Compares this tuple to another tuple using GT comparison.

A tuple is greater-than than another tuple if all corresponding
elements of lhs is greater-than than rhs.

Note: This is **not** a lexical comparison.

Args:

- `rhs`: Right hand side tuple.

Returns: The comparison result.

#### `IndexList.__ge__`

```mojo
def __ge__(self, rhs: Self) -> Bool
```

Compares this tuple to another tuple using GE comparison.

A tuple is greater-or-equal than another tuple if all corresponding
elements of lhs is greater-or-equal than rhs.

Note: This is **not** a lexical comparison.

Args:

- `rhs`: Right hand side tuple.

Returns: The comparison result.

#### `IndexList.__add__`

```mojo
def __add__(self, rhs: Self) -> Self
```

Performs element-wise integer add.

Args:

- `rhs`: Right hand side operand.

Returns: The resulting index tuple.

#### `IndexList.__sub__`

```mojo
def __sub__(self, rhs: Self) -> Self
```

Performs element-wise integer subtract.

Args:

- `rhs`: Right hand side operand.

Returns: The resulting index tuple.

#### `IndexList.__mul__`

```mojo
def __mul__(self, rhs: Self) -> Self
```

Performs element-wise integer multiply.

Args:

- `rhs`: Right hand side operand.

Returns: The resulting index tuple.

#### `IndexList.__floordiv__`

```mojo
def __floordiv__(self, rhs: Self) -> Self
```

Performs element-wise integer floor division.

Args:

- `rhs`: The elementwise divisor.

Returns: The resulting index tuple.

#### `IndexList.__rfloordiv__`

```mojo
def __rfloordiv__(self, rhs: Self) -> Self
```

Floor divides rhs by this object.

Args:

- `rhs`: The value to elementwise divide by self.

Returns: The resulting index tuple.

#### `IndexList.__len__`

```mojo
def __len__(self) -> Int
```

Returns the size of the tuple.

Returns: The tuple size.

#### `IndexList.get`

```mojo
def get[idx: Int](self) -> Int
```

Gets an element from the tuple by index parameter.

Parameters:

- `idx`: The element index.

Returns: The tuple element value.

#### `IndexList.as_tuple`

```mojo
def as_tuple(self) -> StaticTuple[Int, size]
```

Converts this IndexList to StaticTuple.

Returns: The corresponding StaticTuple object.

#### `IndexList.as_index_tuple`

```mojo
def as_index_tuple(self) -> StaticTuple[SIMDLength, size]
```

Converts this IndexList to a static tuple of mlir indexes.

Returns: The corresponding StaticTuple object.

#### `IndexList.canonicalize`

```mojo
def canonicalize(self) -> IndexList[size]
```

Canonicalizes the IndexList.

Returns: Canonicalizes the object.

#### `IndexList.reverse`

```mojo
def reverse(self) -> Self
```

Reverses the IndexList.

Returns: A new IndexList with the elements in reverse order.

#### `IndexList.flattened_length`

```mojo
def flattened_length(self) -> Int
```

Returns the flattened length of the tuple.

Returns: The flattened length of the tuple.

#### `IndexList.get_row_major_strides`

```mojo
def get_row_major_strides(self) -> Self
```

Interpret the current index list as a shape, and return the strides to traverse such a shape in row-major order.

Returns: The strides to traverse the index list in row-major order.

#### `IndexList.remu`

```mojo
def remu(self, rhs: Self) -> Self
```

Performs element-wise integer unsigned modulo.

Args:

- `rhs`: Right hand side operand.

Returns: The resulting index tuple.

#### `IndexList.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this IndexList value to the provided Writer.

Args:

- `writer`: The object to write to.

#### `IndexList.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this `IndexList` to a writer.

Args:

- `writer`: The object to write to.

#### `IndexList.cast`

```mojo
def cast[dtype: DType](self) -> IndexList[size, element_type=dtype]
```

Casts to the target DType.

Parameters:

- `dtype`: The dtype to cast towards.

Returns: The list casted to the target type.

#### `IndexList.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H)
```

Updates hasher with the underlying bytes.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `IndexList.get_type_name`

```mojo
def get_type_name() -> String
```

Gets the name of the host type (the one implementing this trait). For example, Int would return "Int", DeviceBuffer[.float32] would return "DeviceBuffer[DType.float32]". This is used for error messages when passing types to the device. TODO: This method will be retired soon when better kernel call error messages arrive.

Returns: The host type's name.

## Functions

### `Index`

```mojo
def Index[*Ts: Intable, *, dtype: DType = .int64](*args: *Ts.values) -> IndexList[Int(len(Ts.values)), element_type=dtype]
```

Constructs an N-D Index from the given values.

Parameters:

- `*Ts`: The types of the arguments (must be `Intable`).
- `dtype`: The integer type of the underlying element of the resulting list.

Args:

- `*args`: The values to construct the index from.

Returns: The constructed IndexList.

### `product`

```mojo
def product[size: Int](tuple: IndexList[size, element_type=tuple.element_type], end_idx: Int = size) -> Int
```

Computes a product of values in the tuple up to the given index.

Parameters:

- `size`: The tuple size.

Args:

- `tuple`: The tuple to get a product of.
- `end_idx`: The end index.

Returns: The product of all tuple elements in the given range.

```mojo
def product[size: Int](tuple: IndexList[size, element_type=tuple.element_type], start_idx: Int, end_idx: Int) -> Int
```

Computes a product of values in the tuple in the given index range.

Parameters:

- `size`: The tuple size.

Args:

- `tuple`: The tuple to get a product of.
- `start_idx`: The start index of the range.
- `end_idx`: The end index of the range.

Returns: The product of all tuple elements in the given range.

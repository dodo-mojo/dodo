# `std.utils.static_tuple`

Implements StaticTuple, a statically-sized uniform container.

You can import these APIs from the `utils` package. For example:

```mojo
from std.utils import StaticTuple
```

## Structs

### `StaticTuple`

```mojo
struct StaticTuple[element_type: RegisterPassable & ImplicitlyCopyable & Deinitable, size: Int]
```

A statically sized tuple type which contains elements of homogeneous types.

Parameters:

- `element_type`: The type of the elements in the tuple.
- `size`: The size of the tuple.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Sized`, `TrivialRegisterPassable`

Aliases:

- `device_type = StaticTuple[element_type(DevicePassable & RegisterPassable & ImplicitlyCopyable & Deinitable).device_type(RegisterPassable & ImplicitlyCopyable & Deinitable) if conforms_to(element_type, DevicePassable) else element_type, size]`: The device-side type for this `StaticTuple`.

#### `StaticTuple.__init__`

```mojo
def __init__() -> Self
```

Constructs an empty (undefined) tuple.

```mojo
def __init__(*, mlir_value: __mlir_type.`!pop.array<to_builtin(:scalar<index> #lit.struct.extract<:!lit.struct<_std::_simd::_SIMD<:!lit.struct<_std::_builtin::_dtype::_DType> {:dtype index}, :!lit.struct<_std::_builtin::_simd_length::_SIMDLength> {1}>> size, "_mlir_value">), :trait<_std::_builtin::_value::_RegisterPassable, _std::_traits::_anytype::_AnyType, _std::_traits::_copyable::_Copyable, _std::_traits::_copyable::_ImplicitlyCopyable, _std::_traits::_deinitable::_Deinitable, _std::_traits::_movable::_Movable> element_type>`) -> Self
```

Constructs from an array type.

Args:

- `mlir_value`: Underlying MLIR array type.

```mojo
def __init__(*, fill: element_type) -> Self
```

Constructs a static tuple given a fill value.

Args:

- `fill`: The value to fill the tuple with.

```mojo
def __init__(*elems: element_type) -> Self
```

Constructs a static tuple given a set of arguments.

Args:

- `*elems`: The element types.

```mojo
def __init__[*values: element_type]() -> Self
```

Creates a tuple constant using the specified values.

Parameters:

- `*values`: The list of values.

#### `StaticTuple.__getitem__`

```mojo
def __getitem__[I: Indexer, //](self, idx: I) -> element_type
```

Returns the value of the tuple at the given dynamic index.

Parameters:

- `I`: A type that can be used as an index.

Args:

- `idx`: The index into the tuple.

Returns: The value at the specified position.

#### `StaticTuple.__setitem__`

```mojo
def __setitem__[I: Indexer, //](mut self, idx: I, val: element_type)
```

Stores a single value into the tuple at the specified dynamic index.

Parameters:

- `I`: A type that can be used as an index.

Args:

- `idx`: The index into the tuple.
- `val`: The value to store.

#### `StaticTuple.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool where conforms_to(element_type, Comparable & TrivialRegisterPassable)
```

Returns `True` if `self` is lexicographically less than `other`.

Args:

- `other`: The tuple to compare with.

Returns: True if `self` is lexicographically less than `other`.

#### `StaticTuple.__le__`

```mojo
def __le__(self, other: Self) -> Bool where conforms_to(element_type, Comparable & TrivialRegisterPassable)
```

Returns `True` if `self` is lexicographically less than or equal to `other`.

Args:

- `other`: The tuple to compare with.

Returns: True if `self` is lexicographically less than or equal to `other`.

#### `StaticTuple.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool where conforms_to(element_type, Equatable & TrivialRegisterPassable)
```

Returns `True` if all elements are equal.

Args:

- `other`: The tuple to compare with.

Returns: True if all corresponding elements are equal.

#### `StaticTuple.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool where conforms_to(element_type, Equatable & TrivialRegisterPassable)
```

Returns `True` if any element differs.

Args:

- `other`: The tuple to compare with.

Returns: True if any corresponding elements differ.

#### `StaticTuple.__gt__`

```mojo
def __gt__(self, other: Self) -> Bool where conforms_to(element_type, Comparable & TrivialRegisterPassable)
```

Returns `True` if `self` is lexicographically greater than `other`.

Args:

- `other`: The tuple to compare with.

Returns: True if `self` is lexicographically greater than `other`.

#### `StaticTuple.__ge__`

```mojo
def __ge__(self, other: Self) -> Bool where conforms_to(element_type, Comparable & TrivialRegisterPassable)
```

Returns `True` if `self` is lexicographically greater than or equal to `other`.

Args:

- `other`: The tuple to compare with.

Returns: True if `self` is lexicographically greater than or equal to `other`.

#### `StaticTuple.get_type_name`

```mojo
def get_type_name() -> String
```

Get the human-readable type name for this `StaticTuple`.

Returns: A string representation of the type, e.g. "StaticTuple[Int, 3]".

#### `StaticTuple.__len__`

```mojo
def __len__(self) -> Int
```

Returns the length of the array. This is a known constant value.

Returns: The size of the list.

#### `StaticTuple.get`

```mojo
def get[index: Int](self) -> element_type
```

Returns the value of the tuple at the given index.

Parameters:

- `index`: The index into the tuple.

Returns: The value at the specified position.

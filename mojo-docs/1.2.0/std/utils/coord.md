# `std.utils.coord`

Unified layout system for mixed compile-time and runtime indices.

## Aliases

### `Idx`

```mojo
comptime Idx[value: Int] = ComptimeInt()
```

A compile-time coordinate index value.

### `coord`

```mojo
comptime coord[*values: Int] = Coord()
```

Create a `Coord` from compile-time integer values.

Returns:
    A `Coord` instance containing `ComptimeInt` elements for each value.

### `DynamicCoord`

```mojo
comptime DynamicCoord[dtype: DType, size: Int] = Coord[*#kgen.param_list.tabulate(size, [idx: __mlir_type.index] Scalar[dtype])]
```

Create a Coord full of `size` dynamic elements with `dtype`.

Returns:
    A Coord full of `size` dynamic elements with `dtype`.

### `StaticCoord`

```mojo
comptime StaticCoord[value: Int, size: Int] = Coord[*#kgen.param_list.tabulate(size, [idx: __mlir_type.index] ComptimeInt[value])]
```

Create a Coord full of `size` static elements.

Returns:
    A Coord full of `size` static elements.

## Structs

### `ComptimeInt`

```mojo
struct ComptimeInt[val: Int]
```

Compile-time known index value.

Parameters:

- `val`: The compile-time integer value.

Implemented traits: `AnyType`, `CoordLike`, `Copyable`, `Defaultable`, `Deinitable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `ParamListType = TypeList[ComptimeInt[val]]()`: The element types (Self for scalar types).
- `static_value = val`: The compile-time value.
- `DTYPE = DType.int`: The data type (int for compile-time integers).
- `is_static_value = True`: True, indicating this is a compile-time known value.
- `is_tuple = False`: True if this is a tuple type (`Coord`), False for scalar values.
- `is_value = True`: True if this is a scalar value, False for tuple types.

#### `ComptimeInt.__init__`

```mojo
def __init__() -> Self
```

Initialize a compile-time integer with the specified value.

#### `ComptimeInt.__len__`

```mojo
def __len__() -> Int
```

Get the length (always 1 for scalar types).

Returns: Always returns 1.

#### `ComptimeInt.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write this compile-time integer to a writer.

Args:

- `writer`: The writer to write to.

#### `ComptimeInt.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this compile-time integer to a writer.

Args:

- `writer`: The writer to write to.

#### `ComptimeInt.product`

```mojo
def product(self) -> Int
```

Calculate the product (returns the value for scalar types).

Returns: The integer value.

#### `ComptimeInt.value`

```mojo
def value(self) -> Int
```

Get the scalar value.

Returns: The compile-time integer value.

#### `ComptimeInt.tuple`

```mojo
def tuple(var self) -> Coord[Self]
```

Get as a tuple (not valid for `ComptimeInt`).

Returns: Never returns; aborts at compile time.

### `Coord`

```mojo
struct Coord[*element_types: CoordLike]
```

A struct representing tuple-like data with compile-time and runtime elements.

Parameters:

- `*element_types`: The list of element types that implement `CoordLike`.

Implemented traits: `AnyType`, `CoordLike`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `RegisterPassable`, `Sized`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `device_type = Coord[element_types]`: Indicate the type being used on accelerator devices.
- `ParamListType = element_types`: The element types of this `Coord`.
- `static_value = Int(-1)`: Always -1 for tuple types (value not applicable).
- `DTYPE = DType.int`: The scalar dtype used for tuple-level aggregate operations.
- `is_tuple = True`: True, indicating this is a tuple type.
- `all_dims_known = TypeList.all[comptime[Type: CoordLike] Type.is_static_value]() if TypeList.all[comptime[Type: CoordLike] not Type.is_tuple.__bool__()]() else TypeList.all[comptime[Type: CoordLike] Type.is_static_value]()`: True if all dimensions are statically known at compile time.
- `static_product = #kgen.param_list.reduce(values, base=Int(1), reducer=[PrevV: Int, VA: KGENParamList[CoordLike], idx: __mlir_type.index] Int((mul VA[idx].static_value, PrevV))) if TypeList.all[comptime[Type: CoordLike] not Type.is_tuple.__bool__()]() else #kgen.param_list.reduce(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType)), base=Int(1), reducer=[PrevV: Int, VA: KGENParamList[CoordLike], idx: __mlir_type.index] Int((mul VA[idx].static_value, PrevV)))`: The product of all static dimensions, or -1 if any are dynamic.
- `rank = TypeList[values].length`: The number of top-level elements in this `Coord`.
- `flat_rank = TypeList[#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))].length`: The total number of leaf elements after flattening nested `Coord`s.
- `is_flat = (Int(len(values)) == Int(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(values), [idx: __mlir_type.index] values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType)))))`: If the `Coord` contains nested items.
- `is_static_value = False`: True if the value is known at compile time.
- `is_value = False`: True if this is a scalar value, False for tuple types.

#### `Coord.__init__`

```mojo
def __init__() -> Self
```

Empty initialize a tensor with static dims.

```mojo
def __init__[rank: Int, dtype: DType](index_list: IndexList[element_type=dtype]) -> Coord[*#kgen.param_list.tabulate(index_list.rank, [idx: __mlir_type.index] Scalar[dtype])]
```

Construct a `Coord` from an `IndexList`.

Parameters:

- `rank`: The number of elements in the index list.
- `dtype`: The data type of the index list elements.

Args:

- `index_list`: The `IndexList` to convert to a `Coord`.

```mojo
def __init__[rank: Int, dtype: DType](array: Array[Scalar[dtype]]) -> Coord[*#kgen.param_list.tabulate(array.rank, [idx: __mlir_type.index] Scalar[dtype])]
```

Construct an all-dynamic `Coord` from an `Array`.

Parameters:

- `rank`: The number of elements in the array.
- `dtype`: The data type of the array elements.

Args:

- `array`: The `Array` to convert to a `Coord`.

```mojo
def __init__(var *args: *element_types.values) -> Self
```

Construct tuple from variadic arguments.

Args:

- `*args`: Values for each element.

```mojo
def __init__(var tuple: Tuple[*element_types.values]) -> Self
```

Construct from a Tuple with matching element types.

Args:

- `tuple`: The Tuple to construct from.

#### `Coord.__eq__`

```mojo
def __eq__[*other_types: CoordLike](self, other: Coord[other_types]) -> Bool
```

Check if this `Coord` equals another.

Parameters:

- `*other_types`: The element types of the other `Coord`.

Args:

- `other`: The `Coord` to compare with.

Returns: True if all elements are equal, False otherwise.

#### `Coord.__ne__`

```mojo
def __ne__[*other_types: CoordLike](self, other: Coord[other_types]) -> Bool
```

Check if this `Coord` is not equal to another.

Parameters:

- `*other_types`: The element types of the other `Coord`.

Args:

- `other`: The `Coord` to compare with.

Returns: True if any elements differ, False if all are equal.

#### `Coord.size`

```mojo
def size() -> Int
```

Get the total number of elements including nested ones.

Returns: The total count of all elements.

#### `Coord.__len__`

```mojo
def __len__() -> Int
```

Get the length of the tuple.

Returns: The number of elements in the tuple.

```mojo
def __len__(self) -> Int
```

Get the length of the tuple.

Returns: The number of elements in the tuple.

#### `Coord.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this `Coord` to a writer.

Args:

- `writer`: The writer to write the representation to.

#### `Coord.__getitem_param__`

```mojo
def __getitem_param__[idx: Int](ref self) -> ref[idx._storage] element_types.values[SIMDLength(idx)]
```

Get a reference to an element in the tuple.

Parameters:

- `idx`: The element index to access.

Returns: A reference to the specified element.

#### `Coord.product`

```mojo
def product(self) -> Int
```

Calculate the product of all elements recursively.

Returns: The product of all leaf values in the `Coord`.

```mojo
def product[result_dtype: DType](self) -> Scalar[result_dtype]
```

Calculate the product of all elements recursively at `result_dtype` precision.

Parameters:

- `result_dtype`: The dtype the product is accumulated and returned in.

Returns: The product of all leaf values in the `Coord`.

#### `Coord.value`

```mojo
def value(self) -> Int
```

Get the value (not valid for `Coord` tuples).

Returns: Never returns; aborts at compile time.

#### `Coord.tuple`

```mojo
def tuple(var self) -> Self
```

Get this `Coord` as a tuple.

Returns: This `Coord` (identity operation for tuple types).

#### `Coord.reverse`

```mojo
def reverse(var self) -> Coord[*#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[(add (mul idx, -1), len(element_types.values), -1)])]
```

Reverse the order of elements in this `Coord`.

Returns: A new `Coord` with elements in reverse order.

#### `Coord.concat`

```mojo
def concat[*other_element_types: CoordLike](var self, var other: Coord[other_element_types]) -> Coord[*#kgen.param_list.concat(element_types.values, other_element_types.values)]
```

Concatenate this `Coord` with another.

Parameters:

- `*other_element_types`: The element types of the other `Coord`.

Args:

- `other`: The `Coord` to append.

Returns: A new `Coord` containing elements from both `Coord`s.

#### `Coord.flatten`

```mojo
def flatten(var self) -> Coord[*#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(#kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))), [idx: __mlir_type.index] #kgen.param_list.concat(#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))[idx]._ParamListType))]
```

Convert a nested `Coord` to a flattened `Coord`.

Examples:
```mojo
from layout import Coord, Idx
var nested = Coord(
    Idx[5],
    Coord(Idx[3], Idx[2]),
    7
)
var flat = nested.flatten()
# flat is Coord(Idx[5], Idx[3], Idx[2], 7)
```

Returns: A flattened `Coord` containing all leaf values in order.

#### `Coord.make_dynamic`

```mojo
def make_dynamic[dtype: DType](self) -> Coord[*#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] Scalar[dtype])]
```

Convert all elements to `Scalar[dtype]`.

Examples:
```mojo
from std.utils.coord import Coord, ComptimeInt
var c = Coord(ComptimeInt[3](), Int32(5), ComptimeInt[7]())
var dynamic = c.make_dynamic[.int64]()
# dynamic is Coord(Int64(3), Int64(5), Int64(7))
```

Parameters:

- `dtype`: The data type for the resulting `Scalar` values.

Returns: A new `Coord` where all elements are converted to `Scalar[dtype]`.

#### `Coord.replace`

```mojo
def replace[T: CoordLike, //, at: Int](var self, value: T) -> Coord[*#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] T if identical(idx, at) else element_types.values[idx])]
```

Replace the element at `at`, keeping the other elements' types.

A `Coord`'s element types are part of its type, so a statically known
element has no runtime storage to assign into. Overwriting one with a
runtime value therefore produces a `Coord` of a different type rather
than mutating in place. The untouched elements keep their static
values.

Examples:
```mojo
from std.utils.coord import Coord, ComptimeInt
var c = Coord(ComptimeInt[3](), ComptimeInt[4](), ComptimeInt[5]())
var moved = c.replace[1](Int64(7))
# moved is Coord(ComptimeInt[3](), Int64(7), ComptimeInt[5]())
```

Parameters:

- `T`: The replacement element's type.
- `at`: The index of the element to replace.

Args:

- `value`: The replacement element.

Returns: A new `Coord` with `value` at `at`.

#### `Coord.replace_dynamic`

```mojo
def replace_dynamic[dtype: DType, //, at: Int](mut self, value: Scalar[dtype])
```

Assign a runtime `value` to an already-dynamic element, in place.

`value` must already have the element's own dtype, so the assignment
cannot truncate or wrap; convert at the call site to narrow.

Examples:
```mojo
from std.utils.coord import Coord, ComptimeInt
var c = Coord(ComptimeInt[3](), Int64(0))
c.replace_dynamic[1](Int64(7))
# c is Coord(ComptimeInt[3](), Int64(7))
```

Constraints: - `at` must be a valid element index.
- The `Coord` must be flat. A nested element reports `DType.int`
and is not static, so the other checks would not reject it.
- The element at `at` must not be statically known; use `replace`
to overwrite a static element, which yields a new `Coord` type.
- `dtype` must equal the dtype of the element at `at`.

Parameters:

- `dtype`: The dtype of `value`, which must match the element's.
- `at`: The index of the element to assign to.

Args:

- `value`: The runtime value to store.

#### `Coord.write_to`

```mojo
def write_to(self, mut w: T)
```

Write this `Coord` to a `Writer`.

Args:

- `w`: The writer to output to.

#### `Coord.cast`

```mojo
def cast[dtype: DType](self) -> Coord[*#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] element_types.values[idx] if element_types.values[idx].is_static_value else Scalar[dtype])]
```

Cast runtime elements to `Scalar[dtype]`.

Compile-time elements are preserved as-is, so statically known
dimensions stay static after the cast.

Parameters:

- `dtype`: The target data type for runtime elements.

Returns: A new `Coord` where runtime elements use `dtype` and static elements keep their original type.

#### `Coord.get_type_name`

```mojo
def get_type_name() -> String
```

Get the human-readable type name for this `Coord`.

This is used for error messages when passing types to the device.

Returns: A string representation of the type, e.g. "Coord[ComptimeInt[2], Int64]".

## Traits

### `CoordLike`

```mojo
trait CoordLike
```

Trait for unified layout handling of compile-time and runtime indices.

Inherits from: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `ParamListType`: The type list of element types for coordinates.
- `static_value`: The compile-time value if statically known, -1 otherwise.
- `is_static_value = False`: True if the value is known at compile time.
- `is_tuple = False`: True if this is a tuple type (`Coord`), False for scalar values.
- `is_value = not _Self.is_tuple.__bool__()`: True if this is a scalar value, False for tuple types.
- `DTYPE = DType.int`: The data type used by scalar-returning coordinate operations.

#### `CoordLike.__len__`

```mojo
def __len__() -> Int
```

Get the number of elements in this type.

Returns: The number of elements (1 for single values, >1 for tuples).

#### `CoordLike.value`

```mojo
def value(self) -> Scalar[Self.DTYPE]
```

Get the scalar value of this coordinate.

Only valid for value types (not tuples).

Returns: The scalar value.

#### `CoordLike.tuple`

```mojo
def tuple(var self) -> Coord[Self.ParamListType]
```

Get this coordinate as a `Coord` tuple.

Only valid for tuple types.

Returns: The coordinate as a `Coord` tuple.

#### `CoordLike.product`

```mojo
def product(self) -> Scalar[Self.DTYPE]
```

Calculate the product of all elements.

Returns: The product of all elements.

#### `CoordLike.__int__`

```mojo
def __int__(self) -> Int
```

Convert this coordinate to an `Int`.

Returns: The coordinate's scalar value as an `Int`.

## Functions

### `crd2idx`

```mojo
def crd2idx[Index: CoordLike, Shape: CoordLike, Stride: CoordLike, out_type: DType = .int64](crd: Index, shape: Shape, stride: Stride) -> Scalar[out_type]
```

Calculate the linear index from a coordinate tuple.

The dot product is computed at `out_type` precision (each `coord * stride`
term is evaluated after narrowing both operands to `out_type`), and so is
splitting a scalar coordinate across a mode's sub-modes. Callers that pick
a narrow `out_type` (e.g. `uint32`) are responsible for ensuring the
coordinate, every per-dim product and their sum fit in that type. The default
`DType.int64` is wide enough for realistic layouts. See `_crd2idx_flat`.

Parameters:

- `Index`: The coordinate type (must be CoordLike).
- `Shape`: The shape type (must be CoordLike).
- `Stride`: The stride type (must be CoordLike).
- `out_type`: The output scalar type.

Args:

- `crd`: The multi-dimensional coordinate.
- `shape`: The shape of the tensor.
- `stride`: The stride of the tensor.

Returns: The linear index corresponding to the coordinate.

### `idx2crd`

```mojo
def idx2crd[Shape: CoordLike, Stride: CoordLike, out_dtype: DType = .int64](idx: Int, shape: Shape, stride: Stride) -> Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx].is_tuple else ComptimeInt[Int(0)] if Shape._ParamListType[idx].is_static_value and identical(Shape._ParamListType[idx].static_value, 1) else Scalar[out_dtype])]
```

Calculate the coordinate tuple from a linear index.

This is the inverse of crd2idx - given a linear index, shape, and stride,
it computes the multi-dimensional coordinates using the per-element formula:
``coord[i] = (idx // stride[i]) % shape[i]``.

When a shape dimension is statically known to be 1, the corresponding
output coordinate is a `ComptimeInt[0]`. Otherwise, coordinates are
`Scalar[out_dtype]`.

The idx, and all components of shape and stride must be non-negative.

Examples:

```mojo
For a 2D tensor with shape (3, 4) and row-major strides (4, 1):
```

- idx2crd(0, shape, stride) returns (0, 0).
- idx2crd(5, shape, stride) returns (1, 1).
- idx2crd(11, shape, stride) returns (2, 3).

Parameters:

- `Shape`: The shape type (must be CoordLike).
- `Stride`: The stride type (must be CoordLike).
- `out_dtype`: The output data type for coordinate values.

Args:

- `idx`: The linear index to convert.
- `shape`: The shape of the tensor.
- `stride`: The stride of the tensor.

Returns: A `Coord` containing the coordinate values for each dimension. Dimensions with static shape 1 produce `ComptimeInt[0]`, others produce `Scalar[out_dtype]`.

```mojo
def idx2crd[Index: CoordLike, Shape: CoordLike, Stride: CoordLike, out_dtype: DType = .int64](idx: Index, shape: Shape, stride: Stride) -> Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Coord[*#kgen.param_list.tabulate(len(Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType), [idx: __mlir_type.index] Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx]._ParamListType[idx].is_tuple else Scalar[out_dtype])] if Shape._ParamListType[idx].is_tuple else ComptimeInt[Int(0)] if Shape._ParamListType[idx].is_static_value and identical(Shape._ParamListType[idx].static_value, 1) else ComptimeInt[((Index.static_value // Stride._ParamListType[idx].static_value) % Shape._ParamListType[idx].static_value)] if Index.is_static_value and Shape._ParamListType[idx].is_static_value and Stride._ParamListType[idx].is_static_value else Scalar[out_dtype])]
```

Calculate the coordinate tuple from a CoordLike linear index.

This overload accepts a CoordLike index, enabling compile-time result
computation when the index, shape, and stride are all statically known.
Uses the per-element formula: ``coord[i] = (idx // stride[i]) % shape[i]``.

The idx, and all components of shape and stride must be non-negative.

Parameters:

- `Index`: The index type (must be CoordLike).
- `Shape`: The shape type (must be CoordLike).
- `Stride`: The stride type (must be CoordLike).
- `out_dtype`: The output data type for coordinate values.

Args:

- `idx`: The CoordLike linear index to convert.
- `shape`: The shape of the tensor.
- `stride`: The stride of the tensor.

Returns: A `Coord` containing the coordinate values for each dimension. When idx, shape, and stride are all compile-time known, produces `ComptimeInt` results. Otherwise produces `Scalar[out_dtype]`.

### `coord_to_index_list`

```mojo
def coord_to_index_list[element_types: TypeList[element_types.values]](value: Coord[element_types]) -> IndexList[Int(len(element_types.values))]
```

Convert a flat `Coord` to an `IndexList`.

Parameters:

- `element_types`: The list of element types in the `Coord`.

Args:

- `value`: The `Coord` to convert.

Returns: An `IndexList` with the same rank and values as the input `Coord`.

### `dyn_coord`

```mojo
def dyn_coord[dtype: DType, *element_types: Deinitable & Movable](var values: Tuple[*element_types.values]) -> Coord[*#kgen.param_list.tabulate(len(element_types.values), [idx: __mlir_type.index] Scalar[dtype])] where TypeList.all[comptime[Type: AnyType] Bool(identical(Type, Int))]()
```

Create a `Coord` from a tuple of integers with specified dtype.

Parameters:

- `dtype`: The data type for the runtime integer values.
- `*element_types`: The types of elements in the input tuple.

Args:

- `values`: The runtime integer values.

Returns: A `Coord` instance containing `Scalar` elements for each value.

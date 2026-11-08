# `std.python.numpy`

NumPy interoperability helpers for Mojo collections.

These functions move flat numeric data between Mojo `Span` and NumPy
arrays when a Mojo program drives CPython (via `Python.import_module`), without
hand-written `ctypes` plumbing:

- `copy_to_numpy_array` builds a NumPy array from a Mojo `Span` by copying
  the data into a new, independent array.
- `from_numpy_array` borrows a NumPy array's buffer as a Mojo `Span`
  (zero-copy).

Only 1-D, C-contiguous arrays of the fixed-width numeric dtypes (`int8` through
`int64`, `uint8` through `uint64`, `float16`, `float32`, `float64`) are
supported. This targets the common case of handing computed numeric data to a
library such as `matplotlib`.

## Structs

### `NumPyView`

```mojo
struct NumPyView[mut: Bool, //, dtype: DType, rank: Int, origin: Origin[mut=mut]]
```

A borrowed view of a C-contiguous NumPy array's buffer and shape.

`from_numpy_tensor` returns this rather than a bare `Span`, so the extents
needed to index the buffer travel with it. `shape` is a `Coord`, so it can
be handed straight back to `copy_to_numpy_tensor`.

Parameters:

- `mut`: The mutability of the borrow.
- `dtype`: The element dtype.
- `rank`: The number of dimensions.
- `origin`: The origin of the borrow.

Fields:

- `data` (`Span[Scalar[dtype], origin]`): The array's elements, in C order.
- `shape` (`Coord[*#kgen.param_list.tabulate(rank, [idx: __mlir_type.index] Int)]`): The extent of each axis. Subscript it with a compile-time index.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

#### `NumPyView.__getitem__`

```mojo
def __getitem__[*Ts: Intable](self, *idx: *Ts.values) -> ref[origin] Scalar[dtype]
```

Returns a reference to the element at `idx`.

Constraints: The number of indices must equal `rank`.

Parameters:

- `*Ts`: The type of each index argument.

Args:

- `*idx`: One index per axis.

Returns: A reference to the element, mutable if the view is.

## Functions

### `copy_to_numpy_array`

```mojo
def copy_to_numpy_array[dtype: DType, origin: Origin[mut=origin.mut]](data: Span[Scalar[dtype], origin]) raises -> PythonObject
```

Builds a 1-D NumPy array from a Mojo `Span` of scalars.

The data is copied into a new, independent NumPy array, so the result
remains valid after `data` is later mutated or freed. Unlike
`from_numpy_array`, which returns a zero-copy view, this function does not
alias `data`: mutating `data` after this call is not reflected in the
returned array, and writes to the array are not reflected in `data`.

Example:

```mojo
from std.python.numpy import copy_to_numpy_array
from std.math import sin

var values = List[Float64](capacity=1024)
for i in range(1024):
    var x = Float64(i) * 0.01
    values.append(sin(x) * sin(x))

var arr = copy_to_numpy_array(values)  # an independent NumPy float64 array
```

Constraints: `dtype` must be one of the fixed-width numeric dtypes supported by
NumPy: `int8`-`int64`, `uint8`-`uint64`, `float16`, `float32`, or
`float64`.

Parameters:

- `dtype`: The element dtype of the span (inferred).
- `origin`: The origin of the span (inferred).

Args:

- `data`: The scalars to copy into a NumPy array.

Returns: A 1-D NumPy `ndarray` of dtype `dtype` and length `len(data)`.

Raises: If NumPy is unavailable, or if the underlying NumPy calls fail.

### `copy_to_numpy_tensor`

```mojo
def copy_to_numpy_tensor[dtype: DType, origin: ImmOrigin, *shape_types: CoordLike](data: Span[Scalar[dtype], origin], shape: Coord[shape_types]) raises -> PythonObject
```

Builds an N-D NumPy array from a Mojo `Span` of scalars and a shape.

The span supplies the elements in C order (last axis varying fastest) and
`shape` supplies the extents, so `shape.product()` must equal `len(data)`.
The data is copied into a new, independent NumPy array, so the result
remains valid after `data` is later mutated or freed.

Example:

```mojo
from std.python.numpy import copy_to_numpy_tensor
from std.utils.coord import Coord, Idx

var values = List[Float64](capacity=6)
for i in range(6):
    values.append(Float64(i))

var arr = copy_to_numpy_tensor(values, Coord(Idx[2], Idx[3]))  # 2x3 array
```

Dimensions may be compile-time (`Idx[N]`) or runtime (`Int`) in any mix.

Constraints: `dtype` must be one of the fixed-width numeric dtypes supported by
NumPy: `int8`-`int64`, `uint8`-`uint64`, `float16`, `float32`, or
`float64`. `shape` must be flat (no nested `Coord`) and must not
contain `All`.

Parameters:

- `dtype`: The element dtype of the span (inferred).
- `origin`: The origin of the span (inferred).
- `*shape_types`: The per-dimension types of `shape` (inferred).

Args:

- `data`: The scalars to copy into a NumPy array, in C order.
- `shape`: The extents of the result, one element per axis.

Returns: A NumPy `ndarray` of dtype `dtype` and shape `shape`.

Raises: If `shape.product()` does not equal `len(data)`, if NumPy is unavailable, or if the underlying NumPy calls fail.

### `from_numpy_array`

```mojo
def from_numpy_array[mut: Bool, //, dtype: DType, origin: Origin[mut=mut]](ref[origin] array: PythonObject) raises -> Span[Scalar[dtype], origin]
```

Borrows a 1-D C-contiguous NumPy array as a Mojo `Span`.

The returned span aliases the NumPy array's buffer; no bytes are copied. Its
origin is tied to `array`, so the compiler keeps `array` alive for as long as
the span is used; you must still not resize or reallocate `array` while the
span is in use, or the span will dangle. Only pass arrays whose buffer is
owned by NumPy (or another Python object).

The borrow follows the mutability of the `array` reference: an immutable
(`read`) reference yields a read-only span. A mutable reference
yields a mutable span, so writes are visible to NumPy and vice versa.
Creating a mutable span fails if the underlying NumPy array is not
writable. Pass `array` as an immutable reference to avoid this error.

Example:

```mojo
from std.python import Python
from std.python.numpy import from_numpy_array

var np = Python.import_module("numpy")
var array = np.arange(8, dtype="float64")
var span = from_numpy_array[.float64](array)
var total = Float64(0)
for value in span:
    total += value
```

Constraints: `dtype` must be one of the fixed-width numeric dtypes supported by
NumPy.

Parameters:

- `mut`: The mutability of the borrow, inferred from `array`.
- `dtype`: The expected element dtype of the array.
- `origin`: The origin of the borrow, inferred from `array`.

Args:

- `array`: A 1-D, C-contiguous NumPy `ndarray` whose dtype matches `dtype`.

Returns: A `Span` of length `array.size` viewing the array's buffer, with the same mutability and origin as the `array` binding.

Raises: If `array` is not 1-D, is not C-contiguous, has a dtype that does not match `dtype`, or is not writable when borrowed mutably.

### `from_numpy_tensor`

```mojo
def from_numpy_tensor[mut: Bool, //, dtype: DType, rank: Int, origin: Origin[mut=mut]](ref[origin] array: PythonObject) raises -> NumPyView[dtype, rank, origin]
```

Borrows an N-D C-contiguous NumPy array as a `NumPyView`.

This is the N-D counterpart of `from_numpy_array`: the view aliases the
array's whole buffer in C order (last axis varying fastest) and carries the
extents needed to index it. No bytes are copied, and the same aliasing
rules as `from_numpy_array` apply.

Example:

```mojo
from std.python import Python
from std.python.numpy import from_numpy_tensor

var np = Python.import_module("numpy")
var array = np.arange(6, dtype="float64").reshape(2, 3)
var view = from_numpy_tensor[.float64, 2](array)
var value = view[1, 2]          # array[1, 2]
var flat = view.data            # the buffer as a `Span`, in C order
```

Constraints: `dtype` must be one of the fixed-width numeric dtypes supported by
NumPy. `rank` must be positive.

Parameters:

- `mut`: The mutability of the borrow, inferred from `array`.
- `dtype`: The expected element dtype of the array.
- `rank`: The expected number of dimensions.
- `origin`: The origin of the borrow, inferred from `array`.

Args:

- `array`: A C-contiguous NumPy `ndarray` of `rank` dimensions whose dtype matches `dtype`.

Returns: A `NumPyView` of the array's buffer and shape, with the same mutability and origin as the `array` binding.

Raises: If `array.ndim` is not `rank`, is not C-contiguous, has a dtype that does not match `dtype`, or is not writable when borrowed mutably.

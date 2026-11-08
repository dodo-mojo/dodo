# `std.bit.mask`

Provides functions for bit masks.

You can import these APIs from the `bit` package. For example:

```mojo
from std.bit.mask import is_negative
```

## Functions

### `is_negative`

```mojo
def is_negative[dtype: DType, //](value: SIMD[dtype]) -> SIMD[dtype, value.length]
```

Get a bitmask of whether the value is negative.

Parameters:

- `dtype`: The DType.

Args:

- `value`: The value to check.

Returns: A bitmask filled with `1` if the value is negative, filled with `0` otherwise.

### `splat`

```mojo
def splat[size: SIMDLength, //, dtype: DType](value: SIMD[.bool, size]) -> SIMD[dtype, size]
```

Elementwise splat the boolean value of each element in the SIMD vector into all bits of the corresponding element in a new SIMD vector.

Parameters:

- `size`: The size of the SIMD vector.
- `dtype`: The DType of the output.

Args:

- `value`: The value to check.

Returns: A SIMD vector where each element is filled with `1` bits if the corresponding element in `value` is `True`, or filled with `0` bits otherwise.

```mojo
def splat(value: Bool) -> Int
```

Get a bitmask of whether the value is `True`.

Args:

- `value`: The value to check.

Returns: A bitmask filled with `1` if the value is `True`, filled with `0` otherwise.

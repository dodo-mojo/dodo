# `std.bit.bit`

Provides functions for bit manipulation.

You can import these APIs from the `bit` package. For example:

```mojo
from std.bit import count_leading_zeros
```

## Functions

### `count_leading_zeros`

```mojo
def count_leading_zeros[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Counts the per-element number of leading zeros in a SIMD vector.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `DType` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` contains the number of leading zeros at position `i` of the input value.

### `count_trailing_zeros`

```mojo
def count_trailing_zeros[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Counts the per-element number of trailing zeros in a SIMD vector.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` contains the number of trailing zeros at position `i` of the input value.

### `bit_reverse`

```mojo
def bit_reverse[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Element-wise reverses the bitpattern of a SIMD vector of integer values.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` has a reversed bitpattern of an integer value of the element at position `i` of the input value.

### `byte_swap`

```mojo
def byte_swap[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Byte-swaps a SIMD vector of integer values with an even number of bytes.

Byte swap an integer value or vector of integer values with an even number
of bytes (positive multiple of 16 bits). For example, The Int16 returns an
Int16 value that has the high and low byte of the input Int16 swapped.
Similarly, Int32 returns an Int32 value that has the four bytes of the input Int32 swapped,
so that if the input bytes are numbered 0, 1, 2, 3 then the returned Int32 will
have its bytes in 3, 2, 1, 0 order. Int64 and other integer type extend this
concept to additional even-byte lengths (6 bytes, 8 bytes and more, respectively).

Constraints: The element type of the input vector must be an integral type.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` is the value of the element at position `i` of the input value with its bytes swapped.

### `pop_count`

```mojo
def pop_count[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Counts the number of bits set in a SIMD vector of integer values.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` contains the number of bits set in the element at position `i` of the input value.

### `bit_not`

```mojo
def bit_not[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Performs a bitwise NOT operation on an SIMD vector of integer values.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` is computed as a bitwise NOT of the integer value at position `i` of the input value.

### `bit_width`

```mojo
def bit_width[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Computes the minimum number of bits required to represent each element of a SIMD vector of integer values.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` equals the number of bits required to represent the integer at position `i` of the input.

### `log2_floor`

```mojo
def log2_floor[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Returns the floor of the base-2 logarithm of an integer value.

Parameters:

- `dtype`: The `dtype` of the input SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `val`: The input value.

Returns: The floor of the base-2 logarithm of the input value, which is equal to the position of the highest set bit. Returns -1 if val is 0 or negative.

### `log2_ceil`

```mojo
def log2_ceil(val: Scalar) -> Scalar[val.dtype]
```

Returns the ceiling of the base-2 logarithm of an integer value.

Args:

- `val`: The input value.

Returns: The smallest integer `n` such that `2^n` is greater than or equal to the input value. Returns 0 if `val` is 0.

### `next_power_of_two`

```mojo
def next_power_of_two[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Computes the smallest power of 2 that is greater than or equal to the input value for each element of a SIMD vector. Any integral value less than or equal to 1 will be ceiled to 1.

This operation is called `bit_ceil()` in C++.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` is the smallest power of 2 that is greater than or equal to the integer at position `i` of the input value.

### `prev_power_of_two`

```mojo
def prev_power_of_two[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Computes the largest power of 2 that is less than or equal to the input value for each element of a SIMD vector. Any integral value less than or equal to 0 will be floored to 0.

This operation is called `bit_floor()` in C++.

Constraints: The element type of the input vector must be integral.

Parameters:

- `dtype`: `dtype` used for the computation.
- `width`: SIMD width used for the computation.

Args:

- `val`: The input value.

Returns: A SIMD value where the element at position `i` is the largest power of 2 that is less than or equal to the integer at position `i` of the input value.

### `rotate_bits_left`

```mojo
def rotate_bits_left[dtype: DType, width: SIMDLength, //, shift: Int](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_integral()
```

Shifts bits to the left by `shift` positions (with wrap-around) for each element of a SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector. Must be integral.
- `width`: The width of the SIMD vector.
- `shift`: The number of positions to rotate left.

Args:

- `x`: SIMD vector input.

Returns: SIMD vector with each element rotated left by `shift` bits.

### `rotate_bits_right`

```mojo
def rotate_bits_right[dtype: DType, width: SIMDLength, //, shift: Int](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_integral()
```

Shifts bits to the right by `shift` positions (with wrap-around) for each element of a SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector. Must be integral.
- `width`: The width of the SIMD vector.
- `shift`: The number of positions to rotate right.

Args:

- `x`: SIMD vector input.

Returns: SIMD vector with each element rotated right by `shift` bits.

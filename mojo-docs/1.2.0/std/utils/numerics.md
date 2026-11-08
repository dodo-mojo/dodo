# `std.utils.numerics`

Defines utilities to work with numeric types.

You can import these APIs from the `utils` package. For example:

```mojo
from std.utils.numerics import FPUtils
```

## Structs

### `FPUtils`

```mojo
struct FPUtils[dtype: DType, *, _constraint: NoneType = _constrain_fp_type[dtype]()]
```

Collection of utility functions for working with FP values.

Parameters:

- `dtype`: The concrete FP dtype (FP32/FP64/etc).
- `_constraint`: Implements the constraint. Do not pass explicitly.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `integral_type = _integral_type_of[dtype]()`: The equivalent integer dtype of the float type.
- `uint_type = _unsigned_integral_type_of[dtype]()`: The equivalent uint dtype of the float type.

#### `FPUtils.mantissa_width`

```mojo
def mantissa_width() -> Int
```

Returns the mantissa width of a floating point type.

Returns: The mantissa width.

#### `FPUtils.max_exponent`

```mojo
def max_exponent() -> Int
```

Returns the max exponent of a floating point dtype without accounting for inf representations. This is not the maximum representable exponent, which is generally equal to the exponent_bias.

Returns: The max exponent.

#### `FPUtils.exponent_width`

```mojo
def exponent_width() -> Int
```

Returns the exponent width of a floating point type.

Returns: The exponent width.

#### `FPUtils.exponent_bias`

```mojo
def exponent_bias() -> Int
```

Returns the exponent bias of a floating point type.

Returns: The exponent bias.

#### `FPUtils.mantissa_mask`

```mojo
def mantissa_mask() -> Int
```

Returns the mantissa mask of a floating point type.

Returns: The mantissa mask.

#### `FPUtils.sign_mask`

```mojo
def sign_mask() -> Int
```

Returns the sign mask of a floating point type.

It is computed by `1 << (exponent_width + mantissa_width)`.

Returns: The sign mask.

#### `FPUtils.exponent_mask`

```mojo
def exponent_mask() -> Int
```

Returns the exponent mask of a floating point type.

It is computed by `~(sign_mask | mantissa_mask)`.

Returns: The exponent mask.

#### `FPUtils.exponent_mantissa_mask`

```mojo
def exponent_mantissa_mask() -> Int
```

Returns the exponent and mantissa mask of a floating point type.

It is computed by `exponent_mask | mantissa_mask`.

Returns: The exponent and mantissa mask.

#### `FPUtils.quiet_nan_mask`

```mojo
def quiet_nan_mask() -> Int
```

Returns the quiet NaN mask for a floating point type.

The mask is defined by evaluating:

```
(1<<exponent_width-1)<<mantissa_width + 1<<(mantissa_width-1)
```

Returns: The quiet NaN mask.

#### `FPUtils.bitcast_to_integer`

```mojo
def bitcast_to_integer(value: Scalar[dtype]) -> Int
```

Bitcasts the floating-point value to an integer.

Args:

- `value`: The floating-point type.

Returns: An integer representation of the floating-point value.

#### `FPUtils.bitcast_to_uint`

```mojo
def bitcast_to_uint(value: Scalar[dtype]) -> Scalar[Self.uint_type]
```

Bitcasts the floating-point value to an integer.

Args:

- `value`: The floating-point type.

Returns: An integer representation of the floating-point value.

#### `FPUtils.bitcast_from_integer`

```mojo
def bitcast_from_integer(value: Int) -> Scalar[dtype]
```

Bitcasts the floating-point value from an integer.

Args:

- `value`: The int value.

Returns: An floating-point representation of the Int.

#### `FPUtils.get_sign`

```mojo
def get_sign(value: Scalar[dtype]) -> Bool
```

Returns the sign of the floating point value.

Args:

- `value`: The floating-point type.

Returns: Returns True if the sign is set and False otherwise.

#### `FPUtils.set_sign`

```mojo
def set_sign(value: Scalar[dtype], sign: Bool) -> Scalar[dtype]
```

Sets the sign of the floating point value.

Args:

- `value`: The floating-point value.
- `sign`: True to set the sign and false otherwise.

Returns: Returns the floating point value with the sign set.

#### `FPUtils.get_exponent`

```mojo
def get_exponent(value: Scalar[dtype]) -> Int
```

Returns the exponent bits of the floating-point value.

Args:

- `value`: The floating-point value.

Returns: Returns the exponent bits.

#### `FPUtils.get_exponent_biased`

```mojo
def get_exponent_biased(value: Scalar[dtype]) -> Int
```

Returns the biased exponent of the floating-point value as an Int, this is how the value is stored before subtracting the exponent bias.

Args:

- `value`: The floating-point value.

Returns: The biased exponent as an Int.

#### `FPUtils.set_exponent`

```mojo
def set_exponent(value: Scalar[dtype], exponent: Int) -> Scalar[dtype]
```

Sets the exponent bits of the floating-point value.

Args:

- `value`: The floating-point value.
- `exponent`: The exponent bits.

Returns: Returns the floating-point value with the exponent bits set.

#### `FPUtils.get_mantissa`

```mojo
def get_mantissa(value: Scalar[dtype]) -> Int
```

Gets the mantissa bits of the floating-point value.

Args:

- `value`: The floating-point value.

Returns: The mantissa bits.

#### `FPUtils.get_mantissa_uint`

```mojo
def get_mantissa_uint(value: Scalar[dtype]) -> Scalar[Self.uint_type]
```

Gets the mantissa bits of the floating-point value.

Args:

- `value`: The floating-point value.

Returns: The mantissa bits.

#### `FPUtils.set_mantissa`

```mojo
def set_mantissa(value: Scalar[dtype], mantissa: Int) -> Scalar[dtype]
```

Sets the mantissa bits of the floating-point value.

Args:

- `value`: The floating-point value.
- `mantissa`: The mantissa bits.

Returns: Returns the floating-point value with the mantissa bits set.

#### `FPUtils.pack`

```mojo
def pack(sign: Bool, exponent: Int, mantissa: Int) -> Scalar[dtype]
```

Construct a floating-point value from its constituent sign, exponent, and mantissa.

Args:

- `sign`: The sign of the floating-point value.
- `exponent`: The exponent of the floating-point value.
- `mantissa`: The mantissa of the floating-point value.

Returns: Returns the floating-point value.

### `FlushDenormals`

```mojo
struct FlushDenormals
```

Flushes and denormals are set to zero within the context and the state is restored to the prior value on exit.

Fields:

- `state` (`Int32`): The current state.

Implemented traits: `AnyType`, `Defaultable`, `Deinitable`, `Movable`

#### `FlushDenormals.__init__`

```mojo
def __init__(out self)
```

Initializes the FlushDenormals.

#### `FlushDenormals.__enter__`

```mojo
def __enter__(self)
```

Enters the context. This will set denormals to zero.

#### `FlushDenormals.__exit__`

```mojo
def __exit__(self)
```

Exits the context. This will restore the prior FPState.

## Functions

### `nan`

```mojo
def nan[dtype: DType]() -> Scalar[dtype]
```

Gets a NaN value for the given dtype.

Constraints: Can only be used for FP dtypes.

Parameters:

- `dtype`: The value dtype.

Returns: The NaN value of the given dtype.

### `isnan`

```mojo
def isnan[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[.bool, width]
```

Checks if the value is Not a Number (NaN).

Parameters:

- `dtype`: The value dtype.
- `width`: The width of the SIMD vector.

Args:

- `val`: The value to check.

Returns: True if val is NaN and False otherwise.

### `inf`

```mojo
def inf[dtype: DType]() -> Scalar[dtype]
```

Gets a +inf value for the given dtype.

Constraints: Can only be used for FP dtypes.

Parameters:

- `dtype`: The value dtype.

Returns: The +inf value of the given dtype.

### `neg_inf`

```mojo
def neg_inf[dtype: DType]() -> Scalar[dtype]
```

Gets a -inf value for the given dtype.

Constraints: Can only be used for FP dtypes.

Parameters:

- `dtype`: The value dtype.

Returns: The -inf value of the given dtype.

### `max_finite`

```mojo
def max_finite[dtype: DType]() -> Scalar[dtype]
```

Returns the maximum finite value of type.

Parameters:

- `dtype`: The value dtype.

Returns: The maximum representable value of the type. Does not include infinity for floating-point types.

### `min_finite`

```mojo
def min_finite[dtype: DType]() -> Scalar[dtype]
```

Returns the minimum (lowest) finite value of type.

Parameters:

- `dtype`: The value dtype.

Returns: The minimum representable value of the type. Does not include negative infinity for floating-point types.

### `max_or_inf`

```mojo
def max_or_inf[dtype: DType]() -> Scalar[dtype]
```

Returns the maximum (potentially infinite) value of type.

Parameters:

- `dtype`: The value dtype.

Returns: The maximum representable value of the type. Can include infinity for floating-point types.

### `min_or_neg_inf`

```mojo
def min_or_neg_inf[dtype: DType]() -> Scalar[dtype]
```

Returns the minimum (potentially negative infinite) value of type.

Parameters:

- `dtype`: The value dtype.

Returns: The minimum representable value of the type. Can include negative infinity for floating-point types.

### `isinf`

```mojo
def isinf[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[.bool, width]
```

Checks if the value is infinite.

This is always False for non-FP data types.

Parameters:

- `dtype`: The value dtype.
- `width`: The width of the SIMD vector.

Args:

- `val`: The value to check.

Returns: True if val is infinite and False otherwise.

### `isfinite`

```mojo
def isfinite[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width]) -> SIMD[.bool, width]
```

Checks if the value is not infinite.

This is always True for non-FP data types.

Parameters:

- `dtype`: The value dtype.
- `width`: The width of the SIMD vector.

Args:

- `val`: The value to check.

Returns: True if val is finite and False otherwise.

### `get_accum_type`

```mojo
def get_accum_type[dtype: DType, *, preferred_accum_type: DType = .float32]() -> DType
```

Returns the recommended dtype for accumulation operations.

Half precision and float8 types can introduce numerical error if they are
used in reduction/accumulation operations. This method returns a higher
precision dtype to use for accumulation if a half precision types is
provided, otherwise it returns the original dtype.

The rules are as follows:

```mojo
- If the dtype is a float8 type, return a float16 type.
- If the dtype is a bfloat16 precision type, return a float32 type.
- If the dtype is a float16 precision type, return a float32 dtype if
    the preferred_accum_type is float32, otherwise return a float16
    type.
- Otherwise, return the original type.
```

Parameters:

- `dtype`: The dtype of some accumulation operation.
- `preferred_accum_type`: The preferred dtype for accumulation.

Returns: The recommended dtype for accumulation operations based on the input dtype and the preferred accumulation type.

### `nextafter`

```mojo
def nextafter[dtype: DType, width: SIMDLength, //](arg0: SIMD[dtype, width], arg1: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Computes next representable value of `arg0` in the direction of `arg1`.

CPU and GPU targets share one Mojo implementation that walks the IEEE-754
bit pattern directly: the only floating-point operation is the NaN check,
so the result is exact on every target and is unaffected by targets that
flush subnormal arithmetic. Read as a signed integer, the raw bit pattern
is monotone on each half of the real line — increasing with value from
+0 to +NaN, and decreasing from -1 at -NaN to the most negative integer
at -0 — so a single ±1 step of the bit pattern, with the direction
decided by the ordering of `arg0` and `arg1` and the sign of `arg0`,
reaches the neighbouring representable value.

Constraints: The element dtype of the input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `arg0`: The first input argument.
- `arg1`: The second input argument.

Returns: The `nextafter` of the inputs.

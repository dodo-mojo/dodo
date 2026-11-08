# `std.math.math`

Defines math utilities.

You can import these APIs from the `math` package. For example:

```mojo
from std.math import floor
```

## Traits

### `Ceilable`

```mojo
trait Ceilable
```

The `Ceilable` trait describes a type that defines a ceiling operation.

Types that conform to `Ceilable` will work with the builtin `ceil`
function. The ceiling operation always returns the same type as the input.

For example:
```mojo
from std.math import Ceilable, ceil

@fieldwise_init
struct Complex(Ceilable, ImplicitlyCopyable):
    var re: Float64
    var im: Float64

    def __ceil__(self) -> Self:
        return Self(ceil(self.re), ceil(self.im))
```

Inherits from: `AnyType`

#### `Ceilable.__ceil__`

```mojo
def __ceil__(self) -> Self
```

Return the ceiling of the Int value, which is itself.

Returns: The Int value itself.

### `Floorable`

```mojo
trait Floorable
```

The `Floorable` trait describes a type that defines a floor operation.

Types that conform to `Floorable` will work with the builtin `floor`
function. The floor operation always returns the same type as the input.

For example:
```mojo
from std.math import Floorable, floor

@fieldwise_init
struct Complex(Floorable, ImplicitlyCopyable):
    var re: Float64
    var im: Float64

    def __floor__(self) -> Self:
        return Self(floor(self.re), floor(self.im))
```

Inherits from: `AnyType`

#### `Floorable.__floor__`

```mojo
def __floor__(self) -> Self
```

Return the floor of the Int value, which is itself.

Returns: The Int value itself.

### `CeilDivable`

```mojo
trait CeilDivable
```

The `CeilDivable` trait describes a type that defines a ceil division operation.

Types that conform to `CeilDivable` will work with the `math.ceildiv`
function.

For example:
```mojo
from std.math import CeilDivable

@fieldwise_init
struct Foo(CeilDivable, ImplicitlyCopyable):
    var x: Float64

    def __ceildiv__(self, denominator: Self) -> Self:
        return Self(self.x // denominator.x)
```

Inherits from: `AnyType`

#### `CeilDivable.__ceildiv__`

```mojo
def __ceildiv__(self, denominator: Self) -> Self
```

Return the rounded-up result of dividing self by denominator.

Args:

- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

### `CeilDivableRaising`

```mojo
trait CeilDivableRaising
```

The `CeilDivable` trait describes a type that define a floor division and negation operation that can raise.

Types that conform to `CeilDivableRaising` will work with the `//` operator
as well as the `math.ceildiv` function.

For example:
```mojo
from std.math import CeilDivableRaising

@fieldwise_init
struct Foo(CeilDivableRaising, ImplicitlyCopyable):
    var x: Float64

    def __ceildiv__(self, denominator: Self) raises -> Self:
        return Self(self.x // denominator.x)
```

Inherits from: `AnyType`

#### `CeilDivableRaising.__ceildiv__`

```mojo
def __ceildiv__(self, denominator: Self) raises -> Self
```

Return the rounded-up result of dividing self by denominator.

Args:

- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

Raises: If the operation fails.

### `Truncable`

```mojo
trait Truncable
```

The `Truncable` trait describes a type that defines a truncation operation.

Types that conform to `Truncable` will work with the builtin `trunc`
function. The truncation operation always returns the same type as the
input.

For example:
```mojo
from std.math import Truncable, trunc

@fieldwise_init
struct Complex(Truncable, ImplicitlyCopyable):
    var re: Float64
    var im: Float64

    def __trunc__(self) -> Self:
        return Self(trunc(self.re), trunc(self.im))
```

Inherits from: `AnyType`

#### `Truncable.__trunc__`

```mojo
def __trunc__(self) -> Self
```

Return the truncated Int value, which is itself.

Returns: The Int value itself.

### `Absable`

```mojo
trait Absable
```

The `Absable` trait describes a type that defines an absolute value operation.

Types that conform to `Absable` will work with the builtin `abs` function.
The absolute value operation always returns the same type as the input.

For example:
```mojo
struct Celsius(Absable):
    var degrees: Float64

    def __init__(out self, degrees: Float64):
        self.degrees = degrees

    def __abs__(self) -> Self:
        return Self(abs(self.degrees))
```

Inherits from: `AnyType`

#### `Absable.__abs__`

```mojo
def __abs__(self) -> Self
```

Get the absolute value of this instance.

Returns: The absolute value of the instance.

### `DivModable`

```mojo
trait DivModable
```

The `DivModable` trait describes a type that defines division and modulo operations returning both quotient and remainder.

Types that conform to `DivModable` will work with the builtin `divmod` function,
which will return the same type as the inputs.

For example:
```mojo
from std.math import DivModable

@fieldwise_init
struct Bytes(DivModable):
    var size: Int

    def __divmod__(self, other: Self) -> Tuple[Self, Self]:
        var quotient_int = self.size // other.size
        var remainder_int = self.size % other.size
        return (Bytes(quotient_int), Bytes(remainder_int))
```

Inherits from: `AnyType`, `Copyable`, `ImplicitlyCopyable`, `Movable`

#### `DivModable.__divmod__`

```mojo
def __divmod__(self, denominator: Self) -> Tuple[_Self, _Self]
```

Performs division and returns the quotient and the remainder.

Args:

- `denominator`: The value to divide by.

Returns: A `Tuple` containing the quotient and the remainder.

### `Powable`

```mojo
trait Powable
```

The `Powable` trait describes a type that defines a power operation (i.e. exponentiation) with the same base and exponent types.

Types that conform to `Powable` will work with the builtin `pow` function,
which will return the same type as the inputs.

For example:
```mojo
struct Rational(Powable):
    var numerator: Float64
    var denominator: Float64

    def __init__(out self, numerator: Float64, denominator: Float64):
        self.numerator = numerator
        self.denominator = denominator

    def __pow__(self, exp: Self)  -> Self:
        var exp_value = exp.numerator / exp.denominator
        return Self(pow(self.numerator, exp_value), pow(self.denominator, exp_value))
```

You can now use the ** operator to exponentiate objects
inside generic functions:

```mojo
def exponentiate[T: Powable](base: T, exp: T) -> T:
    return base ** exp

var base = Rational(Float64(3.0), 5.0)
var exp = Rational(Float64(1.0), 2.0)
var res = exponentiate(base, exp)
```

```plaintext
raising to power
```

Inherits from: `AnyType`

#### `Powable.__pow__`

```mojo
def __pow__(self, exp: Self) -> Self
```

Return the value raised to the power of the given exponent.

Args:

- `exp`: The exponent value.

Returns: The value of `self` raised to the power of `exp`.

### `Roundable`

```mojo
trait Roundable
```

The `Roundable` trait describes a type that defines a rounding operation.

Types that conform to `Roundable` will work with the builtin `round`
function. The round operation always returns the same type as the input.

For example:
```mojo
@fieldwise_init
struct Complex(Roundable):
    var re: Float64
    var im: Float64

    def __round__(self) -> Self:
        return Self(round(self.re), round(self.im))

    def __round__(self, ndigits: Int) -> Self:
        return Self(round(self.re, ndigits), round(self.im, ndigits))
```

Inherits from: `AnyType`

#### `Roundable.__round__`

```mojo
def __round__(self) -> Self
```

Get a rounded value for the type.

Returns: The rounded value.

```mojo
def __round__(self, ndigits: Int) -> Self
```

Get a rounded value for the type.

Args:

- `ndigits`: Number of digits after the decimal point.

Returns: The rounded value.

## Functions

### `floor`

```mojo
def floor[T: Floorable, //](value: T) -> T
```

Get the floor value of the given object.

Parameters:

- `T`: The type conforming to `Floorable`.

Args:

- `value`: The object to get the floor value of.

Returns: The floor value of the object.

### `ceil`

```mojo
def ceil[T: Ceilable, //](value: T) -> T
```

Get the ceiling value of the given object.

Parameters:

- `T`: The type conforming to `Ceilable`.

Args:

- `value`: The object to get the ceiling value of.

Returns: The ceiling value of the object.

### `ceildiv`

```mojo
def ceildiv[T: CeilDivable, //](numerator: T, denominator: T) -> T
```

Return the rounded-up result of dividing numerator by denominator.

Parameters:

- `T`: A type that support floor division.

Args:

- `numerator`: The numerator.
- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

```mojo
def ceildiv[T: CeilDivableRaising, //](numerator: T, denominator: T) raises -> T
```

Return the rounded-up result of dividing numerator by denominator, potentially raising.

Parameters:

- `T`: A type that support floor division.

Args:

- `numerator`: The numerator.
- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

Raises: If the operation fails.

```mojo
def ceildiv(numerator: IntLiteral, denominator: IntLiteral) -> IntLiteral[(0 - (numerator.value // (0 - denominator.value)))]
```

Return the rounded-up result of dividing numerator by denominator.

Args:

- `numerator`: The numerator.
- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

### `trunc`

```mojo
def trunc[T: Truncable, //](value: T) -> T
```

Get the truncated value of the given object.

Parameters:

- `T`: The type conforming to Truncable.

Args:

- `value`: The object to get the truncated value of.

Returns: The truncated value of the object.

### `sqrt`

```mojo
def sqrt[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Performs elementwise square root on the elements of a SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: SIMD vector to perform square root on.

Returns: The elementwise square root of x.

### `rsqrt`

```mojo
def rsqrt[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Performs elementwise reciprocal square root on a SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: SIMD vector to perform reciprocal square root on.

Returns: The elementwise reciprocal square root of x.

### `recip`

```mojo
def recip[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Performs elementwise reciprocal on a SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: SIMD vector to perform reciprocal on.

Returns: The elementwise reciprocal of x.

### `exp2`

```mojo
def exp2[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes elementwise 2 raised to the power of n, where n is an element of the input SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: SIMD vector to perform exp2 on.

Returns: Vector containing $2^n$ computed elementwise, where n is an element in the input SIMD vector.

### `ldexp`

```mojo
def ldexp[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width], exp: SIMD[.int32, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes elementwise ldexp function.

The ldexp function multiplies a floating point value x by the number 2
raised to the exp power. I.e. $ldexp(x,exp)$ calculate the value of $x *
2^{exp}$ and is used within the $erf$ function.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: SIMD vector of floating point values.
- `exp`: SIMD vector containing the exponents.

Returns: Vector containing elementwise result of ldexp on x and exp.

### `exp`

```mojo
def exp[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Calculates elementwise exponential of the input vector.

Given an input vector $X$ and an output vector $Y$, sets $Y_i = e^{X_i}$ for
each position $i$ in the input vector (where $e$ is the mathematical constant
$e$).

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input SIMD vector.

Returns: A SIMD vector containing $e$ raised to the power $X_i$ where $X_i$ is an element in the input SIMD vector.

```mojo
def exp[T: _Expable](x: T) -> T
```

Computes the exponential of the input value.

Parameters:

- `T`: The type of the input value.

Args:

- `x`: The input value.

Returns: The exponential of the input value.

### `exp_approx_f32`

```mojo
def exp_approx_f32[W: Int](x: SIMD[.float32, W]) -> SIMD[.float32, W]
```

Computes a fast approximate e^x for SIMD vectors of 32-bit floats using the base-2 approximation as a backend.

This function converts the natural exponential input `z` to base-2 space
using the identity e^z = 2^(z * log2(e)), then calls the internal
`_exp2_approx_f32` function to evaluate the FA-4 polynomial approximation
of 2^x. It is optimized for small SIMD widths and is fully inlined for
high performance.

Constraints: The input must be a SIMD vector of 32-bit floating-point values.

Parameters:

- `W`: The width of the SIMD vector.

Args:

- `x`: The input SIMD vector representing the exponent.

Returns: A SIMD vector containing the approximate value of e^x.

### `frexp`

```mojo
def frexp[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> StaticTuple[SIMD[dtype, width], Int(2)] where dtype.is_floating_point()
```

Breaks floating point values into a fractional part and an exponent part. This follows C and Python in increasing the exponent by 1 and normalizing the fraction from 0.5 to 1.0 instead of 1.0 to 2.0.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input values.

Returns: A tuple of two SIMD vectors containing the fractional and exponent parts of the input floating point values.

### `log`

```mojo
def log[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Performs elementwise natural log (base E) of a SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: Vector to perform logarithm operation on.

Returns: Vector containing result of performing natural log base E on x.

### `log2`

```mojo
def log2[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Performs elementwise log (base 2) of a SIMD vector.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: Vector to perform logarithm operation on.

Returns: Vector containing result of performing log base 2 on x.

### `copysign`

```mojo
def copysign[dtype: DType, width: SIMDLength, //](magnitude: SIMD[dtype, width], sign: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Returns a value with the magnitude of the first operand and the sign of the second operand.

Constraints: The type of the input must be numeric.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `magnitude`: The magnitude to use.
- `sign`: The sign to copy.

Returns: Copies the sign from sign to magnitude.

### `erf`

```mojo
def erf[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Performs the elementwise Erf on a SIMD vector.

Constraints: The type must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: SIMD vector to perform elementwise Erf on.

Returns: The result of the elementwise Erf operation.

### `tanh`

```mojo
def tanh[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Performs elementwise evaluation of the tanh function.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The vector to perform the elementwise tanh on.

Returns: The result of the elementwise tanh operation.

### `isclose`

```mojo
def isclose[dtype: DType, width: SIMDLength, *, symmetrical: Bool = True](a: SIMD[dtype, width], b: SIMD[dtype, width], *, atol: Float64 = 1.0E-8, rtol: Float64 = 1.0000000000000001E-5, equal_nan: Bool = False) -> SIMD[.bool, width]
```

Returns a boolean SIMD vector indicating which element pairs of `a` and `b` are equal within a given tolerance.

For floating-point dtypes, the following criteria apply:

- Symmetric (Python `math.isclose` style), when `symmetrical` is true:
    ```text
    |a - b| ≤ max(atol, rtol * max(|a|, |b|))
    ```
- Asymmetric (NumPy style), when `symmetrical` is false:
    ```text
    |a - b| ≤ atol + rtol * |b|
    ```

NaN values are considered equal only if `equal_nan` is true.

Parameters:

- `dtype`: Element type of the input and output vectors.
- `width`: Number of lanes in each SIMD vector.
- `symmetrical`: If true, use the symmetric comparison formula (default: true).

Args:

- `a`: First input vector.
- `b`: Second input vector.
- `atol`: Absolute tolerance.
- `rtol`: Relative tolerance.
- `equal_nan`: If true, treat NaNs as equal (default: false).

Returns: A boolean vector where `a` and `b` are equal within the given tolerance.

### `iota`

```mojo
def iota[dtype: DType, width: Int](offset: Scalar[dtype] = 0) -> SIMD[dtype, width]
```

Creates a SIMD vector containing an increasing sequence, starting from offset.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `offset`: The value to start the sequence at. Default is zero.

Returns: An increasing sequence of values, starting from offset.

```mojo
def iota[dtype: DType, //](buff: Pointer[Scalar[dtype], address_space=buff.address_space], len: Int, offset: Int = Int(0))
```

Fill the buffer with numbers ranging from offset to offset + len - 1, spaced by 1.

The function doesn't return anything, the buffer is updated inplace.

Parameters:

- `dtype`: DType of the underlying data.

Args:

- `buff`: The buffer to fill.
- `len`: The length of the buffer to fill.
- `offset`: The value to fill at index 0.

```mojo
def iota[dtype: DType, //](span: Span[Scalar[dtype]], offset: Int = Int(0))
```

Fill a Span with consecutive numbers starting from the specified offset.

Parameters:

- `dtype`: DType of the underlying data.

Args:

- `span`: The Span to fill with numbers.
- `offset`: The starting value to fill at index 0.

### `fma`

```mojo
def fma[dtype: DType, width: SIMDLength, //](a: SIMD[dtype, width], b: SIMD[dtype, width], c: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Performs elementwise `fma` (fused multiply-add) on the inputs.

Each element in the result SIMD vector is $(A_i * B_i) + C_i$, where $A_i$,
$B_i$ and $C_i$ are elements at index $i$ in a, b, and c respectively.

Parameters:

- `dtype`: The `dtype` of the input SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `a`: The first vector of inputs.
- `b`: The second vector of inputs.
- `c`: The third vector of inputs.

Returns: Elementwise `fma` of a, b and c.

### `align_down`

```mojo
def align_down[dtype: DType, width: SIMDLength, //](value: SIMD[dtype, width], alignment: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_integral()
```

Returns the closest multiple of alignment that is less than or equal to value, elementwise.

Parameters:

- `dtype`: The `dtype` of the input SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `value`: The value to align.
- `alignment`: Value to align to.

Returns: Closest multiple of the alignment that is less than or equal to the input value. In other words, floor(value / alignment) * alignment.

### `align_up`

```mojo
def align_up[dtype: DType, width: SIMDLength, //](value: SIMD[dtype, width], alignment: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_integral()
```

Returns the closest multiple of alignment that is greater than or equal to value, elementwise.

Parameters:

- `dtype`: The `dtype` of the input SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `value`: The value to align.
- `alignment`: Value to align to.

Returns: Closest multiple of the alignment that is greater than or equal to the input value. In other words, ceiling(value / alignment) * alignment.

### `mulhi`

```mojo
def mulhi(a: UInt32, b: UInt32) -> UInt32
```

Calculates the most significant 32 bits of the product of two 32-bit unsigned integers.

Multiplies two 32-bit unsigned integers and returns the high 32 bits
of their product. Useful for fixed-point arithmetic and overflow detection.

Note:
On NVIDIA GPUs, this maps directly to the MULHI.U32 PTX instruction.
On others, it performs multiplication using 64-bit arithmetic.

Args:

- `a`: First 32-bit unsigned integer operand.
- `b`: Second 32-bit unsigned integer operand.

Returns: The high 32 bits of the product a * b

```mojo
def mulhi(a: Int32, b: Int32) -> Int32
```

Calculates the most significant 32 bits of the product of two 32-bit signed integers.

Multiplies two 32-bit signed integers and returns the high 32 bits
of their product. Useful for fixed-point arithmetic and overflow detection.

Note:
On NVIDIA GPUs, this maps directly to the MULHI.S32 PTX instruction.
On others, it performs multiplication using 64-bit arithmetic.

Args:

- `a`: First 32-bit signed integer operand.
- `b`: Second 32-bit signed integer operand.

Returns: The high 32 bits of the product a * b

```mojo
def mulhi(a: UInt64, b: UInt64) -> UInt64
```

Calculates the most significant 64 bits of the product of two 64-bit unsigned integers.

Multiplies two 64-bit unsigned integers and returns the high 64 bits
of their product. Useful for fixed-point arithmetic and overflow detection.

Note:
On NVIDIA GPUs, this maps directly to the MULHI.U64 PTX instruction.
On others, it performs multiplication using 128-bit arithmetic.

Args:

- `a`: First 64-bit unsigned integer operand.
- `b`: Second 64-bit unsigned integer operand.

Returns: The high 64 bits of the product a * b.

```mojo
def mulhi(a: Int64, b: Int64) -> Int64
```

Calculates the most significant 64 bits of the product of two 64-bit signed integers.

Multiplies two 64-bit signed integers and returns the high 64 bits
of their product. Useful for fixed-point arithmetic and overflow detection.

Note:
On NVIDIA GPUs, this maps directly to the MULHI.S64 PTX instruction.
On others, it performs multiplication using 128-bit arithmetic.

Args:

- `a`: First 64-bit signed integer operand.
- `b`: Second 64-bit signed integer operand.

Returns: The high 64 bits of the product a * b.

### `mulwide`

```mojo
def mulwide(a: UInt32, b: UInt32) -> UInt64
```

Performs a wide multiplication of two 32-bit unsigned integers.

Multiplies two 32-bit unsigned integers and returns the full 64-bit result.
Useful when the product may exceed 32 bits.

Note:
On NVIDIA GPUs, this maps directly to the MUL.WIDE.U32 PTX instruction.
On others, it performs multiplication using 64-bit casts.

Args:

- `a`: First 32-bit unsigned integer operand.
- `b`: Second 32-bit unsigned integer operand.

Returns: The full 64-bit product of a * b

```mojo
def mulwide(a: Int32, b: Int32) -> Int64
```

Performs a wide multiplication of two 32-bit signed integers.

Multiplies two 32-bit signed integers and returns the full 64-bit result.
Useful when the product may exceed 32 bits or be negative.

Note:
On NVIDIA GPUs, this maps directly to the MUL.WIDE.S32 PTX instruction.
On others, it performs multiplication using 64-bit casts.

Args:

- `a`: First 32-bit signed integer operand.
- `b`: Second 32-bit signed integer operand.

Returns: The full 64-bit signed product of a * b

### `acos`

```mojo
def acos[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `acos` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `acos` of the input.

### `asin`

```mojo
def asin[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `asin` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `asin` of the input.

### `atan`

```mojo
def atan[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `atan` of the inputs.

Constraints: The input must be a floating-point type.
`float64` is not supported on Apple GPUs.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `atan` of the input.

### `atan2`

```mojo
def atan2[dtype: DType, width: SIMDLength, //](y: SIMD[dtype, width], x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `atan2` of the inputs.

Constraints: The input must be a floating-point type.
`float64` is not supported on Apple GPUs.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `y`: The first input argument.
- `x`: The second input argument.

Returns: The `atan2` of the inputs.

### `cos`

```mojo
def cos[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `cos` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `cos` of the input.

### `sin`

```mojo
def sin[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `sin` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `sin` of the input.

### `tan`

```mojo
def tan[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `tan` of the inputs.

Constraints: The input must be a floating-point type.
`float64` is not supported on Apple GPUs.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `tan` of the input.

### `acosh`

```mojo
def acosh[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `acosh` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `acosh` of the input.

### `asinh`

```mojo
def asinh[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `asinh` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `asinh` of the input.

### `atanh`

```mojo
def atanh[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `atanh` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `atanh` of the input.

### `cosh`

```mojo
def cosh[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `cosh` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `cosh` of the input.

### `sinh`

```mojo
def sinh[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `sinh` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `sinh` of the input.

### `expm1`

```mojo
def expm1[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `expm1` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `expm1` of the input.

### `log10`

```mojo
def log10[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `log10` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `log10` of the input.

### `log1p`

```mojo
def log1p[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `log1p` of the inputs.

The `log1p(x)` is equivalent to `log(1+x)`, but stays accurate when `x` is
close to zero, where `1 + x` would round away the low bits of `x`.

The result is accurate to within 1 ulp for `float32` and `float64`.
`float16` and `bfloat16` inputs are computed in `float32` and rounded once
to the narrow type. Special values: `log1p(±0)` is `±0`, `log1p(-1)` is
`-inf`, `log1p(+inf)` is `+inf`, and NaN is returned for NaN and for
`x < -1`.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `log1p` of the input.

### `logb`

```mojo
def logb[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `logb` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `logb` of the input.

### `cbrt`

```mojo
def cbrt[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `cbrt` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `cbrt` of the input.

### `hypot`

```mojo
def hypot[dtype: DType, width: SIMDLength, //](arg0: SIMD[dtype, width], arg1: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `hypot` of the inputs.

Constraints: The input must be a floating-point type. Float64 is unsupported on
Apple GPU.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `arg0`: The first input argument.
- `arg1`: The second input argument.

Returns: The `hypot` of the inputs.

### `erfc`

```mojo
def erfc[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `erfc` of the inputs.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `erfc` of the input.

### `lgamma`

```mojo
def lgamma[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `lgamma` of the inputs.

The error is about 2 ulp or less, including next to the negative real
zeros of `lgamma` (such as -2.457 and -2.748), where the result is near
0.

Constraints: The input must be a floating-point type. `float64` is not supported
on Apple GPU.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The `lgamma` of the input.

### `gamma`

```mojo
def gamma[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the Gamma of the input.

For details, see https://en.wikipedia.org/wiki/Gamma_function.

Constraints: The input must be a floating-point type.
`float64` is not supported on Apple GPU targets.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input argument.

Returns: The Gamma function evaluated at the input.

### `remainder`

```mojo
def remainder[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width], y: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the `remainder` of the inputs.

Constraints: The input must be a floating-point type.
The `float64` type is not supported on Apple GPUs.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The first input argument.
- `y`: The second input argument.

Returns: The `remainder` of the inputs.

### `j0`

```mojo
def j0[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the Bessel function of the first kind of order 0 for each input value.

For float32, relative error grows near the zeros of the function;
absolute error stays small there.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input vector.

Returns: A vector containing the computed value for each value in the input.

### `j1`

```mojo
def j1[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the Bessel function of the first kind of order 1 for each input value.

For float32, relative error grows near the zeros of the function;
absolute error stays small there.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input vector.

Returns: A vector containing the computed value for each value in the input.

### `y0`

```mojo
def y0[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the Bessel function of the second kind of order 0 for each input value.

For float32, relative error grows near the zeros of the function;
absolute error stays small there.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input vector.

Returns: A vector containing the computed value for each value in the input.

### `y1`

```mojo
def y1[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the Bessel function of the second kind of order 1 for each input value.

For float32, relative error grows near the zeros of the function;
absolute error stays small there.

Constraints: The input must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input vector.

Returns: A vector containing the computed value for each value in the input.

### `scalb`

```mojo
def scalb[dtype: DType, width: SIMDLength, //](arg0: SIMD[dtype, width], arg1: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Scales each value in `arg0` by 2 raised to its exponent in `arg1`.

A finite, non-integral exponent produces NaN. A positive infinite
exponent produces infinity with the sign of `arg0`, except that a zero
base produces NaN. A negative infinite exponent produces zero with the
sign of `arg0`, except that an infinite base produces NaN. NaN arguments
produce NaN.

For example:

```mojo
from std.math import scalb
var scaled = scalb(Float32(1.5), Float32(2.0))
```

Constraints: The input must be a floating-point type. The `float64` type is not
supported on Apple GPU.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `arg0`: The values to scale.
- `arg1`: The base-2 exponents.

Returns: The scaled values, computed elementwise.

### `gcd`

```mojo
def gcd(m: Int, n: Int, /) -> Int
```

Compute the greatest common divisor of two integers.

Args:

- `m`: The first integer.
- `n`: The second integrer.

Returns: The greatest common divisor of the two integers.

```mojo
def gcd(s: Span[Int], /) -> Int
```

Computes the greatest common divisor of a span of integers.

Args:

- `s`: A span containing a collection of integers.

Returns: The greatest common divisor of all the integers in the span.

```mojo
def gcd(*values: Int) -> Int
```

Computes the greatest common divisor of a variadic number of integers.

Args:

- `*values`: A variadic list of integers.

Returns: The greatest common divisor of the given integers.

### `lcm`

```mojo
def lcm(m: Int, n: Int, /) -> Int
```

Computes the least common multiple of two integers.

Args:

- `m`: The first integer.
- `n`: The second integer.

Returns: The least common multiple of the two integers.

```mojo
def lcm(s: Span[Int], /) -> Int
```

Computes the least common multiple of a span of integers.

Args:

- `s`: A span of integers.

Returns: The least common multiple of the span.

```mojo
def lcm(*values: Int) -> Int
```

Computes the least common multiple of a variadic list of integers.

Args:

- `*values`: A variadic list of integers.

Returns: The least common multiple of the list.

### `modf`

```mojo
def modf[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> Tuple[SIMD[dtype, width], SIMD[dtype, width]]
```

Computes the integral and fractional part of the value.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: The input value.

Returns: A tuple containing the integral and fractional part of the value.

### `ulp`

```mojo
def ulp[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width] where dtype.is_floating_point()
```

Computes the ULP (units of last place) or (units of least precision) of the number.

Constraints: The element type of the inpiut must be a floating-point type.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `x`: SIMD vector input.

Returns: The ULP of x.

### `factorial`

```mojo
def factorial(n: Int) -> Int
```

Computes the factorial of the integer.

Args:

- `n`: The input value. Must be non-negative.

Returns: The factorial of the input. Results are undefined for negative inputs.

### `comb`

```mojo
def comb(n: Int, k: Int) -> Int
```

Computes the number of ways to choose `k` items from `n` items without repetition and without order (binomial coefficient).

Equivalent to Python's `math.comb(n, k)`.

Examples:

```mojo
from std.math import comb
print(comb(5, 2))  # 10
print(comb(10, 0)) # 1
print(comb(3, 5))  # 0
```

Args:

- `n`: The total number of items. Must be non-negative.
- `k`: The number of items to choose. Must be non-negative.

Returns: The binomial coefficient C(n, k). Returns 0 if `k > n`. Asserts if either argument is negative.

### `perm`

```mojo
def perm(n: Int, k: Int = Int(-1)) -> Int
```

Computes the number of ways to arrange `k` items from `n` items without repetition (permutations).

Equivalent to Python's `math.perm(n, k)`.

Examples:

```mojo
from std.math import perm
print(perm(5, 2))  # 20
print(perm(5))     # 120  (same as factorial(5))
print(perm(5, 0))  # 1
```

Args:

- `n`: The total number of items. Must be non-negative.
- `k`: The number of items to arrange. Must be non-negative and at most `n`. If omitted (default), returns `n!` via `factorial(n)`.

Returns: The number of permutations P(n, k) = n! / (n-k)!. Asserts if `n` is negative, `k` is negative, or `k > n`.

### `clamp`

```mojo
def clamp[dtype: DType, width: SIMDLength, //](val: SIMD[dtype, width], lower_bound: SIMD[dtype, width], upper_bound: SIMD[dtype, width]) -> SIMD[dtype, width]
```

Clamps the values in a SIMD vector to be in a certain range.

Clamp cuts values in the input SIMD vector off at the upper bound and
lower bound values. For example,  SIMD vector `[0, 1, 2, 3]` clamped to
a lower bound of 1 and an upper bound of 2 would return `[1, 1, 2, 2]`.

Parameters:

- `dtype`: The `dtype` of the input and output SIMD vector.
- `width`: The width of the input and output SIMD vector.

Args:

- `val`: The value to clamp.
- `lower_bound`: Minimum of the range to clamp to.
- `upper_bound`: Maximum of the range to clamp to.

Returns: A SIMD vector containing x clamped to be within lower_bound and upper_bound.

### `abs`

```mojo
def abs[T: Absable](value: T) -> T
```

Get the absolute value of the given object.

Parameters:

- `T`: The type conforming to Absable.

Args:

- `value`: The object to get the absolute value of.

Returns: The absolute value of the object.

### `divmod`

```mojo
def divmod[T: DivModable](numerator: T, denominator: T) -> Tuple[T, T]
```

Performs division and returns the quotient and the remainder.

Parameters:

- `T`: A type conforming to the `DivModable` trait.

Args:

- `numerator`: The dividend.
- `denominator`: The divisor.

Returns: A `Tuple` containing the quotient and the remainder.

### `max`

```mojo
def max[dtype: DType, //](x: SIMD[dtype], y: SIMD[dtype, x.length], /) -> SIMD[dtype, x.length]
```

Performs elementwise maximum of x and y.

An element of the result SIMD vector will be the maximum of the
corresponding elements in x and y.

Constraints: The type of the inputs must be numeric or boolean.

Parameters:

- `dtype`: The data type of the SIMD vector.

Args:

- `x`: First SIMD vector.
- `y`: Second SIMD vector.

Returns: A SIMD vector containing the elementwise maximum of x and y.

```mojo
def max[T: Comparable & Copyable & Deinitable](x: T, *ys: T) -> T
```

Gets the maximum value from a sequence of values.

Parameters:

- `T`: A type that is both copyable and comparable with greater than.

Args:

- `x`: The first value to compare.
- `*ys`: Zero or more additional values to compare.

Returns: The maximum value from the input sequence.

### `min`

```mojo
def min[dtype: DType, //](x: SIMD[dtype], y: SIMD[dtype, x.length], /) -> SIMD[dtype, x.length]
```

Gets the elementwise minimum of x and y.

An element of the result SIMD vector will be the minimum of the
corresponding elements in x and y.

Constraints: The type of the inputs must be numeric or boolean.

Parameters:

- `dtype`: The data type of the SIMD vector.

Args:

- `x`: First SIMD vector.
- `y`: Second SIMD vector.

Returns: A SIMD vector containing the elementwise minimum of x and y.

```mojo
def min[T: Comparable & Copyable & Deinitable](x: T, *ys: T) -> T
```

Gets the minimum value from a sequence of values.

Parameters:

- `T`: A type that is both copyable and comparable with less than.

Args:

- `x`: The first value to compare.
- `*ys`: Zero or more additional values to compare.

Returns: The minimum value from the input sequence.

### `pow`

```mojo
def pow[T: Powable](base: T, exp: T) -> T
```

Computes the `base` raised to the power of the `exp`.

Parameters:

- `T`: A type conforming to the `Powable` trait.

Args:

- `base`: The base of the power operation.
- `exp`: The exponent of the power operation.

Returns: The `base` raised to the power of the `exp`.

```mojo
def pow(base: SIMD, exp: Int) -> SIMD[base.dtype, base.length]
```

Computes elementwise value of a SIMD vector raised to the power of the given integer.

Args:

- `base`: The first input argument.
- `exp`: The second input argument.

Returns: The `base` elementwise raised raised to the power of `exp`.

### `round`

```mojo
def round[T: Roundable, //](number: T) -> T
```

Get the rounded value of the given object.

Parameters:

- `T`: The type conforming to Roundable.

Args:

- `number`: The object to get the rounded value of.

Returns: The rounded value of the object.

```mojo
def round[T: Roundable, //](number: T, ndigits: Int) -> T
```

Get the value of this object, rounded to a specified number of digits after the decimal point.

Parameters:

- `T`: The type conforming to Roundable.

Args:

- `number`: The object to get the rounded value of.
- `ndigits`: The number of digits to round to.

Returns: The rounded value of the object.

# `std.complex.complex`

Implements the Complex dtype.

You can import these APIs from the `complex` package. For example:

```mojo
from std.complex import ComplexSIMD
```

## Aliases

### `ComplexScalar`

```mojo
comptime ComplexScalar = ComplexSIMD[_, 1]
```

Represents a scalar complex value.

### `ComplexFloat32`

```mojo
comptime ComplexFloat32 = ComplexSIMD[.float32, 1]
```

A complex number with 32-bit floating point components.

### `ComplexFloat64`

```mojo
comptime ComplexFloat64 = ComplexSIMD[.float64, 1]
```

A complex number with 64-bit floating point components.

## Structs

### `ComplexSIMD`

```mojo
struct ComplexSIMD[dtype: DType, length: SIMDLength]
```

Represents a complex SIMD value.

The class provides basic methods for manipulating complex values.

Parameters:

- `dtype`: DType of the value.
- `length`: SIMD width of the value.

Fields:

- `re` (`ComplexSIMD[dtype, length].element_type`): The real part of the complex SIMD value.
- `im` (`ComplexSIMD[dtype, length].element_type`): The imaginary part of the complex SIMD value.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`, `_Expable`

Aliases:

- `type = dtype`: The data type of the complex components.
- `element_type = SIMD[dtype, length]`: The SIMD type used for real and imaginary parts.

#### `ComplexSIMD.__init__`

```mojo
def __init__(re: SIMD[dtype, length], im: SIMD[dtype, length] = 0) -> Self
```

Initializes a complex SIMD value.

Args:

- `re`: The real part of the complex value.
- `im`: The imaginary part of the complex value.

```mojo
def __init__(*, from_interleaved: SIMD[dtype, (Int(2) * SIMD(length))]) -> Self
```

Initializes a complex SIMD value.

Args:

- `from_interleaved`: An interleaved vector of complex values e.g. `[0, 1, 1, 0]` where the pattern is `[re0, im0, re1, im1]`.

```mojo
def __init__(*, from_deinterleaved: SIMD[dtype, (Int(2) * SIMD(length))]) -> Self
```

Initializes a complex SIMD value.

Args:

- `from_deinterleaved`: A deinterleaved vector of complex values e.g. `[0, 1, 1, 0]` where the pattern is `[re0, re1, im0, im1]`.

#### `ComplexSIMD.__neg__`

```mojo
def __neg__(self) -> Self
```

Negates the complex value.

Returns: The negative of the complex value.

#### `ComplexSIMD.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compares two ComplexSIMD for equality.

Args:

- `rhs`: The ComplexSIMD to compare with.

Returns: True if all elements of the ComplexSIMD are equal, False otherwise.

#### `ComplexSIMD.__add__`

```mojo
def __add__(self, rhs: Self) -> Self
```

Adds two complex values.

Args:

- `rhs`: Complex value to add.

Returns: A sum of this and RHS complex values.

#### `ComplexSIMD.__sub__`

```mojo
def __sub__(self, rhs: Self) -> Self
```

Subtracts two complex values.

Args:

- `rhs`: Complex value to subtract.

Returns: A difference of this and RHS complex values.

#### `ComplexSIMD.__mul__`

```mojo
def __mul__(self, rhs: Self) -> Self
```

Multiplies two complex values.

Args:

- `rhs`: Complex value to multiply with.

Returns: A product of this and RHS complex values.

```mojo
def __mul__(self, rhs: Scalar[dtype]) -> Self
```

Multiplies a complex value to a scalar.

Args:

- `rhs`: Scalar value to multiply with.

Returns: A product of self and rhs.

#### `ComplexSIMD.__truediv__`

```mojo
def __truediv__(self, rhs: Self) -> Self
```

Divides two complex values.

Args:

- `rhs`: Complex value to divide by.

Returns: A quotient of this and RHS complex values.

#### `ComplexSIMD.__rmul__`

```mojo
def __rmul__(self, lhs: Scalar[dtype]) -> Self
```

Multiplies a complex value to a scalar.

Args:

- `lhs`: Scalar value to multiply with.

Returns: A product of self and lhs.

#### `ComplexSIMD.__imul__`

```mojo
def __imul__(mut self, rhs: Self)
```

Multiplies two complex values inplace.

Args:

- `rhs`: Complex value to multiply with.

```mojo
def __imul__(mut self, rhs: Scalar[dtype])
```

Multiplies a complex value to a scalar inplace.

Args:

- `rhs`: Scalar value to multiply with.

#### `ComplexSIMD.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this complex value to the provided Writer.

Args:

- `writer`: The object to write to.

#### `ComplexSIMD.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Formats the complex value for debug representation.

Args:

- `writer`: The Writer to write the representation to.

#### `ComplexSIMD.__abs__`

```mojo
def __abs__(self) -> SIMD[dtype, length]
```

Returns the magnitude of the complex value.

Returns: Value of `sqrt(re*re + im*im)`.

#### `ComplexSIMD.conj`

```mojo
def conj(self) -> Self
```

Return the complex conjugate of self.

Returns: The complex conjugate of self.

#### `ComplexSIMD.norm`

```mojo
def norm(self) -> SIMD[dtype, length]
```

Returns the magnitude of the complex value.

Returns: Value of `sqrt(re*re + im*im)`.

#### `ComplexSIMD.squared_norm`

```mojo
def squared_norm(self) -> SIMD[dtype, length]
```

Returns the squared magnitude of the complex value.

Returns: Value of `re*re + im*im`.

#### `ComplexSIMD.fma`

```mojo
def fma(self, b: Self, c: Self) -> Self
```

Computes FMA operation.

Compute fused multiple-add with two other complex values:
`result = self * b + c`

Args:

- `b`: Multiplier complex value.
- `c`: Complex value to add.

Returns: Computed `Self * B + C` complex value.

#### `ComplexSIMD.squared_add`

```mojo
def squared_add(self, c: Self) -> Self
```

Computes Square-Add operation.

Compute `Self * Self + C`.

Args:

- `c`: Complex value to add.

Returns: Computed `Self * Self + C` complex value.

#### `ComplexSIMD.__exp__`

```mojo
def __exp__(self) -> Self
```

Computes the exponential of the complex value.

Returns: The exponential of the complex value.

## Functions

### `abs`

```mojo
def abs(x: ComplexSIMD) -> SIMD[x.dtype, x.length]
```

Performs elementwise abs (norm) on each element of the complex value.

Args:

- `x`: The complex vector to perform absolute value on.

Returns: The elementwise abs of x.

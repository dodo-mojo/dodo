# `std.builtin.dtype`

Implements the DType class.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `DType`

```mojo
struct DType
```

Represents a data type specification and provides methods for working with it.

`DType` defines a set of compile-time constant that specify the precise
numeric representation of data in order to prevent runtime errors by
catching type mismatches at compile time. It directly maps to CPU/GPU
instruction sets, allowing the compiler to generate optimal SIMD and vector
operations.

`DType` behaves like an enum rather than a typical object. You don't
instantiate it, but instead use its compile-time constants (aliases) to
declare data types for SIMD vectors, tensors, and other data structures.

Key usage patterns:

- **Type specification**: Use aliases like `DType.float32` to specify types
  for SIMD vectors, tensors, and other data structures
- **Type parameters**: Pass `DType` values as compile-time parameters to
  parameterized types like `SIMD[dtype, size]`
- **Type introspection**: Call methods like `.is_floating_point()` to query
  type properties at compile time
- **Type conversion**: Use in casting operations to convert between different
  numeric representations

**Note:** Not all data types are supported on all platforms. For example,
`DType.bfloat16` is currently not supported on Apple Silicon.

Example:

```mojo
var data = SIMD[.float16, 4](1.5, 2.5, 3.5, 4.5)
var dtype = data.dtype

print("Is float:", dtype.is_floating_point())  # True
print("Is signed:", dtype.is_signed())         # True
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `Hashable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `bool = DType.bool`: Represents a boolean data type.
- `int = DType.int`: Represents an integral type whose bitwidth is the maximum integral value on the system.
- `uint = DType.uint`: Represents an unsigned integral type whose bitwidth is the maximum unsigned integral value on the system.
- `uint8 = DType.uint8`: Represents an unsigned integer type whose bitwidth is 8.
- `int8 = DType.int8`: Represents a signed integer type whose bitwidth is 8.
- `uint16 = DType.uint16`: Represents an unsigned integer type whose bitwidth is 16.
- `int16 = DType.int16`: Represents a signed integer type whose bitwidth is 16.
- `uint32 = DType.uint32`: Represents an unsigned integer type whose bitwidth is 32.
- `int32 = DType.int32`: Represents a signed integer type whose bitwidth is 32.
- `uint64 = DType.uint64`: Represents an unsigned integer type whose bitwidth is 64.
- `int64 = DType.int64`: Represents a signed integer type whose bitwidth is 64.
- `uint128 = DType.uint128`: Represents an unsigned integer type whose bitwidth is 128.
- `int128 = DType.int128`: Represents a signed integer type whose bitwidth is 128.
- `uint256 = DType.uint256`: Represents an unsigned integer type whose bitwidth is 256.
- `int256 = DType.int256`: Represents a signed integer type whose bitwidth is 256.
- `float4_e2m1fn = DType.float4_e2m1fn`: Represents a 4-bit `e2m1` floating point format.
- `float6_e2m3fn = DType.float6_e2m3fn`: Represents a 6-bit `e2m3` floating point format.
- `float6_e3m2fn = DType.float6_e3m2fn`: Represents a 6-bit `e3m2` floating point format.
- `float8_e8m0fnu = DType.float8_e8m0fnu`: Represents the 8-bit `E8M0Fnu` floating point format.
- `float8_e3m4 = DType.float8_e3m4`: Represents an 8-bit `e3m4` floating point format.
- `float8_e4m3fn = DType.float8_e4m3fn`: Represents the 8-bit `E4M3` floating point format defined in the [OFP8 standard](https://www.opencompute.org/documents/ocp-8-bit-floating-point-specification-ofp8-revision-1-0-2023-12-01-pdf-1).
- `float8_e4m3fnuz = DType.float8_e4m3fnuz`: Represents an 8-bit `e4m3fnuz` floating point format.
- `float8_e5m2 = DType.float8_e5m2`: Represents the 8-bit `E5M2` floating point format.
- `float8_e5m2fnuz = DType.float8_e5m2fnuz`: Represents an 8-bit `e5m2fnuz` floating point format.
- `bfloat16 = DType.bfloat16`: Represents a brain floating point value whose bitwidth is 16.
- `float16 = DType.float16`: Represents an IEEE754-2008 `binary16` floating point value.
- `float32 = DType.float32`: Represents an IEEE754-2008 `binary32` floating point value.
- `float64 = DType.float64`: Represents an IEEE754-2008 `binary64` floating point value.

#### `DType.__init__`

```mojo
def __init__(*, mlir_value: __mlir_type.`!kgen.dtype`) -> Self
```

Construct a DType from MLIR dtype.

Args:

- `mlir_value`: The MLIR dtype.

#### `DType.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compares one DType to another for equality.

Args:

- `rhs`: The DType to compare against.

Returns: True if the DTypes are the same and False otherwise.

#### `DType.__ne__`

```mojo
def __ne__(self, rhs: Self) -> Bool
```

Compares one DType to another for inequality.

Args:

- `rhs`: The DType to compare against.

Returns: False if the DTypes are the same and True otherwise.

#### `DType.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this dtype to the provided Writer.

Args:

- `writer`: The object to write to.

#### `DType.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the string representation of the DType.

Args:

- `writer`: The value to write to.

#### `DType.get_value`

```mojo
def get_value(self) -> __mlir_type.`!kgen.dtype`
```

Gets the associated internal kgen.dtype value.

Returns: The kgen.dtype value.

#### `DType.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H)
```

Updates hasher with this `DType` value.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `DType.is_unsigned`

```mojo
def is_unsigned(self) -> Bool
```

Returns True if the type parameter is unsigned and False otherwise.

Returns: Returns True if the input type parameter is unsigned.

#### `DType.is_signed`

```mojo
def is_signed(self) -> Bool
```

Returns True if the type parameter is signed and False otherwise.

Returns: Returns True if the input type parameter is signed.

#### `DType.is_integral`

```mojo
def is_integral(self) -> Bool
```

Returns True if the type parameter is an integer and False otherwise.

Returns: Returns True if the input type parameter is an integer.

#### `DType.is_floating_point`

```mojo
def is_floating_point(self) -> Bool
```

Returns True if the type parameter is a floating-point and False otherwise.

Returns: Returns True if the input type parameter is a floating-point.

#### `DType.is_float8`

```mojo
def is_float8(self) -> Bool
```

Returns True if the dtype is a 8bit-precision floating point type, e.g. float8_e5m2, float8_e5m2fnuz, float8_e4m3fn and float8_e4m3fnuz.

Returns: True if the dtype is a 8bit-precision float, false otherwise.

#### `DType.is_half_float`

```mojo
def is_half_float(self) -> Bool
```

Returns True if the dtype is a half-precision floating point type, e.g. either fp16 or bf16.

Returns: True if the dtype is a half-precision float, false otherwise..

#### `DType.is_numeric`

```mojo
def is_numeric(self) -> Bool
```

Returns True if the type parameter is numeric (i.e. you can perform arithmetic operations on).

Returns: Returns True if the input type parameter is either integral or floating-point.

#### `DType.mantissa_width`

```mojo
def mantissa_width[dtype: Self]() -> Int
```

Returns the mantissa width of a floating point type.

Parameters:

- `dtype`: The DType.

Returns: The mantissa width.

#### `DType.max_exponent`

```mojo
def max_exponent[dtype: Self]() -> Int
```

Returns the max exponent of a floating point dtype without accounting for inf representations. This is not the maximum representable exponent, which is generally equal to the exponent_bias.

Parameters:

- `dtype`: The DType.

Returns: The max exponent.

#### `DType.exponent_width`

```mojo
def exponent_width[dtype: Self]() -> Int
```

Returns the exponent width of a floating point type.

Parameters:

- `dtype`: The DType.

Returns: The exponent width.

#### `DType.exponent_bias`

```mojo
def exponent_bias[dtype: Self]() -> Int
```

Returns the exponent bias of a floating point type.

Parameters:

- `dtype`: The DType.

Returns: The exponent bias.

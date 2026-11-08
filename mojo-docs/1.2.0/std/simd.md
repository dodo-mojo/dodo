# `std.simd`

Implements SIMD primitives and abstractions.

Provides high-performance SIMD primitives and abstractions for
vectorized computation in Mojo. It enables efficient data-parallel operations
by leveraging hardware vector processing units across different architectures.

Key Features:
1. Architecture-agnostic SIMD abstractions with automatic hardware detection
2. Optimized vector operations for common numerical computations
3. Explicit control over vectorization strategies and memory layouts
4. Zero-cost abstractions that compile to efficient machine code
5. Support for different vector widths and element types

Primary Components:
- Vector types: Strongly-typed vector containers with element-wise operations
- SIMD intrinsics: Low-level access to hardware SIMD instructions
- Vectorized algorithms: Common algorithms optimized for SIMD execution
- Memory utilities: Aligned memory allocation and vector load/store operations

Performance Considerations:
- Vector width selection should match target hardware capabilities
- Memory alignment affects load/store performance
- Data layout transformations may be necessary for optimal vectorization

Integration:
This module is designed to work seamlessly with other Mojo numerical computing
components, including tensor operations, linear algebra routines, and
domain-specific libraries for machine learning and scientific computing.

## Aliases

### `Scalar`

```mojo
comptime Scalar = Scalar[_]
```

Represents a scalar dtype.

### `Int`

```mojo
comptime Int = Int
```

Represents a signed integer suitable for indexing.

### `Int8`

```mojo
comptime Int8 = Int8
```

Represents an 8-bit signed scalar integer.

### `UInt8`

```mojo
comptime UInt8 = UInt8
```

Represents an 8-bit unsigned scalar integer.

### `Int16`

```mojo
comptime Int16 = Int16
```

Represents a 16-bit signed scalar integer.

### `UInt16`

```mojo
comptime UInt16 = UInt16
```

Represents a 16-bit unsigned scalar integer.

### `Int32`

```mojo
comptime Int32 = Int32
```

Represents a 32-bit signed scalar integer.

### `UInt32`

```mojo
comptime UInt32 = UInt32
```

Represents a 32-bit unsigned scalar integer.

### `Int64`

```mojo
comptime Int64 = Int64
```

Represents a 64-bit signed scalar integer.

### `UInt64`

```mojo
comptime UInt64 = UInt64
```

Represents a 64-bit unsigned scalar integer.

### `Int128`

```mojo
comptime Int128 = Int128
```

Represents a 128-bit signed scalar integer.

### `UInt128`

```mojo
comptime UInt128 = UInt128
```

Represents a 128-bit unsigned scalar integer.

### `Int256`

```mojo
comptime Int256 = Int256
```

Represents a 256-bit signed scalar integer.

### `UInt256`

```mojo
comptime UInt256 = UInt256
```

Represents a 256-bit unsigned scalar integer.

### `Float4_e2m1fn`

```mojo
comptime Float4_e2m1fn = Float4_e2m1fn
```

Represents a 4-bit `e2m1` floating point format.

This type is encoded as `s.ee.m` and defined by the
[Open Compute MX Format Specification](https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf):

- (s)ign: 1 bit
- (e)xponent: 2 bits
- (m)antissa: 1 bits
- exponent_bias: 1

### `Float8_e5m2`

```mojo
comptime Float8_e5m2 = Float8_e5m2
```

Represents the 8-bit E5M2 floating point format.

This type is from the [OFP8
standard](https://www.opencompute.org/documents/ocp-8-bit-floating-point-specification-ofp8-revision-1-0-2023-12-01-pdf-1),
encoded as `seeeeemm`:
- (s)ign: 1 bit
- (e)xponent: 5 bits
- (m)antissa: 2 bits
- exponent bias: 15
- nan: {0,1}11111{01,10,11}
- inf: 01111100
- -inf: 11111100
- -0: 10000000

### `Float8_e5m2fnuz`

```mojo
comptime Float8_e5m2fnuz = Float8_e5m2fnuz
```

Represents an 8-bit floating point format.

This type is encoded as `seeeeemm`:
- (s)ign: 1 bit
- (e)xponent: 5 bits
- (m)antissa: 2 bits
- exponent bias: 16
- nan: 10000000
- fn: finite (no inf or -inf encodings)
- uz: unsigned zero (no -0 encoding)

### `Float8_e4m3fn`

```mojo
comptime Float8_e4m3fn = Float8_e4m3fn
```

Represents the E4M3 floating point format defined in the [OFP8 standard](https://www.opencompute.org/documents/ocp-8-bit-floating-point-specification-ofp8-revision-1-0-2023-12-01-pdf-1).

This type is named differently across libraries and vendors, for example:
- Mojo, PyTorch, JAX, and LLVM refer to it as `e4m3fn`.
- OCP, NVIDIA CUDA, and AMD ROCm refer to it as `e4m3`.

In these contexts, they are all referring to the same finite type specified
in the OFP8 standard above, encoded as `seeeemmm`:
- (s)ign: 1 bit
- (e)xponent: 4 bits
- (m)antissa: 3 bits
- exponent bias: 7
- nan: 01111111, 11111111
- -0: 10000000
- fn: finite (no inf or -inf encodings)

### `Float8_e4m3fnuz`

```mojo
comptime Float8_e4m3fnuz = Float8_e4m3fnuz
```

Represents an 8-bit e4m3fnuz floating point format.

This type is encoded as `seeeemmm`:
- (s)ign: 1 bit
- (e)xponent: 4 bits
- (m)antissa: 3 bits
- exponent bias: 8
- nan: 10000000
- fn: finite (no inf or -inf encodings)
- uz: unsigned zero (no -0 encoding)

### `Float8_e8m0fnu`

```mojo
comptime Float8_e8m0fnu = Float8_e8m0fnu
```

Represents the 8-bit E8M0FNU floating point format.

This type is defined in the [OCP MX
spec](https://www.opencompute.org/documents/ocp-microscaling-formats-mx-v1-0-spec-final-pdf),
encoded as `eeeeeeee`:
- (e)xponent: 8 bits
- (m)antissa: 0 bits
- exponent bias: 127
- nan: 11111111
- fn: finite (no inf or -inf encodings)
- u: unsigned (no sign bit or zero value)

### `BFloat16`

```mojo
comptime BFloat16 = BFloat16
```

Represents a 16-bit brain floating point value.

### `Float16`

```mojo
comptime Float16 = Float16
```

Represents a 16-bit floating point value.

### `Float32`

```mojo
comptime Float32 = Float32
```

Represents a 32-bit floating point value.

### `Float64`

```mojo
comptime Float64 = Float64
```

Represents a 64-bit floating point value.

### `Byte`

```mojo
comptime Byte = UInt8
```

Represents a byte (backed by an 8-bit unsigned integer).

### `UInt`

```mojo
comptime UInt = UInt
```

Represents an unsigned integer of platform-dependent bit-width.

### `U8x16`

```mojo
comptime U8x16 = SIMD[.uint8, 16]
```

A 16-element vector of unsigned 8-bit integers.

## Structs

### `FastMathFlag`

```mojo
struct FastMathFlag
```

Flags for controlling fast-math optimizations in floating-point operations.

FastMathFlag provides compile-time controls for various floating-point math
optimization modes that trade strict IEEE 754 compliance for performance.

Available flags:
- `NONE`: No fast-math optimizations.
- `NNAN`: Assume operands and results are not NaN.
- `NINF`: Assume operands and results are not +/- infinity.
- `NSZ`: Treat the sign of a zero as insignificant.
- `ARCP`: Allow reciprocal of values.
- `CONTRACT`: Allow floating-point contraction (e.g., fused multiply-add).
- `AFN`: Allow algebraic function approximations.
- `REASSOC`: Allow reassociation of floating-point operations.
- `FAST`: Enable all fast-math optimizations.

Examples:
```mojo
from std.simd import FastMathFlag
var value = Float32(2.0)
var multiplier = Float32(3.0)
var accumulator = Float32(1.0)

# Use contract flag for fused multiply-add
var result = value.fma[FastMathFlag.CONTRACT](multiplier, accumulator)

# Use fast flag for maximum optimization
var fast_result = value.fma[FastMathFlag.FAST](multiplier, accumulator)
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `EnumLike`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`

Aliases:

- `NONE = FastMathFlag(UInt8(0))`: No fast-math optimizations enabled.
- `NNAN = FastMathFlag(UInt8(1))`: Assume no NaN values.
- `NINF = FastMathFlag(UInt8(2))`: Assume no infinite values.
- `NSZ = FastMathFlag(UInt8(3))`: Treat the sign of zero as insignificant.
- `ARCP = FastMathFlag(UInt8(4))`: Allow reciprocal approximations.
- `CONTRACT = FastMathFlag(UInt8(5))`: Allow floating-point contraction.
- `AFN = FastMathFlag(UInt8(6))`: Allow approximate function implementations.
- `REASSOC = FastMathFlag(UInt8(7))`: Allow reassociation of operations.
- `FAST = FastMathFlag(UInt8(8))`: Enable all fast-math optimizations.

#### `FastMathFlag.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Compares two FastMathFlag values for identity.

Args:

- `other`: The FastMathFlag to compare against.

Returns: True if both flags have the same value, False otherwise.

### `SIMD`

```mojo
struct SIMD[dtype: DType, length: SIMDLength]
```

Represents a vector type that leverages hardware acceleration to process multiple data elements with a single operation.

SIMD (Single Instruction, Multiple Data) is a fundamental parallel
computing paradigm where a single CPU instruction operates on multiple data
elements at once. Modern CPUs can perform 4, 8, 16, or even 32 operations
in parallel using SIMD, delivering substantial performance improvements
over scalar operations. Instead of processing one value at a time, SIMD
processes entire vectors of values with each instruction.

For example, when adding two vectors of four values, a scalar operation
adds each value in the vector one by one, while a SIMD operation adds all
four values at once using vector registers:

```text
Scalar operation:                SIMD operation:
┌─────────────────────────┐      ┌───────────────────────────┐
│ 4 instructions          │      │ 1 instruction             │
│ 4 clock cycles          │      │ 1 clock cycle             │
│                         │      │                           │
│ ADD  a[0], b[0] → c[0]  │      │ Vector register A         │
│ ADD  a[1], b[1] → c[1]  │      │ ┌─────┬─────┬─────┬─────┐ │
│ ADD  a[2], b[2] → c[2]  │      │ │a[0] │a[1] │a[2] │a[3] │ │
│ ADD  a[3], b[3] → c[3]  │      │ └─────┴─────┴─────┴─────┘ │
└─────────────────────────┘      │           +               │
                                 │ Vector register B         │
                                 │ ┌─────┬─────┬─────┬─────┐ │
                                 │ │b[0] │b[1] │b[2] │b[3] │ │
                                 │ └─────┴─────┴─────┴─────┘ │
                                 │           ↓               │
                                 │        SIMD_ADD           │
                                 │           ↓               │
                                 │ Vector register C         │
                                 │ ┌─────┬─────┬─────┬─────┐ │
                                 │ │c[0] │c[1] │c[2] │c[3] │ │
                                 │ └─────┴─────┴─────┴─────┘ │
                                 └───────────────────────────┘
```

The `SIMD` type maps directly to hardware vector registers and
instructions. Mojo automatically generates optimal SIMD code that leverages
CPU-specific instruction sets (such as AVX and NEON) without requiring
manual intrinsics or assembly programming.

This type is the foundation of high-performance CPU computing in Mojo,
enabling you to write code that automatically leverages modern CPU vector
capabilities while maintaining code clarity and portability.

**Caution:** If you declare a SIMD vector size larger than the vector
registers of the target hardware, the compiler will break up the SIMD into
multiple vector registers for compatibility. However, you should avoid
using a vector that's more than 2x the hardware's vector register size
because the resulting code will perform poorly.

Key properties:

- **Hardware-mapped**: Directly maps to CPU vector registers
- **Type-safe**: Data types and vector sizes are checked at compile time
- **Zero-cost**: No runtime overhead compared to hand-optimized intrinsics
- **Portable**: Same code works across different CPU architectures
  (x86, ARM, etc.)
- **Composable**: Seamlessly integrates with Mojo's parallelization features

Key APIs:

- Construction:
  - Broadcast single value to all elements: `SIMD[dtype, length](value)`
  - Initialize with specific values: `SIMD[dtype, length](v1, v2, ...)`
  - Zero-initialized vector: `SIMD[dtype, length]()`

- Element operations:
  - Arithmetic: `+`, `-`, `*`, `/`, `%`, `//`
  - Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`
  - Math functions: `sqrt()`, `sin()`, `cos()`, `fma()`, etc.
  - Bit operations: `&`, `|`, `^`, `~`, `<<`, `>>`

- Vector operations:
  - Horizontal reductions: `reduce_add()`, `reduce_mul()`, `reduce_min()`, `reduce_max()`
  - Element-wise conditional selection: `select(true_case, false_case)`
  - Vector manipulation: `shuffle()`, `slice()`, `join()`, `split()`
  - Type conversion: `cast[target_dtype]()`

Examples:

Vectorized math operations:

```mojo
# Process 8 floating-point numbers simultaneously
var a = SIMD[.float32, 8](1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
var b = SIMD[.float32, 8](2.0)  # Broadcast 2.0 to all elements
var result = a * b + 1.0
print(result)  # => [3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0]
```

Conditional operations with masking:

```mojo
# Double the positive values and negate the negative values
var values = SIMD[.int32, 4](1, -2, 3, -4)
var is_positive = values.gt(0)  # greater-than: gets SIMD of booleans
var result = is_positive.select(values * 2, values * -1)
print(result)  # => [2, 2, 6, 4]
```

Horizontal reductions:

```mojo
# Sum all elements in a vector
var data = SIMD[.float64, 4](10.5, 20.3, 30.1, 40.7)
var total = data.reduce_add()
var maximum = data.reduce_max()
print(total, maximum)  # => 101.6 40.7
```

Parameters:

- `dtype`: The data type of SIMD vector elements.
- `length`: The length of the SIMD vector (number of elements).

Implemented traits: `Absable`, `AnyType`, `Boolable`, `CeilDivable`, `Ceilable`, `Comparable`, `ConvertibleFromPython`, `CoordLike`, `Copyable`, `Defaultable`, `Deinitable`, `DevicePassable`, `DivModable`, `Equatable`, `Floorable`, `Hashable`, `ImplicitlyCopyable`, `Indexer`, `Intable`, `IntervalElement`, `Movable`, `Powable`, `RegisterPassable`, `Roundable`, `Sized`, `TrivialRegisterPassable`, `Truncable`, `Writable`, `_FromInt`

Aliases:

- `MAX = SIMD(max_or_inf[dtype]())`: Gets the maximum value for the SIMD value, potentially +inf.
- `MIN = SIMD(min_or_neg_inf[dtype]())`: Gets the minimum value for the SIMD value, potentially -inf.
- `MAX_FINITE = SIMD(max_finite[dtype]())`: Returns the maximum finite value of SIMD value.
- `MIN_FINITE = SIMD(min_finite[dtype]())`: Returns the minimum (lowest) finite value of SIMD value.
- `device_type = SIMD[dtype, length]`: SIMD types are remapped to the same type when passed to accelerator devices.
- `ParamListType = TypeList[SIMD[dtype, length]]()`: The element types (Self for scalar types).
- `static_value = Int(-1)`: Always -1 for runtime values (not statically known).
- `DTYPE = dtype`: The data type for the runtime integer value.
- `is_static_value = False`: True if the value is known at compile time.
- `is_tuple = False`: True if this is a tuple type (`Coord`), False for scalar values.
- `is_value = True`: True if this is a scalar value, False for tuple types.

#### `SIMD.__init__`

```mojo
def __init__() -> Self
```

Default initializer of the SIMD vector.

By default the SIMD vectors are initialized to all zeros.

```mojo
def __init__[T: Intable, target_dtype: DType = .int](value: T) -> Scalar[target_dtype]
```

Initialize an integer scalar from an intable value.

Example:

```mojo
var x = 42
var p = Pointer(to=x)
print(UInt(p))  # the address of `x`
```

Constraints: The target dtype must be integral.

Parameters:

- `T`: The Intable type.
- `target_dtype`: The dtype of the scalar to construct.

Args:

- `value`: The value to initialize from.

```mojo
def __init__[T: IntableRaising](out self: Int, value: T) raises
```

Initialize from a raising intable value.

Parameters:

- `T`: The IntableRaising type.

Args:

- `value`: The value to initialize from.

Raises: Any errors from the conversion to Int.

```mojo
def __init__[other_dtype: DType, //](value: SIMD[other_dtype, length], /) -> Self
```

Initialize from another SIMD of the same size. If the value passed is a scalar, you can initialize a SIMD vector with more elements.

Example:

```mojo
print(UInt64(UInt8(42))) # 42
print(SIMD[.uint64, 4](UInt8(42))) # [42, 42, 42, 42]
```

Casting behavior:

```mojo
# Basic casting preserves value within range
Int8(UInt8(127)) == Int8(127)

# Numbers above signed max wrap to negative using two's complement
Int8(UInt8(128)) == Int8(-128)
Int8(UInt8(129)) == Int8(-127)
Int8(UInt8(256)) == Int8(0)

# Negative signed cast to unsigned using two's complement
UInt8(Int8(-128)) == UInt8(128)
UInt8(Int8(-127)) == UInt8(129)
UInt8(Int8(-1)) == UInt8(255)

# Truncate precision after downcast and upcast
Float64(Float32(Float64(123456789.123456789))) == Float64(123456792.0)

# Rightmost bits of significand become 0's on upcast
Float64(Float32(0.3)) == Float64(0.30000001192092896)

# Numbers equal after truncation of float literal and cast truncation
Float32(Float64(123456789.123456789)) == Float32(123456789.123456789)

# Float to int/uint floors
Int64(Float64(42.2)) == Int64(42)
```

Parameters:

- `other_dtype`: The type of the value that is being cast from.

Args:

- `value`: The value to cast from.

```mojo
def __init__(value: SIMDLength, /) -> Self
```

Initializes the SIMD vector with a signed integer.

The signed integer value is splatted across all the elements of the SIMD
vector.

Args:

- `value`: The input value.

```mojo
def __init__[T: Floatable, //](value: T, /) -> Float64
```

Initialize a Float64 from a type conforming to Floatable.

Parameters:

- `T`: The Floatable type.

Args:

- `value`: The object to get the float point representation of.

```mojo
def __init__[T: FloatableRaising, //](out self: Float64, value: T, /) raises
```

Initialize a Float64 from a type conforming to FloatableRaising.

Parameters:

- `T`: The FloatableRaising type.

Args:

- `value`: The object to get the float point representation of.

Raises: If the type does not have a float point representation.

```mojo
def __init__(value: IntLiteral, /) -> Self
```

Initializes the SIMD vector with an integer.

The integer value is splatted across all the elements of the SIMD
vector.

Args:

- `value`: The input value.

```mojo
def __init__(value: Bool, /) -> SIMD[.bool, length]
```

Initializes a Scalar with a bool value.

Since this constructor does not splat, it can be implicit.

Args:

- `value`: The bool value to initialize the Scalar with.

```mojo
def __init__(*, fill: Bool) -> SIMD[.bool, length]
```

Initializes the SIMD vector with a bool value.

The bool value is splatted across all elements of the SIMD vector.

Args:

- `fill`: The bool value to fill each element of the SIMD vector with.

```mojo
def __init__(value: Scalar[dtype], /) -> Self
```

Constructs a SIMD vector by splatting a scalar value.

The input value is splatted across all elements of the SIMD vector.

Args:

- `value`: The value to splat to the elements of the vector.

```mojo
def __init__(*elems: Scalar[dtype], *, __list_literal__: NoneType = None) -> Self
```

Constructs a SIMD vector via a variadic list of elements.

The input values are assigned to the corresponding elements of the SIMD
vector.

Constraints: The number of input values is equal to size of the SIMD vector.

Args:

- `*elems`: The variadic list of elements from which the SIMD vector is constructed.
- `__list_literal__`: Tell Mojo to use this method for list literals.

```mojo
def __init__(value: FloatLiteral, /) -> Self
```

Initializes the SIMD vector with a float.

The value is splatted across all the elements of the SIMD
vector.

Args:

- `value`: The input value.

```mojo
def __init__[int_dtype: DType, //](*, from_bits: SIMD[int_dtype, length]) -> Self
```

Initializes the SIMD vector from the bits of an integral SIMD vector.

Parameters:

- `int_dtype`: The integral type of the input SIMD vector.

Args:

- `from_bits`: The SIMD vector to copy the bits from.

```mojo
def __init__(out self, *, py: PythonObject) raises
```

Initialize a SIMD value from a PythonObject.

Args:

- `py`: The PythonObject to convert.

Raises: If the conversion to double fails, or if the value is out of range for an unsigned dtype (a negative or too-large Python int).

#### `SIMD.__bool__`

```mojo
def __bool__(self) -> Bool
```

Converts the SIMD scalar into a boolean value.

Returns: True if the SIMD scalar is non-zero and False otherwise.

#### `SIMD.__getitem__`

```mojo
def __getitem__(self, idx: Int) -> Scalar[dtype]
```

Gets an element from the vector.

Args:

- `idx`: The element index.

Returns: The value at position `idx`.

#### `SIMD.__setitem__`

```mojo
def __setitem__(mut self, idx: Int, val: Scalar[dtype])
```

Sets an element in the vector.

Args:

- `idx`: The index to set.
- `val`: The value to set.

#### `SIMD.__neg__`

```mojo
def __neg__(self) -> Self
```

Defines the unary `-` operation.

Returns: The negation of this SIMD vector.

#### `SIMD.__pos__`

```mojo
def __pos__(self) -> Self
```

Defines the unary `+` operation.

Returns: This SIMD vector.

#### `SIMD.__invert__`

```mojo
def __invert__(self) -> Self
```

Returns `~self`.

Constraints: The element type of the SIMD vector must be boolean or integral.

Returns: The `~self` value.

#### `SIMD.__lt__`

```mojo
def __lt__(self, rhs: Self) -> Bool
```

Compares two Scalars using less-than comparison.

Args:

- `rhs`: The Scalar to compare with.

Returns: True if `self` is less than `rhs`, False otherwise.

#### `SIMD.__le__`

```mojo
def __le__(self, rhs: Self) -> Bool
```

Compares two Scalars using less-than-or-equal comparison.

Args:

- `rhs`: The Scalar to compare with.

Returns: True if `self` is less than or equal to `rhs`, False otherwise.

#### `SIMD.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compares two SIMD vectors for equality.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: True if all elements of the SIMD vectors are equal, False otherwise.

#### `SIMD.__ne__`

```mojo
def __ne__(self, rhs: Self) -> Bool
```

Compares two SIMD vectors for inequality.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: True if any elements of the SIMD vectors are not equal, False otherwise.

#### `SIMD.__gt__`

```mojo
def __gt__(self, rhs: Self) -> Bool
```

Compares two Scalars using greater-than comparison.

Args:

- `rhs`: The Scalar to compare with.

Returns: True if `self` is greater than `rhs`, False otherwise.

#### `SIMD.__ge__`

```mojo
def __ge__(self, rhs: Self) -> Bool
```

Compares two Scalars using greater-than-or-equal comparison.

Args:

- `rhs`: The Scalar to compare with.

Returns: True if `self` is greater than or equal to `rhs`, False otherwise.

#### `SIMD.__contains__`

```mojo
def __contains__(self, value: Scalar[dtype]) -> Bool
```

Whether the vector contains the value.

Args:

- `value`: The value.

Returns: Whether the vector contains the value.

#### `SIMD.__add__`

```mojo
def __add__(self, rhs: Self) -> Self
```

Computes `self + rhs`.

Args:

- `rhs`: The rhs value.

Returns: A new vector whose element at position `i` is computed as `self[i] + rhs[i]`.

#### `SIMD.__sub__`

```mojo
def __sub__(self, rhs: Self) -> Self
```

Computes `self - rhs`.

Args:

- `rhs`: The rhs value.

Returns: A new vector whose element at position `i` is computed as `self[i] - rhs[i]`.

#### `SIMD.__mul__`

```mojo
def __mul__(self, rhs: Self) -> Self
```

Computes `self * rhs`.

Args:

- `rhs`: The rhs value.

Returns: A new vector whose element at position `i` is computed as `self[i] * rhs[i]`.

#### `SIMD.__truediv__`

```mojo
def __truediv__(self, rhs: Self) -> Self
```

Computes `self / rhs`.

Args:

- `rhs`: The rhs value.

Returns: A new vector whose element at position `i` is computed as `self[i] / rhs[i]`.

#### `SIMD.__floordiv__`

```mojo
def __floordiv__(self, rhs: Self) -> Self
```

Returns the division of self and rhs rounded down to the nearest integer.

Constraints: The element type of the SIMD vector must be numeric.

Args:

- `rhs`: The value to divide with.

Returns: `floor(self / rhs)` value.

#### `SIMD.__mod__`

```mojo
def __mod__(self, rhs: Self) -> Self
```

Returns the remainder of self divided by rhs.

Args:

- `rhs`: The value to divide with.

Returns: The remainder of dividing self by rhs.

#### `SIMD.__pow__`

```mojo
def __pow__(self, exp: SIMD) -> Self
```

Computes the vector raised to the power of the input integer value.

Args:

- `exp`: The exponent value.

Returns: A SIMD vector where each element is raised to the power of the specified exponent value.

```mojo
def __pow__(self, exp: FloatLiteral) -> Self
```

Computes the vector raised to the power of a float literal.

The literal is converted to `Self`, so the exponent always has the
same dtype as the base.

Constraints: The SIMD dtype must be floating point.

Args:

- `exp`: The exponent value.

Returns: A SIMD vector where each element is raised to the power of the specified exponent value.

```mojo
def __pow__(self, exp: Self) -> Self
```

Computes the vector raised elementwise to the right hand side power.

Args:

- `exp`: The exponent value.

Returns: A SIMD vector where each element is raised to the power of the specified exponent value.

#### `SIMD.__lshift__`

```mojo
def __lshift__(self, rhs: Self) -> Self
```

Returns `self << rhs`.

Constraints: The element type of the SIMD vector must be integral.

Args:

- `rhs`: The RHS value.

Returns: `self << rhs`.

#### `SIMD.__rshift__`

```mojo
def __rshift__(self, rhs: Self) -> Self
```

Returns `self >> rhs`.

Constraints: The element type of the SIMD vector must be integral.

Args:

- `rhs`: The RHS value.

Returns: `self >> rhs`.

#### `SIMD.__and__`

```mojo
def __and__(self, rhs: Self) -> Self
```

Returns `self & rhs`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `rhs`: The RHS value.

Returns: `self & rhs`.

#### `SIMD.__or__`

```mojo
def __or__(self, rhs: Self) -> Self
```

Returns `self | rhs`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `rhs`: The RHS value.

Returns: `self | rhs`.

#### `SIMD.__xor__`

```mojo
def __xor__(self, rhs: Self) -> Self
```

Returns `self ^ rhs`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `rhs`: The RHS value.

Returns: `self ^ rhs`.

#### `SIMD.__radd__`

```mojo
def __radd__(self, value: Self) -> Self
```

Returns `value + self`.

Args:

- `value`: The other value.

Returns: `value + self`.

#### `SIMD.__rsub__`

```mojo
def __rsub__(self, value: Self) -> Self
```

Returns `value - self`.

Args:

- `value`: The other value.

Returns: `value - self`.

#### `SIMD.__rmul__`

```mojo
def __rmul__(self, value: Self) -> Self
```

Returns `value * self`.

Args:

- `value`: The other value.

Returns: `value * self`.

#### `SIMD.__rtruediv__`

```mojo
def __rtruediv__(self, value: Self) -> Self
```

Returns `value / self`.

Args:

- `value`: The other value.

Returns: `value / self`.

#### `SIMD.__rfloordiv__`

```mojo
def __rfloordiv__(self, rhs: Self) -> Self
```

Returns the division of rhs and self rounded down to the nearest integer.

Constraints: The element type of the SIMD vector must be numeric.

Args:

- `rhs`: The value to divide by self.

Returns: `floor(rhs / self)` value.

#### `SIMD.__rmod__`

```mojo
def __rmod__(self, value: Self) -> Self
```

Returns `value mod self`.

Args:

- `value`: The other value.

Returns: `value mod self`.

#### `SIMD.__rpow__`

```mojo
def __rpow__(self, base: Self) -> Self
```

Returns `base ** self`.

Args:

- `base`: The base value.

Returns: `base ** self`.

#### `SIMD.__rlshift__`

```mojo
def __rlshift__(self, value: Self) -> Self
```

Returns `value << self`.

Constraints: The element type of the SIMD vector must be integral.

Args:

- `value`: The other value.

Returns: `value << self`.

#### `SIMD.__rrshift__`

```mojo
def __rrshift__(self, value: Self) -> Self
```

Returns `value >> self`.

Constraints: The element type of the SIMD vector must be integral.

Args:

- `value`: The other value.

Returns: `value >> self`.

#### `SIMD.__rand__`

```mojo
def __rand__(self, value: Self) -> Self
```

Returns `value & self`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `value`: The other value.

Returns: `value & self`.

#### `SIMD.__ror__`

```mojo
def __ror__(self, value: Self) -> Self
```

Returns `value | self`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `value`: The other value.

Returns: `value | self`.

#### `SIMD.__rxor__`

```mojo
def __rxor__(self, value: Self) -> Self
```

Returns `value ^ self`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `value`: The other value.

Returns: `value ^ self`.

#### `SIMD.__iadd__`

```mojo
def __iadd__(mut self, rhs: Self)
```

Performs in-place addition.

The vector is mutated where each element at position `i` is computed as
`self[i] + rhs[i]`.

Args:

- `rhs`: The rhs of the addition operation.

#### `SIMD.__isub__`

```mojo
def __isub__(mut self, rhs: Self)
```

Performs in-place subtraction.

The vector is mutated where each element at position `i` is computed as
`self[i] - rhs[i]`.

Args:

- `rhs`: The rhs of the operation.

#### `SIMD.__imul__`

```mojo
def __imul__(mut self, rhs: Self)
```

Performs in-place multiplication.

The vector is mutated where each element at position `i` is computed as
`self[i] * rhs[i]`.

Args:

- `rhs`: The rhs of the operation.

#### `SIMD.__itruediv__`

```mojo
def __itruediv__(mut self, rhs: Self)
```

In-place true divide operator.

The vector is mutated where each element at position `i` is computed as
`self[i] / rhs[i]`.

Args:

- `rhs`: The rhs of the operation.

#### `SIMD.__ifloordiv__`

```mojo
def __ifloordiv__(mut self, rhs: Self)
```

In-place flood div operator.

The vector is mutated where each element at position `i` is computed as
`self[i] // rhs[i]`.

Args:

- `rhs`: The rhs of the operation.

#### `SIMD.__imod__`

```mojo
def __imod__(mut self, rhs: Self)
```

In-place mod operator.

The vector is mutated where each element at position `i` is computed as
`self[i] % rhs[i]`.

Args:

- `rhs`: The rhs of the operation.

#### `SIMD.__ipow__`

```mojo
def __ipow__(mut self, rhs: Int)
```

In-place pow operator.

The vector is mutated where each element at position `i` is computed as
`pow(self[i], rhs)`.

Args:

- `rhs`: The rhs of the operation.

#### `SIMD.__ilshift__`

```mojo
def __ilshift__(mut self, rhs: Self)
```

Computes `self << rhs` and save the result in `self`.

Constraints: The element type of the SIMD vector must be integral.

Args:

- `rhs`: The RHS value.

#### `SIMD.__irshift__`

```mojo
def __irshift__(mut self, rhs: Self)
```

Computes `self >> rhs` and save the result in `self`.

Constraints: The element type of the SIMD vector must be integral.

Args:

- `rhs`: The RHS value.

#### `SIMD.__iand__`

```mojo
def __iand__(mut self, rhs: Self)
```

Computes `self & rhs` and save the result in `self`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `rhs`: The RHS value.

#### `SIMD.__ixor__`

```mojo
def __ixor__(mut self, rhs: Self)
```

Computes `self ^ rhs` and save the result in `self`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `rhs`: The RHS value.

#### `SIMD.__ior__`

```mojo
def __ior__(mut self, rhs: Self)
```

Computes `self | rhs` and save the result in `self`.

Constraints: The element type of the SIMD vector must be bool or integral.

Args:

- `rhs`: The RHS value.

#### `SIMD.get_type_name`

```mojo
def get_type_name() -> String
```

Gets this type's name, for use in error messages when handing arguments to kernels. TODO: This will go away soon, when we get better error messages for kernel calls.

Returns: This type's name.

#### `SIMD.__divmod__`

```mojo
def __divmod__(self, denominator: Self) -> Tuple[Self, Self]
```

Computes both the quotient and remainder using floor division.

Args:

- `denominator`: The value to divide on.

Returns: The quotient and remainder as a `Tuple(self // denominator, self % denominator)`.

#### `SIMD.eq`

```mojo
def eq(self, rhs: Self) -> SIMD[.bool, length]
```

Compares two SIMD vectors using elementwise equality.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: A new bool SIMD vector of the same size whose element at position `i` is the value of `self[i] == rhs[i]`.

#### `SIMD.ne`

```mojo
def ne(self, rhs: Self) -> SIMD[.bool, length]
```

Compares two SIMD vectors using elementwise inequality.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: A new bool SIMD vector of the same size whose element at position `i` is the value of `self[i] != rhs[i]`.

#### `SIMD.gt`

```mojo
def gt(self, rhs: Self) -> SIMD[.bool, length]
```

Compares two SIMD vectors using elementwise greater-than comparison.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: A new bool SIMD vector of the same size whose element at position `i` is the value of `self[i] > rhs[i]`.

#### `SIMD.ge`

```mojo
def ge(self, rhs: Self) -> SIMD[.bool, length]
```

Compares two SIMD vectors using elementwise greater-than-or-equal comparison.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: A new bool SIMD vector of the same size whose element at position `i` is the value of `self[i] >= rhs[i]`.

#### `SIMD.lt`

```mojo
def lt(self, rhs: Self) -> SIMD[.bool, length]
```

Compares two SIMD vectors using elementwise less-than comparison.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: A new bool SIMD vector of the same size whose element at position `i` is the value of `self[i] < rhs[i]`.

#### `SIMD.le`

```mojo
def le(self, rhs: Self) -> SIMD[.bool, length]
```

Compares two SIMD vectors using elementwise less-than-or-equal comparison.

Args:

- `rhs`: The SIMD vector to compare with.

Returns: A new bool SIMD vector of the same size whose element at position `i` is the value of `self[i] <= rhs[i]`.

#### `SIMD.__len__`

```mojo
def __len__(self) -> Int
```

Gets the length of the SIMD vector.

Returns: The length of the SIMD vector.

```mojo
def __len__() -> Int
```

Get the length (always 1 for scalar types).

Returns: Always returns 1.

#### `SIMD.__int__`

```mojo
def __int__(self) -> Int
```

Casts to the value to an Int. If there is a fractional component, then the fractional part is truncated.

Constraints: The size of the SIMD vector must be 1.

Returns: The value as an integer.

#### `SIMD.__float__`

```mojo
def __float__(self) -> Float64
```

Casts the value to a float.

Constraints: The size of the SIMD vector must be 1.

Returns: The value as a float.

#### `SIMD.__floor__`

```mojo
def __floor__(self) -> Self
```

Performs elementwise floor on the elements of a SIMD vector.

Returns: The elementwise floor of this SIMD vector.

#### `SIMD.__ceil__`

```mojo
def __ceil__(self) -> Self
```

Performs elementwise ceiling on the elements of a SIMD vector.

Returns: The elementwise ceiling of this SIMD vector.

#### `SIMD.__trunc__`

```mojo
def __trunc__(self) -> Self
```

Performs elementwise truncation on the elements of a SIMD vector.

Returns: The elementwise truncated values of this SIMD vector.

#### `SIMD.__abs__`

```mojo
def __abs__(self) -> Self
```

Defines the absolute value operation.

For signed integral element types, the absolute value of the minimum
representable value is the minimum value itself.

Returns: The absolute value of this SIMD vector.

#### `SIMD.__round__`

```mojo
def __round__(self) -> Self
```

Performs elementwise rounding on the elements of a SIMD vector.

This rounding goes to the nearest integer with ties towards the nearest
even value ("banker's rounding"). This is the default rounding mode for
binary floating point in the IEEE 754 Standard for Floating Point
Arithmetic.

Returns: The elementwise rounded value of this SIMD vector.

```mojo
def __round__(self, ndigits: Int) -> Self
```

Performs elementwise rounding on the elements of a SIMD vector.

This rounding goes to the nearest integer with ties towards the nearest
even value ("banker's rounding"). This is the default rounding mode for
binary floating point in the IEEE 754 Standard for Floating Point
Arithmetic.

Args:

- `ndigits`: The number of digits to round to.

Returns: The elementwise rounded value of this SIMD vector.

#### `SIMD.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H)
```

Updates hasher with this SIMD value.

For a floating-point vector, `-0.0` hashes as `0.0`, since the two
compare equal.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `SIMD.__ceildiv__`

```mojo
def __ceildiv__(self, denominator: Self) -> Self
```

Return the rounded-up result of dividing self by denominator.

Args:

- `denominator`: The denominator.

Returns: The ceiling of dividing numerator by denominator.

#### `SIMD.cast`

```mojo
def cast[target: DType](self) -> SIMD[target, length]
```

Casts the elements of the SIMD vector to the target element type.

Casting behavior:

```mojo
# Basic casting preserves value within range
Int8(UInt8(127)) == Int8(127)

# Numbers above signed max wrap to negative using two's complement
Int8(UInt8(128)) == Int8(-128)
Int8(UInt8(129)) == Int8(-127)
Int8(UInt8(256)) == Int8(0)

# Negative signed cast to unsigned using two's complement
UInt8(Int8(-128)) == UInt8(128)
UInt8(Int8(-127)) == UInt8(129)
UInt8(Int8(-1)) == UInt8(255)

# Truncate precision after downcast and upcast
Float64(Float32(Float64(123456789.123456789))) == Float64(123456792.0)

# Rightmost bits of significand become 0's on upcast
Float64(Float32(0.3)) == Float64(0.30000001192092896)

# Numbers equal after truncation of float literal and cast truncation
Float32(Float64(123456789.123456789)) == Float32(123456789.123456789)

# Float to int/uint floors
Int64(Float64(42.2)) == Int64(42)
```

Parameters:

- `target`: The target DType.

Returns: A new SIMD vector whose elements have been cast to the target element type.

#### `SIMD.is_power_of_two`

```mojo
def is_power_of_two(self) -> SIMD[.bool, length]
```

Checks if the input value is a power of 2 for each element of a SIMD vector.

Constraints: The element type of the input vector must be integral.

Returns: A SIMD value where the element at position `i` is True if the integer at position `i` of the input value is a power of 2, False otherwise.

#### `SIMD.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this SIMD value to the provided Writer.

Args:

- `writer`: The object to write to.

#### `SIMD.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the string representation of the SIMD value.

Args:

- `writer`: The value to write to.

#### `SIMD.write_padded`

```mojo
def write_padded[W: Writer](self, mut writer: W, width: Int) where dtype.is_integral()
```

Write the integral SIMD with each element right-aligned to a set padding. No additional space between elements is inserted.

Parameters:

- `W`: A type conforming to the Writable trait.

Args:

- `writer`: The object to write to.
- `width`: The amount to pad to the left.

#### `SIMD.to_bits`

```mojo
def to_bits[_dtype: DType = _uint_type_of_width[bit_width_of[dtype]()]()](self) -> SIMD[_dtype, length]
```

Bitcasts the SIMD vector to an integer SIMD vector.

Parameters:

- `_dtype`: The integer type to cast to.

Returns: An integer representation of the floating-point value.

#### `SIMD.from_bytes`

```mojo
def from_bytes[*, endian: Endian = Endian.native()](bytes: Array[UInt8]) -> Self
```

Converts a byte array to a vector.

Example:

```mojo
var port = UInt16.from_bytes[endian=.big]([0x1F, 0x90])  # 8080
```

Parameters:

- `endian`: The byte order of `bytes`.

Args:

- `bytes`: The byte array to convert.

Returns: The vector stored in `bytes`.

#### `SIMD.as_bytes`

```mojo
def as_bytes[*, endian: Endian = Endian.native()](self, out result: Array[UInt8, size_of[Self]()])
```

Converts the vector to a byte array.

Example:

```mojo
var bytes = UInt16(8080).as_bytes[endian=.big]()  # [0x1F, 0x90]
```

Parameters:

- `endian`: The byte order of the returned bytes.

Returns: The vector's bytes, in `endian` byte order.

#### `SIMD.to_endian`

```mojo
def to_endian[endian: Endian](self) -> Self
```

Returns the value whose in-memory bytes are `self` encoded in `endian` byte order.

Examples:

```mojo
var wire = UInt16(8080).to_endian[.big]()
print(wire.as_bytes())  # [31, 144], that is [0x1F, 0x90]
```

Constraints: The element type must be integral.

Parameters:

- `endian`: The byte order to encode in.

Returns: The value whose bytes in memory are `self` in `endian` order.

#### `SIMD.from_endian`

```mojo
def from_endian[endian: Endian](value) -> Self
```

Returns the value encoded in `endian` byte order by the in-memory bytes of `value`.

The inverse of `to_endian()`: each element's bytes are reversed when
`endian` differs from the target's byte order and left unchanged
otherwise.

Examples:

```mojo
var wire = UInt16.from_bytes([0x1F, 0x90])  # big-endian 8080
print(UInt16.from_endian[.big](wire))  # 8080
```

Constraints: The element type must be integral.

Parameters:

- `endian`: The byte order `value` is encoded in.

Args:

- `value`: A value whose bytes in memory hold an `endian` encoding.

Returns: The decoded value.

#### `SIMD.clamp`

```mojo
def clamp(self, lower_bound: Self, upper_bound: Self) -> Self
```

Clamps the values in a SIMD vector to be in a certain range.

Clamp cuts values in the input SIMD vector off at the upper bound and
lower bound values. For example,  SIMD vector `[0, 1, 2, 3]` clamped to
a lower bound of 1 and an upper bound of 2 would return `[1, 1, 2, 2]`.

Args:

- `lower_bound`: Minimum of the range to clamp to.
- `upper_bound`: Maximum of the range to clamp to.

Returns: A new SIMD vector containing x clamped to be within lower_bound and upper_bound.

#### `SIMD.fma`

```mojo
def fma[flag: FastMathFlag = FastMathFlag.CONTRACT](self, multiplier: Self, accumulator: Self) -> Self
```

Performs a fused multiply-add operation, i.e. `self*multiplier + accumulator`.

Parameters:

- `flag`: Fast-math optimization flags to apply (default: CONTRACT).

Args:

- `multiplier`: The value to multiply.
- `accumulator`: The value to accumulate.

Returns: A new vector whose element at position `i` is computed as `self[i]*multiplier[i] + accumulator[i]`.

#### `SIMD.shuffle`

```mojo
def shuffle[*mask: SIMDLength](self) -> Self
```

Shuffles (also called blend) the values of the current vector with the `other` value using the specified mask (permutation). The mask values must be within `2 * len(self)`.

Parameters:

- `*mask`: The permutation to use in the shuffle.

Returns: A new vector with the same length as the mask where the value at position `i` is `(self)[permutation[i]]`.

```mojo
def shuffle[*mask: SIMDLength](self, other: Self) -> Self
```

Shuffles (also called blend) the values of the current vector with the `other` value using the specified mask (permutation). The mask values must be within `2 * len(self)`.

Parameters:

- `*mask`: The permutation to use in the shuffle.

Args:

- `other`: The other vector to shuffle with.

Returns: A new vector with the same length as the mask where the value at position `i` is `(self + other)[permutation[i]]`.

```mojo
def shuffle[mask: IndexList[length, element_type=mask.element_type]](self) -> Self
```

Shuffles (also called blend) the values of the current vector with the `other` value using the specified mask (permutation). The mask values must be within `2 * len(self)`.

Parameters:

- `mask`: The permutation to use in the shuffle.

Returns: A new vector with the same length as the mask where the value at position `i` is `(self)[permutation[i]]`.

```mojo
def shuffle[mask: IndexList[length, element_type=mask.element_type]](self, other: Self) -> Self
```

Shuffles (also called blend) the values of the current vector with the `other` value using the specified mask (permutation). The mask values must be within `2 * len(self)`.

Parameters:

- `mask`: The permutation to use in the shuffle.

Args:

- `other`: The other vector to shuffle with.

Returns: A new vector with the same length as the mask where the value at position `i` is `(self + other)[permutation[i]]`.

#### `SIMD.slice`

```mojo
def slice[output_width: Int, /, *, offset: Int = Int(0)](self) -> SIMD[dtype, output_width]
```

Returns a slice of the vector of the specified width with the given offset.

Constraints: `output_width + offset` must not exceed the size of this SIMD
vector.

Parameters:

- `output_width`: The output SIMD vector size.
- `offset`: The given offset for the slice.

Returns: A new vector whose elements map to `self[offset:offset+output_width]`.

#### `SIMD.insert`

```mojo
def insert[*, offset: Int = Int(0)](self, value: SIMD[dtype]) -> Self
```

Returns a new vector where the elements between `offset` and `offset + input_width` have been replaced with the elements in `value`.

Parameters:

- `offset`: The offset to insert at. This must be a multiple of value's size.

Args:

- `value`: The value to be inserted.

Returns: A new vector whose elements at `self[offset:offset+input_width]` contain the values of `value`.

#### `SIMD.join`

```mojo
def join(self, other: Self) -> SIMD[dtype, (Int(2) * SIMD(length))]
```

Concatenates the two vectors together.

Args:

- `other`: The other SIMD vector.

Returns: A new vector `self_0, self_1, ..., self_n, other_0, ..., other_n`.

#### `SIMD.interleave`

```mojo
def interleave(self, other: Self) -> SIMD[dtype, (SIMD(length) * Int(2))]
```

Constructs a vector by interleaving two input vectors.

Args:

- `other`: The other SIMD vector.

Returns: A new vector `self_0, other_0, ..., self_n, other_n`.

#### `SIMD.split`

```mojo
def split(self) -> Tuple[SIMD[dtype, Int(2).__rfloordiv__(SIMD(length))], SIMD[dtype, Int(2).__rfloordiv__(SIMD(length))]]
```

Splits the SIMD vector into 2 subvectors.

Returns: A new vector `self_0:N/2, self_N/2:N`.

#### `SIMD.deinterleave`

```mojo
def deinterleave(self) -> Tuple[SIMD[dtype, (length / 2)], SIMD[dtype, (length / 2)]]
```

Constructs two vectors by deinterleaving the even and odd lanes of the vector.

Constraints: The vector size must be greater than 1.

Returns: Two vectors the first of the form `self_0, self_2, ..., self_{n-2}` and the other being `self_1, self_3, ..., self_{n-1}`.

#### `SIMD.reduce`

```mojo
def reduce[func: def[width: Int](SIMD[dtype, width], SIMD[dtype, width]) thin -> SIMD[dtype, width], size_out: Int = Int(1)](self) -> SIMD[dtype, size_out]
```

Reduces the vector using a provided reduce operator.

Constraints: `size_out` must not exceed width of the vector.

Parameters:

- `func`: The reduce function to apply to elements in this SIMD.
- `size_out`: The width of the reduction.

Returns: A new scalar which is the reduction of all vector elements.

```mojo
def reduce[FuncType: def[width: SIMDLength](SIMD[dtype, width], SIMD[dtype, width]) -> SIMD[dtype, width] & RegisterPassable & ImplicitlyCopyable, //, size_out: Int = Int(1)](self, func: FuncType) -> SIMD[dtype, size_out]
```

Reduces the vector using a provided reduce closure.

Example:

```mojo
def add[width: SIMDLength](
    lhs: SIMD[DType.int32, width], rhs: SIMD[DType.int32, width]
) -> SIMD[DType.int32, width]:
    return lhs + rhs

var total = SIMD[DType.int32, 4](1, 2, 3, 4).reduce(add)  # 10
```

Constraints: `size_out` must not exceed width of the vector.

Parameters:

- `FuncType`: The type of the reduce closure.
- `size_out`: The width of the reduction.

Args:

- `func`: The reduce function to apply to elements in this SIMD.

Returns: A new scalar which is the reduction of all vector elements.

#### `SIMD.reduce_max`

```mojo
def reduce_max[size_out: Int = Int(1)](self) -> SIMD[dtype, size_out]
```

Reduces the vector using the `max` operator.

Constraints: `size_out` must not exceed width of the vector.
The element type of the vector must be integer or FP.

Parameters:

- `size_out`: The width of the reduction.

Returns: The maximum element of the vector.

#### `SIMD.reduce_min`

```mojo
def reduce_min[size_out: Int = Int(1)](self) -> SIMD[dtype, size_out]
```

Reduces the vector using the `min` operator.

Constraints: `size_out` must not exceed width of the vector.
The element type of the vector must be integer or FP.

Parameters:

- `size_out`: The width of the reduction.

Returns: The minimum element of the vector.

#### `SIMD.reduce_add`

```mojo
def reduce_add[size_out: Int = Int(1)](self) -> SIMD[dtype, size_out]
```

Reduces the vector using the `add` operator.

Constraints: `size_out` must not exceed width of the vector.

Parameters:

- `size_out`: The width of the reduction.

Returns: The sum of all vector elements.

#### `SIMD.reduce_mul`

```mojo
def reduce_mul[size_out: Int = Int(1)](self) -> SIMD[dtype, size_out]
```

Reduces the vector using the `mul` operator.

Constraints: `size_out` must not exceed width of the vector.
The element type of the vector must be integer or FP.

Parameters:

- `size_out`: The width of the reduction.

Returns: The product of all vector elements.

#### `SIMD.reduce_and`

```mojo
def reduce_and[size_out: Int = Int(1)](self) -> SIMD[dtype, size_out]
```

Reduces the vector using the bitwise `&` operator.

Constraints: `size_out` must not exceed width of the vector.
The element type of the vector must be integer or boolean.

Parameters:

- `size_out`: The width of the reduction.

Returns: The reduced vector.

#### `SIMD.reduce_or`

```mojo
def reduce_or[size_out: Int = Int(1)](self) -> SIMD[dtype, size_out]
```

Reduces the vector using the bitwise `|` operator.

Constraints: `size_out` must not exceed width of the vector.
The element type of the vector must be integer or boolean.

Parameters:

- `size_out`: The width of the reduction.

Returns: The reduced vector.

#### `SIMD.reduce_bit_count`

```mojo
def reduce_bit_count(self) -> Int
```

Returns the total number of bits set in the SIMD vector.

Constraints: Must be either an integral or a boolean type.

Returns: Count of set bits across all elements of the vector.

#### `SIMD.select`

```mojo
def select[_dtype: DType](self, true_case: SIMD[_dtype, length], false_case: SIMD[_dtype, length]) -> SIMD[_dtype, length]
```

Selects the values of the `true_case` or the `false_case` based on the current boolean values of the SIMD vector.

Constraints: The element type of the vector must be boolean.

Parameters:

- `_dtype`: The element type of the input and output SIMD vectors.

Args:

- `true_case`: The values selected if the positional value is True.
- `false_case`: The values selected if the positional value is False.

Returns: A new vector of the form `[true_case[i] if elem else false_case[i] for i, elem in enumerate(self)]`.

#### `SIMD.rotate_left`

```mojo
def rotate_left[shift: Int](self) -> Self
```

Shifts the elements of a SIMD vector to the left by `shift` elements (with wrap-around).

Constraints: `-length <= shift < length`

Parameters:

- `shift`: The number of positions by which to rotate the elements of SIMD vector to the left (with wrap-around).

Returns: The SIMD vector rotated to the left by `shift` elements (with wrap-around).

#### `SIMD.rotate_right`

```mojo
def rotate_right[shift: Int](self) -> Self
```

Shifts the elements of a SIMD vector to the right by `shift` elements (with wrap-around).

Constraints: `-length < shift <= length`

Parameters:

- `shift`: The number of positions by which to rotate the elements of SIMD vector to the right (with wrap-around).

Returns: The SIMD vector rotated to the right by `shift` elements (with wrap-around).

#### `SIMD.shift_left`

```mojo
def shift_left[shift: Int](self) -> Self
```

Shifts the elements of a SIMD vector to the left by `shift` elements (no wrap-around, fill with zero).

Constraints: `0 <= shift <= length`

Parameters:

- `shift`: The number of positions by which to rotate the elements of SIMD vector to the left (no wrap-around, fill with zero).

Returns: The SIMD vector rotated to the left by `shift` elements (no wrap-around, fill with zero).

#### `SIMD.shift_right`

```mojo
def shift_right[shift: Int](self) -> Self
```

Shifts the elements of a SIMD vector to the right by `shift` elements (no wrap-around, fill with zero).

Constraints: `0 <= shift <= length`

Parameters:

- `shift`: The number of positions by which to rotate the elements of SIMD vector to the right (no wrap-around, fill with zero).

Returns: The SIMD vector rotated to the right by `shift` elements (no wrap-around, fill with zero).

#### `SIMD.reversed`

```mojo
def reversed(self) -> Self
```

Reverses the SIMD vector by indexes.

Examples:
```mojo
print(SIMD[.uint8, 4](1, 2, 3, 4).reversed()) # [4, 3, 2, 1]
```

Returns: The by index reversed vector.

#### `SIMD.product`

```mojo
def product(self) -> Scalar[dtype]
```

Calculate the product (returns the value for scalar types).

Returns: The integer value.

#### `SIMD.sum`

```mojo
def sum(self) -> Scalar[dtype]
```

Calculate the sum (returns the value for scalar types).

Returns: The integer value.

#### `SIMD.value`

```mojo
def value(self) -> Scalar[dtype]
```

Get the scalar value.

Returns: The runtime integer value.

#### `SIMD.tuple`

```mojo
def tuple(var self) -> Coord[Self]
```

Get as a tuple (not valid for `Scalar` CoordLike).

Returns: Never returns; aborts at compile time.

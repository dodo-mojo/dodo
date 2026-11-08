# `std.utils.fast_div`

Implements the fast division algorithm.

This method replaces division by constants with a sequence of shifts and
multiplications, significantly optimizing division performance.

## Structs

### `FastDiv`

```mojo
struct FastDiv[dtype: DType]
```

Implements fast division for a given type.

This struct provides optimized division by a constant divisor,
replacing the division operation with a series of shifts and
multiplications. This approach significantly improves performance,
especially in scenarios where division is a frequent operation.

Parameters:

- `dtype`: The data type for the division operation.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `uint_type = _uint_type_of_width[bit_width_of[dtype]()]()`: The unsigned integer type used for the fast division algorithm.

#### `FastDiv.__init__`

```mojo
def __init__(divisor: Int = Int(1)) -> Self
```

Initializes FastDiv with the divisor.

Constraints: ConstraintError: If the bitwidth of the type is > 64.

Args:

- `divisor`: The divisor to use for fast division. Defaults to 1.

#### `FastDiv.__rtruediv__`

```mojo
def __rtruediv__(self, other: Scalar[Self.uint_type]) -> Scalar[Self.uint_type]
```

Divides the other scalar by the divisor (true division).

Uses the fast division algorithm, with optimized path for power-of-2 divisors.

Args:

- `other`: The dividend.

Returns: The result of the division.

#### `FastDiv.__rmod__`

```mojo
def __rmod__(self, other: Scalar[Self.uint_type]) -> Scalar[Self.uint_type]
```

Computes the remainder of division.

Args:

- `other`: The dividend.

Returns: The remainder.

#### `FastDiv.__rdiv__`

```mojo
def __rdiv__(self, other: Scalar[Self.uint_type]) -> Scalar[Self.uint_type]
```

Divides the other scalar by the divisor.

Args:

- `other`: The dividend.

Returns: The result of the division.

#### `FastDiv.__divmod__`

```mojo
def __divmod__(self, other: Scalar[Self.uint_type]) -> Tuple[Scalar[Self.uint_type], Scalar[Self.uint_type]]
```

Computes both quotient and remainder.

Args:

- `other`: The dividend.

Returns: A tuple containing the quotient and remainder.

#### `FastDiv.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Writes the FastDiv parameters to a writer.

Parameters:

- `W`: The type of the writer.

Args:

- `writer`: The writer to which the parameters are written.

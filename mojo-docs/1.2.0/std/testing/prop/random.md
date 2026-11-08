# `std.testing.prop.random`

Implements random number generation for property-based testing.

## Structs

### `Rng`

```mojo
struct Rng
```

A seeded pseudo-random number generator.

Users should not need to create this type directly, instead use the `Rng`
value provided by the `Strategy` trait.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Rng.rand_bool`

```mojo
def rand_bool(mut self, *, true_probability: Float64 = 0.5) raises -> Bool
```

Returns a random `Bool` with the given probability of being True.

Args:

- `true_probability`: The probability of being `True` (between 0.0 and 1.0).

Returns: A random `Bool`.

Raises: If the underlying random number generator raises an error.

#### `Rng.rand_scalar`

```mojo
def rand_scalar[dtype: DType](mut self, *, min: Scalar[dtype] = Scalar[dtype].MIN_FINITE, max: Scalar[dtype] = Scalar[dtype].MAX_FINITE) raises -> Scalar[dtype]
```

Returns a random `Scalar` from the given range.

Parameters:

- `dtype`: The `DType` of the scalar.

Args:

- `min`: The minimum value.
- `max`: The maximum value.

Returns: A random number in the range [min, max].

Raises: If the minimum value is greater than the maximum value or if the underlying random number generator raises an error.

#### `Rng.rand_uint`

```mojo
def rand_uint(mut self, *, min: UInt = UInt.MIN, max: UInt = UInt.MAX) raises -> UInt
```

Returns a random `UInt` from the given range.

Args:

- `min`: The minimum value.
- `max`: The maximum value.

Returns: A random `UInt` in the range [min, max].

Raises: If the underlying random number generator raises an error.

#### `Rng.rand_int`

```mojo
def rand_int(mut self, *, min: Int = Int.MIN, max: Int = Int.MAX) raises -> Int
```

Returns a random `Int` from the given range.

Args:

- `min`: The minimum value.
- `max`: The maximum value.

Returns: A random `Int` in the range [min, max].

Raises: If the underlying random number generator raises an error.

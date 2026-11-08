# `std.random.philox`

Random number generation using the Philox algorithm.

This module implements a high-performance random number generator using the Philox algorithm,
which is designed for parallel computing and works efficiently on both CPU and GPU. The Philox
algorithm is a counter-based random number generator that provides high-quality random numbers
with excellent statistical properties.

The main class is Random which generates both uniform random numbers and raw 32-bit integers.
It supports:
- Seeding for reproducible sequences
- Multiple independent subsequences
- Configurable number of rounds for quality vs performance tradeoff
- Vectorized operations for efficiency
- Cross-platform support (CPU and GPU)

Example:

```mojo
from std.random.philox import Random
    rng = Random(seed=42)
    uniform_values = rng.step_uniform()  # Returns 4 random floats in [0,1)
    raw_values = rng.step()  # Returns 4 raw 32-bit integers
```

## Structs

### `Random`

```mojo
struct Random[rounds: Int = Int(10)]
```

A high-performance random number generator using the Philox algorithm.

The Philox algorithm is a counter-based random number generator designed for parallel
computing. It provides high-quality random numbers with excellent statistical properties
and works efficiently on both CPU and GPU.

Parameters:

- `rounds`: Number of mixing rounds to perform. Higher values provide better statistical quality at the cost of performance. Default is 10.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Random.__init__`

```mojo
def __init__(out self, *, seed: UInt64 = UInt64(67280421310721), subsequence: UInt64 = UInt64(0), offset: UInt64 = UInt64(0))
```

Initialize the random number generator.

Args:

- `seed`: Initial seed value for reproducible sequences. Default is 0.
- `subsequence`: Subsequence number for generating independent streams. Default is 0.
- `offset`: Starting offset in the sequence. Default is 0.

#### `Random.step`

```mojo
def step(mut self) -> SIMD[.uint32, 4]
```

Generate 4 random 32-bit unsigned integers.

Returns: SIMD vector containing 4 random 32-bit unsigned integers.

#### `Random.step_uniform`

```mojo
def step_uniform(mut self) -> SIMD[.float32, 4]
```

Generate 4 random floating point numbers uniformly distributed in [0,1).

Returns: SIMD vector containing 4 random float32 values in range [0,1).

#### `Random.step_uniform_unbiased`

```mojo
def step_uniform_unbiased(mut self) -> SIMD[.float32, 4]
```

Generate 4 uniform float32 values in (0, 1), unbiased.

Uses all 32 raw bits of each Philox output via the conversion
`u = (raw + 0.5) / 2^32`, which is fused into a single FMA. The
resulting range is `(2^-33, 1 - 2^-33)` — never exactly 0 or 1.
Compared to `step_uniform`, this uses one extra bit of randomness
and is bounded away from 0, which removes the need for a `1.0 - u`
guard before `log(u)` in Box-Muller transforms.

Returns: SIMD vector containing 4 random float32 values in (0, 1).

### `NormalRandom`

```mojo
struct NormalRandom[rounds: Int = Int(10)]
```

A high-performance random number generator using the Box-Muller transform.

The Box-Muller transform is a method for generating pairs of independent standard normal
random variables. Works efficiently on both CPU and GPU.

Parameters:

- `rounds`: Number of mixing rounds to perform for the underlying random uniform generator that serves as input to the Box-Muller transform. Higher values provide better statistical quality at the cost of performance. Default is 10.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `NormalRandom.__init__`

```mojo
def __init__(out self, *, seed: UInt64 = UInt64(67280421310721), subsequence: UInt64 = UInt64(0), offset: UInt64 = UInt64(0))
```

Initializes the normal distribution random number generator.

Args:

- `seed`: Seed value for the RNG.
- `subsequence`: Subsequence number for the RNG.
- `offset`: Offset value for the RNG.

#### `NormalRandom.step_normal`

```mojo
def step_normal(mut self, mean: Float32 = 0, stddev: Float32 = 1) -> SIMD[.float32, 8]
```

Generate 8 normally distributed random numbers using Box-Muller transform.

Args:

- `mean`: Mean of the normal distribution.
- `stddev`: Standard deviation of the normal distribution.

Returns: SIMD vector containing 8 random float32 values from a normal distribution with mean `mean` and standard deviation `stddev`.

#### `NormalRandom.step_normal_4`

```mojo
def step_normal_4(mut self, mean: Float32 = 0, stddev: Float32 = 1) -> SIMD[.float32, 4]
```

Generate 4 normal floats from a single Philox step.

Pairs adjacent uint32 outputs `(raw[0], raw[1])` and
`(raw[2], raw[3])` into Box-Muller pairs (one Philox step total,
vs two for `step_normal`). Uses the unbiased
`(raw + 0.5) / 2^32` uniform conversion, which is bounded away
from 0 — no `1.0 - u` guard before `log(u)` is needed.

Result lane order: `(sin(v_0)*s_0, cos(v_0)*s_0, sin(v_1)*s_1,
cos(v_1)*s_1)` — sin/cos interleaved per pair, matching the
natural output of a single Box-Muller call.

Args:

- `mean`: Mean of the normal distribution.
- `stddev`: Standard deviation of the normal distribution.

Returns: SIMD vector of 4 normal float32 values.

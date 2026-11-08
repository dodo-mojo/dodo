# `std.random.random`

Provides functions for pseudorandom numbers.

You can import these APIs from the `random` package. For example:

```mojo
from std.random import seed
```

These functions use a shared, global pseudorandom number generator (PRNG)
state. The global random state is shared across threads and concurrent
access can cause race conditions and undefined behavior.

Warning:
    NOT cryptographically secure. This PRNG is suitable for simulations,
    games, and general statistical purposes, but shouldn't be used for
    security-sensitive applications such as generating passwords,
    authentication tokens, or encryption keys.

## Functions

### `seed`

```mojo
def seed()
```

Seeds the random number generator using a time-based value.

Example:

```mojo
from std.random import seed

seed()
```

```mojo
def seed(a: Int)
```

Seeds the random number generator using the value provided.

Example:

```mojo
from std.random import seed

seed(123456)
```

Args:

- `a`: The seed value to initialize the PRNG state.

### `random_float64`

```mojo
def random_float64(min: Float64 = Float64("0"), max: Float64 = Float64("1")) -> Float64
```

Returns a random `Float64` number from the given range [min, max).

Example:
```mojo
from std.random import random_float64, seed

seed()
var rnd = random_float64(10.0, 20.0)
print(rnd)  # Random float between 10.0 and 20.0
```

Args:

- `min`: The minimum number in the range (inclusive, default is 0.0).
- `max`: The maximum number in the range (exclusive, default is 1.0).

Returns: A random number sampled uniformly from [min, max).

### `random_si64`

```mojo
def random_si64(min: Int64, max: Int64) -> Int64
```

Returns a random `Int64` number from the given range [min, max].

Example:

```mojo
from std.random import random_si64, seed

seed()
var rnd = random_si64(-100, 100)
print(rnd)  # Random Int64 between -100 and 100
```

Args:

- `min`: The minimum number in the range (inclusive).
- `max`: The maximum number in the range (inclusive).

Returns: A random integer sampled uniformly from [min, max].

### `random_ui64`

```mojo
def random_ui64(min: UInt64, max: UInt64) -> UInt64
```

Returns a random `UInt64` number from the given range [min, max].

Example:

```mojo
from std.random import random_ui64, seed

seed()
var rnd = random_ui64(0, 100)
print(rnd)  # Random UInt64 between 0 and 100
```

Args:

- `min`: The minimum number in the range (inclusive).
- `max`: The maximum number in the range (inclusive).

Returns: A random unsigned integer sampled uniformly from [min, max].

### `randint`

```mojo
def randint[dtype: DType](span: Span[Scalar[dtype]], low: Int, high: Int) where dtype.is_integral()
```

Fills memory with uniformly distributed random integers in the range [low, high].

Constraints: The type must be integral.

Parameters:

- `dtype`: The dtype of the pointer.

Args:

- `span`: The memory area to fill.
- `low`: The inclusive lower bound.
- `high`: The inclusive upper bound.

```mojo
def randint[dtype: DType](ptr: Pointer[Scalar[dtype]], size: Int, low: Int, high: Int) where dtype.is_integral()
```

Fills memory with uniformly distributed random integers in the range [low, high].

Example:

```mojo
from std.random import randint, seed
seed()
var size: Int = 10
var data = List(length=size, fill=Int32(0))
randint(data, -50, 50)
for i in range(size):
    print(data[i])  # Random Int32 between -50 and 50
```

Constraints: The type must be integral.

Parameters:

- `dtype`: The dtype of the pointer.

Args:

- `ptr`: The pointer to the memory area to fill.
- `size`: The number of elements to fill.
- `low`: The inclusive lower bound.
- `high`: The inclusive upper bound.

### `rand`

```mojo
def rand[dtype: DType](span: Span[Scalar[dtype]], /, *, min: Float64 = 0, max: Float64 = 1, int_scale: Optional[Int] = None)
```

Fills memory with random values from a uniform distribution.

Behavior depends on the dtype:
- Floating-point types sample values uniformly from [min, max).
- Integral types sample values uniformly from [min, max],
clamped to the representable range of the dtype.

Parameters:

- `dtype`: The dtype of the pointer.

Args:

- `span`: The memory area to fill.
- `min`: The lower bound of the range.
- `max`: The upper bound of the range.
- `int_scale`: Optional quantization scale for floating-point types. When provided, values are quantized to increments of 2^(-int_scale).

```mojo
def rand[dtype: DType](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space], size: Int, /, *, min: Float64 = 0, max: Float64 = 1, int_scale: Optional[Int] = None)
```

Fills memory with random values from a uniform distribution.

Behavior depends on the dtype:
- Floating-point types sample values uniformly from [min, max).
- Integral types sample values uniformly from [min, max],
  clamped to the representable range of the dtype.

Example:

```mojo
from std.random import rand, seed

seed()
var size: Int = 10
var data = List(length=size, fill=Float32(0))
rand(data, min=0.0, max=1.0, int_scale=16)
for i in range(size):
    print(data[i])  # Random Float32 between 0.0 and 1.0
```

Parameters:

- `dtype`: The dtype of the pointer.

Args:

- `ptr`: The pointer to the memory area to fill.
- `size`: The number of elements to fill.
- `min`: The lower bound of the range.
- `max`: The upper bound of the range.
- `int_scale`: Optional quantization scale for floating-point types. When provided, values are quantized to increments of 2^(-int_scale).

### `randn_float64`

```mojo
def randn_float64(mean: Float64 = 0, standard_deviation: Float64 = 1) -> Float64
```

Returns a random `Float64` sampled from a normal distribution.

Example:

```mojo
from std.random import randn_float64, seed
seed()
var rnd = randn_float64(0.0, 1.0)
print(rnd)  # Random Float64 from Normal(0.0, 1.0)
```

Args:

- `mean`: The mean of the distribution.
- `standard_deviation`: The standard deviation of the distribution.

Returns: A random `Float64` sampled from Normal(mean, standard_deviation).

### `randn`

```mojo
def randn[dtype: DType](span: Span[Scalar[dtype]], mean: Float64 = 0, standard_deviation: Float64 = 1)
```

Fills memory with random values from a Normal distribution.

Constraints: The type should be floating point.

Parameters:

- `dtype`: The dtype of the pointer.

Args:

- `span`: The memory area to fill.
- `mean`: The mean of the normal distribution.
- `standard_deviation`: The standard deviation of the normal distribution.

```mojo
def randn[dtype: DType](ptr: Pointer[Scalar[dtype], address_space=ptr.address_space], size: Int, mean: Float64 = 0, standard_deviation: Float64 = 1)
```

Fills memory with random values from a Normal distribution.

Example:

```mojo
from std.random import randn, seed

seed()
var size: Int = 10
var data = List(length=size, fill=Float64(0))
randn(data, mean=0.0, standard_deviation=1.0)
for i in range(size):
    print(data[i])  # Random Float64 from Normal(0.0, 1.0)
```

Constraints: The type should be floating point.

Parameters:

- `dtype`: The dtype of the pointer.

Args:

- `ptr`: The pointer to the memory area to fill.
- `size`: The number of elements to fill.
- `mean`: The mean of the normal distribution.
- `standard_deviation`: The standard deviation of the normal distribution.

### `shuffle`

```mojo
def shuffle[T: Copyable, //](mut list: List[T])
```

Shuffles the elements of the list randomly.

Performs an in-place Fisher-Yates shuffle on the provided list.

Example:

```mojo
from std.random import shuffle
var list: List[Int] = [0, 1, 2, 3, 4, 5]
shuffle(list)
print(list)  # The list elements are now in random order
# There is a very small chance that the shuffled list is
# the same as the original
```

Parameters:

- `T`: The type of element in the List.

Args:

- `list`: The list to modify.

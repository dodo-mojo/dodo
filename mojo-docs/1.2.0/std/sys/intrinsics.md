# `std.sys.intrinsics`

Defines intrinsics.

You can import these APIs from the `sys` package. For example:

```mojo
from std.sys import PrefetchLocality
```

## Structs

### `PrefetchLocality`

```mojo
struct PrefetchLocality
```

The prefetch locality.

The locality, rw, and cache type correspond to LLVM prefetch intrinsic's
inputs (see
[LLVM prefetch locality](https://llvm.org/docs/LangRef.html#llvm-prefetch-intrinsic))

Fields:

- `value` (`Int32`): The prefetch locality to use. It should be a value in [0, 3].

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `NONE = PrefetchLocality(Int(0))`: No locality.
- `LOW = PrefetchLocality(Int(1))`: Low locality.
- `MEDIUM = PrefetchLocality(Int(2))`: Medium locality.
- `HIGH = PrefetchLocality(Int(3))`: Extremely local locality (keep in cache).

#### `PrefetchLocality.__init__`

```mojo
def __init__(value: Int) -> Self
```

Constructs a prefetch locality option.

Args:

- `value`: An integer value representing the locality. Should be a value in the range `[0, 3]`.

### `PrefetchRW`

```mojo
struct PrefetchRW
```

Prefetch read or write.

Fields:

- `value` (`Int32`): The read-write prefetch. It should be in [0, 1].

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `READ = PrefetchRW(Int(0))`: Read prefetch.
- `WRITE = PrefetchRW(Int(1))`: Write prefetch.

#### `PrefetchRW.__init__`

```mojo
def __init__(value: Int) -> Self
```

Constructs a prefetch read-write option.

Args:

- `value`: An integer value representing the prefetch read-write option to be used. Should be a value in the range `[0, 1]`.

#### `PrefetchRW.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Checks if two prefetch read-write options are equal.

Args:

- `other`: The option to compare with.

Returns: True if the two prefetch read-write options are equal and False otherwise.

### `PrefetchCache`

```mojo
struct PrefetchCache
```

Prefetch cache type.

Fields:

- `value` (`Int32`): The cache prefetch. It should be in [0, 1].

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `INSTRUCTION = PrefetchCache(Int(0))`: The instruction prefetching option.
- `DATA = PrefetchCache(Int(1))`: The data prefetching option.

#### `PrefetchCache.__init__`

```mojo
def __init__(value: Int) -> Self
```

Constructs a prefetch option.

Args:

- `value`: An integer value representing the prefetch cache option to be used. Should be a value in the range `[0, 1]`.

### `PrefetchOptions`

```mojo
struct PrefetchOptions
```

Collection of configuration parameters for a prefetch intrinsic call.

The op configuration follows similar interface as LLVM intrinsic prefetch
op, with a "locality" attribute that specifies the level of temporal locality
in the application, that is, how soon would the same data be visited again.
Possible locality values are: `NONE`, `LOW`, `MEDIUM`, and `HIGH`.

The op also takes a "cache tag" attribute giving hints on how the
prefetched data will be used. Possible tags are: `ReadICache`, `ReadDCache`
and `WriteDCache`.

Note: the actual behavior of the prefetch op and concrete interpretation of
these attributes are target-dependent.

Fields:

- `rw` (`PrefetchRW`): Indicates prefetching for read or write.
- `locality` (`PrefetchLocality`): Indicates locality level.
- `cache` (`PrefetchCache`): Indicates i-cache or d-cache prefetching.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

#### `PrefetchOptions.__init__`

```mojo
def __init__() -> Self
```

Constructs an instance of PrefetchOptions with default params.

#### `PrefetchOptions.for_read`

```mojo
def for_read(self) -> Self
```

Sets the prefetch purpose to read.

Returns: The updated prefetch parameter.

#### `PrefetchOptions.for_write`

```mojo
def for_write(self) -> Self
```

Sets the prefetch purpose to write.

Returns: The updated prefetch parameter.

#### `PrefetchOptions.no_locality`

```mojo
def no_locality(self) -> Self
```

Sets the prefetch locality to none.

Returns: The updated prefetch parameter.

#### `PrefetchOptions.low_locality`

```mojo
def low_locality(self) -> Self
```

Sets the prefetch locality to low.

Returns: The updated prefetch parameter.

#### `PrefetchOptions.medium_locality`

```mojo
def medium_locality(self) -> Self
```

Sets the prefetch locality to medium.

Returns: The updated prefetch parameter.

#### `PrefetchOptions.high_locality`

```mojo
def high_locality(self) -> Self
```

Sets the prefetch locality to high.

Returns: The updated prefetch parameter.

#### `PrefetchOptions.to_data_cache`

```mojo
def to_data_cache(self) -> Self
```

Sets the prefetch target to data cache.

Returns: The updated prefetch parameter.

#### `PrefetchOptions.to_instruction_cache`

```mojo
def to_instruction_cache(self) -> Self
```

Sets the prefetch target to instruction cache.

Returns: The updated prefetch parameter.

## Functions

### `llvm_intrinsic`

```mojo
def llvm_intrinsic[intrin: StringSpan[ImmStaticOrigin], type: TrivialRegisterPassable, *types: AnyType, *, has_side_effect: Bool = True](*args: *types.values) -> type
```

Calls an LLVM intrinsic with the name `intrin` and return type `type`.

Parameters:

- `intrin`: The name of the llvm intrinsic.
- `type`: The return type of the intrinsic.
- `*types`: The argument types for the function.
- `has_side_effect`: If `True` the intrinsic will have side effects, otherwise its pure.

Args:

- `*args`: The arguments to the function.

Returns: The result of calling the llvm intrinsic with no arguments.

### `gather`

```mojo
def gather[dtype: DType, size: SIMDLength, //, *, invariant: Bool = False, alignment: Int = Int(0)](var base: SIMD[.int, size], mask: SIMD[.bool, size], passthrough: SIMD[dtype, size]) -> SIMD[dtype, size]
```

Reads scalar values from a SIMD vector, and gathers them into one vector.

The gather function reads scalar values from a SIMD vector of memory
locations and gathers them into one vector. The memory locations are
provided in the vector of pointers `base` as addresses. The memory is
accessed according to the provided mask. The mask holds a bit for each
vector lane, and is used to prevent memory accesses to the masked-off
lanes. The masked-off lanes in the result vector are taken from the
corresponding lanes of the `passthrough` operand.

In general, for some vector of pointers `base`, mask `mask`, and passthrough
`passthrough` a call of the form:

```text
from std.sys.intrinsics import gather

result = gather(base, mask, passthrough)
```

is equivalent to the following sequence of scalar loads in C++:

```cpp
for (int i = 0; i < N; i++)
  result[i] = mask[i] ? *base[i] : passthrough[i];
```

Parameters:

- `dtype`: DType of the return SIMD buffer.
- `size`: Size of the return SIMD buffer.
- `invariant`: Whether the memory is load invariant.
- `alignment`: The alignment of the source addresses. Must be 0 or a power of two constant integer value.

Args:

- `base`: The vector containing memory addresses that gather will access.
- `mask`: A binary vector which prevents memory access to certain lanes of the base vector.
- `passthrough`: In the result vector, the masked-off lanes are replaced with the passthrough vector.

Returns: A SIMD[dtype, size] containing the result of the gather operation.

### `scatter`

```mojo
def scatter[dtype: DType, size: SIMDLength, //, alignment: Int = Int(0)](value: SIMD[dtype, size], var base: SIMD[.int, size], mask: SIMD[.bool, size])
```

Takes scalar values from a SIMD vector and `scatters` them into a vector of pointers.

The scatter operation stores scalar values from a SIMD vector of memory
locations and scatters them into a vector of pointers. The memory locations
are provided in the vector of pointers `base` as addresses. The memory is
stored according to the provided mask. The mask holds a bit for each vector
lane, and is used to prevent memory accesses to the masked-off lanes.

The `value` operand is a vector value to be written to memory. The `base`
operand is a vector of pointers, pointing to where the value elements
should be stored. It has the same underlying type as the value operand. The
`mask` operand, mask, is a vector of boolean values. The types of the
`mask` and the `value` operand must have the same number of vector
elements.

Scatter with overlapping addresses is guaranteed to be ordered from
least-significant to most-significant element.

In general, for some vector `value`, vector of pointers `base`, and mask
`mask` a call of the form:

```text
from std.sys.intrinsics import scatter

scatter(value, base, mask)
```

is equivalent to the following sequence of scalar stores in C++:

```cpp
for (int i = 0; i < N; i++)
  if (mask[i])
    base[i] = value[i];
```

Parameters:

- `dtype`: DType of `value`, the result SIMD buffer.
- `size`: Size of `value`, the result SIMD buffer.
- `alignment`: The alignment of the source addresses. Must be 0 or a power of two constant integer value.

Args:

- `value`: The vector that will contain the result of the scatter operation.
- `base`: The vector containing memory addresses that scatter will access.
- `mask`: A binary vector which prevents memory access to certain lanes of the base vector.

### `prefetch`

```mojo
def prefetch[dtype: DType, //, params: PrefetchOptions = PrefetchOptions()](addr: Pointer[Scalar[dtype], address_space=addr.address_space])
```

Prefetches an instruction or data into cache before it is used.

The prefetch function provides prefetching hints for the target
to prefetch instruction or data into cache before they are used.

Parameters:

- `dtype`: The DType of value stored in addr.
- `params`: Configuration options for the prefect intrinsic.

Args:

- `addr`: The data pointer to prefetch.

### `masked_load`

```mojo
def masked_load[dtype: DType, //, size: SIMDLength, alignment: Int = Int(1)](addr: Pointer[Scalar[dtype], address_space=addr.address_space], mask: SIMD[.bool, size], passthrough: SIMD[dtype, size]) -> SIMD[dtype, size]
```

Loads data from memory and return it, replacing masked lanes with values from the passthrough vector.

Parameters:

- `dtype`: DType of the return SIMD buffer.
- `size`: Size of the return SIMD buffer.
- `alignment`: The alignment of the destination locations. Must be 0 or a power of two constant integer value. Default is 1.

Args:

- `addr`: The base pointer for the load.
- `mask`: A binary vector which prevents memory access to certain lanes of the memory stored at addr.
- `passthrough`: In the result vector, the masked-off lanes are replaced with the passthrough vector.

Returns: The loaded memory stored in a vector of type SIMD[dtype, size].

### `masked_store`

```mojo
def masked_store[size: SIMDLength, alignment: Int = Int(1)](value: SIMD, addr: Pointer[Scalar[value.dtype], address_space=addr.address_space], mask: SIMD[.bool, size])
```

Stores a value at a memory location, skipping masked lanes.

Parameters:

- `size`: Size of `value`, the data to store.
- `alignment`: The alignment of the destination locations. Must be 0 or a power of two constant integer value. Default is 1.

Args:

- `value`: The vector containing data to store.
- `addr`: A vector of memory location to store data at.
- `mask`: A binary vector which prevents memory access to certain lanes of `value`.

### `compressed_store`

```mojo
def compressed_store[dtype: DType, size: SIMDLength](value: SIMD[dtype, size], addr: Pointer[Scalar[dtype], address_space=addr.address_space], mask: SIMD[.bool, size])
```

Compresses the lanes of `value`, skipping `mask` lanes, and stores at `addr`.

Parameters:

- `dtype`: DType of `value`, the value to store.
- `size`: Size of `value`, the value to store.

Args:

- `value`: The vector containing data to store.
- `addr`: The memory location to store the compressed data.
- `mask`: A binary vector which prevents memory access to certain lanes of `value`.

### `strided_load`

```mojo
def strided_load[dtype: DType, //, simd_width: SIMDLength, *, invariant: Bool = False](addr: Pointer[Scalar[dtype], address_space=addr.address_space], stride: Int, mask: SIMD[.bool, simd_width] = SIMD(fill=True)) -> SIMD[dtype, simd_width]
```

Loads values from addr according to a specific stride.

Parameters:

- `dtype`: DType of `value`, the value to store.
- `simd_width`: The width of the SIMD vectors.
- `invariant`: Whether the memory is load invariant.

Args:

- `addr`: The memory location to load data from.
- `stride`: How many lanes to skip before loading again.
- `mask`: A binary vector which prevents memory access to certain lanes of `value`.

Returns: A vector containing the loaded data.

### `strided_store`

```mojo
def strided_store[dtype: DType, //, simd_width: SIMDLength](value: SIMD[dtype, simd_width], addr: Pointer[Scalar[dtype], address_space=addr.address_space], stride: Int, mask: SIMD[.bool, simd_width] = SIMD(fill=True))
```

Loads values from addr according to a specific stride.

Parameters:

- `dtype`: DType of `value`, the value to store.
- `simd_width`: The width of the SIMD vectors.

Args:

- `value`: The values to store.
- `addr`: The location to store values at.
- `stride`: How many lanes to skip before storing again.
- `mask`: A binary vector which prevents memory access to certain lanes of `value`.

### `expect`

```mojo
def expect[T: TrivialRegisterPassable, //, expected_val: T](val: T) -> T
```

Provides information about expected (the most probable) value of `val`, which can be used by optimizers.

Notes:
Only works with integer/boolean types.

Parameters:

- `T`: The type of the input value.
- `expected_val`: The expected value of `val`.

Args:

- `val`: The input value.

Returns: The input value.

### `likely`

```mojo
def likely(val: Bool) -> Bool
```

Provides information that the most probable value of `val` is going to be `True`. This information can be used by optimizers.

Args:

- `val`: The input value which is likely to be `True` most of the time.

Returns: The input value.

### `unlikely`

```mojo
def unlikely(val: Bool) -> Bool
```

Provides information that the most probable value of `val` is going to be `False`. This information can be used by optimizers.

Args:

- `val`: The input value which is likely to be `False` most of the time.

Returns: The input value.

### `assume`

```mojo
def assume(val: Bool)
```

Signals to the optimizer that the condition is always true. This allows the optimizer to optimize the code.

Args:

- `val`: The input value which is assumed to be `True`.

### `implicitarg_ptr`

```mojo
def implicitarg_ptr() -> Pointer[UInt8, MutUntrackedOrigin, address_space=AddressSpace.CONSTANT]
```

Get a pointer to AMD's implicit arguments table.

Returns: A pointer to LLVM's implicit arguments table.

### `readfirstlane`

```mojo
def readfirstlane[T: AnyType, //](value: Pointer[T, address_space=value.address_space]) -> Pointer[T, value.origin, address_space=value.address_space]
```

Get the value in the lowest active lane of the input operand.

Parameters:

- `T`: The type the pointer points to.

Args:

- `value`: The input pointer.

Returns: The value in the lowest active lane of the input operand.

```mojo
def readfirstlane[dtype: DType](value: Scalar[dtype]) -> Scalar[dtype]
```

Gets the value in the lowest active lane of the input operand.

Constraints: The scalar type must be 2, 4, or 8 bytes wide.

Parameters:

- `dtype`: The element type.

Args:

- `value`: The input scalar value.

Returns: The value in the lowest active lane of the input operand.

### `sendmsg`

```mojo
def sendmsg(opcode: Int32, msg: Int32)
```

Send a message to fixed function hardware. Refer to the specific ISA manual for the ops and messages.

Args:

- `opcode`: The operation to perform.
- `msg`: The message to send.

### `ballot`

```mojo
def ballot[dtype: DType](value: Bool) -> Scalar[dtype]
```

Returns a bitfield(Int32 or Int64) containing the result of its Bool argument in all active lanes, and zero in all inactive lanes. For example, ballot(True) returns EXEC mask.

Parameters:

- `dtype`: The DType of the return type.

Args:

- `value`: The value to place across the mask.

Returns: A bitfield(Int32 or Int64) containing the result of its Bool argument in all active lanes.

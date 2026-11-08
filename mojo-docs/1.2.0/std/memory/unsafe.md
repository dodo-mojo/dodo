# `std.memory.unsafe`

Provides utility functions for unsafe manipulation of SIMD values.

You can import these APIs from the `memory` package. For example:

```mojo
from std.memory import bitcast
```

## Functions

### `bitcast`

```mojo
def bitcast[src_dtype: DType, src_width: SIMDLength, //, dtype: DType, width: SIMDLength = src_width](val: SIMD[src_dtype, src_width]) -> SIMD[dtype, width]
```

Bitcasts a SIMD value to another SIMD value.

For a discussion of byte order, see
[Converting data: bitcasting and byte order](../../manual/pointers/using-pointers.md#converting-data-bitcasting-and-byte-order)
in the Mojo Manual.

Examples:

The following example uses `bitcast` to break a 32-bit integer into a vector
of four 8-bit integers:

```mojo
from std.memory import bitcast

u32 = UInt32(4631)
u8x4 = bitcast[.uint8, 4](u32)
print(u32, u8x4) # 4631 [23, 18, 0, 0]
```

Constraints: The bitwidth of the two types must be the same.

Parameters:

- `src_dtype`: The source type.
- `src_width`: The source width.
- `dtype`: The target type.
- `width`: The target width.

Args:

- `val`: The source value.

Returns: A new SIMD value with the specified type and width with a bitcopy of the source SIMD value.

### `pack_bits`

```mojo
def pack_bits[src_width: SIMDLength, //, dtype: DType = _uint_type_of_width[SIMD(src_width)](), width: SIMDLength = 1](val: SIMD[.bool, src_width]) -> SIMD[dtype, width]
```

Packs a SIMD vector of `bool` values into an integer.

Examples:

This example packs a vector of 8 `bool` values into a single 8-bit integer.

```mojo
from std.memory import pack_bits

bits = SIMD[.bool, 8](1, 1, 0, 1, 0, 0, 0, 0)
u8 = pack_bits[.uint8](bits)
print(bits, u8) # [True, True, False, True, False, False, False, False] 11
```

Constraints: The logical bitwidth of the bool vector must be the same as the bitwidth of the
target type. The target type must be a unsigned type.

Parameters:

- `src_width`: The source width.
- `dtype`: The target type.
- `width`: The target width.

Args:

- `val`: The source value.

Returns: A new integer scalar which has the same bitwidth as the bool vector.

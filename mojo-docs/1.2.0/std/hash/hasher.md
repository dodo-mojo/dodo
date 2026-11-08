# `std.hash.hasher`

Defines the Hasher trait and default hasher implementations.

This module provides the `Hasher` trait for implementing hash algorithms and
default hasher instances for common use cases. The `default_hasher` uses AHash
for runtime hashing, while `default_comp_time_hasher` uses FNV-1a for
compile-time hashing.

## Aliases

### `default_hasher`

```mojo
comptime default_hasher = AHasher[SIMD[.uint64, 4](0)]
```

The default hasher for runtime hashing.

### `default_comp_time_hasher`

```mojo
comptime default_comp_time_hasher = Fnv1a
```

The default hasher for compile-time hashing.

## Traits

### `Hasher`

```mojo
trait Hasher
```

A trait for types that can incrementally compute hash values.

The `Hasher` trait defines the interface for hash algorithms that can process
data in chunks and produce a final hash value.

Implementers must provide methods to initialize the hasher, update it with
data, and finalize the hash computation.

Inherits from: `AnyType`

#### `Hasher.update`

```mojo
def update(mut self, value: Span[UInt8])
```

Update the hash with a value.

Args:

- `value`: The value to incorporate into the hash.

#### `Hasher.finish`

```mojo
def finish(self) -> UInt64
```

Finalize the hash computation and return the hash value.

Returns: The computed hash value as a 64-bit unsigned integer.

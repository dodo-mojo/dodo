# `std.hash.hash`

Implements the `Hashable` trait and `hash()` built-in function.

There are a few main tools in this module:

- `Hashable` trait for types implementing `__hash__(self, mut hasher)`
- `hash[T: Hashable](hashable: T) -> UInt64` built-in function.
- `hash_bytes(bytes: ImmSpan[Byte]) -> UInt64` for arbitrary byte strings,
  is the workhorse function, which implements efficient hashing via SIMD
  vectors. See the documentation of this function for more details on the hash
  implementation.
- `hash(SIMD)` and `hash(UInt8)` implementations
    These are useful helpers to specialize for the general bytes implementation.

## Traits

### `Hashable`

```mojo
trait Hashable
```

A trait for types which specify a function to hash their data.

This hash function will be used for applications like hash maps, and
don't need to be cryptographically secure. A good hash function will
hash similar / common types to different values, and in particular
the _low order bits_ of the hash, which are used in smaller dictionaries,
should be sensitive to any changes in the data structure. If your type's
hash function doesn't meet this criteria it will get poor performance in
common hash map implementations.

The `Hashable` trait has a default implementation of `__hash__()` that uses
reflection to hash all fields. This means simple structs can conform to
`Hashable` without implementing any methods:

```mojo
@fieldwise_init
struct Point(Hashable):
    var x: Int
    var y: Int

var p = Point(1, 2)
print(hash(p))
```

All fields must conform to `Hashable`. Override `__hash__()` for custom
hashing behavior.

Note: When implementing both `Hashable` and `Equatable`, ensure that
equal values produce equal hashes (i.e., if `a == b` then `hash(a) == hash(b)`).
The default implementations of both traits satisfy this property when all
fields implement both traits correctly.

Note: The default reflection-based implementation iterates over all fields
at compile time. For mutually recursive types (e.g., struct `A` has a field
of type `List[B]` and struct `B` has a field of type `A`), this creates an
infinite monomorphization cycle that causes the compiler to hang. To fix
this, provide an explicit `__hash__()` implementation for at least one type
in the cycle.

Inherits from: `AnyType`

#### `Hashable.__hash__`

```mojo
def __hash__(self, mut hasher: T)
```

Accepts a hasher and contributes to the hash value by calling the update function of the hasher.

Args:

- `hasher`: The hasher instance to contribute to.

## Functions

### `hash`

```mojo
def hash[T: Hashable, //, HasherType: Defaultable & Hasher & Deinitable = AHasher[SIMD[.uint64, 4](0)]](hashable: T) -> UInt64
```

Hash a Hashable type using its underlying hash implementation.

Parameters:

- `T`: Any Hashable type.
- `HasherType`: Type of the hasher which should be used for hashing.

Args:

- `hashable`: The input data to hash.

Returns: A 64-bit integer hash based on the underlying implementation.

```mojo
def hash[HasherType: Defaultable & Hasher & Deinitable = AHasher[SIMD[.uint64, 4](0)]](bytes: Pointer[UInt8], n: Int) -> UInt64
```

**Deprecated:** Use `hash_bytes()` instead

Hash a sequence of bytes using the specified hasher.

Parameters:

- `HasherType`: Type of the hasher to use for hashing (default: `AHasher`).

Args:

- `bytes`: Pointer to the byte sequence to hash.
- `n`: The number of bytes to hash.

Returns: A 64-bit integer hash value.

### `hash_bytes`

```mojo
def hash_bytes[HasherType: Defaultable & Hasher & Deinitable = AHasher[SIMD[.uint64, 4](0)]](bytes: Span[UInt8]) -> UInt64
```

Hash a sequence of bytes using the specified hasher.

This hashes `bytes` as a flat byte sequence. It is distinct from
`hash()`, which hashes a `Hashable` value: a `Span`, `List` or `Array`
is itself `Hashable`, so `hash(collection)` hashes it element-by-element
and produces a different value.

Parameters:

- `HasherType`: Type of the hasher to use for hashing (default: `AHasher`).

Args:

- `bytes`: The byte sequence to hash.

Returns: A 64-bit integer hash value.

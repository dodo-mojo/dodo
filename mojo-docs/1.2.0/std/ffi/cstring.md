# `std.ffi.cstring`

Implements C string interoperability utilities.

## Aliases

### `CStringSlice`

```mojo
comptime CStringSlice = CStringSpan[_]
```

**Deprecated:** 'CStringSlice' is deprecated, use 'CStringSpan' instead

Provides a compatibility alias for `CStringSpan`.

## Structs

### `CStringSpan`

```mojo
struct CStringSpan[origin: ImmOrigin]
```

A non-owning immutable view to a nul-terminated C string (`const char*`).

This type can be safely constructed from any sort of `StringSpan` or
`Span[Byte]` that is nul-terminated, or unsafely from a raw pointer.

Parameters:

- `origin`: The origin of the `CStringSpan`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Sized`, `TrivialRegisterPassable`, `UnsafeNicheable`, `Writable`

#### `CStringSpan.__init__`

```mojo
def __init__(*, unsafe_from_ptr: Pointer[Scalar[_c_char_dtype()], origin]) -> Self
```

Construct a `CStringSpan` from a `Pointer`.

Safety:
The `Pointer` must be a valid nul-terminated C string.
The pointer cannot be null. To represent nullability, use
`Optional[CStringSpan]`.

Example:

```mojo
from std.ffi import c_char, CStringSpan, external_call

def getenv_wrapper(
    name: CStringSpan,
) raises -> CStringSpan[ImmStaticOrigin]:
    # External call to 'getenv'.
    # C signature: const char *getenv(const char *name);
    var result = external_call[
        "getenv",
        Optional[CStringSpan[ImmStaticOrigin]],
    ](name)

    try:
        # Optional.__getitem__ raises an error if empty.
        return result[]
    except:
        raise Error("getenv returned an error!")
```

Args:

- `unsafe_from_ptr`: The `Pointer` to construct the `CStringSpan` from.

```mojo
def __init__(out self, span: StringSpan[origin]) raises
```

Construct a `CStringSpan` from a `StringSpan`.

Example:

```mojo
from std.ffi import CStringSpan
from std.testing import assert_raises

var string = String("Hello, World!")

with assert_raises():
    # This will raise an error since the string is not nul-terminated.
    _ = CStringSpan(string)
```

Args:

- `span`: The `StringSpan` to construct the `CStringSpan` from.

Raises: An error if the span is not nul-terminated or has interior nul bytes.

```mojo
def __init__(out self, span: Span[UInt8, origin]) raises
```

Construct a `CStringSpan` from a `Span[Byte]`.

Args:

- `span`: The `Span[Byte]` to construct the `CStringSpan` from.

Raises: An error if the span is not nul-terminated or has interior nul bytes.

#### `CStringSpan.__eq__`

```mojo
def __eq__(self, rhs_same: Self) -> Bool
```

Compare two `CStringSpan`s for equality.

Args:

- `rhs_same`: The `CStringSpan` to compare against.

Returns: True if the `CStringSpan`s are equal, False otherwise.

```mojo
def __eq__(self, rhs: CStringSpan) -> Bool
```

Compare two `CStringSpan`s for equality.

Args:

- `rhs`: The `CStringSpan` to compare against.

Returns: True if the `CStringSpan`s are equal, False otherwise.

#### `CStringSpan.__ne__`

```mojo
def __ne__(self, rhs: CStringSpan) -> Bool
```

Compare two `CStringSpan`s for inequality.

Args:

- `rhs`: The `CStringSpan` to compare against.

Returns: True if the `CStringSpan`s are not equal, False otherwise.

#### `CStringSpan.__len__`

```mojo
def __len__(self) -> Int
```

Get the length of the C string. Like C's strlen this does not include the nul terminator.

Returns: The length of the C string.

#### `CStringSpan.write_to`

```mojo
def write_to(self, mut writer: T)
```

Write the `CStringSpan` to a `Writer`, the nul terminator is omitted.

Args:

- `writer`: The `Writer` to write the `CStringSpan` to.

#### `CStringSpan.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the string representation of this `CStringSpan` to a `Writer`.

Args:

- `writer`: The `Writer` to write the `CStringSpan` to.

#### `CStringSpan.ptr`

```mojo
def ptr(self) -> Pointer[Scalar[_c_char_dtype()], origin]
```

Get a pointer to the underlying `CStringSpan`.

Returns: A pointer to the underlying `CStringSpan`.

#### `CStringSpan.as_bytes`

```mojo
def as_bytes(self) -> Span[UInt8, origin]
```

Get a span of the underlying `CStringSpan` as bytes.

The returned span does not include the nul terminator.
If you want a byte span including the nul terminator, use
`as_bytes_with_nul()`.

Returns: A span of the underlying `CStringSpan` as bytes.

#### `CStringSpan.as_bytes_with_nul`

```mojo
def as_bytes_with_nul(self) -> Span[UInt8, origin]
```

Get a span of the underlying `CStringSpan` as bytes including the nul terminator.

If you want a byte span not including the nul terminator, use
`as_bytes()`.

Returns: A span of the underlying `CStringSpan` as bytes.

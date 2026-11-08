# `std.collections.string.codepoint`

Unicode codepoint handling.

This module provides the `Codepoint` type for representing single Unicode scalar values.
A codepoint represents a single Unicode character, restricted to valid Unicode scalar
values in the ranges `0` to `0xD7FF` and `0xE000` to `0x10FFFF` inclusive.

## Structs

### `Codepoint`

```mojo
struct Codepoint
```

A Unicode codepoint, typically a single user-recognizable character; restricted to valid Unicode scalar values.

This type is restricted to store a single Unicode `[*scalar value*][1]`,
typically encoding a single user-recognizable character.

All valid Unicode scalar values are in the range(s) `0` to `0xD7FF` and
`0xE000` to `0x10FFFF`, inclusive. This type guarantees that the stored integer
value falls in these ranges.

The `Codepoint` type provides functionality for:
- Converting between codepoints and UTF-8 encoded bytes.
- Testing character properties like ASCII, digits, whitespace etc.
- Converting between codepoints and strings.
- Safe construction from integers with validation.

Example:

```mojo
from std.collections.string import Codepoint
from std.testing import assert_true

# Create a codepoint from a character
var c = Codepoint.ord('A')

# Check properties
assert_true(c.is_ascii())
assert_true(c.is_ascii_upper())

# Convert to string
var s = String(c)  # "A"
```

[1]: https://www.unicode.org/glossary/#unicode_scalar_value

**Codepoints versus scalar values:**

Formally, Unicode defines a codespace of values in the range `0` to
`0x10FFFF` (inclusive), and a [Unicode
codepoint](https://www.unicode.org/glossary/#code_point) is any integer
falling within that range. However, due to historical reasons, it became
necessary to "carve out" a subset of the codespace known as [Unicode scalar
values][1], that excludes codepoints in the range `0xD800` - `0xDFFF`. The
codepoints in the excluded range are known as "surrogate" codepoints and
will never be assigned a semantic meaning—they can only validly appear in
UTF-16 encoded text.

The difference between codepoints and scalar values is a technical
distinction related to the backwards-compatible workaround chosen to enable
UTF-16 to encode the full range of the Unicode codespace. For simplicities
sake, and to avoid a confusing clash with the Mojo `Scalar` type, this type
is pragmatically named `Codepoint`, even though it is restricted to valid
scalar values.

Implemented traits: `AnyType`, `Comparable`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Intable`, `Movable`, `Writable`

#### `Codepoint.__init__`

```mojo
def __init__(out self, *, unsafe_unchecked_codepoint: UInt32)
```

Construct a `Codepoint` from a code point value without checking that it falls in the valid range.

Safety:
The provided codepoint value MUST be a valid Unicode scalar value.
Providing a value outside of the valid range could lead to undefined
behavior in algorithms that depend on the validity guarantees of
this type.

Args:

- `unsafe_unchecked_codepoint`: A valid Unicode scalar value code point.

```mojo
def __init__(out self, codepoint: UInt8)
```

Construct a `Codepoint` from a single byte value.

This constructor cannot fail because non-negative 8-bit integers are
valid Unicode scalar values.

Args:

- `codepoint`: The 8-bit codepoint value to convert to a `Codepoint`.

```mojo
def __init__(out self, lit: StringLiteral)
```

Construct a `Codepoint` from a single-codepoint `StringLiteral`.

This constructor validates at compile-time that the literal contains
exactly one Unicode codepoint, and computes the codepoint value as a
compile-time constant. This provides an ergonomic and efficient way to
create codepoints from string literals without runtime overhead.

Examples:

```mojo
from std.collections.string import Codepoint
from std.testing import assert_equal

# Create codepoints from ASCII literals
var a = Codepoint("A")
assert_equal(a.to_u32(), 65)

var space = Codepoint(" ")
assert_equal(space, Codepoint.ord(" "))

# Multi-byte UTF-8 codepoints also work
var emoji = Codepoint("🔥")
assert_equal(emoji, Codepoint.ord("🔥"))
```

Constraints: The string literal must contain exactly one Unicode codepoint.
Multi-byte UTF-8 sequences are supported (e.g., "🔥").

Args:

- `lit`: A string literal containing exactly one Unicode codepoint.

#### `Codepoint.__lt__`

```mojo
def __lt__(self, other: Self) -> Bool
```

Return True if this character is less than a different codepoint value from `other`.

Args:

- `other`: The codepoint value to compare against.

Returns: True if this character's value is less than the other codepoint value; False otherwise.

#### `Codepoint.from_u32`

```mojo
def from_u32(codepoint: UInt32) -> Optional[Self]
```

Construct a `Codepoint` from a code point value. Returns None if the provided `codepoint` is not in the valid range.

Args:

- `codepoint`: An integer representing a Unicode scalar value.

Returns: A `Codepoint` if `codepoint` falls in the valid range for Unicode scalar values, otherwise None.

#### `Codepoint.ord`

```mojo
def ord(string: StringSpan) -> Self
```

Returns the `Codepoint` that represents the given single-character string.

Given a string containing one character, return a `Codepoint`
representing the codepoint of that character. For example,
`Codepoint.ord("a")` returns the codepoint `97`. This is the inverse of
the `chr()` function.

This function is similar to the `ord()` free function, except that it
returns a `Codepoint` instead of an `Int`.

Args:

- `string`: The input string, which must contain only a single character.

Returns: A `Codepoint` representing the codepoint of the given character.

#### `Codepoint.unsafe_decode_utf8_codepoint`

```mojo
def unsafe_decode_utf8_codepoint(s: Span[UInt8]) -> Tuple[Self, Int]
```

Decodes a single `Codepoint` and number of bytes read from a given UTF-8 string pointer.

Safety:
`_ptr` MUST point to the first byte in a **known-valid** UTF-8
character sequence. This function MUST NOT be used on unvalidated
input.

Args:

- `s`: Span to UTF-8 encoded data containing at least one valid encoded codepoint.

Returns: The decoded codepoint `Codepoint`, as well as the number of bytes read.

#### `Codepoint.__int__`

```mojo
def __int__(self) -> Int
```

Returns the numeric value of this scalar value as an integer.

Returns: The numeric value of this scalar value as an integer.

#### `Codepoint.write_to`

```mojo
def write_to(self, mut w: T)
```

Write a string representation of this `Codepoint` to the given writer.

Args:

- `w`: The object to write to.

#### `Codepoint.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the repr of this `Codepoint` to a writer.

Writes the codepoint in the format `Codepoint(N)` where N is the
Unicode scalar value.

Args:

- `writer`: The object to write to.

#### `Codepoint.is_ascii`

```mojo
def is_ascii(self) -> Bool
```

Returns True if this `Codepoint` is an ASCII character.

All ASCII characters are less than or equal to codepoint value 127, and
take exactly 1 byte to encode in UTF-8.

Returns: A boolean indicating if this `Codepoint` is an ASCII character.

#### `Codepoint.is_ascii_digit`

```mojo
def is_ascii_digit(self) -> Bool
```

Determines whether the given character is a digit [0-9].

Returns: True if the character is a digit.

#### `Codepoint.is_ascii_upper`

```mojo
def is_ascii_upper(self) -> Bool
```

Determines whether the given character is an uppercase character.

This currently only respects the default "C" locale, i.e. returns True
iff the character specified is one of "ABCDEFGHIJKLMNOPQRSTUVWXYZ".

Returns: True if the character is uppercase.

#### `Codepoint.is_ascii_lower`

```mojo
def is_ascii_lower(self) -> Bool
```

Determines whether the given character is an lowercase character.

This currently only respects the default "C" locale, i.e. returns True
iff the character specified is one of "abcdefghijklmnopqrstuvwxyz".

Returns: True if the character is lowercase.

#### `Codepoint.is_ascii_printable`

```mojo
def is_ascii_printable(self) -> Bool
```

Determines whether the given character is a printable character.

Returns: True if the character is a printable character, otherwise False.

#### `Codepoint.is_python_space`

```mojo
def is_python_space(self) -> Bool
```

Determines whether this character is a Python whitespace string.

This corresponds to Python's [universal separators](
https://docs.python.org/3/library/stdtypes.html#str.splitlines):
 `" \t\n\v\f\r\x1c\x1d\x1e\x85\u2028\u2029"`.

For example, check if a string contains only whitespace:

```mojo
from std.testing import assert_true, assert_false

# ASCII space characters
assert_true(Codepoint.ord(" ").is_python_space())
assert_true(Codepoint.ord("	").is_python_space())

# Unicode paragraph separator:
assert_true(Codepoint.from_u32(0x2029).value().is_python_space())

# Letters are not space characters
assert_false(Codepoint.ord("a").is_python_space())
```

Returns: True if this character is one of the whitespace characters listed above, otherwise False.

#### `Codepoint.is_posix_space`

```mojo
def is_posix_space(self) -> Bool
```

Returns True if this `Codepoint` is a **space** character according to the [POSIX locale][1].

The POSIX locale is also known as the C locale.

[1]: https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap07.html#tag_07_03_01

This only respects the default "C" locale, i.e. returns True only if the
character specified is one of " \t\n\v\f\r". For semantics similar
to Python, use `String.isspace()`.

Returns: True iff the character is one of the whitespace characters listed above.

#### `Codepoint.to_u32`

```mojo
def to_u32(self) -> UInt32
```

Returns the numeric value of this scalar value as an unsigned 32-bit integer.

Returns: The numeric value of this scalar value as an unsigned 32-bit integer.

#### `Codepoint.unsafe_write_utf8`

```mojo
def unsafe_write_utf8[optimize_ascii: Bool = True, branchless: Bool = False](self, ptr: Pointer[UInt8, address_space=ptr.address_space]) -> Int
```

Shift unicode to utf8 representation.

Safety:
`ptr` MUST point to at least `self.utf8_byte_length()` allocated
bytes or else an out-of-bounds write will occur, which is undefined
behavior.

### Unicode (represented as UInt32 BE) to UTF-8 conversion:
- 1: 00000000 00000000 00000000 0aaaaaaa -> 0aaaaaaa
    - a
- 2: 00000000 00000000 00000aaa aabbbbbb -> 110aaaaa 10bbbbbb
    - (a >> 6)  | 0b11000000, b         | 0b10000000
- 3: 00000000 00000000 aaaabbbb bbcccccc -> 1110aaaa 10bbbbbb 10cccccc
    - (a >> 12) | 0b11100000, (b >> 6)  | 0b10000000, c        | 0b10000000
- 4: 00000000 000aaabb bbbbcccc ccdddddd -> 11110aaa 10bbbbbb 10cccccc
10dddddd
    - (a >> 18) | 0b11110000, (b >> 12) | 0b10000000, (c >> 6) | 0b10000000,
    d | 0b10000000
.

Parameters:

- `optimize_ascii`: Optimize for languages with mostly ASCII characters.
- `branchless`: Use a branchless algorithm.

Args:

- `ptr`: Pointer value to write the encoded UTF-8 bytes. Must validly point to a sufficient number of bytes (1-4) to hold the encoded data.

Returns: Returns the number of bytes written.

#### `Codepoint.utf8_byte_length`

```mojo
def utf8_byte_length(self) -> Int
```

Returns the number of UTF-8 bytes required to encode this character.

Notes:
The returned value is always between 1 and 4 bytes.

Returns: Byte count of UTF-8 bytes required to encode this character.

# `std.collections.string.string_span`

Implements the `StringSpan` type and related utilities for efficient string operations.

## Aliases

### `StringSlice`

```mojo
comptime StringSlice = StringSpan[_]
```

Provides a compatibility alias for `StringSpan`.

### `ImmStringSpan`

```mojo
comptime ImmStringSpan[origin: ImmOrigin] = StringSpan[origin]
```

Provides read-only access to the string data it views.

### `ImmStringSlice`

```mojo
comptime ImmStringSlice[origin: ImmOrigin] = ImmStringSpan
```

Provides a compatibility alias for `ImmStringSpan`.

### `StaticString`

```mojo
comptime StaticString = StringSpan[ImmStaticOrigin]
```

An immutable static string span.

This is a type of
[`StringSpan`](../../../std/collections/string/string_span.md#stringspan)
that's immutable and statically allocated. You might use this for situations
that could also be done with a `String` type, but when you want to
optimize memory usage with zero heap allocations.

The key difference from `StringSpan` is that a `StaticString` is guaranteed
to point to data (string literals, constants) that will never be deallocated
(a regular `StringSpan` may point to any string data that might be freed).
This makes `StaticString` safe to store long-term without lifetime concerns.

Although you can reassign a `StaticString`-typed variable with a new value,
you can't modify the underlying data of a `StaticString` after it's created
the way you can with a `String`, such as using `+=` to append to it.

Because this is still a `StringSpan` type, you can do all the same things
with it, such as format a string:

```mojo
var format_string = StaticString("{}: {}")
print(format_string.format("bats", 6))     # => bats: 6
```

## Structs

### `StringSpan`

```mojo
struct StringSpan[origin: ImmOrigin]
```

An immutable, non-owning view into encoded string data.

A `StringSpan` is a lightweight view into string data that lets you look
at part (or all) of a string without copying the data. Unlike a
[`String`](../../../std/collections/string/string.md#string), a `StringSpan`
doesn't own the string data, but it knows where to find it and how long it
is. It's designed for efficient zero-copy string operations without memory
allocation, while maintaining memory safety and UTF-8 awareness.

`StringSpan` is always immutable. To mutate string storage, operate on an
owning `String` or a mutable `Span[Byte]` instead.

Key features:

- Zero-copy string operations for high performance.
- Lightweight immutable view that doesn't own or allocate memory.
- UTF-8 aware string processing and character iteration.
- Compatible ABI with `llvm::StringRef` for C++ interoperability.
- Memory-safe slicing and substring operations.
- Efficient string parsing and tokenization.

Examples:

```mojo
# Create a string span
var text = StringSpan("Hello, 世界")

# Zero-copy slicing (byte-level)
var hello = text[byte=0:5] # Hello

# Unicode-aware byte slicing
var world = text[byte=7:13]  # "世界"

# String comparison
if text.startswith("Hello"):
    print("Found greeting")

# String formatting
var format_string = StaticString("{}: {}")
print(format_string.format("bats", 6)) # bats: 6
```

Related types:

- [`String`](../../../std/collections/string/string.md#string): An owning,
  mutable string that allocates and manages its own memory.
- [`StaticString`](../../../std/collections/string/string_span.md#staticstring): An
  alias for an immutable constant `StringSpan`.
- [`StringLiteral`](../../../std/builtin/string_literal.md#stringliteral): A
  string literal. String literals are compile-time values.

Notes:
TODO: The underlying string data is guaranteed to be encoded using
UTF-8.

Parameters:

- `origin`: The origin of the underlying string data.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `Equatable`, `FloatableRaising`, `Hashable`, `ImplicitlyCopyable`, `IntableRaising`, `Movable`, `PathLike`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

Aliases:

- `Immutable = StringSpan[origin_of(_mlir_origin)]`: A `StringSpan` with a canonical immutable origin.

#### `StringSpan.__init__`

```mojo
def __init__() -> Self
```

Create an empty / zero-length slice.

```mojo
def __init__(lit: StringLiteral) -> StaticString
```

Construct a new `StringSpan` from a `StringLiteral`.

Args:

- `lit`: The literal to construct this `StringSpan` from.

```mojo
def __init__(*, unsafe_from_utf8: Span[UInt8, origin]) -> Self
```

Construct a new `StringSpan` from a sequence of UTF-8 encoded bytes.

Safety:
`unsafe_from_utf8` MUST be valid UTF-8 encoded data.

Args:

- `unsafe_from_utf8`: A `Span[Byte]` encoded in UTF-8.

```mojo
def __init__[cstring_origin: ImmOrigin, //](*, unsafe_from_utf8: CStringSpan[cstring_origin]) -> StringSpan[cstring_origin]
```

Construct a new `StringSpan` from a UTF-8 encoded `CStringSpan`.

Safety:
`unsafe_from_utf8` MUST be valid UTF-8 encoded data.

Parameters:

- `cstring_origin`: The origin of the source `CStringSpan`.

Args:

- `unsafe_from_utf8`: A `CStringSpan` encoded in UTF-8.

```mojo
def __init__(out self, *, from_utf8: Span[UInt8, origin]) raises
```

Construct a new `StringSpan` from a buffer containing UTF-8 encoded data.

Args:

- `from_utf8`: A span of bytes containing UTF-8 encoded data.

Raises: An exception is raised if the provided buffer byte values do not form valid UTF-8 encoded codepoints.

```mojo
def __init__(ref[origin] value: String) -> Self
```

Construct a StringSpan from a String.

Args:

- `value`: The string value.

#### `StringSpan.__bool__`

```mojo
def __bool__(self) -> Bool
```

Check if a string span is non-empty.

Returns: True if a string span is non-empty, False otherwise.

#### `StringSpan.__getitem__`

```mojo
def __getitem__(self, *, byte: ContiguousSlice) -> Self
```

Gets a substring at the specified byte positions.

This performs byte-level slicing, not character (codepoint) slicing.
The start and end positions are byte indices. For strings containing
multi-byte UTF-8 characters, slicing at byte positions that do not fall
on codepoint boundaries will abort.

Aborts if `byte`'s start or end index is out of bounds (valid range is
`0` to `self.byte_length()`, inclusive), or if start is greater than
end. Negative indices are not supported and always abort.

Args:

- `byte`: A slice that specifies byte positions of the new substring.

Returns: A new StringSpan containing the bytes in the specified range.

```mojo
def __getitem__(self, *, codepoint: T) -> Self
```

Gets the character at the specified position.

Aborts if `codepoint` is out of bounds.

Args:

- `codepoint`: The codepoint index.

Returns: A `StringSpan` view containing the unicode codepoint at the specified position.

```mojo
def __getitem__(self, *, codepoint: ContiguousSlice) -> Self
```

Gets a substring at the specified codepoint positions.

Aborts if `codepoint`'s start or end index is out of bounds (valid
range is `0` to `self.count_codepoints()`, inclusive), or if start
is greater than end. Negative indices are not supported and always
abort.

Args:

- `codepoint`: A slice that specifies codepoint positions of the new substring.

Returns: A new StringSpan containing the codepoints in the specified range.

```mojo
def __getitem__(self, *, grapheme: T) -> Self
```

Gets the character at the specified position.

Args:

- `grapheme`: The grapheme index.

Returns: A `StringSpan` view containing the unicode grapheme at the specified position.

```mojo
def __getitem__[I: Indexer, //](self, *, byte: I) -> Self
```

Gets a single byte at the specified byte index.

This performs byte-level indexing, not character (codepoint) indexing.
For strings containing multi-byte UTF-8 characters `byte` must fall on
a codepoint boundary and an entire codepoint will be returned.
Aborts if `byte` does not fall on a codepoint boundary.

Parameters:

- `I`: A type that can be used as an index.

Args:

- `byte`: The byte index (0-based).

Returns: A StringSpan containing the codepoint starting at the specified byte position.

```mojo
def __getitem__(self, *, byte: IntLiteral) -> Self
```

Gets a single byte at the specified byte index.

This performs byte-level indexing, not character (codepoint) indexing.
For strings containing multi-byte UTF-8 characters `byte` must fall on
a codepoint boundary and an entire codepoint will be returned.
Aborts if `byte` does not fall on a codepoint boundary.

Args:

- `byte`: The byte index (0-based).

Returns: A StringSpan containing the codepoint starting at the specified byte position.

```mojo
def __getitem__(self, *, grapheme: ContiguousSlice) -> Self
```

Gets a substring at the specified grapheme-cluster positions.

A grapheme cluster is what a user would typically think of as a
single "character" on screen (see `graphemes()`). Slicing by
grapheme requires a forward scan of the string and is O(n) in the
byte length; use `byte=` slicing when you already have byte
offsets.

Aborts if `grapheme`'s start or end index is out of bounds (valid
range is `0` to `self.count_graphemes()`, inclusive), or if start is
greater than end. Negative indices are not supported and always
abort. Counting the total number of graphemes to report a precise
out-of-bounds message is itself an O(n) scan, so it is only done
once a bad index is detected, not on every call.

Examples:

```mojo
from std.testing import assert_equal

# "café" decomposed: 'c', 'a', 'f', 'e' + combining acute.
# 5 codepoints, 4 graphemes.
var s = StringSpan("cafe\u{0301}")
assert_equal(s[grapheme=0:3], "caf")
assert_equal(s[grapheme=3:4], "e\u{0301}")
assert_equal(s[grapheme=3:], "e\u{0301}")
assert_equal(s[grapheme=:], s)
```

Args:

- `grapheme`: A slice specifying the grapheme-cluster range of the new substring.

Returns: A new `StringSpan` covering the requested grapheme range.

#### `StringSpan.__lt__`

```mojo
def __lt__(self, rhs: StringSpan) -> Bool
```

Verify if the `StringSpan` bytes are strictly less than the input in overlapping content.

Args:

- `rhs`: The other `StringSpan` to compare against.

Returns: If the `StringSpan` bytes are strictly less than the input in overlapping content.

```mojo
def __lt__(self, rhs: String) -> Bool
```

Define whether this String span is strictly less than the RHS.

Args:

- `rhs`: The other `String` to compare against.

Returns: If the `StringSpan` bytes are strictly less than the input in overlapping content.

#### `StringSpan.__le__`

```mojo
def __le__(self, rhs: StringSpan) -> Bool
```

Define whether this String span is less than or equal to the RHS.

Args:

- `rhs`: The other `StringSpan` to compare against.

Returns: True if this String span is less than or equal to the RHS StringSpan.

```mojo
def __le__(self, rhs: String) -> Bool
```

Define whether this String span is less than or equal to the RHS.

Args:

- `rhs`: The other String to compare against.

Returns: True if this String span is less than or equal to the RHS String.

#### `StringSpan.__eq__`

```mojo
def __eq__(self, rhs_same: Self) -> Bool
```

Verify if a `StringSpan` is equal to another `StringSpan` with the same origin.

Args:

- `rhs_same`: The `StringSpan` to compare against.

Returns: If the `StringSpan` is equal to the input in length and contents.

```mojo
def __eq__(self, rhs: String) -> Bool
```

Verify if a `StringSpan` is equal to another `String`.

Args:

- `rhs`: The `String` to compare against.

Returns: If the `StringSpan` is equal to the input in length and contents.

```mojo
def __eq__(self, rhs: StringSpan) -> Bool
```

Verify if a `StringSpan` is equal to another `StringSpan`.

Args:

- `rhs`: The `StringSpan` to compare against.

Returns: If the `StringSpan` is equal to the input in length and contents.

#### `StringSpan.__ne__`

```mojo
def __ne__(self, rhs_same: Self) -> Bool
```

Verify if a `StringSpan` is not equal to another `StringSpan` with the same origin.

Args:

- `rhs_same`: The `StringSpan` to compare against.

Returns: If the `StringSpan` is not equal to the input in length and contents.

```mojo
def __ne__(self, rhs: StringSpan) -> Bool
```

Verify if span is not equal to another `StringSpan`.

Args:

- `rhs`: The `StringSpan` to compare against.

Returns: If the `StringSpan` is not equal to the input in length and contents.

#### `StringSpan.__gt__`

```mojo
def __gt__(self, rhs: StringSpan) -> Bool
```

Define whether this String span is strictly greater than the RHS.

Args:

- `rhs`: The other `StringSpan` to compare against.

Returns: True if this String span is strictly greater than the RHS StringSpan.

```mojo
def __gt__(self, rhs: String) -> Bool
```

Define whether this String span is strictly greater than the RHS.

Args:

- `rhs`: The other String to compare against.

Returns: True if this String span is strictly greater than the RHS String.

#### `StringSpan.__ge__`

```mojo
def __ge__(self, rhs: String) -> Bool
```

Define whether this String span is greater than or equal to the RHS.

Args:

- `rhs`: The other String to compare against.

Returns: True if this String span is greater than or equal to the RHS String.

#### `StringSpan.__contains__`

```mojo
def __contains__(self, substr: StringSpan) -> Bool
```

Returns True if the substring is contained within the current string.

Args:

- `substr`: The substring to check.

Returns: True if the string contains the substring.

#### `StringSpan.__add__`

```mojo
def __add__(self, rhs: StringSpan) -> String
```

Returns a string with this value prefixed on another string.

Args:

- `rhs`: The right side of the result.

Returns: The result string.

#### `StringSpan.__mul__`

```mojo
def __mul__(self, n: Int) -> String
```

Concatenates the string `n` times.

Args:

- `n`: The number of times to concatenate the string.

Returns: The string concatenated `n` times.

#### `StringSpan.__radd__`

```mojo
def __radd__(self, lhs: StringSpan) -> String
```

Returns a string with this value appended to another string.

Args:

- `lhs`: The left side of the result.

Returns: The result string.

#### `StringSpan.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this string span to the provided `Writer`.

Args:

- `writer`: The object to write to.

#### `StringSpan.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Formats this string span to the provided `Writer`.

Notes:
Mojo's repr always prints single quotes (`'`) at the start and end
of the repr. Any single quote inside a string should be escaped
(`\'`).

Args:

- `writer`: The object to write to.

#### `StringSpan.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H)
```

Updates hasher with the underlying bytes.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `StringSpan.__fspath__`

```mojo
def __fspath__(self) -> String
```

Return the file system path representation of this string.

Returns: The file system path representation as a string.

#### `StringSpan.__iter__`

```mojo
def __iter__(self) -> GraphemeSliceIter[origin]
```

Iterate over the grapheme clusters in the string span.

A grapheme cluster is what a user would typically think of as a
single "character" on screen. See `graphemes()` for the precise
definition.

To iterate by Unicode codepoint or by byte instead, use
`codepoints()`/`codepoint_slices()` or `bytes()`.

Returns: An iterator yielding each grapheme cluster as a `StringSpan`.

#### `StringSpan.__reversed__`

```mojo
def __reversed__(self) -> GraphemeSliceIter[origin, False]
```

Iterate backwards over the grapheme clusters in the string span.

A grapheme cluster is what a user would typically think of as a
single "character" on screen. See `graphemes()` for the precise
definition.

Returns: A reverse iterator yielding each grapheme cluster as a `StringSpan`.

#### `StringSpan.__int__`

```mojo
def __int__(self) raises -> Int
```

Parses the given string as a base-10 integer and returns that value. If the string cannot be parsed as an int, an error is raised.

Returns: An integer value that represents the string, or otherwise raises.

Raises: If the operation fails.

#### `StringSpan.__float__`

```mojo
def __float__(self) raises -> Float64
```

Parses the string as a float point number and returns that value. If the string cannot be parsed as a float, an error is raised.

Returns: A float value that represents the string, or otherwise raises.

Raises: If the operation fails.

#### `StringSpan.__merge_with__`

```mojo
def __merge_with__[other_type: AnyStruct[StringSpan[other_type.origin]]](self) -> StringSpan[origin_of(origin, other_type.origin)]
```

Returns a string span with merged origins.

Parameters:

- `other_type`: The type of the origin to merge with.

Returns: A StringSpan merged with the other origin.

#### `StringSpan.as_c_string_slice`

```mojo
def as_c_string_slice(self: StringSpan[ImmStaticOrigin]) -> CStringSpan[ImmStaticOrigin]
```

**Deprecated:** 'as_c_string_slice' is deprecated, use 'as_c_string_span' instead

Return a CStringSpan for this StaticString.

Returns: A c-compatible CStringSpan.

#### `StringSpan.as_c_string_span`

```mojo
def as_c_string_span(self: StringSpan[ImmStaticOrigin]) -> CStringSpan[ImmStaticOrigin]
```

Return a CStringSpan for this StaticString.

Returns: A c-compatible CStringSpan.

#### `StringSpan.as_imm`

```mojo
def as_imm(self) -> Self.Immutable
```

Return an immutable version of this Span.

Returns: An immutable version of the same Span.

#### `StringSpan.replace`

```mojo
def replace(self, old: StringSpan, new: StringSpan) -> String
```

Return a copy of the string with all occurrences of substring `old` if replaced by `new`.

Args:

- `old`: The substring to replace.
- `new`: The substring to replace with.

Returns: The string where all occurrences of `old` are replaced with `new`.

#### `StringSpan.strip`

```mojo
def strip(self, chars: StringSpan) -> Self
```

Returns a view of the string with leading and trailing characters removed. Note character is defined as a single unicode code-point, not any kind of displayed character, and strip can break apart graphemes.

Example:

```mojo
print("himojohi".strip("hi")) # "mojo"
```

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A view of the string with no leading or trailing characters.

```mojo
def strip(self) -> Self
```

Returns a view of the string with leading and trailing whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Example:

```mojo
print("  mojo  ".strip()) # "mojo"
```

Returns: A view of the string with no leading or trailing whitespaces.

#### `StringSpan.rstrip`

```mojo
def rstrip(self, chars: StringSpan) -> Self
```

Returns a view of the string with trailing characters removed.

Example:

```mojo
print("mojohi".strip("hi")) # "mojo"
```

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A view of the string with no trailing characters.

```mojo
def rstrip(self) -> Self
```

Returns a view of the string with trailing whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Example:

```mojo
print("mojo  ".strip()) # "mojo"
```

Returns: A view of the string with no trailing whitespaces.

#### `StringSpan.lstrip`

```mojo
def lstrip(self, chars: StringSpan) -> Self
```

Returns a view of the string with leading characters removed.

Example:

```mojo
print("himojo".strip("hi")) # "mojo"
```

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A view of the string with no leading characters.

```mojo
def lstrip(self) -> Self
```

Returns a view of the string with leading whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Example:

```mojo
print("  mojo".strip()) # "mojo"
```

Returns: A view of the string with no leading whitespaces.

#### `StringSpan.bytes`

```mojo
def bytes(self) -> BytesIter[origin]
```

Returns an iterator over the raw bytes of this string span.

Unlike `codepoints()` and `graphemes()`, this iterator operates at the
byte level and yields individual `Byte` values without interpreting
multi-byte UTF-8 sequences.

Examples:

Iterate over the bytes of an ASCII string:

```mojo
from std.testing import assert_equal, assert_raises

var s = StringSpan("abc")
var iter = s.bytes()
assert_equal(next(iter), Byte(ord("a")))
assert_equal(next(iter), Byte(ord("b")))
assert_equal(next(iter), Byte(ord("c")))
with assert_raises():
    _ = next(iter) # raises StopIteration
```

Multi-byte UTF-8 sequences are yielded as individual bytes:

```mojo
from std.testing import assert_equal

# "é" is encoded in UTF-8 as two bytes: 0xC3 0xA9.
var s = StringSpan("é")
var iter = s.bytes()
assert_equal(next(iter), Byte(0xC3))
assert_equal(next(iter), Byte(0xA9))
```

Returns: An iterator type that returns successive `Byte` values stored in this string span.

#### `StringSpan.codepoints`

```mojo
def codepoints(self) -> CodepointsIter[origin]
```

Returns an iterator over the `Codepoint`s encoded in this string span.

**Examples:**

Print the characters in a string:

```mojo
from std.testing import assert_equal, assert_raises

var s = StringSpan("abc")
var iter = s.codepoints()
assert_equal(iter.__next__(), Codepoint.ord("a"))
assert_equal(iter.__next__(), Codepoint.ord("b"))
assert_equal(iter.__next__(), Codepoint.ord("c"))
with assert_raises():
    _ = iter.__next__() # raises StopIteration
```

`codepoints()` iterates over Unicode codepoints, and supports multibyte
codepoints:

```mojo
from std.testing import assert_equal, assert_raises

# A visual character composed of a combining sequence of 2 codepoints.
var s = StringSpan("á")
assert_equal(s.byte_length(), 3)

var iter = s.codepoints()
assert_equal(iter.__next__(), Codepoint.ord("a"))
 # U+0301 Combining Acute Accent
assert_equal(iter.__next__().to_u32(), 0x0301)
with assert_raises():
    _ = iter.__next__() # raises StopIteration
```

Returns: An iterator type that returns successive `Codepoint` values stored in this string span.

#### `StringSpan.codepoint_slices`

```mojo
def codepoint_slices(self) -> CodepointSliceIter[origin]
```

Iterate over the string, returning immutable references.

Returns: An iterator of references to the string elements.

#### `StringSpan.codepoint_slices_reversed`

```mojo
def codepoint_slices_reversed(self) -> CodepointSliceIter[origin, False]
```

Iterates backwards over the string span, returning single-character slices.

Each returned slice points to a single Unicode codepoint encoded in the
underlying UTF-8 representation of this string span, starting from the end
and moving towards the beginning.

Returns: A reversed iterator of references to the string span elements.

#### `StringSpan.graphemes`

```mojo
def graphemes(self) -> GraphemeSliceIter[origin]
```

Return an iterator over the grapheme clusters in this string.

A grapheme cluster is what a user would typically think of as a
single "character" on screen. This handles combining marks, emoji
ZWJ sequences, flag emoji, Hangul syllables, and other
multi-codepoint clusters as defined by UAX #29.

Example:

```mojo
from std.testing import assert_equal
# "café" with combining accent: c, a, f, e + combining acute
var s = StringSpan("cafe\u{0301}")
var count = 0
for g in s.graphemes():
    count += 1
assert_equal(count, 4)
```

Returns: An iterator yielding each grapheme cluster as a `StringSpan`.

#### `StringSpan.graphemes_reversed`

```mojo
def graphemes_reversed(self) -> GraphemeSliceIter[origin, False]
```

Return an iterator over the grapheme clusters in this string, yielding them in reverse order.

See `graphemes()` for the definition of a grapheme cluster. Reverse
iteration is more expensive per element than forward iteration: the
UAX #29 state machine is forward-scanning, so each step backs up
to a guaranteed grapheme boundary (typically a line break or the
start of the string) and forward-scans from there.

Example:

```mojo
from std.testing import assert_equal

var s = StringSpan("abc")
var result = List[String]()
for g in s.graphemes_reversed():
    result.append(String(g))
assert_equal(len(result), 3)
assert_equal(result[0], "c")
assert_equal(result[1], "b")
assert_equal(result[2], "a")
```

Returns: A reverse iterator yielding each grapheme cluster as a `StringSpan`.

#### `StringSpan.grapheme_indices`

```mojo
def grapheme_indices(self) -> GraphemeIndicesIter[origin]
```

Return an iterator over grapheme clusters paired with their byte offsets.

Each yielded element is a `Tuple[Int, StringSpan]` where the first
element is the byte offset (relative to the start of this string)
at which the grapheme begins, and the second is the grapheme slice.

Mirrors the shape of Rust's `str::grapheme_indices`.

Example:

```mojo
from std.testing import assert_equal

# "café" decomposed: 'c','a','f','e' + combining acute (U+0301)
var s = StringSpan("cafe\u{0301}")
var offsets = List[Int]()
for off, _ in s.grapheme_indices():
    offsets.append(off)
# Offsets land at 0, 1, 2, 3; the 4th grapheme spans 3 bytes.
assert_equal(len(offsets), 4)
assert_equal(offsets[3], 3)
```

Returns: An iterator yielding `(byte_offset, grapheme)` pairs.

#### `StringSpan.split_at_grapheme`

```mojo
def split_at_grapheme(self, n: Int) -> Tuple[StringSpan[origin_of(origin)], StringSpan[origin_of(origin)]]
```

Split this string at the `n`-th grapheme-cluster boundary.

Returns two slices: the first covers grapheme clusters `[0, n)` and
the second covers `[n, count)` in a single forward pass.

`n == 0` yields `("", self)`; `n >= count_graphemes()` yields
`(self, "")`. Negative `n` is rejected in safe builds.

Example:

```mojo
from std.testing import assert_equal

var s = StringSpan("Hello, World!")
var prefix, suffix = s.split_at_grapheme(5)
assert_equal(prefix, "Hello")
assert_equal(suffix, ", World!")
```

Args:

- `n`: The grapheme-cluster boundary at which to split. Must be non-negative.

Returns: A tuple `(prefix, suffix)` of `StringSpan`s.

#### `StringSpan.count_graphemes`

```mojo
def count_graphemes(self) -> Int
```

Count the number of grapheme clusters in this string.

This is an O(n) operation that scans the full string to identify
grapheme cluster boundaries using UAX #29 rules.

Example:

```mojo
from std.testing import assert_equal
var s = StringSpan("Hello")
assert_equal(s.count_graphemes(), 5)
```

Returns: The number of grapheme clusters.

#### `StringSpan.as_bytes`

```mojo
def as_bytes(self) -> Span[UInt8, origin]
```

Get the sequence of encoded bytes of the underlying string.

Returns: A slice containing the underlying sequence of encoded bytes.

#### `StringSpan.unsafe_ptr`

```mojo
def unsafe_ptr(self) -> Pointer[UInt8, origin]
```

Gets a pointer to the first element of this string span.

Returns: A pointer pointing at the first element of this string span.

#### `StringSpan.byte_length`

```mojo
def byte_length(self) -> Int
```

Get the length of this string span in bytes.

Returns: The length of this string span in bytes.

#### `StringSpan.count_codepoints`

```mojo
def count_codepoints(self) -> Int
```

Calculates the length in Unicode codepoints encoded in the UTF-8 representation of this string.

This is an O(n) operation, where n is the length of the string, as it
requires scanning the full string contents.

Examples:

Query the length of a string, in bytes and Unicode codepoints:

```mojo
from std.testing import assert_equal

var s = StringSpan("ನಮಸ್ಕಾರ")
assert_equal(s.count_codepoints(), 7)
assert_equal(s.byte_length(), 21)
```

Strings containing only ASCII characters have the same byte and
Unicode codepoint length:

```mojo
from std.testing import assert_equal

var s = StringSpan("abc")
assert_equal(s.count_codepoints(), 3)
assert_equal(s.byte_length(), 3)
```

The character length of a string with visual combining characters is
the length in Unicode codepoints, not grapheme clusters:

```mojo
from std.testing import assert_equal

var s = StringSpan("á")
assert_equal(s.count_codepoints(), 2)
assert_equal(s.byte_length(), 3)
```

Notes:
This method needs to traverse the whole string to count, so it has
a performance hit compared to using the byte length.

Returns: The length in Unicode codepoints.

#### `StringSpan.is_codepoint_boundary`

```mojo
def is_codepoint_boundary(self, index: Int) -> Bool
```

Returns True if `index` is the position of the first byte in a UTF-8 codepoint sequence, or is at the end of the string.

A byte position is considered a codepoint boundary if a valid subslice
of the string would end (noninclusive) at `index`.

Positions `0` and `self.byte_length()` are considered to be codepoint boundaries.

Positions beyond the length of the string span will return False.

Examples:

Check if particular byte positions are codepoint boundaries:

```mojo
from std.testing import assert_equal, assert_true, assert_false
var abc = StringSpan("abc")
assert_equal(len(abc), 3)
assert_true(abc.is_codepoint_boundary(0))
assert_true(abc.is_codepoint_boundary(1))
assert_true(abc.is_codepoint_boundary(2))
assert_true(abc.is_codepoint_boundary(3))
```

Only the index of the first byte in a multi-byte codepoint sequence is
considered a codepoint boundary:

```mojo
var thumb = StringSpan("👍")
assert_equal(len(thumb), 4)
assert_true(thumb.is_codepoint_boundary(0))
assert_false(thumb.is_codepoint_boundary(1))
assert_false(thumb.is_codepoint_boundary(2))
assert_false(thumb.is_codepoint_boundary(3))
```

Visualization showing which bytes are considered codepoint boundaries,
within a piece of text that includes codepoints whose UTF-8
representation requires, respectively, 1, 2, 3, and 4-bytes. The
codepoint boundary byte indices are indicated by a vertical arrow (↑).

For example, this diagram shows that a slice of bytes formed by the
half-open range starting at byte 3 and extending up to but not including
byte 6 (`[3, 6)`) is a valid UTF-8 sequence.

```text
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                a©➇𝄞                  ┃ String
┣━━┳━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━━━━━┫
┃97┃  169  ┃   10119   ┃    119070     ┃ Unicode Codepoints
┣━━╋━━━┳━━━╋━━━┳━━━┳━━━╋━━━┳━━━┳━━━┳━━━┫
┃97┃194┃169┃226┃158┃135┃240┃157┃132┃158┃ UTF-8 Bytes
┗━━┻━━━┻━━━┻━━━┻━━━┻━━━┻━━━┻━━━┻━━━┻━━━┛
0  1   2   3   4   5   6   7   8   9  10
↑  ↑       ↑           ↑               ↑
```

The following program verifies the above diagram:

```mojo
from std.testing import assert_true, assert_false

var text = StringSpan("a©➇𝄞")
assert_true(text.is_codepoint_boundary(0))
assert_true(text.is_codepoint_boundary(1))
assert_false(text.is_codepoint_boundary(2))
assert_true(text.is_codepoint_boundary(3))
assert_false(text.is_codepoint_boundary(4))
assert_false(text.is_codepoint_boundary(5))
assert_true(text.is_codepoint_boundary(6))
assert_false(text.is_codepoint_boundary(7))
assert_false(text.is_codepoint_boundary(8))
assert_false(text.is_codepoint_boundary(9))
assert_true(text.is_codepoint_boundary(10))
```

Args:

- `index`: An index into the underlying byte representation of the string.

Returns: A boolean indicating if `index` gives the position of the first byte in a UTF-8 codepoint sequence, or is at the end of the string.

#### `StringSpan.startswith`

```mojo
def startswith(self, prefix: StringSpan, start: Int = Int(0), end: Int = Int(-1)) -> Bool
```

Verify if the `StringSpan` starts with the specified prefix between start and end positions.

The `start` and `end` positions must be offsets given in bytes, and
must be codepoint boundaries.

Args:

- `prefix`: The prefix to check.
- `start`: The start offset in bytes from which to check.
- `end`: The end offset in bytes up to which to check.

Returns: True if the `self[byte=start:end]` is prefixed by the input prefix.

#### `StringSpan.endswith`

```mojo
def endswith(self, suffix: StringSpan, start: Int = Int(0), end: Int = Int(-1)) -> Bool
```

Verify if the `StringSpan` end with the specified suffix between start and end positions.

The `start` and `end` positions must be offsets given in bytes, and
must be codepoint boundaries.

Args:

- `suffix`: The suffix to check.
- `start`: The start offset in bytes from which to check.
- `end`: The end offset in bytes up to which to check.

Returns: True if the `self[byte=start:end]` is suffixed by the input suffix.

#### `StringSpan.removeprefix`

```mojo
def removeprefix(self, prefix: StringSpan, /) -> Self
```

Returns a view of the string with the prefix removed if it was present.

Examples:

```mojo
print(StringSpan('TestHook').removeprefix('Test')) # 'Hook'
print(StringSpan('BaseTestCase').removeprefix('Test')) # 'BaseTestCase'
```

Args:

- `prefix`: The prefix to remove from the string.

Returns: `string[byte=prefix.byte_length():]` if the string starts with the prefix string, or a view of the whole string otherwise.

#### `StringSpan.removesuffix`

```mojo
def removesuffix(self, suffix: StringSpan, /) -> Self
```

Returns a view of the string with the suffix removed if it was present.

Examples:

```mojo
print(StringSpan('TestHook').removesuffix('Hook')) # 'Test'
print(StringSpan('BaseTestCase').removesuffix('Test')) # 'BaseTestCase'
```

Args:

- `suffix`: The suffix to remove from the string.

Returns: `string[byte=:(self.byte_length()-suffix.byte_length())]` if the string ends with the suffix string, or a view of the whole string otherwise.

#### `StringSpan.format`

```mojo
def format[*Ts: Writable](self, *args: *Ts.values) raises -> String
```

Produce a formatted string using the current string as a template.

The template, or "format string" can contain literal text and/or
replacement fields delimited with curly braces (`{}`). Returns a copy of
the format string with the replacement fields replaced with string
representations of the `args` arguments.

For more information, see the discussion in the
[`format` module](../../../std/collections/string/format.md).

Examples:

```mojo
# Manual indexing:
print(StringSpan("{0} {1} {0}").format("Mojo", 1.125)) # Mojo 1.125 Mojo
# Automatic indexing:
print(StringSpan("{} {}").format(True, "hello world")) # True hello world
```

Parameters:

- `*Ts`: The types of substitution values that implement `Writable`.

Args:

- `*args`: The substitution values.

Returns: The template with the given values substituted.

Raises: If the operation fails.

#### `StringSpan.find`

```mojo
def find(self, substr: StringSpan, start: Int = Int(0)) -> Int
```

Finds the offset in bytes of the first occurrence of `substr` starting at `start`. If not found, returns `-1`.

Args:

- `substr`: The substring to find.
- `start`: The offset in bytes from which to find.

Returns: The offset in bytes of `substr` relative to the beginning of the string.

#### `StringSpan.rfind`

```mojo
def rfind(self, substr: StringSpan, start: Int = Int(0)) -> Int
```

Finds the offset in bytes of the last occurrence of `substr` starting at `start`. If not found, returns `-1`.

Args:

- `substr`: The substring to find.
- `start`: The offset in bytes from which to find.

Returns: The offset in bytes of `substr` relative to the beginning of the string.

#### `StringSpan.is_ascii_whitespace`

```mojo
def is_ascii_whitespace[single_character: Bool = False](self) -> Bool
```

Determines whether every character in the given StringSpan is a python whitespace String. This corresponds to Python's [universal separators]( https://docs.python.org/3/library/stdtypes.html#str.splitlines):  `" \t\n\v\f\r\x1c\x1d\x1e\x85\u2028\u2029"`.

Example:

Check if a string contains only whitespace:

```mojo
from std.testing import assert_true, assert_false

# An empty string is not considered to contain only whitespace chars:
assert_false(StringSpan("").isspace())

# ASCII space characters
assert_true(StringSpan(" ").isspace())
assert_true(StringSpan("	").isspace())

# Contains non-space characters
assert_false(StringSpan(" abc  ").isspace())
```

Parameters:

- `single_character`: Whether to evaluate the `StringSpan` as a single unicode character (avoids overhead when already iterating).

Returns: True if the whole StringSpan is made up of whitespace characters listed above, otherwise False.

#### `StringSpan.split`

```mojo
def split(self, sep: StringSpan) -> List[StringSpan[origin_of(origin)]]
```

Split the string by a separator.

Examples:

```mojo
# Splitting a space
_ = StringSpan("hello world").split(" ") # ["hello", "world"]
# Splitting adjacent separators
_ = StringSpan("hello,,world").split(",") # ["hello", "", "world"]
# Splitting with starting or ending separators
_ = StringSpan(",1,2,3,").split(",") # ['', '1', '2', '3', '']
# Splitting with an empty separator
_ = StringSpan("123").split("") # ['', '1', '2', '3', '']
```

Args:

- `sep`: The string to split on.

Returns: A List of Strings containing the input split by the separator.

```mojo
def split(self, sep: StringSpan, maxsplit: Int) -> List[StringSpan[origin_of(origin)]]
```

Split the string by a separator.

Examples:
```mojo
# Splitting with maxsplit
_ = StringSpan("1,2,3").split(",", maxsplit=1) # ['1', '2,3']
# Splitting with starting or ending separators
_ = StringSpan(",1,2,3,").split(",", maxsplit=1) # ['', '1,2,3,']
# Splitting with an empty separator
_ = StringSpan("123").split("", maxsplit=1) # ['', '123']
```

Args:

- `sep`: The string to split on.
- `maxsplit`: The maximum amount of items to split from String.

Returns: A List of Strings containing the input split by the separator.

```mojo
def split(self, sep: NoneType = None) -> List[StringSpan[origin_of(origin)]]
```

Split the string by every Whitespace separator.

Examples:

```mojo
# Splitting an empty string or filled with whitespaces
_ = StringSpan("      ").split() # []
_ = StringSpan("").split() # []

# Splitting a string with leading, trailing, and middle whitespaces
_ = StringSpan("      hello    world     ").split() # ["hello", "world"]
# Splitting adjacent universal newlines:
_ = StringSpan(
    "hello \t\n\v\f\r\x1c\x1d\x1e\x85world"
).split()  # ["hello", "world"]
```

Args:

- `sep`: None.

Returns: A List of Strings containing the input split by the separator.

```mojo
def split(self, sep: NoneType = None, *, maxsplit: Int) -> List[StringSpan[origin_of(origin)]]
```

Split the string by every Whitespace separator.

Examples:
```mojo
# Splitting with maxsplit
_ = StringSpan("1     2  3").split(maxsplit=1) # ['1', '2  3']
```

Args:

- `sep`: None.
- `maxsplit`: The maximum amount of items to split from String.

Returns: A List of Strings containing the input split by the separator.

#### `StringSpan.isnewline`

```mojo
def isnewline[single_character: Bool = False](self) -> Bool
```

Determines whether every character in the given StringSpan is a python newline character. This corresponds to Python's [universal newlines:]( https://docs.python.org/3/library/stdtypes.html#str.splitlines) `"\r\n"` and `"\t\n\v\f\r\x1c\x1d\x1e\x85\u2028\u2029"`.

Parameters:

- `single_character`: Whether to evaluate the stringslice as a single unicode character (avoids overhead when already iterating).

Returns: True if the whole StringSpan is made up of whitespace characters listed above, otherwise False.

#### `StringSpan.splitlines`

```mojo
def splitlines(self, keepends: Bool = False) -> List[StringSpan[origin_of(origin)]]
```

Split the string at line boundaries. This corresponds to Python's [universal newlines:]( https://docs.python.org/3/library/stdtypes.html#str.splitlines) `"\r\n"` and `"\t\n\v\f\r\x1c\x1d\x1e\x85\u2028\u2029"`.

Args:

- `keepends`: If True, line breaks are kept in the resulting strings.

Returns: A List of Strings containing the input split by line boundaries.

#### `StringSpan.count`

```mojo
def count(self, substr: StringSpan) -> Int
```

Return the number of non-overlapping occurrences of substring `substr` in the string.

If sub is empty, returns the number of empty strings between characters
which is the length of the string plus one.

Args:

- `substr`: The substring to count.

Returns: The number of occurrences of `substr`.

#### `StringSpan.is_ascii_digit`

```mojo
def is_ascii_digit(self) -> Bool
```

A string is a digit string if all characters in the string are digits and there is at least one character in the string.

Note that this currently only works with ASCII strings.

Returns: True if all characters are digits and it's not empty else False.

#### `StringSpan.isupper`

```mojo
def isupper(self) -> Bool
```

Returns True if all cased characters in the string are uppercase and there is at least one cased character.

Returns: True if all cased characters in the string are uppercase and there is at least one cased character, False otherwise.

#### `StringSpan.islower`

```mojo
def islower(self) -> Bool
```

Returns True if all cased characters in the string are lowercase and there is at least one cased character.

Returns: True if all cased characters in the string are lowercase and there is at least one cased character, False otherwise.

#### `StringSpan.lower`

```mojo
def lower(self) -> String
```

Returns a copy of the string with all cased characters converted to lowercase.

Returns: A new string where cased letters have been converted to lowercase.

#### `StringSpan.upper`

```mojo
def upper(self) -> String
```

Returns a copy of the string with all cased characters converted to uppercase.

Returns: A new string where cased letters have been converted to uppercase.

#### `StringSpan.is_ascii_printable`

```mojo
def is_ascii_printable(self) -> Bool
```

Returns True if all characters in the string are ASCII printable.

Note that this currently only works with ASCII strings.

Returns: True if all characters are printable else False.

#### `StringSpan.ascii_rjust`

```mojo
def ascii_rjust(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> String
```

Returns the string span right justified in a string of specified width.

Pads the string span on the left with the specified fill character so
that the total (byte) length of the resulting string equals `width`. If the
original string span is already longer than or equal to `width`,
returns the string span unchanged (as a `String`).

Examples:

```mojo
var s = StringSpan("hello")
print(s.ascii_rjust(10))        # "     hello"
print(s.ascii_rjust(10, "*"))   # "*****hello"
print(s.ascii_rjust(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A right-justified string of (byte) length `width`, or the original string slice (as a `String`) if its length is already greater than or equal to `width`.

#### `StringSpan.ascii_ljust`

```mojo
def ascii_ljust(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> String
```

Returns the string span left justified in a string of specified width.

Pads the string span on the right with the specified fill character so
that the total byte length of the resulting string equals `width`. If the
original string span is already longer than or equal to `width`,
returns the string span unchanged (as a `String`).

Examples:

```mojo
var s = StringSpan("hello")
print(s.ascii_ljust(10))        # "hello     "
print(s.ascii_ljust(10, "*"))   # "hello*****"
print(s.ascii_ljust(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A left-justified string of (byte) length `width`, or the original string slice (as a `String`) if its length is already greater than or equal to `width`.

#### `StringSpan.ascii_center`

```mojo
def ascii_center(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> String
```

Returns the string span center justified in a string of specified width.

Pads the string span on both sides with the specified fill character so
that the total length of the resulting string equals `width`. If the
padding needed is odd, the extra character goes on the right side. If the
original string span is already longer than or equal to `width`,
returns the string span unchanged (as a `String`).

Examples:

```mojo
var s = StringSpan("hello")
print(s.ascii_center(10))        # "  hello   "
print(s.ascii_center(11, "*"))   # "***hello***"
print(s.ascii_center(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A center-justified string of length `width`, or the original string slice (as a `String`) if its length is already greater than or equal to `width`.

#### `StringSpan.join`

```mojo
def join[T: Writable & Copyable, //](self, elems: Span[T]) -> String
```

Joins string elements using the current string as a delimiter.

Notes:
- Defaults to writing directly to the string if the bytes
fit in an inline `String`, otherwise will process it by chunks.

Parameters:

- `T`: The type of the elements, must implement the `Copyable`, and `Writable` traits.

Args:

- `elems`: The input values.

Returns: The joined string.

## Functions

### `get_static_string`

```mojo
def get_static_string[string: StringSpan[ImmStaticOrigin], *extra: StringSpan[ImmStaticOrigin]]() -> StaticString
```

Form a StaticString from compile-time StringSpan values. This guarantees that the returned string is compile-time constant in static memory.  It also guarantees that there is a 'nul' zero byte at the end, which is not included in the returned range.

Parameters:

- `string`: The first StringSpan value.
- `*extra`: Additional StringSpan values to concatenate.

Returns: The string value as a StaticString.

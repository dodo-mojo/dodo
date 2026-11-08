# `std.builtin.string_literal`

Implements the StringLiteral struct.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `StringLiteral`

```mojo
struct StringLiteral[value: __mlir_type.`!kgen.string`]
```

This type represents a string literal.

String literals are all null-terminated for compatibility with C APIs, but
this is subject to change. String literals store their length as an integer,
and this does not include the null terminator.

Parameters:

- `value`: The underlying string value.

Implemented traits: `AnyType`, `Boolable`, `Copyable`, `Defaultable`, `Deinitable`, `FloatableRaising`, `ImplicitlyCopyable`, `IntableRaising`, `Movable`, `PathLike`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

#### `StringLiteral.__init__`

```mojo
def __init__() -> Self
```

Constructor for any value.

#### `StringLiteral.__bool__`

```mojo
def __bool__(self) -> Bool
```

Convert the string to a bool value.

Returns: True if the string is not empty.

#### `StringLiteral.__lt__`

```mojo
def __lt__(self, rhs: StringSpan) -> Bool
```

Compare this value to the RHS using lesser than (LT) comparison.

Args:

- `rhs`: The other value to compare against.

Returns: True if this is strictly less than the RHS and False otherwise.

#### `StringLiteral.__le__`

```mojo
def __le__(self, rhs: StringSpan) -> Bool
```

Compare this value to the RHS using lesser than or equal to (LE) comparison.

Args:

- `rhs`: The other value to compare against.

Returns: True if this is less than or equal to the RHS and False otherwise.

#### `StringLiteral.__eq__`

```mojo
def __eq__(self, rhs: StringSpan) -> Bool
```

Compare two string literals for equality.

Args:

- `rhs`: The string to compare.

Returns: True if they are equal.

#### `StringLiteral.__ne__`

```mojo
def __ne__(self, rhs: StringSpan) -> Bool
```

Compare two string literals for inequality.

Args:

- `rhs`: The string to compare.

Returns: True if they are not equal.

#### `StringLiteral.__gt__`

```mojo
def __gt__(self, rhs: StringSpan) -> Bool
```

Compare this value to the RHS using greater than (GT) comparison.

Args:

- `rhs`: The other value to compare against.

Returns: True if this is strictly greater than the RHS and False otherwise.

#### `StringLiteral.__ge__`

```mojo
def __ge__(self, rhs: StringSpan) -> Bool
```

Compare this value to the RHS using greater than or equal to (GE) comparison.

Args:

- `rhs`: The other value to compare against.

Returns: True if this is greater than or equal to the RHS and False otherwise.

#### `StringLiteral.__add__`

```mojo
def __add__(self, rhs: StringLiteral) -> StringLiteral[#pop.string_concat<value, *"rhs.value`2x">]
```

Concatenate two string literals.

Args:

- `rhs`: The string to concat.

Returns: The concatenated string.

#### `StringLiteral.__mul__`

```mojo
def __mul__(self, n: Int) -> String
```

Concatenates the string `n` times.

Args:

- `n`: The number of times to concatenate the string.

Returns: The string concatenated `n` times.

#### `StringLiteral.__int__`

```mojo
def __int__(self) raises -> Int
```

Parses the given string as a base-10 integer and returns that value.

Returns: An integer value that represents the string.

Raises: If the string cannot be parsed as a valid base-10 integer.

#### `StringLiteral.__float__`

```mojo
def __float__(self) raises -> Float64
```

Parses the string as a floating-point number and returns that value.

Returns: A float value that represents the string.

Raises: If the string cannot be parsed as a valid floating-point number.

#### `StringLiteral.__fspath__`

```mojo
def __fspath__(self) -> String
```

Return the file system path representation of the object.

Returns: The file system path representation as a string.

#### `StringLiteral.__iter__`

```mojo
def __iter__(self) -> GraphemeSliceIter[ImmStaticOrigin]
```

Iterate over the grapheme clusters in the string literal.

A grapheme cluster is what a user would typically think of as a
single "character" on screen, such as a base letter together with
any combining marks. See `graphemes()` for the precise definition.

To iterate by Unicode codepoint or by byte instead, use
`codepoints()`/`codepoint_slices()` or `as_bytes()`.

Returns: An iterator yielding each grapheme cluster as a `StringSlice`.

#### `StringLiteral.__reversed__`

```mojo
def __reversed__(self) -> GraphemeSliceIter[ImmStaticOrigin, False]
```

Iterate backwards over the grapheme clusters in the string literal.

See `graphemes()` for the definition of a grapheme cluster. Reverse
iteration is more expensive per element than forward iteration; see
`graphemes_reversed()` for details.

Returns: A reverse iterator yielding each grapheme cluster as a `StringSlice`.

#### `StringLiteral.byte_length`

```mojo
def byte_length(self) -> Int
```

Get the string length in bytes.

Notes:
This does not include the trailing null terminator in the count.

Returns: The length of this string in bytes.

#### `StringLiteral.count_codepoints`

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

var s = StringSlice("ನಮಸ್ಕಾರ")
assert_equal(s.count_codepoints(), 7)
assert_equal(s.byte_length(), 21)
```

Strings containing only ASCII characters have the same byte and
Unicode codepoint length:

```mojo
from std.testing import assert_equal

var s = StringSlice("abc")
assert_equal(s.count_codepoints(), 3)
assert_equal(s.byte_length(), 3)
```

The character length of a string with visual combining characters is
the length in Unicode codepoints, not grapheme clusters:

```mojo
from std.testing import assert_equal

var s = StringSlice("á")
assert_equal(s.count_codepoints(), 2)
assert_equal(s.byte_length(), 3)
```

Notes:
This method needs to traverse the whole string to count, so it has
a performance hit compared to using the byte length.

Returns: The length in Unicode codepoints.

#### `StringLiteral.ptr`

```mojo
def ptr(self) -> Pointer[UInt8, ImmStaticOrigin]
```

Get a pointer to the underlying data.

Returns: The pointer to the data.

#### `StringLiteral.as_c_string_span`

```mojo
def as_c_string_span(self) -> CStringSpan[ImmStaticOrigin]
```

Return a `CStringSpan` to the underlying memory of the string.

Returns: The `CStringSpan` of the string.

#### `StringLiteral.as_c_string_slice`

```mojo
def as_c_string_slice(self) -> CStringSpan[ImmStaticOrigin]
```

**Deprecated:** 'as_c_string_slice' is deprecated, use 'as_c_string_span' instead

Return a `CStringSpan` to the underlying memory of the string.

Returns: The `CStringSpan` of the string.

#### `StringLiteral.as_string_slice`

```mojo
def as_string_slice(self) -> StaticString
```

Returns a string slice of this static string literal.

Returns: A string slice pointing to this static string literal.

#### `StringLiteral.as_bytes`

```mojo
def as_bytes(self) -> Span[UInt8, ImmStaticOrigin]
```

Returns a contiguous Span of the bytes owned by this string.

Returns: A contiguous slice pointing to the bytes owned by this string.

#### `StringLiteral.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this string literal to the provided Writer.

Args:

- `writer`: The object to write to.

#### `StringLiteral.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Write the string representation of the string literal.

Args:

- `writer`: The value to write to.

#### `StringLiteral.find`

```mojo
def find(self, substr: StringSpan[ImmStaticOrigin], start: Int = Int(0)) -> Int
```

Finds the offset of the first occurrence of `substr` starting at `start`. If not found, returns -1.

Args:

- `substr`: The substring to find.
- `start`: The offset from which to find.

Returns: The offset of `substr` relative to the beginning of the string.

#### `StringLiteral.rfind`

```mojo
def rfind(self, substr: StringSpan[ImmStaticOrigin], start: Int = Int(0)) -> Int
```

Finds the offset of the last occurrence of `substr` starting at `start`. If not found, returns -1.

Args:

- `substr`: The substring to find.
- `start`: The offset from which to find.

Returns: The offset of `substr` relative to the beginning of the string.

#### `StringLiteral.count`

```mojo
def count(self, substr: StringSpan) -> Int
```

Return the number of non-overlapping occurrences of substring `substr` in the string literal.

If sub is empty, returns the number of empty strings between characters
which is the length of the string plus one.

Args:

- `substr`: The substring to count.

Returns: The number of occurrences of `substr`.

#### `StringLiteral.lower`

```mojo
def lower(self) -> String
```

Returns a copy of the string literal with all cased characters converted to lowercase.

Returns: A new string where cased letters have been converted to lowercase.

#### `StringLiteral.upper`

```mojo
def upper(self) -> String
```

Returns a copy of the string literal with all cased characters converted to uppercase.

Returns: A new string where cased letters have been converted to uppercase.

#### `StringLiteral.ascii_rjust`

```mojo
def ascii_rjust(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> String
```

Returns the string literal right justified in a string of specified width.

Pads the string literal on the left with the specified fill character so
that the total byte length of the resulting string equals `width`. If the
original string literal is already longer than or equal to `width`,
returns the string literal unchanged (as a `String`).

Examples:

```mojo
var s = "hello"
print(s.ascii_rjust(10))        # "     hello"
print(s.ascii_rjust(10, "*"))   # "*****hello"
print(s.ascii_rjust(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A right-justified string of byte length `width`, or the original string literal (as a `String`) if its length is already greater than or equal to `width`.

#### `StringLiteral.ascii_ljust`

```mojo
def ascii_ljust(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> String
```

Returns the string literal left justified in a string of specified width.

Pads the string literal on the right with the specified fill character so
that the total byte length of the resulting string equals `width`. If the
original string literal is already longer than or equal to `width`,
returns the string literal unchanged (as a `String`).

Examples:

```mojo
var s = "hello"
print(s.ascii_ljust(10))        # "hello     "
print(s.ascii_ljust(10, "*"))   # "hello*****"
print(s.ascii_ljust(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A left-justified string of (byte) length `width`, or the original string literal (as a `String`) if its length is already greater than or equal to `width`.

#### `StringLiteral.ascii_center`

```mojo
def ascii_center(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> String
```

Returns the string literal center justified in a string of specified width.

Pads the string literal on both sides with the specified fill character so
that the total length of the resulting string equals `width`. If the
padding needed is odd, the extra character goes on the right side. If the
original string literal is already longer than or equal to `width`,
returns the string literal unchanged (as a `String`).

Examples:

```mojo
var s = "hello"
print(s.ascii_center(10))        # "  hello   "
print(s.ascii_center(11, "*"))   # "***hello***"
print(s.ascii_center(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A center-justified string of length `width`, or the original string literal (as a `String`) if its length is already greater than or equal to `width`.

#### `StringLiteral.startswith`

```mojo
def startswith(self, prefix: StringSpan, start: Int = Int(0), end: Int = Int(-1)) -> Bool
```

Checks if the string literal starts with the specified prefix between start and end positions. Returns True if found and False otherwise.

Args:

- `prefix`: The prefix to check.
- `start`: The start byte offset from which to check.
- `end`: The end byte offset up to which to check.

Returns: True if the `self[byte=start:end]` is prefixed by the input prefix.

#### `StringLiteral.endswith`

```mojo
def endswith(self, suffix: StringSpan, start: Int = Int(0), end: Int = Int(-1)) -> Bool
```

Checks if the string literal end with the specified suffix between start and end positions. Returns True if found and False otherwise.

Args:

- `suffix`: The suffix to check.
- `start`: The start byte offset from which to check.
- `end`: The end byte offset up to which to check.

Returns: True if the `self[byte=start:end]` is suffixed by the input suffix.

#### `StringLiteral.is_ascii_digit`

```mojo
def is_ascii_digit(self) -> Bool
```

Returns True if all characters in the string literal are ASCII digits.

Note that this currently only works with ASCII strings.

Returns: True if all characters are digits else False.

#### `StringLiteral.isupper`

```mojo
def isupper(self) -> Bool
```

Returns True if all cased characters in the string literal are uppercase and there is at least one cased character.

Note that this currently only works with ASCII strings.

Returns: True if all cased characters in the string literal are uppercase and there is at least one cased character, False otherwise.

#### `StringLiteral.islower`

```mojo
def islower(self) -> Bool
```

Returns True if all cased characters in the string literal are lowercase and there is at least one cased character.

Note that this currently only works with ASCII strings.

Returns: True if all cased characters in the string literal are lowercase and there is at least one cased character, False otherwise.

#### `StringLiteral.strip`

```mojo
def strip(self) -> StaticString
```

Returns a view of the string literal with leading and trailing whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Returns: A `StaticString` into the literal with no leading or trailing whitespaces.

```mojo
def strip(self, chars: StringSpan) -> StaticString
```

Returns a view of the string literal with leading and trailing characters removed.

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A `StaticString` into the literal with no leading or trailing characters.

#### `StringLiteral.rstrip`

```mojo
def rstrip(self, chars: StringSpan) -> StaticString
```

Returns a view of the string literal with trailing characters removed.

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A `StaticString` into the literal with no trailing characters.

```mojo
def rstrip(self) -> StaticString
```

Returns a view of the string literal with trailing whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Returns: A `StaticString` into the literal with no trailing whitespaces.

#### `StringLiteral.lstrip`

```mojo
def lstrip(self, chars: StringSpan) -> StaticString
```

Returns a view of the string literal with leading characters removed.

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A `StaticString` into the literal with no leading characters.

```mojo
def lstrip(self) -> StaticString
```

Returns a view of the string literal with leading whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Returns: A `StaticString` into the literal with no leading whitespaces.

#### `StringLiteral.codepoint_slices`

```mojo
def codepoint_slices(self) -> CodepointSliceIter[ImmStaticOrigin]
```

Iterate over the string's codepoints as immutable slices.

Returns: An iterator of codepoint slices.

#### `StringLiteral.codepoint_slices_reversed`

```mojo
def codepoint_slices_reversed(self) -> CodepointSliceIter[ImmStaticOrigin, False]
```

Iterates backwards over the string literal, returning single-character slices.

Each returned slice points to a single Unicode codepoint encoded in the
underlying UTF-8 representation of this string literal, starting from the end
and moving towards the beginning.

Returns: A reversed iterator of references to the string literal elements.

#### `StringLiteral.codepoints`

```mojo
def codepoints(self) -> CodepointsIter[ImmStaticOrigin]
```

Iterate over the `Codepoint`s in this string constant.

Returns: An iterator over successive `Codepoint` values.

#### `StringLiteral.graphemes`

```mojo
def graphemes(self) -> GraphemeSliceIter[ImmStaticOrigin]
```

Return an iterator over the grapheme clusters in this string.

A grapheme cluster is what a user would typically think of as a
single "character" on screen.

Returns: An iterator yielding each grapheme cluster as a `StringSlice`.

#### `StringLiteral.graphemes_reversed`

```mojo
def graphemes_reversed(self) -> GraphemeSliceIter[ImmStaticOrigin, False]
```

Return an iterator over the grapheme clusters in this string, yielding them in reverse order.

See `graphemes()` for the definition of a grapheme cluster.

Returns: A reverse iterator yielding each grapheme cluster as a `StringSlice`.

#### `StringLiteral.format`

```mojo
def format[*Ts: Writable](self, *args: *Ts.values) -> String
```

Produce a formatted string using the current string as a template.

The template, or "format string" can contain literal text and/or
replacement fields delimited with curly braces (`{}`). Returns a copy of
the format string with the replacement fields replaced with string
representations of the `args` arguments.

For more information, see the discussion in the
[`format` module](../../std/collections/string/format.md).

Example:

```mojo
# Manual indexing:
print("{0} {1} {0}".format("Mojo", 1.125)) # Mojo 1.125 Mojo
# Automatic indexing:
print("{} {}".format(True, "hello world")) # True hello world
```

Parameters:

- `*Ts`: The types of substitution values that implement `Writable`.

Args:

- `*args`: The substitution values.

Returns: The template with the given values substituted.

#### `StringLiteral.join`

```mojo
def join[T: Writable & Copyable, //](self, elems: Span[T]) -> String
```

Joins string elements using the current string as a delimiter. Defaults to writing to the stack if total bytes of `elems` is less than `buffer_size`, otherwise will allocate once to the heap and write directly into that. The `buffer_size` defaults to 4096 bytes to match the default page size on arm64 and x86-64.

Parameters:

- `T`: The type of the elements. Must implement the `Copyable`, and `Writable` traits.

Args:

- `elems`: The input values.

Returns: The joined string.

#### `StringLiteral.split`

```mojo
def split(self, sep: StringSpan) -> List[StringSpan[ImmStaticOrigin]]
```

Split the string by a separator.

Examples:

```mojo
# Splitting a space
_ = StringSlice("hello world").split(" ") # ["hello", "world"]
# Splitting adjacent separators
_ = StringSlice("hello,,world").split(",") # ["hello", "", "world"]
# Splitting with starting or ending separators
_ = StringSlice(",1,2,3,").split(",") # ['', '1', '2', '3', '']
# Splitting with an empty separator
_ = StringSlice("123").split("") # ['', '1', '2', '3', '']
```

Args:

- `sep`: The string to split on.

Returns: A List of Strings containing the input split by the separator.

```mojo
def split(self, sep: StringSpan, maxsplit: Int) -> List[StringSpan[ImmStaticOrigin]]
```

Split the string by a separator.

Examples:
```mojo
# Splitting with maxsplit
_ = StringSlice("1,2,3").split(",", maxsplit=1) # ['1', '2,3']
# Splitting with starting or ending separators
_ = StringSlice(",1,2,3,").split(",", maxsplit=1) # ['', '1,2,3,']
# Splitting with an empty separator
_ = StringSlice("123").split("", maxsplit=1) # ['', '123']
```

Args:

- `sep`: The string to split on.
- `maxsplit`: The maximum amount of items to split from String.

Returns: A List of Strings containing the input split by the separator.

```mojo
def split(self, sep: NoneType = None) -> List[StringSpan[ImmStaticOrigin]]
```

Split the string by every Whitespace separator.

Examples:

```mojo
# Splitting an empty string or filled with whitespaces
_ = StringSlice("      ").split() # []
_ = StringSlice("").split() # []

# Splitting a string with leading, trailing, and middle whitespaces
_ = StringSlice("      hello    world     ").split() # ["hello", "world"]
# Splitting adjacent universal newlines:
_ = StringSlice(
    "hello \t\n\v\f\r\x1c\x1d\x1e\x85world"
).split()  # ["hello", "world"]
```

Args:

- `sep`: None.

Returns: A List of Strings containing the input split by the separator.

```mojo
def split(self, sep: NoneType = None, *, maxsplit: Int) -> List[StringSpan[ImmStaticOrigin]]
```

Split the string by every Whitespace separator.

Examples:
```mojo
# Splitting with maxsplit
_ = StringSlice("1     2  3").split(maxsplit=1) # ['1', '2  3']
```

Args:

- `sep`: None.
- `maxsplit`: The maximum amount of items to split from String.

Returns: A List of Strings containing the input split by the separator.

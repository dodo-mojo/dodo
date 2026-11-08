# `std.collections.string.string`

Implements the core `String` type and related utilities.

## Structs

### `String`

```mojo
struct String
```

Represents a mutable string.

This is Mojo's primary text representation, designed to efficiently handle
UTF-8 encoded text while providing a safe and ergonomic interface for
string manipulation.

You can create a `String` by assigning a string literal to a variable or
with the `String` constructor:

```mojo
# From string literals (String type is inferred)
var hello = "Hello"

# From String constructor
var world = String("World")
print(hello, world)    # "Hello World"
```

You can convert many Mojo types to a `String` because it's common to
implement the [`Writable`](../../../std/format/index.md#writable) trait:

```mojo
var int : Int = 42
print(String(int))    # "42"
```

If you have a custom type you want to convert to a string, you can implement
the [`Writable`](../../../std/format/index.md#writable) trait like this:

```mojo
@fieldwise_init
struct Person(Writable):
    var name: String
    var age: Int

    def write_to(self, mut writer: Some[Writer]):
        t"{self.name} ({self.age})".write_to(writer)

var person = Person("Alice", 30)
print(String(person))      # => Alice (30)
```

However, `print()` doesn't actually specify `String` as its argument type.
Instead, it accepts any type that conforms to the
[`Writable`](../../../std/format/index.md#writable) trait (`String` conforms to
this trait, which is why you can pass it to `print()`). That means it's
actually more efficient to pass any type that implements `Writable`
directly to `print()` (instead of first converting it to `String`).
For example, float types are also writable:

```mojo
var float : Float32 = 3.14
print(float)
```

Be aware of the following characteristics when working with `String`:

- **UTF-8 encoding**: Strings store UTF-8 encoded text, so byte length may
  differ from character count. Use `text.count_codepoints()` to get
  the codepoint count:

  ```mojo
  var text = "café"                # 4 Unicode characters
  print(text.byte_length())        # Prints 5 (é is 2 bytes in UTF-8)
  print(text.count_codepoints())   # Prints 4 (correct Unicode count)
  ```

- **Always mutable**: You can modify strings in-place:

  ```mojo
  var message = "Hello"
  message += " World"        # In-place concatenation
  print(message)             # "Hello World"
  ```

  If you want a compile-time immutable string, use `comptime`:

  ```mojo
  comptime GREETING = "Immutable string"  # Fixed at compile time
  GREETING = "Not gonna happen"        # error: expression must be mutable in assignment
  ```

- **Value semantics**: String assignment creates a copy, but it's optimized
with copy-on-write so that the actual copying happens only if/when one of
the strings is modified.

  ```mojo
  var str1 = "Hello"
  var str2 = str1            # Currently references the same data
  str2 += " World"           # Now str2 becomes a copy of str1
  print(str1)                # "Hello"
  print(str2)                # "Hello World"
  ```

More examples:

```mojo
var text = "Hello"

# String properties and indexing
print(text.byte_length())                 # 5
print(text[byte=1])                       # e (byte slice)
print(text[byte=text.byte_length() - 1])  # o (last character)

# In-place concatenation
text += " World"
print(text)

# Searching and checking
if "World" in text:
    print("Found 'World' in text")

var pos = text.find("World")
if pos != -1:
    print("'World' found at position:", pos)

# String replacement
var replaced = text.replace("Hello", "Hi")   # "Hi World"
print(replaced)

# String formatting
var name = "Alice"
var age = 30
var formatted = "{} is {} years old".format(name, age)
print(formatted)    # "Alice is 30 years old"
```

Related functions:

- String-to-number conversions:
  [`atof()`](../../../std/collections/string/string.md#atof),
  [`atol()`](../../../std/collections/string/string.md#atol)).
- Character code conversions:
  [`chr()`](../../../std/collections/string/string.md#chr),
  [`ord()`](../../../std/collections/string/string.md#ord)).
- String formatting:
  [`format()`](../../../std/collections/string/string.md#stringformat).

Related types:

- [`StringSpan`](../../../std/collections/string/string_span.md#stringspan): A non-owning
  view of string data, which can be either mutable or immutable.
- [`StaticString`](../../../std/collections/string/string_span.md#staticstring): An
  alias for an immutable constant `StringSpan`.
- [`StringLiteral`](../../../std/builtin/string_literal.md#stringliteral): A
  string literal. String literals are compile-time values.

Implemented traits: `AnyType`, `Boolable`, `Comparable`, `ConvertibleFromPython`, `Copyable`, `Defaultable`, `Deinitable`, `Equatable`, `FloatableRaising`, `Hashable`, `ImplicitlyCopyable`, `IntableRaising`, `Movable`, `PathLike`, `Writable`, `Writer`

Aliases:

- `ASCII_LOWERCASE = "abcdefghijklmnopqrstuvwxyz"`: All lowercase ASCII letters.
- `ASCII_UPPERCASE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"`: All uppercase ASCII letters.
- `ASCII_LETTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"`: All ASCII letters (lowercase and uppercase).
- `DIGITS = "0123456789"`: All decimal digit characters.
- `HEX_DIGITS = "0123456789abcdefABCDEF"`: All hexadecimal digit characters.
- `OCT_DIGITS = "01234567"`: All octal digit characters.
- `PUNCTUATION = "!\22#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"`: All ASCII punctuation characters.
- `PRINTABLE = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\22#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\v\f"`: All printable ASCII characters.
- `INLINE_CAPACITY = (Int((mul (bit_width_of[DType.int]() // Int(8)), 3)) - Int(1))`: Maximum bytes for inline (SSO) string storage.
- `FLAG_HAS_NUL_TERMINATOR = (Int(1) << Int((add bit_width_of[DType.int](), -3)))`: Flag indicating string has accessible nul terminator.
- `FLAG_IS_REF_COUNTED = (Int(1) << Int((add bit_width_of[DType.int](), -2)))`: Flag indicating string uses reference-counted storage.
- `FLAG_IS_INLINE = (Int(1) << Int((add bit_width_of[DType.int](), -1)))`: Flag indicating string uses inline (SSO) storage.
- `INLINE_LENGTH_START = (bit_width_of[DType.int]() - Int(8))`: Bit position where inline length field starts.
- `INLINE_LENGTH_MASK = (Int(31) << Int((add bit_width_of[DType.int](), -8)))`: Bit mask for extracting inline string length.
- `REF_COUNT_SIZE = size_of[Atomic[Int]]()`: Size of the reference count prefix for heap strings.

#### `String.__init__`

```mojo
def __init__(out self)
```

Construct an empty string.

```mojo
def __init__(out self, *, capacity_bytes: Int)
```

Construct an empty string with at least a given capacity.

Args:

- `capacity_bytes`: The minimum capacity (in bytes) to allocate.

```mojo
def __init__(out self, data: StringSpan[ImmStaticOrigin], /)
```

Construct a `String` from a `StaticString` without allocating.

Args:

- `data`: The static constant string to refer to.

```mojo
def __init__(out self, data: StringLiteral, /)
```

Construct a `String` from a `StringLiteral` without allocating.

Args:

- `data`: The static constant string to refer to.

```mojo
def __init__(out self, tstring: TString)
```

Construct a string from a TString (template string).

This constructor enables explicit conversion from TString to String.

Args:

- `tstring`: The TString to convert to a String.

```mojo
def __init__(out self, *, unsafe_from_utf8: Span[UInt8])
```

Construct a string by copying the data. This constructor is explicit because it can involve memory allocation.

Consider using the `String(from_utf8=...)` or
`String(from_utf8_lossy=...)` constructors instead, as they are safer
alternatives to the `unsafe_from_utf8` constructor.

Safety:
`unsafe_from_utf8` MUST be valid UTF-8 encoded data.

Args:

- `unsafe_from_utf8`: The utf8 bytes to copy.

```mojo
def __init__(out self, *, from_utf8_lossy: Span[UInt8])
```

Construct a string from a span of bytes, including invalid UTF-8.

Since `String` is guaranteed to be valid UTF-8, invalid UTF-8 sequences
are replaced with the `U+FFFD` replacement character: `�`.

Examples:

```mojo
from std.testing import assert_equal

# Valid UTF-8 sequence
var fire_emoji_bytes = [Byte(0xF0), 0x9F, 0x94, 0xA5]
var fire_emoji = String(from_utf8_lossy=fire_emoji_bytes)
assert_equal(fire_emoji, "🔥")

# Invalid UTF-8 sequence
# "mojo<invalid sequence>"
var mojo_bytes = [Byte(0x6D), 0x6F, 0x6A, 0x6F, 0xF0, 0x90, 0x80]
var mojo = String(from_utf8_lossy=mojo_bytes)
assert_equal(mojo, "mojo�")
```

Args:

- `from_utf8_lossy`: The bytes to convert to a string.

```mojo
def __init__(out self, *, from_utf8: Span[UInt8]) raises
```

Construct a string from a span of bytes, raising an error if the data is not valid UTF-8.

Args:

- `from_utf8`: The bytes to convert to a string.

Raises: An error if the data is not valid UTF-8.

```mojo
def __init__[*Ts: Writable](out self, *args: *Ts.values, *, sep: StringSpan[ImmStaticOrigin] = StringSpan(""), end: StringSpan[ImmStaticOrigin] = StringSpan(""))
```

Construct a string by concatenating a sequence of Writable arguments.

Examples:

Construct a String from several `Writable` arguments:

```mojo
var string = String(1, 2.0, "three", sep=", ")
print(string) # "1, 2.0, three"
```

Forwarding from another variadic function:

```mojo
def variadic_pack_to_string[*Ts: Writable](*args: *Ts) -> String:
    return String(*args)

_ = variadic_pack_to_string(1, ", ", 2.0, ", ", "three")
```

Parameters:

- `*Ts`: Types of the provided argument sequence.

Args:

- `*args`: A sequence of Writable arguments.
- `sep`: The separator used between elements.
- `end`: The String to write after printing the elements.

```mojo
def __init__(out self, *, unsafe_uninit_length: Int)
```

Construct a String with the specified length, with uninitialized memory. This is unsafe, as it relies on the caller initializing the elements with unsafe operations, not assigning over the uninitialized data.

Args:

- `unsafe_uninit_length`: The number of bytes to allocate.

```mojo
def __init__(out self, *, unsafe_from_utf8_ptr: Pointer[Scalar[_c_char_dtype()]])
```

Creates a string from a UTF-8 encoded nul-terminated pointer.

Safety:
- `unsafe_from_utf8_ptr` MUST be valid UTF-8 encoded data.
- `unsafe_from_utf8_ptr` MUST be null terminated.

Args:

- `unsafe_from_utf8_ptr`: A `Pointer[Byte]` of null-terminated bytes encoded in UTF-8.

```mojo
def __init__(out self, *, unsafe_from_utf8_ptr: Pointer[UInt8])
```

Creates a string from a UTF-8 encoded nul-terminated pointer.

Safety:
- `unsafe_from_utf8_ptr` MUST be valid UTF-8 encoded data.
- `unsafe_from_utf8_ptr` MUST be null terminated.

Args:

- `unsafe_from_utf8_ptr`: A `Pointer[Byte]` of null-terminated bytes encoded in UTF-8.

```mojo
def __init__(out self, *, copy: Self)
```

Copy initialize the string from another string.

Args:

- `copy`: The string to copy.

```mojo
def __init__(out self, *, py: PythonObject) raises
```

Construct a `String` from a PythonObject.

Args:

- `py`: The PythonObject to convert from.

Raises: An error if the conversion failed.

#### `String.__deinit__`

```mojo
def __deinit__(deinit self)
```

Destroy the string data.

#### `String.__bool__`

```mojo
def __bool__(self) -> Bool
```

Checks if the string is not empty.

Returns: True if the string length is greater than zero, and False otherwise.

#### `String.__getitem__`

```mojo
def __getitem__(self, *, byte: Int) -> StringSpan[origin_of(self["bytes"])]
```

Gets a single byte at the specified byte index.

This performs byte-level indexing, not character (codepoint) indexing.
For strings containing multi-byte UTF-8 characters `byte` must fall on
a codepoint boundary and an entire codepoint will be returned.
Aborts if `byte` does not fall on a codepoint boundary.

Args:

- `byte`: The byte index (0-based).

Returns: A StringSlice containing a single byte at the specified position.

```mojo
def __getitem__[I: Indexer, //](self, *, byte: I) -> StringSpan[origin_of(self["bytes"])]
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

Returns: A StringSlice containing a single byte at the specified position.

```mojo
def __getitem__(self, *, byte: IntLiteral) -> StringSpan[origin_of(self["bytes"])]
```

Gets a single byte at the specified byte index.

This performs byte-level indexing, not character (codepoint) indexing.
For strings containing multi-byte UTF-8 characters `byte` must fall on
a codepoint boundary and an entire codepoint will be returned.
Aborts if `byte` does not fall on a codepoint boundary.

Args:

- `byte`: The byte index (0-based).

Returns: A StringSlice containing a single byte at the specified position.

```mojo
def __getitem__(self, *, byte: ContiguousSlice) -> StringSpan[origin_of(self["bytes"])]
```

Gets a substring at the specified byte positions.

This performs byte-level slicing, not character (codepoint) slicing.
The start and end positions are byte indices. For strings containing
multi-byte UTF-8 characters, slicing at byte positions that do not fall
on codepoint boundaries will abort.

Aborts if `byte`'s start or end index is out of bounds (valid range
is `0` to `self.byte_length()`, inclusive), or if start is greater
than end. Negative indices are not supported and always abort.

Args:

- `byte`: A slice that specifies byte positions of the new substring.

Returns: A StringSlice containing the bytes in the specified range.

```mojo
def __getitem__[I: Indexer, //](self, *, codepoint: I) -> StringSpan[origin_of(self["bytes"])]
```

Gets the character at the specified position.

Parameters:

- `I`: A type that can be used as an index.

Args:

- `codepoint`: The codepoint index.

Returns: A `StringSlice` view containing the unicode codepoint at the specified position.

```mojo
def __getitem__(self, *, codepoint: ContiguousSlice) -> StringSpan[origin_of(self["bytes"])]
```

Gets a substring at the specified codepoint positions.

Args:

- `codepoint`: A slice that specifies codepoint positions of the new substring.

Returns: A StringSlice containing the codepoints in the specified range.

```mojo
def __getitem__(self, *, grapheme: T) -> StringSpan[origin_of(self["bytes"])]
```

Gets the character at the specified position.

Args:

- `grapheme`: The grapheme index.

Returns: A `StringSlice` view containing the unicode grapheme at the specified position.

#### `String.__lt__`

```mojo
def __lt__(self, rhs: Self) -> Bool
```

Compare this String to the RHS using LT comparison.

Args:

- `rhs`: The other String to compare against.

Returns: True if this String is strictly less than the RHS String and False otherwise.

#### `String.__eq__`

```mojo
def __eq__(self, rhs: Self) -> Bool
```

Compares two Strings if they have the same values.

Args:

- `rhs`: The rhs of the operation.

Returns: True if the Strings are equal and False otherwise.

```mojo
def __eq__(self, other: StringSpan) -> Bool
```

Compares two Strings if they have the same values.

Args:

- `other`: The rhs of the operation.

Returns: True if the Strings are equal and False otherwise.

#### `String.__ne__`

```mojo
def __ne__(self, other: StringSpan) -> Bool
```

Compares two Strings if they have the same values.

Args:

- `other`: The rhs of the operation.

Returns: True if the Strings are equal and False otherwise.

#### `String.__contains__`

```mojo
def __contains__(self, substr: StringSpan) -> Bool
```

Returns True if the substring is contained within the current string.

Args:

- `substr`: The substring to check.

Returns: True if the string contains the substring.

#### `String.__add__`

```mojo
def __add__(self, other: StringSpan) -> Self
```

Creates a string by appending a string slice at the end.

Args:

- `other`: The string slice to append.

Returns: The new constructed string.

#### `String.__mul__`

```mojo
def __mul__(self, n: Int) -> Self
```

Concatenates the string `n` times.

Args:

- `n`: The number of times to concatenate the string.

Returns: The string concatenated `n` times.

#### `String.__radd__`

```mojo
def __radd__(self, other: StringSpan) -> Self
```

Creates a string by prepending another string slice to the start.

Args:

- `other`: The string to prepend.

Returns: The new constructed string.

#### `String.__iadd__`

```mojo
def __iadd__(mut self, other: StringSpan)
```

Appends another string slice to this string.

Args:

- `other`: The string to append.

#### `String.write`

```mojo
def write[*Ts: Writable](mut self, *args: *Ts.values)
```

Write a sequence of Writable arguments to the provided Writer.

Parameters:

- `*Ts`: Types of the provided argument sequence.

Args:

- `*args`: Sequence of arguments to write to this Writer.

```mojo
def write[T: Writable](mut self, value: T)
```

Write a single Writable argument to the provided Writer.

Parameters:

- `T`: The type of the value to write, which must implement `Writable`.

Args:

- `value`: The `Writable` argument to write.

#### `String.capacity_bytes`

```mojo
def capacity_bytes(self) -> Int
```

Get the current capacity of the `String`'s internal buffer.

Returns: The number of bytes that can be stored before reallocation is needed.

#### `String.write_string`

```mojo
def write_string(mut self, string: StringSpan)
```

Write a `StringSlice` to this `String`.

Args:

- `string`: The `StringSlice` to write to this String.

#### `String.append`

```mojo
def append(mut self, codepoint: Codepoint)
```

Append a codepoint to the string.

Args:

- `codepoint`: The codepoint to append.

#### `String.__iter__`

```mojo
def __iter__(self) -> GraphemeSliceIter[origin_of(self)]
```

Iterate over the grapheme clusters in the string.

A grapheme cluster is what a user would typically think of as a
single "character" on screen. See `graphemes()` for the precise
definition.

To iterate by Unicode codepoint or by byte instead, use
`codepoints()`/`codepoint_slices()` or `bytes()`.

Returns: An iterator yielding each grapheme cluster as a `StringSlice`.

#### `String.__reversed__`

```mojo
def __reversed__(self) -> GraphemeSliceIter[origin_of(self), False]
```

Iterate backwards over the grapheme clusters in the string.

A grapheme cluster is what a user would typically think of as a
single "character" on screen. See `graphemes()` for the precise
definition.

Returns: A reverse iterator yielding each grapheme cluster as a `StringSlice`.

#### `String.__fspath__`

```mojo
def __fspath__(self) -> Self
```

Return the file system path representation (just the string itself).

Returns: The file system path representation as a string.

#### `String.write_to`

```mojo
def write_to(self, mut writer: T)
```

Formats this string to the provided Writer.

Args:

- `writer`: The object to write to.

#### `String.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Formats this string slice to the provided `Writer`.

Notes:
Mojo's repr always prints single quotes (`'`) at the start and end
of the repr. Any single quote inside a string should be escaped
(`\'`).

Args:

- `writer`: The object to write to.

#### `String.join`

```mojo
def join[T: Writable & Copyable](self, elems: Span[T]) -> Self
```

Joins string elements using the current string as a delimiter. Defaults to writing to the stack if total bytes of `elems` is less than `buffer_size`, otherwise will allocate once to the heap and write directly into that. The `buffer_size` defaults to 4096 bytes to match the default page size on arm64 and x86-64.

Notes:
- Defaults to writing directly to the string if the bytes
fit in an inline `String`, otherwise will process it by chunks.
- The `buffer_size` defaults to 4096 bytes to match the default
page size on arm64 and x86-64, but you can increase this if you're
joining a very large `List` of elements to write into the stack
instead of the heap.

Parameters:

- `T`: The type of the elements. Must implement the `Copyable`, and `Writable` traits.

Args:

- `elems`: The input values.

Returns: The joined string.

#### `String.bytes`

```mojo
def bytes(self) -> BytesIter[origin_of(self)]
```

Returns an iterator over the raw UTF-8 bytes of this string.

Unlike `codepoints()` and `graphemes()`, this iterator operates at the
byte level and yields individual `Byte` values without interpreting
multi-byte UTF-8 sequences.

Examples:

Iterate over the bytes of an ASCII string:

```mojo
from std.testing import assert_equal, assert_raises

var s = String("abc")
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
var s = String("é")
var iter = s.bytes()
assert_equal(next(iter), Byte(0xC3))
assert_equal(next(iter), Byte(0xA9))
```

Returns: An iterator type that returns successive `Byte` values stored in this string.

#### `String.codepoints`

```mojo
def codepoints(self) -> CodepointsIter[origin_of(self)]
```

Returns an iterator over the `Codepoint`s encoded in this string slice.

Examples:

Print the characters in a string:

```mojo
from std.testing import assert_equal, assert_raises

var s = "abc"
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
var s = "á"
assert_equal(s.byte_length(), 3)

var iter = s.codepoints()
assert_equal(iter.__next__(), Codepoint.ord("a"))
 # U+0301 Combining Acute Accent
assert_equal(iter.__next__().to_u32(), 0x0301)
with assert_raises():
    _ = iter.__next__() # raises StopIteration
```

Returns: An iterator type that returns successive `Codepoint` values stored in this string slice.

#### `String.codepoint_slices`

```mojo
def codepoint_slices(self) -> CodepointSliceIter[origin_of(self)]
```

Returns an iterator over single-character slices of this string.

Each returned slice points to a single Unicode codepoint encoded in the
underlying UTF-8 representation of this string.

Examples:

Iterate over the character slices in a string:

```mojo
from std.testing import assert_equal, assert_raises, assert_true

var s = "abc"
var iter = s.codepoint_slices()
assert_true(iter.__next__() == "a")
assert_true(iter.__next__() == "b")
assert_true(iter.__next__() == "c")
with assert_raises():
    _ = iter.__next__() # raises StopIteration
```

Returns: An iterator of references to the string elements.

#### `String.codepoint_slices_reversed`

```mojo
def codepoint_slices_reversed(self) -> CodepointSliceIter[origin_of(self), False]
```

Iterates backwards over the string, returning single-character slices.

Each returned slice points to a single Unicode codepoint encoded in the
underlying UTF-8 representation of this string, starting from the end
and moving towards the beginning.

Returns: A reversed iterator of references to the string elements.

#### `String.graphemes`

```mojo
def graphemes(self) -> GraphemeSliceIter[origin_of(self)]
```

Return an iterator over the grapheme clusters in this string.

A grapheme cluster is what a user would typically think of as a
single "character" on screen.

Returns: An iterator yielding each grapheme cluster as a `StringSlice`.

#### `String.graphemes_reversed`

```mojo
def graphemes_reversed(self) -> GraphemeSliceIter[origin_of(self), False]
```

Return an iterator over the grapheme clusters in this string, yielding them in reverse order.

See `graphemes()` for the definition of a grapheme cluster.

Returns: A reverse iterator yielding each grapheme cluster as a `StringSlice`.

#### `String.grapheme_indices`

```mojo
def grapheme_indices(self) -> GraphemeIndicesIter[origin_of(self)]
```

Return an iterator over grapheme clusters paired with their byte offsets.

Each yielded element is a `Tuple[Int, StringSlice]` where the first
element is the byte offset at which the grapheme begins.

Returns: An iterator yielding `(byte_offset, grapheme)` pairs.

#### `String.split_at_grapheme`

```mojo
def split_at_grapheme(self, n: Int) -> Tuple[StringSpan[origin_of(self)], StringSpan[origin_of(self)]]
```

Split this string at the `n`-th grapheme-cluster boundary.

Args:

- `n`: The grapheme-cluster boundary at which to split. Must be non-negative.

Returns: A tuple `(prefix, suffix)` of `StringSlice`s. The prefix covers grapheme clusters `[0, n)` and the suffix covers the rest.

#### `String.count_graphemes`

```mojo
def count_graphemes(self) -> Int
```

Count the number of grapheme clusters in this string.

This is an O(n) operation.

Returns: The number of grapheme clusters.

#### `String.unsafe_ptr`

```mojo
def unsafe_ptr(self) -> Pointer[UInt8, origin_of(self)]
```

Retrieves a pointer to the underlying memory.

Returns: The pointer to the underlying memory.

#### `String.unsafe_ptr_mut`

```mojo
def unsafe_ptr_mut(mut self, var capacity: Int = Int(0)) -> Pointer[UInt8, origin_of(self)]
```

Retrieves a mutable pointer to the unique underlying memory. Passing a larger capacity will reallocate the string to the new capacity if larger than the existing capacity, allowing you to write more data.

Args:

- `capacity`: The new capacity of the string.

Returns: The pointer to the underlying memory.

#### `String.as_c_string_slice`

```mojo
def as_c_string_slice(mut self) -> CStringSpan[origin_of(self)]
```

**Deprecated:** 'as_c_string_slice' is deprecated, use 'as_c_string_span' instead

Return a `CStringSpan` to the underlying memory of the string.

Returns: The `CStringSpan` of the string.

#### `String.as_c_string_span`

```mojo
def as_c_string_span(mut self) -> CStringSpan[origin_of(self)]
```

Return a `CStringSpan` to the underlying memory of the string.

Returns: The `CStringSpan` of the string.

#### `String.as_bytes`

```mojo
def as_bytes(ref self) -> Span[UInt8, origin_of(self["bytes"])]
```

Returns a contiguous slice of the bytes owned by this string.

Notes:
The returned span carries an interior origin derived from this
string, so mutating the string (which may reallocate its buffer)
invalidates the span at compile time.

Returns: A contiguous slice pointing to the bytes owned by this string.

#### `String.unsafe_as_bytes_mut`

```mojo
def unsafe_as_bytes_mut(mut self) -> Span[UInt8, origin_of(self["bytes"])]
```

Returns a mutable contiguous slice of the bytes owned by this string. This name has a _mut suffix so the as_bytes() method doesn't have to guarantee mutability.

Safety:
- Any mutation of the byte slice must uphold UTF-8 validity of the
  overall string.

Returns: A contiguous slice pointing to the bytes owned by this string.

#### `String.byte_length`

```mojo
def byte_length(self) -> Int
```

Get the string length in bytes.

Returns: The length of this string in bytes.

#### `String.count_codepoints`

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

#### `String.count`

```mojo
def count(self, substr: StringSpan) -> Int
```

Return the number of non-overlapping occurrences of substring `substr` in the string.

If sub is empty, returns the number of empty strings between characters
which is the length of the string plus one.

Args:

- `substr`: The substring to count.

Returns: The number of occurrences of `substr`.

#### `String.find`

```mojo
def find(self, substr: StringSpan, start: Int = Int(0)) -> Int
```

Finds the offset in bytes of the first occurrence of `substr` starting at `start`. If not found, returns `-1`.

Args:

- `substr`: The substring to find.
- `start`: The offset in bytes from which to find.

Returns: The offset in bytes of `substr` relative to the beginning of the string.

#### `String.rfind`

```mojo
def rfind(self, substr: StringSpan, start: Int = Int(0)) -> Int
```

Finds the offset in bytes of the last occurrence of `substr` starting at `start`. If not found, returns `-1`.

Args:

- `substr`: The substring to find.
- `start`: The offset in bytes from which to find.

Returns: The offset in bytes of `substr` relative to the beginning of the string.

#### `String.is_ascii_whitespace`

```mojo
def is_ascii_whitespace(self) -> Bool
```

Determines whether every character in the given String is a python whitespace String. This corresponds to Python's [universal separators](     https://docs.python.org/3/library/stdtypes.html#str.splitlines) `" \t\n\v\f\r\x1c\x1d\x1e\x85\u2028\u2029"`.

Returns: True if the whole String is made up of whitespace characters listed above, otherwise False.

#### `String.split`

```mojo
def split(self, sep: StringSpan) -> List[StringSpan[origin_of(self["bytes"])]]
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
def split(self, sep: StringSpan, maxsplit: Int) -> List[StringSpan[origin_of(self["bytes"])]]
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
def split(self, sep: NoneType = None) -> List[StringSpan[origin_of(self["bytes"])]]
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
def split(self, sep: NoneType = None, *, maxsplit: Int) -> List[StringSpan[origin_of(self["bytes"])]]
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

#### `String.splitlines`

```mojo
def splitlines(self, keepends: Bool = False) -> List[StringSpan[origin_of(self["bytes"])]]
```

Split the string at line boundaries. This corresponds to Python's [universal newlines:]( https://docs.python.org/3/library/stdtypes.html#str.splitlines) `"\r\n"` and `"\t\n\v\f\r\x1c\x1d\x1e\x85\u2028\u2029"`.

Args:

- `keepends`: If True, line breaks are kept in the resulting strings.

Returns: A List of Strings containing the input split by line boundaries.

#### `String.replace`

```mojo
def replace(self, old: StringSpan, new: StringSpan) -> Self
```

Return a copy of the string with all occurrences of substring `old` if replaced by `new`.

Args:

- `old`: The substring to replace.
- `new`: The substring to replace with.

Returns: The string where all occurrences of `old` are replaced with `new`.

#### `String.strip`

```mojo
def strip(self, chars: StringSpan) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with leading and trailing characters removed.

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A `StringSlice` into this string with no leading or trailing characters.

```mojo
def strip(self) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with leading and trailing whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Returns: A `StringSlice` into this string with no leading or trailing whitespaces.

#### `String.rstrip`

```mojo
def rstrip(self, chars: StringSpan) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with trailing characters removed.

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A `StringSlice` into this string with no trailing characters.

```mojo
def rstrip(self) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with trailing whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Returns: A `StringSlice` into this string with no trailing whitespaces.

#### `String.lstrip`

```mojo
def lstrip(self, chars: StringSpan) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with leading characters removed.

Args:

- `chars`: A set of characters to be removed. Defaults to whitespace.

Returns: A `StringSlice` into this string with no leading characters.

```mojo
def lstrip(self) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with leading whitespaces removed. This only takes ASCII whitespace into account: `" \t\n\v\f\r\x1c\x1d\x1e"`.

Returns: A `StringSlice` into this string with no leading whitespaces.

#### `String.__hash__`

```mojo
def __hash__[H: Hasher](self, mut hasher: H)
```

Updates hasher with the underlying bytes.

Parameters:

- `H`: The hasher type.

Args:

- `hasher`: The hasher instance.

#### `String.lower`

```mojo
def lower(self) -> Self
```

Returns a copy of the string with all cased characters converted to lowercase.

Returns: A new string where cased letters have been converted to lowercase.

#### `String.upper`

```mojo
def upper(self) -> Self
```

Returns a copy of the string with all cased characters converted to uppercase.

Returns: A new string where cased letters have been converted to uppercase.

#### `String.startswith`

```mojo
def startswith(self, prefix: StringSpan, start: Int = Int(0), end: Int = Int(-1)) -> Bool
```

Checks if the string starts with the specified prefix between start and end positions. Returns True if found and False otherwise.

The `start` and `end` positions must be offsets given in bytes, and
must be codepoint boundaries.

Args:

- `prefix`: The prefix to check.
- `start`: The start offset in bytes from which to check.
- `end`: The end offset in bytes up to which to check.

Returns: True if the `self[byte=start:end]` is prefixed by the input prefix.

#### `String.endswith`

```mojo
def endswith(self, suffix: StringSpan, start: Int = Int(0), end: Int = Int(-1)) -> Bool
```

Checks if the string end with the specified suffix between start and end positions. Returns True if found and False otherwise.

The `start` and `end` positions must be offsets given in bytes, and
must be codepoint boundaries.

Args:

- `suffix`: The suffix to check.
- `start`: The start offset in bytes from which to check.
- `end`: The end offset in bytes up to which to check.

Returns: True if the `self[byte=start:end]` is suffixed by the input suffix.

#### `String.removeprefix`

```mojo
def removeprefix(self, prefix: StringSpan, /) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with the prefix removed if it was present.

Examples:

```mojo
print(String('TestHook').removeprefix('Test')) # 'Hook'
print(String('BaseTestCase').removeprefix('Test')) # 'BaseTestCase'
```

Args:

- `prefix`: The prefix to remove from the string.

Returns: A `StringSlice` into this string: `string[byte=prefix.byte_length():]` if the string starts with the prefix string, or the whole string otherwise.

#### `String.removesuffix`

```mojo
def removesuffix(self, suffix: StringSpan, /) -> StringSpan[origin_of(self["bytes"])]
```

Returns a view of the string with the suffix removed if it was present.

Examples:

```mojo
print(String('TestHook').removesuffix('Hook')) # 'Test'
print(String('BaseTestCase').removesuffix('Test')) # 'BaseTestCase'
```

Args:

- `suffix`: The suffix to remove from the string.

Returns: A `StringSlice` into this string: `string[byte=:(self.byte_length()-suffix.byte_length())]` if the string ends with the suffix string, or the whole string otherwise.

#### `String.__int__`

```mojo
def __int__(self) raises -> Int
```

Parses the given string as a base-10 integer and returns that value. If the string cannot be parsed as an int, an error is raised.

Returns: An integer value that represents the string, or otherwise raises.

Raises: If the operation fails.

#### `String.__float__`

```mojo
def __float__(self) raises -> Float64
```

Parses the string as a float point number and returns that value. If the string cannot be parsed as a float, an error is raised.

Returns: A float value that represents the string, or otherwise raises.

Raises: If the operation fails.

#### `String.format`

```mojo
def format[*Ts: Writable](self, *args: *Ts.values) raises -> Self
```

Produce a formatted string using the current string as a template.

The template, or "format string" can contain literal text and/or
replacement fields delimited with curly braces (`{}`). Returns a copy of
the format string with the replacement fields replaced with string
representations of the `args` arguments.

For more information, see the discussion in the
[`format` module](../../../std/collections/string/format.md).

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

Raises: If the operation fails.

#### `String.is_ascii_digit`

```mojo
def is_ascii_digit(self) -> Bool
```

A string is a digit string if all characters in the string are ASCII digits and there is at least one character in the string.

Note that this currently only works with ASCII strings.

Returns: True if all characters are digits and it's not empty else False.

#### `String.isupper`

```mojo
def isupper(self) -> Bool
```

Returns True if all cased characters in the string are uppercase and there is at least one cased character.

Returns: True if all cased characters in the string are uppercase and there is at least one cased character, False otherwise.

#### `String.islower`

```mojo
def islower(self) -> Bool
```

Returns True if all cased characters in the string are lowercase and there is at least one cased character.

Returns: True if all cased characters in the string are lowercase and there is at least one cased character, False otherwise.

#### `String.is_ascii_printable`

```mojo
def is_ascii_printable(self) -> Bool
```

Returns True if all characters in the string are ASCII printable.

Note that this currently only works with ASCII strings.

Returns: True if all characters are printable else False.

#### `String.ascii_rjust`

```mojo
def ascii_rjust(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> Self
```

Returns the string right justified in a string of specified width.

Pads the string on the left with the specified fill character so that
the total (byte) length of the resulting string equals `width`. If the original
string is already longer than or equal to `width`, returns the original
string unchanged.

Examples:

```mojo
var s = String("hello")
print(s.ascii_rjust(10))        # "     hello"
print(s.ascii_rjust(10, "*"))   # "*****hello"
print(s.ascii_rjust(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A right-justified string of (byte) length `width`, or the original string if its length is already greater than or equal to `width`.

#### `String.ascii_ljust`

```mojo
def ascii_ljust(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> Self
```

Returns the string left justified in a string of specified width.

Pads the string on the right with the specified fill character so that
the total (byte) length of the resulting string equals `width`. If the original
string is already longer than or equal to `width`, returns the original
string unchanged.

Examples:

```mojo
var s = String("hello")
print(s.ascii_ljust(10))        # "hello     "
print(s.ascii_ljust(10, "*"))   # "hello*****"
print(s.ascii_ljust(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A left-justified string of (byte) length `width`, or the original string if its length is already greater than or equal to `width`.

#### `String.ascii_center`

```mojo
def ascii_center(self, width: Int, fillchar: StringSpan[ImmStaticOrigin] = StringSpan(" ")) -> Self
```

Returns the string center justified in a string of specified width.

Pads the string on both sides with the specified fill character so that
the total length of the resulting string equals `width`. If the padding
needed is odd, the extra character goes on the right side. If the
original string is already longer than or equal to `width`, returns the
original string unchanged.

Examples:

```mojo
var s = String("hello")
print(s.ascii_center(10))        # "  hello   "
print(s.ascii_center(11, "*"))   # "***hello***"
print(s.ascii_center(3))         # "hello" (no padding)
```

Args:

- `width`: The total width (in bytes) of the resulting string. This is not the amount of padding, but the final length of the returned string.
- `fillchar`: The padding character to use (defaults to space). Must be a single-byte character.

Returns: A center-justified string of length `width`, or the original string if its length is already greater than or equal to `width`.

#### `String.resize`

```mojo
def resize(mut self, length: Int, fill_byte: UInt8 = UInt8(0))
```

Resize the string to a new length. Panics if new_len does not lie on a codepoint boundary or if fill_byte is non-ascii (>=128).

Notes:
If the new length is greater than the current length, the string is
extended by the difference, and the new bytes are initialized to
`fill_byte`.

Args:

- `length`: The new length of the string.
- `fill_byte`: The byte to fill any new space with. Must be a valid single-byte utf-8 character.

```mojo
def resize(mut self, *, unsafe_uninit_length: Int)
```

Resizes the string to the given new size leaving any new data uninitialized. Panics if the new length does not lie on a codepoint boundary.

If the new size is smaller than the current one, elements at the end
are discarded. If the new size is larger than the current one, the
string is extended and the new data is left uninitialized.

Args:

- `unsafe_uninit_length`: The new size.

#### `String.reserve_bytes`

```mojo
def reserve_bytes(mut self, new_capacity_bytes: Int, /)
```

Reserves at least the requested capacity.

Notes:
If the current capacity is greater or equal, this is a no-op.
Otherwise, the storage is reallocated and the data is moved.

Args:

- `new_capacity_bytes`: The minimum new capacity in bytes.

## Functions

### `ord`

```mojo
def ord(s: StringSpan) -> Int
```

Returns an integer that represents the codepoint of a single-character string.

Given a string containing a single character `Codepoint`, return an integer
representing the codepoint of that character. For example, `ord("a")`
returns the integer `97`. This is the inverse of the `chr()` function.

This function is in the prelude, so you don't need to import it.

Args:

- `s`: The input string, which must contain only a single- character.

Returns: An integer representing the code point of the given character.

### `chr`

```mojo
def chr(c: Int) -> String
```

Returns a String based on the given Unicode code point. This is the inverse of the `ord()` function.

This function is in the prelude, so you don't need to import it.

Example:
```mojo
print(chr(97), chr(8364)) # "a €"
```

Args:

- `c`: An integer that represents a code point.

Returns: A string containing a single character based on the given code point.

### `ascii`

```mojo
def ascii(value: StringSpan) -> String
```

Get the ASCII representation of the object.

Args:

- `value`: The object to get the ASCII representation of.

Returns: A string containing the ASCII representation of the object.

### `atol`

```mojo
def atol(str_slice: StringSpan, base: Int = Int(10)) raises -> Int
```

Parses and returns the given string as an integer in the given base.

If base is set to 0, the string is parsed as an integer literal, with the
following considerations:
- '0b' or '0B' prefix indicates binary (base 2)
- '0o' or '0O' prefix indicates octal (base 8)
- '0x' or '0X' prefix indicates hexadecimal (base 16)
- Without a prefix, it's treated as decimal (base 10)

This follows [Python's integer literals format](
https://docs.python.org/3/reference/lexical_analysis.html#integers).

This function is in the prelude, so you don't need to import it.

Notes:
This function only accepts ASCII digits (0-9 and a-z/A-Z for bases
greater than 10). Unicode digit characters are not supported. Leading
and trailing whitespace is trimmed, but only ASCII/POSIX whitespace
characters are recognized (space, tab, newline, etc.). Unicode
whitespace characters will cause a parsing error.

Examples:

```text
>>> atol("32")
32
>>> atol("FF", 16)
255
>>> atol("0xFF", 0)
255
>>> atol("0b1010", 0)
10
```

Args:

- `str_slice`: A string to be parsed as an integer in the given base.
- `base`: Base used for conversion, value must be between 2 and 36, or 0.

Returns: An integer value that represents the string.

Raises: If the given string cannot be parsed as an integer value or if an incorrect base is provided.

### `atof`

```mojo
def atof(str_slice: StringSpan) raises -> Float64
```

Parses the given string as a floating point and returns that value.

For example, `atof("2.25")` returns `2.25`.

This function is in the prelude, so you don't need to import it.

Args:

- `str_slice`: A string to be parsed as a floating point.

Returns: A floating-point value that represents the string.

Raises: If the given string cannot be parsed as an floating-point value, for example in `atof("hi")`.

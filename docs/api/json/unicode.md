# `dodo.json.unicode`

## Functions

### `hex_digit_value`

```mojo
def hex_digit_value(c: UInt8) -> Int
```

Convert a hex digit character to its value.

Returns -1 if not a valid hex digit.

### `parse_unicode_escape`

```mojo
def parse_unicode_escape(data: List[UInt8], start: Int) -> Int
```

Parse a 4-digit hex unicode escape sequence.

Args:

- `data`: The byte span containing the escape.
- `start`: Index of first hex digit (after backslash-u).

Returns: The code point value, or -1 if invalid.

### `parse_unicode_escape_span`

```mojo
def parse_unicode_escape_span(data: Span[UInt8], start: Int) -> Int
```

`parse_unicode_escape` overload that accepts a borrowed byte span.

Used by the tape stage 2 string emitter so it doesn't have to copy
the whole input into a `List[UInt8]` per string with escapes.

### `is_high_surrogate`

```mojo
def is_high_surrogate(code_point: Int) -> Bool
```

Check if code point is a high surrogate (U+D800 - U+DBFF).

### `is_low_surrogate`

```mojo
def is_low_surrogate(code_point: Int) -> Bool
```

Check if code point is a low surrogate (U+DC00 - U+DFFF).

### `decode_surrogate_pair`

```mojo
def decode_surrogate_pair(high: Int, low: Int) -> Int
```

Decode a surrogate pair to a full code point.

Args:

- `high`: High surrogate (U+D800 - U+DBFF).
- `low`: Low surrogate (U+DC00 - U+DFFF).

Returns: The full Unicode code point (U+10000 - U+10FFFF).

### `encode_utf8`

```mojo
def encode_utf8(code_point: Int, mut bytes: List[UInt8])
```

Encode a Unicode code point as UTF-8 bytes.

Args:

- `code_point`: Unicode code point (0 - 0x10FFFF).
- `bytes`: List to append UTF-8 bytes to.

### `unescape_json_string_span`

```mojo
def unescape_json_string_span(data: Span[UInt8], start: Int, end: Int) -> List[UInt8]
```

`unescape_json_string` overload that accepts a borrowed byte span.

Avoids the O(input_size) copy from `List[UInt8]` per string when
only a tiny slice between the quotes contains escapes. Same
behaviour as the `List[UInt8]` overload below; defined inline so
we don't need a generic dispatch helper.

### `unescape_json_string`

```mojo
def unescape_json_string(data: List[UInt8], start: Int, end: Int) -> List[UInt8]
```

Unescape a JSON string, handling all escape sequences including unicode.

Args:

- `data`: The byte span containing the string content.
- `start`: Start index (after opening quote).
- `end`: End index (before closing quote).

Returns: Unescaped bytes.

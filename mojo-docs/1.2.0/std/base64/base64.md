# `std.base64.base64`

Provides functions for base64 encoding strings.

You can import these APIs from the `base64` package. For example:

```mojo
from std.base64 import b64encode
```

## Functions

### `b64encode`

```mojo
def b64encode(input_bytes: Span[UInt8], mut result: String)
```

Performs base64 encoding on the input string.

Notes:
This method reserves the necessary capacity. `result` can be a 0
capacity string.

Args:

- `input_bytes`: The input string buffer.
- `result`: The string in which to store the values.

```mojo
def b64encode(input_string: StringSpan) -> String
```

Performs base64 encoding on the input string.

Args:

- `input_string`: The input string buffer.

Returns: The ASCII base64 encoded string.

```mojo
def b64encode(input_bytes: Span[UInt8]) -> String
```

Performs base64 encoding on the input string.

Args:

- `input_bytes`: The input string buffer.

Returns: The ASCII base64 encoded string.

### `b64decode`

```mojo
def b64decode(str: StringSpan) raises -> List[UInt8]
```

Performs base64 decoding on the input string.

Whitespace (spaces, tabs, newlines, carriage returns, form feeds, and
vertical tabs) is ignored, which allows decoding base64 text that has
been wrapped across multiple lines. Unlike Python's `base64.b64decode`,
which discards *any* non-alphabet byte, Mojo only ignores whitespace and
still rejects other invalid characters.

Args:

- `str`: A base64 encoded string.

Returns: The decoded bytes.

Raises: If the input length (ignoring whitespace) is not divisible by 4, or the input contains a non-whitespace character outside the base64 alphabet.

### `b16encode`

```mojo
def b16encode(str: StringSpan) -> String
```

Performs base16 encoding on the input string slice.

Args:

- `str`: The input string slice.

Returns: Base16 encoding of the input string.

### `b16decode`

```mojo
def b16decode(str: StringSpan) raises -> List[UInt8]
```

Performs base16 decoding on the input string.

Args:

- `str`: A base16 encoded string.

Returns: The decoded bytes.

Raises: If the input length is odd or any character is outside the base16 alphabet `[0-9A-F]` (per RFC 4648 section 8, which is strictly uppercase).

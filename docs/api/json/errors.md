# `dodo.json.errors`

## Functions

### `compute_line_column`

```mojo
def compute_line_column(source: Span[UInt8], position: Int) -> Tuple[Int, Int]
```

Line and column for a byte offset, both 1-indexed.

The column counts bytes, not characters: a column past a
multi-byte character will not line up with what an editor shows.
Counting code points would need a second decode of the line on a
path that only runs when something has already gone wrong, and the
surrounding context in the message is what a reader actually uses
to find the spot.

Args:

- `source`: The document being parsed.
- `position`: Byte offset, 0-indexed.

Returns: A (line, column) pair.

```mojo
def compute_line_column(source: String, position: Int) -> Tuple[Int, Int]
```

Line and column for a byte offset, both 1-indexed.

Args:

- `source`: The document being parsed.
- `position`: Byte offset, 0-indexed.

Returns: A (line, column) pair.

### `format_error_context`

```mojo
def format_error_context(source: Span[UInt8], position: Int, context_chars: Int = Int(20)) -> String
```

A window of the document around `position`, for the message.

Bytes are copied through rather than passed to `chr`, which would
re-encode every byte at or above 0x80 as its own code point and
turn any non-ASCII text in the window into mojibake. The window
can start or end mid-character, so the result is assembled as
bytes and only then called a string.

Args:

- `source`: The document being parsed.
- `position`: Byte offset of the error.
- `context_chars`: How many bytes to show on each side.

Returns: The window, with control characters escaped.

```mojo
def format_error_context(source: String, position: Int, context_chars: Int = Int(20)) -> String
```

A window of the document around `position`, for the message.

Args:

- `source`: The document being parsed.
- `position`: Byte offset of the error.
- `context_chars`: How many bytes to show on each side.

Returns: The window, with control characters escaped.

### `json_parse_error`

```mojo
def json_parse_error(message: String, source: Span[UInt8], position: Int) -> String
```

Build the full parse-error text for a byte offset.

Example:

```mojo
`JSON parse error at line 3, column 15 (offset 42): expected ':' after object key`
`  Near: ..."key" value}...`
```

Args:

- `message`: What is wrong, lower case, no module prefix.
- `source`: The document being parsed.
- `position`: Byte offset of the error.

Returns: The message with its line, column, offset and context.

```mojo
def json_parse_error(message: String, source: String, position: Int) -> String
```

Build the full parse-error text for a byte offset.

Args:

- `message`: What is wrong, lower case, no module prefix.
- `source`: The document being parsed.
- `position`: Byte offset of the error.

Returns: The message with its line, column, offset and context.

### `parse_error`

```mojo
def parse_error(message: String, source: Span[UInt8], position: Int) -> Error
```

A located parse error, ready to raise.

Returns the error rather than raising it so that `raise` stays at
the call site. A helper that raised on the caller's behalf would
read fine but hide the control flow: the compiler would treat the
call as one that can return, and every variable assigned on the
surviving branch would look possibly-uninitialized.

Args:

- `message`: What is wrong, lower case, no module prefix.
- `source`: The document being parsed.
- `position`: Byte offset of the error.

Returns: The error to raise.

### `find_error_position`

```mojo
def find_error_position(source: String) -> Int
```

Guess where a parse failed, for a backend that does not say.

The native parser reports its own offsets, so this is only for the
simdjson backend, whose error codes carry no position.

Args:

- `source`: The source JSON string.

Returns: Estimated error position (byte offset).

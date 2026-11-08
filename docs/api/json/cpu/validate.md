# `dodo.json.cpu.validate`

## Aliases

### `STR_PLAIN`

```mojo
comptime STR_PLAIN = UInt8(0)
```

ASCII, no escapes, nothing below U+0020: copy it and move on.

### `STR_ESCAPE`

```mojo
comptime STR_ESCAPE = UInt8(1)
```

Contains a backslash, so the escapes need validating and expanding.

### `STR_CONTROL`

```mojo
comptime STR_CONTROL = UInt8(2)
```

Contains a byte below U+0020, which section 7 forbids unescaped.

### `STR_NON_ASCII`

```mojo
comptime STR_NON_ASCII = UInt8(4)
```

Contains a byte at or above 0x80, so the UTF-8 needs validating.

### `ESC_OK`

```mojo
comptime ESC_OK = UInt8(0)
```

### `ESC_TRAILING_BACKSLASH`

```mojo
comptime ESC_TRAILING_BACKSLASH = UInt8(1)
```

A backslash with nothing after it.

### `ESC_BAD_CHAR`

```mojo
comptime ESC_BAD_CHAR = UInt8(2)
```

A backslash followed by something other than `"\/bfnrtu`.

### `ESC_BAD_HEX`

```mojo
comptime ESC_BAD_HEX = UInt8(3)
```

`\u` without exactly four hexadecimal digits after it.

### `ESC_LONE_SURROGATE`

```mojo
comptime ESC_LONE_SURROGATE = UInt8(4)
```

An unpaired surrogate escape; only reported when `ijson` is set.

## Functions

### `is_ws`

```mojo
def is_ws(b: UInt8) -> Bool
```

The four bytes RFC 8259 section 2 allows between tokens.

### `skip_ws`

```mojo
def skip_ws(bytes: Span[UInt8], start: Int, end: Int) -> Int
```

Offset of the first non-whitespace byte at or after `start`.

A scalar prelude of four bytes handles compact documents, where
there is rarely more than one whitespace byte between tokens and
the SIMD setup would not pay for itself. Only a longer run falls
into the vector loop, which finds the first non-whitespace byte
with `pack_bits` and a trailing-zero count instead of stepping.

### `scan_string_body`

```mojo
def scan_string_body(bytes: Span[UInt8], start: Int, end: Int) -> UInt8
```

Classify a string's bytes in one pass.

Returns the OR of the `STR_*` flags. `STR_PLAIN` (zero) is the
answer for most strings in most documents, and it is the answer
that lets the caller take a zero-copy slice.

### `find_control_char`

```mojo
def find_control_char(bytes: Span[UInt8], start: Int, end: Int) -> Int
```

Offset of the first byte below U+0020, or -1.

Only called once a scan has already said there is one, so it can
afford to be a plain loop: its job is to name the position for the
error message.

### `is_valid_utf8`

```mojo
def is_valid_utf8(bytes: Span[UInt8]) -> Bool
```

Whether `bytes` is well-formed UTF-8 (RFC 3629).

Rejects overlong encodings, encoded surrogates, anything above
U+10FFFF, and truncated or orphaned continuation bytes. Wraps the
stdlib's vectorized validator so there is one place to change if
that moves.

### `first_invalid_utf8`

```mojo
def first_invalid_utf8(bytes: Span[UInt8], start: Int, end: Int) -> Int
```

Offset of the first byte that cannot begin a valid sequence.

Walks the sequence structure scalar, which is fine because this
only runs on the error path, after the vectorized check has
already said the span is bad. Its job is to point at the byte.

### `validate_escapes`

```mojo
def validate_escapes(bytes: Span[UInt8], start: Int, end: Int, ijson: Bool, mut err_pos: Int) -> UInt8
```

Check every escape in a string body.

The four hexadecimal digits after `\u` are checked, and an escape
that fails to parse is reported, so `"\uqqqq"` and `"\u00A"` are
errors.

A surrogate escape is paired here rather than in the unescaper, so
that the decision about an unpaired one is made once. RFC 8259
section 8.2 permits it -- the unescaper substitutes U+FFFD -- and
RFC 7493 section 2.1 forbids it, which is what `ijson` selects.

Args:

- `bytes`: The document.
- `start`: First byte of the string body.
- `end`: One past the last byte of the string body.
- `ijson`: Whether to reject unpaired surrogate escapes.
- `err_pos`: Set to the offset of the offending backslash on failure.

Returns: `ESC_OK`, or one of the `ESC_*` reasons.

# `dodo.json.cpu.number_parse`

## Aliases

### `NUM_INT`

```mojo
comptime NUM_INT = UInt8(0)
```

Integer grammar, value fits `Int64`.

### `NUM_UINT`

```mojo
comptime NUM_UINT = UInt8(1)
```

Integer grammar, value exceeds `Int64.MAX` but fits `UInt64`.

### `NUM_FLOAT`

```mojo
comptime NUM_FLOAT = UInt8(2)
```

Has a fraction or exponent, or an integer too large for `UInt64`.

### `NUM_INVALID`

```mojo
comptime NUM_INVALID = UInt8(3)
```

Not a number; `end` is the offset of the offending byte.

### `NUM_ERR_NONE`

```mojo
comptime NUM_ERR_NONE = UInt8(0)
```

### `NUM_ERR_GRAMMAR`

```mojo
comptime NUM_ERR_GRAMMAR = UInt8(1)
```

A byte appeared where the grammar does not allow it.

### `NUM_ERR_LEADING_ZERO`

```mojo
comptime NUM_ERR_LEADING_ZERO = UInt8(2)
```

`01`, `-00`: a zero followed by another digit.

### `NUM_ERR_RANGE`

```mojo
comptime NUM_ERR_RANGE = UInt8(3)
```

Magnitude overflows `Float64`.

## Structs

### `NumberToken`

```mojo
struct NumberToken
```

One scanned number: its kind, its value, and where it ended.

Fields:

- `kind` (`UInt8`)
- `err` (`UInt8`)
- `end` (`Int`)
- `int_value` (`Int64`)
- `uint_value` (`UInt64`)
- `float_value` (`Float64`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `NumberToken.invalid`

```mojo
def invalid(reason: UInt8, at: Int) -> Self
```

## Functions

### `scan_number`

```mojo
def scan_number(bytes: Span[UInt8], start: Int, limit: Int) raises -> NumberToken
```

Scan one JSON number from `start`, stopping at the first byte that cannot extend it.

Args:

- `bytes`: The document.
- `start`: Offset of the first byte of the number.
- `limit`: One past the last byte the scanner may read.

Returns: A token whose `kind` says how to read the value, or `NUM_INVALID` with `end` pointing at the byte that broke the grammar.

Raises: If the magnitude overflows `Float64`.

### `parse_float_span`

```mojo
def parse_float_span(bytes: Span[UInt8], start: Int, limit: Int) raises -> Tuple[Float64, Int]
```

Read one number as a `Float64`. Returns (value, end offset).

### `parse_int_checked`

```mojo
def parse_int_checked[dtype: DType](bytes: Span[UInt8], start: Int, limit: Int) raises -> Tuple[Scalar[dtype], Int]
```

Read one number as an integer of `dtype`, or raise.

A fractional or exponent part is a type error, not a truncation:
silently turning `1.5` into `1` loses data the caller asked to
keep. A magnitude outside `dtype` is an error for the same reason.

Parameters:

- `dtype`: The integer type to produce.

Args:

- `bytes`: The document.
- `start`: Offset of the first byte of the number.
- `limit`: One past the last byte the scanner may read.

Returns: The value and the offset one past the number.

Raises: If the token is not an integer or does not fit `dtype`.

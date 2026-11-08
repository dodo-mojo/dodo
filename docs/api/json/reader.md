# `dodo.json.reader`

## Aliases

### `DEFAULT_MAX_DEPTH`

```mojo
comptime DEFAULT_MAX_DEPTH = 1024
```

Nesting past this is refused. Deep input is otherwise a stack hazard.

## Structs

### `KeySpan`

```mojo
struct KeySpan
```

Where an object key's bytes are, and whether they need expanding.

Fields:

- `start` (`Int`)
- `end` (`Int`)
- `escaped` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

### `JsonReader`

```mojo
struct JsonReader[origin: ImmOrigin]
```

A forward cursor over JSON bytes.

Borrows its input rather than owning it, so decoding a document
does not begin by copying it.

Fields:

- `data` (`Span[UInt8, origin]`)
- `pos` (`Int`)
- `depth` (`Int`)
- `max_depth` (`Int`)
- `scratch` (`List[UInt8]`): Reused buffer for keys and strings that contain escapes.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `JsonReader.__init__`

```mojo
def __init__(out self, data: Span[UInt8, origin], *, max_depth: Int = Int(1024))
```

#### `JsonReader.error`

```mojo
def error(self, message: String) -> Error
```

A located error at the cursor.

#### `JsonReader.error_at`

```mojo
def error_at(self, message: String, at: Int) -> Error
```

#### `JsonReader.skip_ws`

```mojo
def skip_ws(mut self)
```

Advance past whitespace.

A hand-written inline check for "the next byte is not
whitespace" before this call was measured and was slower on
every shape: the shared scan already opens with a scalar
prelude for exactly that case, and the extra branch only
added work.

#### `JsonReader.peek`

```mojo
def peek(mut self) -> UInt8
```

The next significant byte, or 0 at end of input.

Zero is safe as the end marker: a NUL outside a string is not
in the grammar, so every caller that compares against a real
byte rejects it anyway.

#### `JsonReader.at_end`

```mojo
def at_end(mut self) -> Bool
```

#### `JsonReader.expect_end`

```mojo
def expect_end(mut self) raises
```

Nothing but whitespace may follow the top-level value.

#### `JsonReader.expect_object_begin`

```mojo
def expect_object_begin(mut self) raises
```

#### `JsonReader.expect_array_begin`

```mojo
def expect_array_begin(mut self) raises
```

#### `JsonReader.next_member`

```mojo
def next_member(mut self, first: Bool) raises -> Bool
```

Advance to the next object member. False at the closing brace.

Each byte is looked at once. The previous shape called `peek`
three times per member, and every call re-ran the whitespace
scan from a position where nothing had been consumed since the
last one; the byte it returned was already in a register.

#### `JsonReader.next_element`

```mojo
def next_element(mut self, first: Bool) raises -> Bool
```

Advance to the next array element. False at the closing bracket.

#### `JsonReader.read_string`

```mojo
def read_string(mut self) raises -> String
```

#### `JsonReader.read_key`

```mojo
def read_key(mut self) raises -> KeySpan
```

Consume an object key and its colon, without materializing it.

A key is compared against a field name far more often than it
is kept, and building a `String` for each comparison would
allocate on the order of the square of the field count per
record.

#### `JsonReader.key_matches`

```mojo
def key_matches[name: StringSpan[ImmStaticOrigin]](self, key: KeySpan) -> Bool
```

Whether an unescaped key spells `name`.

Takes `self` immutably and the name as a parameter, both for
the same reason: this runs inside a comptime-unrolled loop over
a struct's fields, and a method that could mutate the reader
forces the compiler to reload its span and position after every
call in that loop. With the name known at compile time the
length test is a comparison against a constant, which settles
most fields without looking at a byte.

#### `JsonReader.key_equals`

```mojo
def key_equals(mut self, key: KeySpan, name: StringSpan[ImmStaticOrigin]) -> Bool
```

Whether a key spells `name`, expanding escapes if it has any.

The escaped case is why this takes `self` mutably: the key is
unescaped into the reader's scratch buffer before comparing, so
that a key written `"a"` still matches a field named `a`.
Callers on the hot path go through `key_matches` and only reach
here when the key actually carries an escape.

#### `JsonReader.key_text`

```mojo
def key_text(mut self, key: KeySpan) raises -> String
```

A key as a `String`, for the cases that must keep it.

#### `JsonReader.read_bool`

```mojo
def read_bool(mut self) raises -> Bool
```

#### `JsonReader.read_null`

```mojo
def read_null(mut self) raises
```

#### `JsonReader.try_null`

```mojo
def try_null(mut self) raises -> Bool
```

Consume `null` if that is what comes next.

#### `JsonReader.read_int`

```mojo
def read_int[dtype: DType](mut self) raises -> Scalar[dtype]
```

Read an integer field.

Most integers in a document are a handful of digits, and
reaching them through the full number scanner costs four
outlined calls: the scanner walks the digits once to check the
grammar and again to accumulate, peeks for an eight-digit SWAR
block that a short integer never has, and hands back a
forty-eight byte token that the range check then unpacks.

The path below commits only when it has itself established the
whole token: an optional minus, a leading digit in 1-9 so that
anything starting `0` defers, at most eighteen digits so the
accumulator cannot overflow, and a terminator that cannot
continue a number. Everything else -- `0`, `-0`, a fraction, an
exponent, a leading zero, nineteen digits or more -- falls
through to the scanner, which stays the only authority on the
grammar, the messages and the offsets they carry.

#### `JsonReader.read_float`

```mojo
def read_float[dtype: DType](mut self) raises -> Scalar[dtype]
```

#### `JsonReader.skip_value`

```mojo
def skip_value(mut self) raises -> Tuple[Int, Int]
```

Consume one value without binding it. Returns its byte range.

Used for a member no field wants, and to hand a subtree to a
type that parses itself. Validating rather than merely counting
brackets matters: an unknown field is still part of the
document, and accepting rubbish inside it would mean two
readers of the same bytes disagree about whether they are JSON.

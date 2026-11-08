# `dodo.json.writer`

## Structs

### `JsonWriter`

```mojo
struct JsonWriter
```

Append-only JSON byte sink over a pre-sized buffer.

Construct with a capacity estimate, write, then `finish()`. The
estimate does not have to be right -- `ensure` grows the buffer when
it is short -- but a good estimate means the hot path never checks
anything but the cursor.

Example:

```mojo
var w = JsonWriter(capacity=64)
w.begin_object()
w.key("name")
w.write_string("Ada")
w.end_object()
var out = w^.finish_string()
```

Fields:

- `buf` (`List[UInt8]`)
- `pos` (`Int`)
- `indent` (`String`)
- `pretty` (`Bool`): Whether `indent` is non-empty, hoisted so the compact path is one predictable branch per child rather than a string length check.
- `depth` (`Int`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `JsonWriter.__init__`

```mojo
def __init__(out self, *, capacity: Int = Int(256))
```

```mojo
def __init__(out self, *, capacity: Int = Int(256), indent: String)
```

Pretty-printing writer. `indent` is one level of indentation.

```mojo
def __init__(out self, var buf: List[UInt8])
```

Adopt a caller-owned buffer, so allocations can be reused.

#### `JsonWriter.ensure`

```mojo
def ensure(mut self, n: Int)
```

Make room for `n` more bytes. Cold path when sized correctly.

#### `JsonWriter.write_byte`

```mojo
def write_byte(mut self, c: UInt8)
```

#### `JsonWriter.write_bytes`

```mojo
def write_bytes(mut self, data: Span[UInt8])
```

#### `JsonWriter.write_literal`

```mojo
def write_literal(mut self, s: StringSpan[ImmStaticOrigin])
```

#### `JsonWriter.reset`

```mojo
def reset(mut self)
```

Rewind to empty, keeping the buffer.

For a caller serializing many values in a row: the allocation
is the expensive part and it is already the right size.

#### `JsonWriter.write_null`

```mojo
def write_null(mut self)
```

#### `JsonWriter.write_bool`

```mojo
def write_bool(mut self, b: Bool)
```

#### `JsonWriter.write_int`

```mojo
def write_int(mut self, v: Int64)
```

Decimal integer, written backwards two digits at a time.

The magnitude is taken in unsigned arithmetic, so
`Int64.MIN` -- which has no positive counterpart -- needs no
special case: negating it as `UInt64` gives exactly 2**63.

#### `JsonWriter.write_uint`

```mojo
def write_uint(mut self, v: UInt64)
```

Decimal integer above the signed range.

JSON puts no upper bound on an integer, so a document may hold
a value that only fits unsigned. Writing it through the signed
path would wrap it into a negative number, silently.

#### `JsonWriter.write_float`

```mojo
def write_float(mut self, v: Float64)
```

A float as the shortest decimal that reads back as itself.

Digits come from `json.dtoa`, not from `String(Float64)`: the
stdlib formatter does not always produce a representation that
round-trips, and a serializer that writes a number nothing can
read back as the value given to it has lost the one property
it exists to keep.

Layout follows the convention this library already emitted --
fixed notation while the leading digit sits between 1e-5 and
1e15, scientific outside that, exponent always signed and at
least two digits. Integer-valued floats keep a trailing `.0`
so that a value written as a float reads back as one.

A non-finite value writes `null`. JSON has no spelling for
infinity or NaN, so the alternatives are an invalid document
or a refusal; refusing needs a policy the caller sets, which
`SerializerConfig` grows separately.

#### `JsonWriter.write_string`

```mojo
def write_string[ascii_only: Bool = False, solidus: Bool = False](mut self, s: String)
```

A quoted, escaped JSON string literal.

Both default off and are parameters rather than fields so the
ordinary path carries no check for them. Carrying them as `Bool`
fields instead measured about eight percent on
`document@100 serialize` even with every read of them removed.

Parameters:

- `ascii_only`: Escape every code point above U+007F as `\uXXXX`. A character outside the basic plane becomes the surrogate pair JSON spells it with.
- `solidus`: Escape `/` as `\/`. JSON does not require it, but embedding output in a `<script>` element does.

#### `JsonWriter.write_string_span`

```mojo
def write_string_span[ascii_only: Bool = False, solidus: Bool = False](mut self, b: Span[UInt8])
```

A quoted, escaped JSON string literal.

One pass: the first chunk with something to escape hands
straight over to the escape path, which restarts from the
beginning; a string with no escapes -- the usual case -- is a
quote, one memcpy and a quote.

#### `JsonWriter.begin_object`

```mojo
def begin_object(mut self)
```

#### `JsonWriter.end_object`

```mojo
def end_object(mut self)
```

#### `JsonWriter.begin_array`

```mojo
def begin_array(mut self)
```

#### `JsonWriter.end_array`

```mojo
def end_array(mut self)
```

#### `JsonWriter.key`

```mojo
def key(mut self, k: String)
```

An object key plus its colon.

#### `JsonWriter.value_written`

```mojo
def value_written(mut self)
```

Mark that a value completed, so the next member emits a comma.

#### `JsonWriter.item_null`

```mojo
def item_null(mut self)
```

#### `JsonWriter.item_bool`

```mojo
def item_bool(mut self, b: Bool)
```

#### `JsonWriter.item_int`

```mojo
def item_int(mut self, v: Int64)
```

#### `JsonWriter.item_float`

```mojo
def item_float(mut self, v: Float64)
```

#### `JsonWriter.item_string`

```mojo
def item_string(mut self, s: String)
```

#### `JsonWriter.open_container`

```mojo
def open_container(mut self, brace: UInt8)
```

#### `JsonWriter.close_container`

```mojo
def close_container(mut self, brace: UInt8, empty: Bool)
```

#### `JsonWriter.next_child`

```mojo
def next_child(mut self, first: Bool)
```

Separator before a container child.

The compact case -- every child of every container, in the
overwhelmingly common configuration -- is one comma and one
correctly predicted branch; the newline helper is only called
for pretty output.

#### `JsonWriter.colon`

```mojo
def colon(mut self)
```

#### `JsonWriter.finish`

```mojo
def finish(deinit self) -> List[UInt8]
```

The written bytes. Moves the buffer out; no copy.

#### `JsonWriter.finish_string`

```mojo
def finish_string(deinit self) -> String
```

The written bytes as a `String`.

## Functions

### `needs_escape`

```mojo
def needs_escape(b: Span[UInt8]) -> Bool
```

True if any byte requires escaping in a JSON string literal.

One SIMD pass testing `== '"'`, `== '\'` and `< 0x20` per byte. The
answer is almost always False, which is what makes the memcpy fast
path in `write_string` worth having.

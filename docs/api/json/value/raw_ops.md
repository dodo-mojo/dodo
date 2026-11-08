# `dodo.json.value.raw_ops`

## Functions

### `escape_json_bytes`

```mojo
def escape_json_bytes(mut out: List[UInt8], s: String)
```

Append `s` to `out` as a quoted, escaped JSON string literal.

Appends into a caller-owned buffer so a container can escape many
keys and values into one allocation.

Escapes per RFC 8259 s7: quote and backslash always; 0x08, 0x0C,
0x0A, 0x0D and 0x09 as their two-character short forms; every other
byte below 0x20 as a six-character "u00" hex escape.
Bytes >= 0x20 pass through unchanged -- that includes 0x7F (DEL),
which the RFC does *not* require escaping, and all UTF-8
continuation bytes, so multi-byte characters survive untouched.

### `escape_json_string`

```mojo
def escape_json_string(s: String) -> String
```

`s` as a quoted, escaped JSON string literal.

Builds the bytes once and converts once, rather than the previous
`out += chr(Int(c))` per byte -- which constructed a heap `String`
for every character in the input.

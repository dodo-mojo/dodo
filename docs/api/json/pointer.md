# `dodo.json.pointer`

## Functions

### `parse_pointer`

```mojo
def parse_pointer(pointer: String) raises -> List[String]
```

The reference tokens of a JSON Pointer, unescaped.

Args:

- `pointer`: A JSON Pointer. The empty string names the whole document and yields no tokens; anything else must begin with a solidus.

Returns: One entry per reference token, with `~1` decoded to `/` and `~0` to `~`.

Raises: Error: If the pointer does not begin with a solidus, or a `~` is followed by anything other than `0` or `1`.

### `escape_token`

```mojo
def escape_token(token: String) -> String
```

A reference token encoded for use inside a JSON Pointer.

The inverse of what `parse_pointer` decodes: `~` becomes `~0` and
`/` becomes `~1`, in that order, so the result decodes back to the
token it came from.

### `build_pointer`

```mojo
def build_pointer(tokens: List[String]) -> String
```

A JSON Pointer naming the location reached by `tokens`.

### `is_dash`

```mojo
def is_dash(token: String) -> Bool
```

Whether `token` is the past-the-end token `-`.

RFC 6901 gives `-` a meaning only where a new element may be
added, so the caller decides whether to honour it or reject it.

### `array_index`

```mojo
def array_index(token: String, count: Int) raises -> Int
```

A reference token read as an array index.

RFC 6901 spells an index as `0` or a non-zero digit followed by
digits, so `01`, `+1`, `-1`, ` 1` and the empty string are all
invalid rather than merely out of range. `atol` accepts every one
of them, which is why this does the digit check itself.

Args:

- `token`: The reference token.
- `count`: The array's length, used for the range check.

Returns: The index, which is in `[0, count)`.

Raises: Error: If the token is not a valid index, or names an element the array does not have.

### `index_value`

```mojo
def index_value(token: String) raises -> Int
```

A reference token read as an index, without a range check.

Used where the bound differs from the array's length, as it does
for the `add` operation of RFC 6902, which may name the position
one past the last element.

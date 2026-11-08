# `dodo.json.document`

## Aliases

### `TAPE_TAG_NULL`

```mojo
comptime TAPE_TAG_NULL = UInt8(0)
```

### `TAPE_TAG_BOOL`

```mojo
comptime TAPE_TAG_BOOL = UInt8(1)
```

### `TAPE_TAG_INT`

```mojo
comptime TAPE_TAG_INT = UInt8(2)
```

### `TAPE_TAG_FLOAT`

```mojo
comptime TAPE_TAG_FLOAT = UInt8(3)
```

### `TAPE_TAG_STRING`

```mojo
comptime TAPE_TAG_STRING = UInt8(4)
```

### `TAPE_TAG_ARRAY`

```mojo
comptime TAPE_TAG_ARRAY = UInt8(5)
```

### `TAPE_TAG_OBJECT`

```mojo
comptime TAPE_TAG_OBJECT = UInt8(6)
```

### `TAPE_TAG_KEY`

```mojo
comptime TAPE_TAG_KEY = UInt8(7)
```

### `TAPE_TAG_STRING_OWNED`

```mojo
comptime TAPE_TAG_STRING_OWNED = UInt8(8)
```

### `TAPE_TAG_KEY_INLINE`

```mojo
comptime TAPE_TAG_KEY_INLINE = UInt8(9)
```

### `TAPE_TAG_INT_POOL`

```mojo
comptime TAPE_TAG_INT_POOL = UInt8(10)
```

### `TAPE_TAG_UINT`

```mojo
comptime TAPE_TAG_UINT = UInt8(11)
```

## Structs

### `Document`

```mojo
struct Document
```

Owns the JSON input bytes and a packed tape of entries.

A `Document` is the storage unit produced by parsers. A `Value` view
references a tape entry inside a `Document` by index; when a `Value`
is mutated, the document is materialized into an owned tree
(`OwnedValue` in `value/owned.mojo`).

Side pools:
  - `key_pool` stores unescaped object keys. Object KEY entries store a
    pool offset rather than an offset into `input`, so unescaped keys
    survive even when the original bytes are released.
  - `string_pool` stores unescaped STRING values that needed
    materialisation (e.g. escapes). Clean strings stay zero-copy
    as STRING (offset, length) entries into `input`.
  - `float_pool` stores `Float64` values, since 64-bit IEEE 754 doesn't
    fit in 60 bits.
  - `int_pool` holds integers too wide for the 60-bit inline
    payload, both signed (`TAPE_TAG_INT_POOL`) and unsigned
    (`TAPE_TAG_UINT`, stored as a bit pattern).

Fields:

- `input` (`String`)
- `tape` (`List[UInt64]`)
- `key_pool` (`List[String]`)
- `string_pool` (`List[String]`)
- `float_pool` (`List[Float64]`)
- `int_pool` (`List[Int64]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Document.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, var input: String)
```

#### `Document.copy`

```mojo
def copy(self) -> Self
```

#### `Document.append_null`

```mojo
def append_null(mut self) -> Int
```

#### `Document.append_bool`

```mojo
def append_bool(mut self, b: Bool) -> Int
```

#### `Document.append_int`

```mojo
def append_int(mut self, value: Int64) -> Int
```

Append an integer, inline when it fits and pooled when not.

The inline payload is 60 bits, so anything outside
[-2**59, 2**59) is stored in `int_pool`, so
`576460752303423488` keeps its value.

#### `Document.append_uint`

```mojo
def append_uint(mut self, value: UInt64) -> Int
```

Append a magnitude above `Int64.MAX`.

Stored as a bit pattern in the same pool; the tag is what says
to read it back unsigned.

#### `Document.append_float`

```mojo
def append_float(mut self, value: Float64) -> Int
```

#### `Document.append_string`

```mojo
def append_string(mut self, offset: Int, length: Int) -> Int
```

Append a STRING entry referencing bytes [offset:offset+length] of input.

#### `Document.append_key`

```mojo
def append_key(mut self, var key: String) -> Int
```

Intern a key into key_pool and append a KEY entry referencing it.

#### `Document.append_key_inline`

```mojo
def append_key_inline(mut self, offset: Int, length: Int) -> Int
```

Append a zero-copy KEY entry referencing input[offset:offset+length].

Used for the by-far-common case where the JSON key contains no
escapes -- avoids the per-key heap allocation, memcpy, and
key_pool append.

#### `Document.append_string_owned`

```mojo
def append_string_owned(mut self, var value: String) -> Int
```

Append a STRING_OWNED entry whose bytes live in string_pool.

Used for JSON strings that contain escapes (where a zero-copy
slice into `input` would expose the escaped bytes). Clean
strings stay on the zero-copy `append_string` path.

#### `Document.append_array`

```mojo
def append_array(mut self, count: Int, child_start_idx: Int) -> Int
```

#### `Document.append_object`

```mojo
def append_object(mut self, pair_count: Int, child_start_idx: Int) -> Int
```

#### `Document.get_tag`

```mojo
def get_tag(self, tape_idx: Int) -> UInt8
```

#### `Document.get_payload`

```mojo
def get_payload(self, tape_idx: Int) -> UInt64
```

#### `Document.get_bool`

```mojo
def get_bool(self, tape_idx: Int) -> Bool
```

#### `Document.get_int`

```mojo
def get_int(self, tape_idx: Int) -> Int64
```

Read an integer entry, inline or pooled.

#### `Document.get_uint`

```mojo
def get_uint(self, tape_idx: Int) -> UInt64
```

Read an entry as an unsigned magnitude.

A `TAPE_TAG_UINT` entry is one that only fits here; the signed
tags are accepted too so a caller can ask this question of any
non-negative integer without checking the tag first.

#### `Document.get_float`

```mojo
def get_float(self, tape_idx: Int) -> Float64
```

#### `Document.get_string_offset`

```mojo
def get_string_offset(self, tape_idx: Int) -> Int
```

#### `Document.get_string_length`

```mojo
def get_string_length(self, tape_idx: Int) -> Int
```

#### `Document.get_string`

```mojo
def get_string(self, tape_idx: Int) -> String
```

Materialize a STRING / STRING_OWNED entry as a fresh `String`.

- For `TAPE_TAG_STRING` (clean / zero-copy), the returned string
  is a fresh copy of the slice of `input` referenced by the
  (offset, length) payload. Safe even if `input` is later
  consumed.
- For `TAPE_TAG_STRING_OWNED` (had escapes at parse time), the
  string is read out of `string_pool` and returned as-is.

#### `Document.key_equals`

```mojo
def key_equals(self, tape_idx: Int, key: String) -> Bool
```

Whether a KEY entry spells `key`, without materializing it.

#### `Document.get_key`

```mojo
def get_key(self, tape_idx: Int) -> String
```

Return the unescaped key for a KEY / KEY_INLINE entry.

Dispatches on the tag: TAPE_TAG_KEY is a key_pool index (used
when the key had escapes, or when the key is an owned string);
TAPE_TAG_KEY_INLINE is a
zero-copy `(offset, length)` slice into `input` that we copy
out on read.

#### `Document.get_count`

```mojo
def get_count(self, tape_idx: Int) -> Int
```

Element count for ARRAY, pair count for OBJECT.

#### `Document.get_child_start`

```mojo
def get_child_start(self, tape_idx: Int) -> Int
```

Tape index where this container's children start.

#### `Document.root`

```mojo
def root(self) -> Int
```

Tape index of the root entry. Defined as the LAST entry, since builders write children before their parent so the parent can record a backwards-pointing child_start_idx.

#### `Document.size`

```mojo
def size(self) -> Int
```

## Functions

### `pack_tape_entry`

```mojo
def pack_tape_entry(tag: UInt8, payload: UInt64) -> UInt64
```

Pack a 4-bit tag with a 60-bit payload into one tape entry.

### `tape_tag`

```mojo
def tape_tag(entry: UInt64) -> UInt8
```

Extract the 4-bit type tag from a tape entry.

### `tape_payload`

```mojo
def tape_payload(entry: UInt64) -> UInt64
```

Extract the 60-bit payload from a tape entry.

### `pack_pair`

```mojo
def pack_pair(hi30: UInt64, lo30: UInt64) -> UInt64
```

Pack two 30-bit unsigned values into a 60-bit payload.

### `payload_hi30`

```mojo
def payload_hi30(payload: UInt64) -> Int
```

Return the high 30 bits of a payload as an Int.

### `payload_lo30`

```mojo
def payload_lo30(payload: UInt64) -> Int
```

Return the low 30 bits of a payload as an Int.

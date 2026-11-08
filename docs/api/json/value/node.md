# `dodo.json.value.node`

## Aliases

### `OWNED_NULL`

```mojo
comptime OWNED_NULL = 0
```

### `OWNED_BOOL`

```mojo
comptime OWNED_BOOL = 1
```

### `OWNED_INT`

```mojo
comptime OWNED_INT = 2
```

### `OWNED_FLOAT`

```mojo
comptime OWNED_FLOAT = 3
```

### `OWNED_STRING`

```mojo
comptime OWNED_STRING = 4
```

### `OWNED_ARRAY`

```mojo
comptime OWNED_ARRAY = 5
```

### `OWNED_OBJECT`

```mojo
comptime OWNED_OBJECT = 6
```

### `OWNED_UINT`

```mojo
comptime OWNED_UINT = 7
```

## Structs

### `OwnedValue`

```mojo
struct OwnedValue
```

Structured tree representation of a JSON value.

Unlike `Value`, an `OwnedValue` for an array stores its children in
`array_val: List[OwnedValue]` rather than as a raw JSON substring,
so a mutation at any nesting level can be applied in place and a
fresh JSON serialization can be produced after the fact.

Fields:

- `kind` (`Int`)
- `bool_val` (`Bool`)
- `int_val` (`Int64`)
- `float_val` (`Float64`)
- `str_val` (`String`)
- `array_val` (`List[OwnedValue]`)
- `object_keys` (`List[String]`)
- `object_values` (`List[OwnedValue]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `OwnedValue.__init__`

```mojo
def __init__(out self)
```

#### `OwnedValue.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `OwnedValue.copy`

```mojo
def copy(self) -> Self
```

#### `OwnedValue.make_null`

```mojo
def make_null() -> Self
```

#### `OwnedValue.make_bool`

```mojo
def make_bool(b: Bool) -> Self
```

#### `OwnedValue.make_int`

```mojo
def make_int(i: Int64) -> Self
```

#### `OwnedValue.make_uint`

```mojo
def make_uint(u: UInt64) -> Self
```

#### `OwnedValue.make_float`

```mojo
def make_float(f: Float64) -> Self
```

#### `OwnedValue.make_string`

```mojo
def make_string(var s: String) -> Self
```

#### `OwnedValue.make_array`

```mojo
def make_array(var items: List[Self]) -> Self
```

#### `OwnedValue.make_object`

```mojo
def make_object(var keys: List[String], var values: List[Self]) -> Self
```

#### `OwnedValue.find_key`

```mojo
def find_key(self, key: String) -> Int
```

Index of `key` in `object_keys`, or -1.

A linear scan, deliberately. Objects in practice hold a handful of
keys, where scanning a contiguous `List` beats hashing; and giving
every node a `Dict` would put a heap allocation back into the
default-constructed node, which is exactly what keeps scalars and
empty containers allocation-free.

#### `OwnedValue.set_key`

```mojo
def set_key(mut self, var key: String, var value: Self)
```

Insert or overwrite `key`. O(1) amortized for a new key.

#### `OwnedValue.push`

```mojo
def push(mut self, var value: Self)
```

Append to an array node. O(1) amortized.

#### `OwnedValue.take_key`

```mojo
def take_key(mut self, key: String) raises -> Self
```

Remove `key` from an object node and hand back its value.

The value is moved out rather than copied, so removing a large
subtree costs no more than removing a scalar. Removal shifts the
later members down one slot, which keeps the two parallel lists
in step and preserves the insertion order of everything that
stays; an object that round-trips through a removal therefore
still serializes its remaining members in the order they were
parsed.

Args:

- `key`: The member name to remove.

Returns: The value that was stored under `key`.

Raises: Error: If no member named `key` is present.

#### `OwnedValue.take_index`

```mojo
def take_index(mut self, index: Int) raises -> Self
```

Remove element `index` from an array node and hand it back.

Args:

- `index`: A position already normalized into `0 ..< len`.

Returns: The element that was stored at `index`.

Raises: Error: If `index` names no element.

# `dodo.http.headers`

HTTP header collection with case-insensitive key lookup.

Lookups use inline case-insensitive byte comparison (no pre-computed
lowercase mirror). Original casing is preserved for wire serialisation.

## Structs

### `HeaderInjectionError`

```mojo
struct HeaderInjectionError
```

Raised when a header key or value contains CR, LF or NUL bytes.

Fields:

- `field` (`String`)
- `value` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `HeaderInjectionError.__init__`

```mojo
def __init__(out self, field: String, value: String)
```

#### `HeaderInjectionError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `HeaderMap`

```mojo
struct HeaderMap
```

An ordered, case-insensitive HTTP header collection.

Keys are stored in their original casing. Lookups use inline
case-insensitive byte comparison -- no pre-computed lowercase list.

This type is ``Movable`` but not ``Copyable``.
Use ``copy()`` when an explicit copy is needed.

Example:
```mojo
var h = HeaderMap()
h.set("Content-Type", "application/json")
print(h.get("content-type")) # application/json
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `Writable`

#### `HeaderMap.__init__`

```mojo
def __init__(out self)
```

#### `HeaderMap.reserve`

```mojo
def reserve(mut self, n: Int)
```

Make room for ``n`` fields without regrowing.

#### `HeaderMap.copy`

```mojo
def copy(self) -> Self
```

Return a deep copy of this ``HeaderMap``.

#### `HeaderMap.set`

```mojo
def set(mut self, key: String, value: String) raises
```

Set a header, replacing any existing value with the same key.

Args:

- `key`: Header name (case-insensitive; stored in original casing).
- `value`: Header value.

Raises: HeaderInjectionError: If ``key`` or ``value`` contains CR, LF or NUL.

#### `HeaderMap.append`

```mojo
def append(mut self, key: String, value: String) raises
```

Append a header without replacing existing values.

Args:

- `key`: Header name.
- `value`: Header value.

Raises: HeaderInjectionError: If ``key`` or ``value`` contains CR, LF or NUL.

#### `HeaderMap.get`

```mojo
def get(self, key: String) -> String
```

Return the first value for ``key``, or ``""`` if absent.

Args:

- `key`: Header name (case-insensitive).

Returns: The header value, or ``""`` if not present.

#### `HeaderMap.get_all`

```mojo
def get_all(self, key: String) -> List[String]
```

Return all values for ``key`` in insertion order.

Args:

- `key`: Header name (case-insensitive).

Returns: All matching values; empty list if absent.

#### `HeaderMap.contains`

```mojo
def contains(self, key: String) -> Bool
```

Return True if the header is present.

Args:

- `key`: Header name (case-insensitive).

Returns: True if at least one entry with this key exists.

#### `HeaderMap.remove`

```mojo
def remove(mut self, key: String) -> Bool
```

Remove all entries with the given key.

Args:

- `key`: Header name (case-insensitive).

Returns: True if at least one entry was removed.

#### `HeaderMap.len`

```mojo
def len(self) -> Int
```

Return the total number of header entries (including duplicates).

#### `HeaderMap.name_at`

```mojo
def name_at(self, i: Int) raises -> ref[self._keys["element"]] String
```

The name of field ``i``, in the order the fields were added.

With :meth:`value_at` and :meth:`len`, this walks every field once,
repeated names as separate entries, without copying::

```mojo
for i in range(h.len()):
    use(h.name_at(i), h.value_at(i))
```

Raises: Error: If ``i`` is not in ``[0, len())``.

#### `HeaderMap.value_at`

```mojo
def value_at(self, i: Int) raises -> ref[self._values["element"]] String
```

The value of field ``i``; see :meth:`name_at`.

Raises: Error: If ``i`` is not in ``[0, len())``.

#### `HeaderMap.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

#### `HeaderMap.encode_to`

```mojo
def encode_to(self, mut buf: List[UInt8])
```

Serialise all headers as wire bytes into ``buf``.

Appends ``key: value\r\n`` for each header.

## Functions

### `trailer_field_allowed`

```mojo
def trailer_field_allowed(name: String) -> Bool
```

Whether a trailer field may be kept: not one that frames, routes, authenticates or describes the content (RFC 9110 sec 6.5.1).

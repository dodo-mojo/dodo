# `dodo.http.form`

``application/x-www-form-urlencoded`` parsing (WHATWG URL Living Standard, §5.1).

The format predates RFC 3986 by a decade and lives separately as the
HTML form serialisation algorithm. Practical differences vs §3 query
strings:

- ``+`` decodes to a literal space (RFC 3986 reserves ``+`` for plus).
- Pairs are separated by ``&`` (or ``;`` for legacy compatibility).
- Each pair is ``name=value``; missing ``=`` is treated as ``name=""``.
- Percent-decoding is applied to *both* names and values, after the
  pair split.

This module ships:

- ``urldecode`` — RFC 3986 percent-decode + ``+``→space (the form-data
  variant). Returns the decoded ``String``; bad ``%XX`` escapes raise.
- ``FormData`` — multimap-of-strings (one key may map to multiple
  values, e.g. checkboxes), backed by parallel lists for stable
  insertion order.
- ``parse_form_urlencoded`` — bytes/string → ``FormData``; the
  ``Form`` extractor in ``dodo.http.extract`` is the typed
  handler-side wrapper.

## Structs

### `FormData`

```mojo
struct FormData
```

A name → value(s) multimap, in insertion order.

Backs the ``Form`` extractor; mirrors the API of ``HeaderMap`` so
handlers can write the same code shape against headers, query
strings, and form bodies.

Internally two parallel lists keep insertion order stable
(lookups are O(n), n is typically tiny — sub-100 fields). For
larger forms the dict-of-lists layout would be a future
optimisation; the bench harness has not pushed past 32 fields.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `FormData.__init__`

```mojo
def __init__(out self)
```

#### `FormData.get`

```mojo
def get(self, name: String) -> String
```

Return the first value for ``name`` (case-sensitive), else ``""``.

#### `FormData.get_optional`

```mojo
def get_optional(self, name: String) -> Optional[String]
```

Return ``Some(value)`` if ``name`` is present, ``None`` otherwise.

#### `FormData.get_all`

```mojo
def get_all(self, name: String) -> List[String]
```

Return every value bound to ``name`` in insertion order.

#### `FormData.append`

```mojo
def append(mut self, name: String, value: String)
```

Append ``(name, value)``; existing bindings are preserved.

#### `FormData.contains`

```mojo
def contains(self, name: String) -> Bool
```

Return ``True`` if any binding for ``name`` exists.

#### `FormData.len`

```mojo
def len(self) -> Int
```

Return the total number of bindings (counting duplicate keys).

#### `FormData.keys`

```mojo
def keys(self) -> List[String]
```

Return the list of keys (with duplicates) in insertion order.

#### `FormData.values`

```mojo
def values(self) -> List[String]
```

Return the list of values in insertion order, parallel to ``keys()``.

#### `FormData.to_urlencoded`

```mojo
def to_urlencoded(self) -> String
```

Serialise back to ``application/x-www-form-urlencoded``.

Round-trips ``parse_form_urlencoded`` for any well-formed
input. Uses ``+`` for spaces and ``%XX`` for everything else
outside the unreserved set.

## Functions

### `urldecode`

```mojo
def urldecode(s: String) raises -> String
```

Percent-decode ``s`` and convert ``+`` to space.

Implements the WHATWG application/x-www-form-urlencoded byte
decode: each ``%XX`` triple becomes the byte ``XX``, each ``+``
becomes a single 0x20, every other byte is preserved verbatim.

The decoded bytes must form well-formed UTF-8 (RFC 3629): a
``String`` may not hold anything else, and the escapes come from
attacker-controlled input (``%F0`` alone is a lone 4-byte lead).
Ill-formed output is rejected rather than wrapped unchecked.

Args:

- `s`: The encoded string (ASCII, possibly with percent-escapes).

Returns: The decoded ``String``.

Raises: Error: When a ``%`` escape is truncated or contains a non-hex digit, or when the decoded bytes are not valid UTF-8.

### `urlencode`

```mojo
def urlencode(s: String) -> String
```

Percent-encode ``s`` for use in form bodies / query strings.

Encodes per the WHATWG application/x-www-form-urlencoded byte
encode: unreserved characters (``A-Z``, ``a-z``, ``0-9``, ``-``,
``_``, ``.``, ``~``) pass through; spaces become ``+``; every
other byte becomes ``%XX``. Suitable for both names and values.

Args:

- `s`: The string to encode (any UTF-8 bytes).

Returns: The percent-encoded ``String``.

### `parse_form_urlencoded`

```mojo
def parse_form_urlencoded(body: String) raises -> FormData
```

Parse ``application/x-www-form-urlencoded`` bytes into a ``FormData``.

Pair separators are ``&`` and ``;`` (legacy HTML forms still emit
the latter). Empty pairs are skipped silently. ``name=`` keeps an
empty-string value; ``name`` (no ``=``) also keeps an empty-string
value.

Args:

- `body`: Form body as a ``String``. Empty input produces an empty ``FormData`` (no error).

Returns: Populated ``FormData``.

Raises: Error: If a percent-escape is malformed inside a name or value, or a decoded name / value is not valid UTF-8 (delegated from ``urldecode``).

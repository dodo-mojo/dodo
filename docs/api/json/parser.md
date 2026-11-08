# `dodo.json.parser`

``loads``: JSON text to a ``Value``.

Parsing goes through simdjson (``dodo/json/ffi``) when its library is
available, and through the pure-Mojo parser otherwise. When simdjson
rejects an input, the pure-Mojo parser decides: it returns the value for
the few inputs simdjson refuses but JSON allows (integers wider than 64
bits become floats, a lone surrogate escape becomes U+FFFD), and it raises
the error for everything else. So both paths give the same result for
every input.

## Functions

### `loads`

```mojo
def loads(var s: String) raises -> Value
```

Parse JSON text into a ``Value``.

Args:

- `s`: The JSON text. The returned ``Value`` owns it.

Returns: A ``Value`` view over the parsed document.

Raises: Error: If ``s`` is not valid JSON.

```mojo
def loads(bytes: Span[UInt8]) raises -> Value
```

Parse JSON bytes into a ``Value``.

The bytes are checked for well-formed UTF-8, because a ``String`` built
from ill-formed bytes is undefined behaviour.

Args:

- `bytes`: The JSON text.

Returns: A ``Value`` view over the parsed document.

Raises: Error: If ``bytes`` is not UTF-8 or not valid JSON.

### `parse_mojo_string`

```mojo
def parse_mojo_string(var s: String) raises -> Value
```

Parse ``s`` with the pure-Mojo parser.

Args:

- `s`: The JSON text. The returned ``Value`` owns it.

Returns: A ``Value`` view over the parsed document.

Raises: Error: If ``s`` is not valid JSON.

### `parse_mojo_bytes`

```mojo
def parse_mojo_bytes(bytes: Span[UInt8]) raises -> Value
```

Parse ``bytes`` with the pure-Mojo parser, after a UTF-8 check.

Args:

- `bytes`: The JSON text.

Returns: A ``Value`` view over the parsed document.

Raises: Error: If ``bytes`` is not UTF-8 or not valid JSON.

### `parse_simdjson_string`

```mojo
def parse_simdjson_string(var s: String) raises -> Value
```

Parse ``s`` with simdjson, falling back to the Mojo parser when simdjson rejects it.

Args:

- `s`: The JSON text.

Returns: A ``Value`` view over the parsed document.

Raises: Error: If the library is not loaded or ``s`` is not valid JSON.

### `parse_simdjson_bytes`

```mojo
def parse_simdjson_bytes(bytes: Span[UInt8]) raises -> Value
```

Parse ``bytes`` with simdjson, falling back to the Mojo parser when simdjson rejects them.

Args:

- `bytes`: The JSON text.

Returns: A ``Value`` view over the parsed document.

Raises: Error: If the library is not loaded, or ``bytes`` is not UTF-8 or not valid JSON.

### `simdjson_accepts`

```mojo
def simdjson_accepts(bytes: Span[UInt8]) raises -> Bool
```

Whether simdjson itself parses ``bytes``, with no fallback.

Args:

- `bytes`: The JSON text.

Returns: True if simdjson accepts ``bytes``.

Raises: Error: If the library is not loaded.

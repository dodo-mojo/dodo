# `dodo.json.config`

## Structs

### `ParserConfig`

```mojo
struct ParserConfig
```

Configuration options for JSON parsing.

Example:

```mojo
var config = ParserConfig(max_depth=10, allow_comments=True)
var data = loads(json_str, config).
```

Fields:

- `max_depth` (`Int`): Maximum nesting depth allowed. 0 = unlimited (default).
- `allow_comments` (`Bool`): Allow JavaScript-style comments (// and /* */). Default: False.
- `allow_trailing_comma` (`Bool`): Allow trailing commas in arrays and objects. Default: False.
- `ijson` (`Bool`): Enforce I-JSON (RFC 7493). Default: False.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `ParserConfig.__init__`

```mojo
def __init__(out self, max_depth: Int = Int(0), allow_comments: Bool = False, allow_trailing_comma: Bool = False, ijson: Bool = False)
```

Create parser configuration.

Args:

- `max_depth`: Maximum nesting depth (0 = unlimited).
- `allow_comments`: Allow // and /* */ comments.
- `allow_trailing_comma`: Allow trailing commas.
- `ijson`: Enforce the checkable rules of RFC 7493.

#### `ParserConfig.default`

```mojo
def default() -> Self
```

Create default (strict) parser configuration.

#### `ParserConfig.lenient`

```mojo
def lenient() -> Self
```

Create lenient parser configuration allowing common extensions.

#### `ParserConfig.interoperable`

```mojo
def interoperable() -> Self
```

Create an I-JSON (RFC 7493) parser configuration.

Stricter than the default: the extensions stay off and the two
checkable I-JSON rules are enforced.

### `SerializerConfig`

```mojo
struct SerializerConfig
```

Configuration options for JSON serialization.

Example:

```mojo
var config = SerializerConfig(sort_keys=True, indent="  ")
var json = dumps(value, config).
```

Fields:

- `indent` (`String`): Indentation string. Empty = compact output (default).
- `sort_keys` (`Bool`): Sort object keys alphabetically. Default: False.
- `escape_unicode` (`Bool`): Escape non-ASCII characters as \uXXXX. Default: False.
- `escape_forward_slash` (`Bool`): Escape forward slashes as \/. Default: False (for HTML safety).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `SerializerConfig.__init__`

```mojo
def __init__(out self, indent: String = "", sort_keys: Bool = False, escape_unicode: Bool = False, escape_forward_slash: Bool = False)
```

Create serializer configuration.

Args:

- `indent`: Indentation string (empty = compact).
- `sort_keys`: Sort object keys alphabetically.
- `escape_unicode`: Escape non-ASCII as \uXXXX.
- `escape_forward_slash`: Escape / as \/ (for HTML embedding).

#### `SerializerConfig.default`

```mojo
def default() -> Self
```

Create default serializer configuration (compact output).

#### `SerializerConfig.pretty`

```mojo
def pretty(indent: String = "  ") -> Self
```

Create pretty-print configuration with given indent.

## Functions

### `preprocess_json`

```mojo
def preprocess_json(json: String, config: ParserConfig) raises -> String
```

Preprocess JSON according to config options.

This handles:
- Stripping comments if allow_comments is True.
- Removing trailing commas if allow_trailing_comma is True.
- Checking max_depth if specified.

Args:

- `json`: Input JSON string.
- `config`: Parser configuration.

Returns: Preprocessed JSON string.

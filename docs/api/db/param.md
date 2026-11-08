# `dodo.db.param`

Query parameters: one value sent to the server apart from the SQL text.

## Structs

### `Param`

```mojo
struct Param
```

A value bound to a placeholder (`$1`, `?`, `{name:Type}`).

Converts implicitly from the common types, so calls read naturally:

```mojo
db.query("select * from users where id = $1 and active = $2", 42, True)
db.execute("update users set note = $1", Param.null())
```

`Optional` values become NULL when empty.

Fields:

- `kind` (`Int`)
- `int_value` (`Int`)
- `float_value` (`Float64`)
- `text` (`String`)
- `data` (`List[UInt8]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

Aliases:

- `NULL = 0`
- `INT = 1`
- `FLOAT = 2`
- `BOOL = 3`
- `TEXT = 4`
- `BYTES = 5`

#### `Param.__init__`

```mojo
def __init__(out self, *, kind: Int)
```

```mojo
def __init__(out self, value: Int)
```

```mojo
def __init__(out self, value: Int64)
```

```mojo
def __init__(out self, value: Int32)
```

```mojo
def __init__(out self, value: Float64)
```

```mojo
def __init__(out self, value: Float32)
```

```mojo
def __init__(out self, value: Bool)
```

```mojo
def __init__(out self, value: String)
```

```mojo
def __init__(out self, value: StringLiteral)
```

```mojo
def __init__(out self, value: StringSpan)
```

```mojo
def __init__(out self, value: Optional[Int])
```

```mojo
def __init__(out self, value: Optional[Float64])
```

```mojo
def __init__(out self, value: Optional[Bool])
```

```mojo
def __init__(out self, value: Optional[String])
```

#### `Param.null`

```mojo
def null() -> Self
```

SQL NULL.

#### `Param.bytes`

```mojo
def bytes(data: Span[UInt8]) -> Self
```

Raw bytes (`bytea`, `BLOB`, `VARBINARY`).

#### `Param.is_null`

```mojo
def is_null(self) -> Bool
```

#### `Param.as_text`

```mojo
def as_text(self) -> String
```

The value as the text a server parses: `42`, `9.5`, `true`.

Bytes are not text; drivers send them in binary form instead.

#### `Param.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

## Functions

### `params_of`

```mojo
def params_of(params: VariadicList[Param]) -> List[Param]
```

Copy variadic parameters into a list a driver can keep.

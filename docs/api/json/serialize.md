# `dodo.json.serialize`

## Traits

### `Serializable`

```mojo
trait Serializable
```

Trait for types that can be serialized to JSON.

Implement this trait to enable automatic serialization with serialize().

Example:

```mojo
struct Person(Serializable):
    var name: String
    var age: Int

    def to_json(self) -> String:
        return '{"name":' + to_json_value(self.name) +
               ',"age":' + to_json_value(self.age) + '}'

var json = serialize(Person("Alice", 30))  # {"name":"Alice","age":30}
```

Inherits from: `AnyType`

#### `Serializable.to_json`

```mojo
def to_json(self) -> String
```

Serialize this object to a JSON string.

## Functions

### `to_string`

```mojo
def to_string(v: Value) -> String
```

Convert a Value to a JSON string (compact).

### `dumps`

```mojo
def dumps(v: Value, indent: String = "") -> String
```

Serialize a Value to JSON string (like Python's json.dumps).

Example:

```mojo
var data = loads('{"name": "Alice", "age": 30}')
print(dumps(data))  # {"name":"Alice","age":30}.
print(dumps(data, indent="  "))  # Pretty-printed.
```

Args:

- `v`: Value to serialize.
- `indent`: Indentation string (empty for compact, e.g., " " for 2 spaces).

Returns: JSON string representation.

```mojo
def dumps(v: Value, config: SerializerConfig) -> String
```

Serialize a Value with custom configuration.

Every option is honoured by the writer during the one structural
walk, so the finished text is never re-scanned.

Example:

```mojo
var json = dumps(value, SerializerConfig(indent="  ", escape_unicode=True)).
```

Args:

- `v`: Value to serialize.
- `config`: Serializer configuration.

Returns: JSON string representation.

```mojo
def dumps[format: StringSpan[ImmStaticOrigin] = StringSpan("json")](values: List[Value]) -> String
```

Serialize a list of Values to NDJSON string.

Example:

```mojo
var values = List[Value]()
values.append(loads('{"a":1}'))
values.append(loads('{"a":2}'))
print(dumps[format="ndjson"](values)).
```

Parameters:

- `format`: Must be "ndjson" for this overload.

Args:

- `values`: List of Values to serialize.

Returns: NDJSON string (one JSON value per line).

```mojo
def dumps[format: StringSpan[ImmStaticOrigin] = StringSpan("json")](values: List[Value], config: SerializerConfig) -> String
```

Serialize a list of Values to NDJSON with custom configuration.

The indent option is ignored here: NDJSON puts one value per line,
so a value spread over several lines would not be readable back.

Parameters:

- `format`: Must be "ndjson" for this overload.

Args:

- `values`: List of Values to serialize.
- `config`: Serializer configuration.

Returns: NDJSON string (one JSON value per line).

### `dump`

```mojo
def dump(v: Value, mut f: FileHandle) raises
```

Serialize a Value and write to file (like Python's json.dump).

Example:

```mojo
with open("output.json", "w") as f:
    dump(data, f).
```

Args:

- `v`: Value to serialize.
- `f`: FileHandle to write JSON to.

```mojo
def dump(v: Value, mut f: FileHandle, indent: String) raises
```

Serialize a Value with indentation and write to file.

Example:

```mojo
with open("output.json", "w") as f:
    dump(data, f, indent="  ").
```

Args:

- `v`: Value to serialize.
- `f`: FileHandle to write JSON to.
- `indent`: Indentation string.

```mojo
def dump(v: Value, mut f: FileHandle, config: SerializerConfig) raises
```

Serialize a Value with custom configuration and write to file.

Example:

```mojo
with open("output.json", "w") as f:
    dump(data, f, SerializerConfig(indent="  ", sort_keys=True)).
```

Args:

- `v`: Value to serialize.
- `f`: FileHandle to write JSON to.
- `config`: Serializer configuration.

```mojo
def dump[format: StringSpan[ImmStaticOrigin] = StringSpan("json")](values: List[Value], mut f: FileHandle) raises
```

Serialize a list of Values to NDJSON and write to file.

Example:

```mojo
with open("output.ndjson", "w") as f:
    dump[format="ndjson"](values, f).
```

Parameters:

- `format`: Must be "ndjson" for this overload.

Args:

- `values`: List of Values to serialize.
- `f`: FileHandle to write NDJSON to.

### `to_json_string`

```mojo
def to_json_string(s: String) -> String
```

Convert a String to JSON string format (with quotes and escaping).

### `to_json_value`

```mojo
def to_json_value(val: String) -> String
```

Convert String to JSON.

```mojo
def to_json_value(val: Int) -> String
```

Convert Int to JSON.

```mojo
def to_json_value(val: Int64) -> String
```

Convert Int64 to JSON.

```mojo
def to_json_value(val: Float64) -> String
```

Convert Float64 to JSON.

```mojo
def to_json_value(val: Bool) -> String
```

Convert Bool to JSON.

### `serialize`

```mojo
def serialize[T: Serializable](obj: T) -> String
```

Serialize an object to JSON string.

The object must implement the Serializable trait with a to_json() method.

Example:

```mojo
var person = Person("Alice", 30)
var json = serialize(person)  # `{"name":"Alice","age":30}`.
```

Parameters:

- `T`: Type that implements Serializable.

Args:

- `obj`: Object to serialize.

Returns: JSON string representation.

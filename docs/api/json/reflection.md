# `dodo.json.reflection`

Reflection-based JSON serialization and deserialization.

Zero-boilerplate serde for Mojo structs using compile-time reflection.
Structs are automatically mapped to/from JSON objects by reflecting over
field names and types at compile time.

Supported field types:

```mojo
Scalars: Int, Int64, Bool, Float64, Float32, String
Containers: List[Int], List[String], List[Float64], List[Bool],
            Optional[Int], Optional[String], Optional[Float64], Optional[Bool]
Nested structs (recursive reflection)
Value (raw JSON pass-through)
```

Serialization requires no traits -- any struct works:

```mojo
@fieldwise_init
struct Point:
    var x: Int
    var y: Int

var json = serialize_json(Point(1, 2))  # {"x":1,"y":2}
```

Deserialization requires Defaultable and Movable:

```mojo
@fieldwise_init
struct Point(Defaultable, Movable):
    var x: Int
    var y: Int

    def __init__(out self):
        self.x = 0
        self.y = 0

var p = deserialize_json[Point]('{"x":1,"y":2}')
```

## Traits

### `JsonSerializable`

```mojo
trait JsonSerializable
```

Override reflection serialization for a struct.

Implement this to control exactly how a struct is serialized to a
json Value. The reflection serializer will call ``to_json_value``
instead of walking fields.

Example::

```mojo
@fieldwise_init
struct Color(JsonSerializable, Defaultable, Movable):
    var r: Int
    var g: Int
    var b: Int

    def to_json_value(self) raises -> Value:
        return loads(
            '"rgb(' + String(self.r) + ","
            + String(self.g) + "," + String(self.b) + ')"'
        )
```

Inherits from: `AnyType`

#### `JsonSerializable.to_json_value`

```mojo
def to_json_value(self) raises -> Value
```

### `JsonDeserializable`

```mojo
trait JsonDeserializable
```

Override reflection deserialization for a struct.

Implement this to control exactly how a struct is deserialized from
a json Value. The reflection deserializer will call
``from_json_value`` instead of walking fields.

Example::

```mojo
@fieldwise_init
struct Color(JsonDeserializable, Defaultable, Movable):
    var r: Int
    var g: Int
    var b: Int

    @staticmethod
    def from_json_value(json: Value) raises -> Self:
        var s = json.string_value()
        # parse "rgb(r,g,b)" ...
        return Self(r=..., g=..., b=...)
```

Inherits from: `AnyType`

#### `JsonDeserializable.from_json_value`

```mojo
def from_json_value(json: Value) raises -> Self
```

## Functions

### `serialize_json`

```mojo
def serialize_json[T: AnyType, pretty: Bool = False](value: T) raises -> String
```

Serialize any value to JSON through compile-time reflection.

Indentation is a second pass over the compact output, on purpose:
making it a mode of the first pass turns every separator in the
comptime-unrolled emitter into a runtime branch and costs the
compact path, which is the one that runs in anger.

Parameters:

- `T`: The type, inferred from the argument.
- `pretty`: Indent with two spaces per level.

Args:

- `value`: The value to serialize.

Returns: The JSON text.

Raises: If a custom `to_json_value` raises.

### `serialize_json_into`

```mojo
def serialize_json_into[T: AnyType](mut w: JsonWriter, value: T) raises
```

Serialize into a writer the caller owns.

For a caller emitting many values: the buffer is the expensive
part, and `reset` makes it reusable. Also the way to splice a
typed value into a larger document without it becoming its own
`String` first.

Parameters:

- `T`: The type, inferred from the argument.

Args:

- `w`: The writer to emit into.
- `value`: The value to serialize.

Raises: If a custom `to_json_value` raises.

### `serialize_value`

```mojo
def serialize_value[T: AnyType](value: T) raises -> Value
```

Serialize a struct to a json Value via compile-time reflection.

Parameters:

- `T`: The struct type (inferred).

Args:

- `value`: The struct instance.

Returns: A json Value representing the JSON.

### `deserialize_json`

```mojo
def deserialize_json[T: Deinitable & Movable](json_str: String) raises -> T
```

Read JSON into a struct through compile-time reflection.

Reads straight from the bytes into the fields, with no `Document`,
no refcount touch per access and no `String` per object key.

`T` needs only to be movable: fields are written once, into their
final addresses.

Parameters:

- `T`: The struct type to build.

Args:

- `json_str`: The JSON text.

Returns: The decoded value.

Raises: If the text is not valid JSON, a required field is missing, or a field's value does not match its type. The message names the path to the offending field.

```mojo
def deserialize_json[T: Deinitable & Movable](json_bytes: Span[UInt8]) raises -> T
```

Read JSON bytes into a struct through compile-time reflection.

Parameters:

- `T`: The struct type to build.

Args:

- `json_bytes`: The JSON text, as bytes.

Returns: The decoded value.

Raises: If the text is not valid JSON or does not match `T`.

### `deserialize_value`

```mojo
def deserialize_value[T: Deinitable & Movable](json: Value) raises -> T
```

Read a `Value` into a struct.

Goes through the value's text, because the reader works on bytes
and a `Value` is a position in a document rather than one. A
caller with the text should hand over the text.

Parameters:

- `T`: The struct type to build.

Args:

- `json`: The value to read.

Returns: The decoded value.

Raises: If the value does not match `T`.

### `try_deserialize_json`

```mojo
def try_deserialize_json[T: Deinitable & Movable](json_str: String) -> Optional[T]
```

`deserialize_json` without the raise.

Parameters:

- `T`: The struct type to build.

Args:

- `json_str`: The JSON text.

Returns: The decoded value, or `None` if anything went wrong.

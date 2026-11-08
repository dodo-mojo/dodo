# `dodo.json.deserialize`

## Traits

### `Deserializable`

```mojo
trait Deserializable
```

Trait for types that can be deserialized from JSON.

Implement this trait to enable automatic deserialization with deserialize().

Example:

```mojo
struct Person(Deserializable):
    var name: String
    var age: Int

    @staticmethod
    def from_json(json: Value) raises -> Self:
        return Self(
            name=get_string(json, "name"),
            age=get_int(json, "age")
        )

var person = deserialize[Person]('{"name":"Alice","age":30}')
```

Inherits from: `AnyType`

#### `Deserializable.from_json`

```mojo
def from_json(json: Value) raises -> Self
```

Deserialize from a JSON Value.

## Functions

### `get_string`

```mojo
def get_string(value: Value, key: String) raises -> String
```

Extract a string field from a JSON object Value.

Example:

```mojo
var json = loads('{"name": "Alice"}')
var name = get_string(json, "name")  # Returns "Alice".
```

Args:

- `value`: The JSON object Value.
- `key`: The field name.

Returns: The string value.

### `get_int`

```mojo
def get_int(value: Value, key: String) raises -> Int
```

Extract an int field from a JSON object Value.

Example:

```mojo
var json = loads('{"age": 30}')
var age = get_int(json, "age")  # Returns 30.
```

Args:

- `value`: The JSON object Value.
- `key`: The field name.

Returns: The int value.

### `get_bool`

```mojo
def get_bool(value: Value, key: String) raises -> Bool
```

Extract a bool field from a JSON object Value.

Example:

```mojo
var json = loads('{"active": true}')
var active = get_bool(json, "active")  # Returns True.
```

Args:

- `value`: The JSON object Value.
- `key`: The field name.

Returns: The bool value.

### `get_float`

```mojo
def get_float(value: Value, key: String) raises -> Float64
```

Extract a float field from a JSON object Value.

Example:

```mojo
var json = loads('{"price": 19.99}')
var price = get_float(json, "price")  # Returns 19.99.
```

Args:

- `value`: The JSON object Value.
- `key`: The field name.

Returns: The float value.

### `deserialize`

```mojo
def deserialize[T: Deserializable](json_str: String) raises -> T
```

Deserialize a JSON string into a typed object.

The type must implement the Deserializable trait with a from_json() static method.

Example:

```mojo
var person = deserialize[Person]('{"name":"Alice","age":30}')
print(person.name)  # Prints "Alice".
```

Parameters:

- `T`: Type that implements Deserializable.

Args:

- `json_str`: JSON string to deserialize.

Returns: Deserialized object of type T.

# `std.builtin.none`

Defines the builtin `NoneType`.

These are Mojo built-ins, so you don't need to import them.

## Structs

### `NoneType`

```mojo
struct NoneType
```

Represents the absence of a value.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`

#### `NoneType.__init__`

```mojo
def __init__() -> Self
```

Construct an instance of the `None` type.

```mojo
def __init__(value: None) -> Self
```

Construct an instance of the `None` type.

Args:

- `value`: The MLIR none type to construct from.

#### `NoneType.write_to`

```mojo
def write_to(self, mut writer: T)
```

Writes `None` to a writer.

Args:

- `writer`: The object to write to.

#### `NoneType.write_repr_to`

```mojo
def write_repr_to(self, mut writer: T)
```

Writes `None` to a writer.

Args:

- `writer`: The object to write to.

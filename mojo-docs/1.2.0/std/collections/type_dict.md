# `std.collections.type_dict`

Provides a data structure which acts to map a value of a given type to one of a set of types.

## Structs

### `TypeDict`

```mojo
struct TypeDict[T: Equatable & Movable, Trait: AnyTrait[AnyType], //, keys: List[T], *values: Trait]
```

A compile-time map from a value of type `T` to a type.

`TypeDict` pairs a list of compile-time key values with a list of types of
the same length. Looking up a key value yields the type at the matching
position, so it acts as a value-keyed switch over types resolved entirely
at compile time.

Examples:

```mojo
from std.collections import TypeDict
from std.testing import assert_equal

comptime td = TypeDict[
    T=Int,
    Trait=AnyType,
    [1,2,3],
    Int, String, Float64,
]

def main() raises:
    comptime assert td.get[1] == Int
    comptime assert td.get[2] == String
    comptime assert td.get[3] == Float64
    assert_equal(td.length, 3)
```

Parameters:

- `T`: The type of the key values.
- `Trait`: The trait that every mapped type conforms to.
- `keys`: The key values, one per mapped type.
- `*values`: The mapped types, parallel to `keys`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`

Aliases:

- `length = len[TypeList[values]](values)`: The number of entries in the map.
- `get = values[SIMDLength(keys.try_index(key, Int(0), Optional(None)).or_else(TypeDict._assert_key_is_present[key]()))]`: Gets the type mapped to `key`.

#### `TypeDict.__init__`

```mojo
def __init__() -> Self
```

Constructs a `TypeDict`.

Constraints: `keys` and `values` must have the same length.

#### `TypeDict.__len__`

```mojo
def __len__(self) -> Int
```

Gets the number of entries in the map.

Returns: The number of entries in the map (`length`).

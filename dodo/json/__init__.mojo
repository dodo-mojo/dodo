"""JSON for dodo: parse, build, serialise, and reflect structs.

Vendored from ``json`` v0.4.2 (MIT, see ``THIRD_PARTY_NOTICES.md``).

```mojo
from dodo.json import loads, dumps, Value

var data = loads('{"name": "Alice", "scores": [95, 87, 92]}')
print(data["name"].string_value())      # Alice
print(data["scores"][0].int_value())    # 95
print(dumps(data, indent="  "))
```

``loads`` parses with simdjson (``ffi/``) and fills a ``Document`` tape.
If the simdjson wrapper library cannot be loaded, it uses a pure-Mojo
two-pass parser (``cpu/``) that gives the same results. ``Value`` is a
view into the tape until it is mutated, then an owned tree; the API is
the same either way.
"""

from .parser import loads
from .serialize import dumps, dump
from .config import SerializerConfig

from .value import (
    Null,
    Value,
    ValueArrayIter,
    ValueItemsIter,
    ValueKeysIter,
    ValueValuesIter,
)

from .serialize import to_json_value, to_json_string, Serializable, serialize
from .deserialize import (
    get_string,
    get_int,
    get_bool,
    get_float,
    Deserializable,
    deserialize,
)

from .reflection import (
    serialize_json,
    serialize_json_into,
    serialize_value,
    deserialize_json,
    deserialize_value,
    try_deserialize_json,
    JsonSerializable,
    JsonDeserializable,
)

from .pointer import (
    array_index,
    build_pointer,
    escape_token,
    parse_pointer,
)

from .reader import JsonReader
from .writer import JsonWriter
from .value.value import write_value

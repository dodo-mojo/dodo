# `dodo.json`

JSON for dodo: parse, build, serialise, and reflect structs.

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

## Packages

- [`dodo.json.cpu`](cpu/index.md): The CPU parser: a two-pass stage 1 + stage 2 walker.
- [`dodo.json.ffi`](ffi/index.md): Native simdjson binding for ``dodo.json``.
- [`dodo.json.value`](value/index.md)

## Modules

- [`dodo.json.config`](config.md)
- [`dodo.json.deserialize`](deserialize.md)
- [`dodo.json.document`](document.md)
- [`dodo.json.dtoa`](dtoa.md)
- [`dodo.json.errors`](errors.md)
- [`dodo.json.parser`](parser.md): ``loads``: JSON text to a ``Value``.
- [`dodo.json.pointer`](pointer.md)
- [`dodo.json.reader`](reader.md)
- [`dodo.json.reflection`](reflection.md): Reflection-based JSON serialization and deserialization.
- [`dodo.json.serialize`](serialize.md)
- [`dodo.json.unicode`](unicode.md)
- [`dodo.json.writer`](writer.md)

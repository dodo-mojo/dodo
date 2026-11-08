# `dodo.json.ffi.simdjson`

Bindings to simdjson through ``libdodo_simdjson.so``.

The library (built by ``dodo/json/ffi/build.sh``) parses JSON with simdjson
and lays the result out as a ``Document`` tape in its own buffers. This
module loads it once per process, resolves its three entry points, and
copies those buffers into a ``Document``.

## Aliases

### `SIMDJSON_OK`

```mojo
comptime SIMDJSON_OK = Int(0)
```

## Structs

### `SimdjsonTape`

```mojo
struct SimdjsonTape
```

Entry points over the calling thread's parser.

The parser is created once per thread and reuses its buffers, so a
small document costs little beyond simdjson's own work.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `SimdjsonTape.__init__`

```mojo
def __init__(out self) raises
```

Resolve the entry points.

Raises: Error: If the library is not available.

#### `SimdjsonTape.parse`

```mojo
def parse(self, json: Span[UInt8]) -> Int
```

Parse ``json`` into the parser's tape buffers.

Args:

- `json`: The JSON text, any bytes.

Returns: ``SIMDJSON_OK``, or the code of the failure.

#### `SimdjsonTape.take_document`

```mojo
def take_document(self) -> Document
```

Copy the last successful parse out of the parser's buffers.

## Functions

### `simdjson_available`

```mojo
def simdjson_available() -> Bool
```

Whether ``libdodo_simdjson.so`` loaded. Checked once per process.

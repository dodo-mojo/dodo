# `dodo.db.mongo.bson`

BSON, MongoDB's document format: building, validating and reading.

`Bson` is one document, used both to build a query and to read a result:

```mojo
var user = Bson().add("name", "ada").add("score", 9.5).add("tags", BsonArray().append("admin"))
var name = found.string("name")
var city = found.doc("address").string("city")
```

Values are kept encoded. A nested document is just its bytes inside the
parent, so no type has to contain itself. A document from the server is
validated once, bounds and all, when it arrives; reads after that trust it.

## Aliases

### `DB`

```mojo
comptime DB = "mongo"
```

### `DOUBLE`

```mojo
comptime DOUBLE = UInt8(1)
```

### `STRING`

```mojo
comptime STRING = UInt8(2)
```

### `DOCUMENT`

```mojo
comptime DOCUMENT = UInt8(3)
```

### `ARRAY`

```mojo
comptime ARRAY = UInt8(4)
```

### `BINARY`

```mojo
comptime BINARY = UInt8(5)
```

### `UNDEFINED`

```mojo
comptime UNDEFINED = UInt8(6)
```

### `OBJECT_ID`

```mojo
comptime OBJECT_ID = UInt8(7)
```

### `BOOL`

```mojo
comptime BOOL = UInt8(8)
```

### `DATETIME`

```mojo
comptime DATETIME = UInt8(9)
```

### `NULL`

```mojo
comptime NULL = UInt8(10)
```

### `REGEX`

```mojo
comptime REGEX = UInt8(11)
```

### `DB_POINTER`

```mojo
comptime DB_POINTER = UInt8(12)
```

### `JAVASCRIPT`

```mojo
comptime JAVASCRIPT = UInt8(13)
```

### `SYMBOL`

```mojo
comptime SYMBOL = UInt8(14)
```

### `CODE_WITH_SCOPE`

```mojo
comptime CODE_WITH_SCOPE = UInt8(15)
```

### `INT32`

```mojo
comptime INT32 = UInt8(16)
```

### `TIMESTAMP`

```mojo
comptime TIMESTAMP = UInt8(17)
```

### `INT64`

```mojo
comptime INT64 = UInt8(18)
```

### `DECIMAL128`

```mojo
comptime DECIMAL128 = UInt8(19)
```

### `MIN_KEY`

```mojo
comptime MIN_KEY = UInt8(255)
```

### `MAX_KEY`

```mojo
comptime MAX_KEY = UInt8(127)
```

### `MAX_DEPTH`

```mojo
comptime MAX_DEPTH = 100
```

Documents nested deeper than this are refused (the server's own limit).

## Structs

### `BsonValue`

```mojo
struct BsonValue
```

One value: its BSON type byte and its encoded bytes.

Converts implicitly from Int, Float64, Bool, String, `Bson` and
`BsonArray`, so builders read naturally. An Int that fits 32 bits is
sent as int32, like the official drivers do.

Fields:

- `kind` (`UInt8`)
- `data` (`List[UInt8]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `BsonValue.__init__`

```mojo
def __init__(out self, kind: UInt8, var data: List[UInt8])
```

```mojo
def __init__(out self, value: Int)
```

```mojo
def __init__(out self, value: Float64)
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
def __init__(out self, value: Bson)
```

```mojo
def __init__(out self, value: BsonArray)
```

#### `BsonValue.null`

```mojo
def null() -> Self
```

#### `BsonValue.int64`

```mojo
def int64(value: Int) -> Self
```

Always 64 bits (cursor ids, counters that will grow).

#### `BsonValue.binary`

```mojo
def binary(data: Span[UInt8], subtype: UInt8 = UInt8(0)) -> Self
```

#### `BsonValue.date_ms`

```mojo
def date_ms(ms: Int) -> Self
```

A UTC datetime, as milliseconds since 1970.

#### `BsonValue.object_id`

```mojo
def object_id(hex: String) raises -> Self
```

An ObjectId from its 24 hex digits.

#### `BsonValue.new_object_id`

```mojo
def new_object_id() raises -> Self
```

A fresh ObjectId: the time in seconds, then 8 random bytes.

#### `BsonValue.is_null`

```mojo
def is_null(self) -> Bool
```

#### `BsonValue.as_string`

```mojo
def as_string(self) raises -> String
```

A string (also a symbol or JavaScript code).

#### `BsonValue.as_int`

```mojo
def as_int(self) raises -> Int
```

An Int (int32, int64, datetime milliseconds, or a whole double).

#### `BsonValue.as_float`

```mojo
def as_float(self) raises -> Float64
```

#### `BsonValue.as_bool`

```mojo
def as_bool(self) raises -> Bool
```

#### `BsonValue.as_bytes`

```mojo
def as_bytes(self) raises -> List[UInt8]
```

Binary data, without its subtype.

#### `BsonValue.as_doc`

```mojo
def as_doc(self) raises -> Bson
```

#### `BsonValue.as_array`

```mojo
def as_array(self) raises -> List[Self]
```

#### `BsonValue.object_id_hex`

```mojo
def object_id_hex(self) raises -> String
```

#### `BsonValue.type_name`

```mojo
def type_name(self) -> String
```

#### `BsonValue.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Relaxed Extended JSON, for logs and debugging.

### `Bson`

```mojo
struct Bson
```

One document: its elements, in order, without the length header.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Sized`, `Writable`

#### `Bson.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, var body: List[UInt8])
```

#### `Bson.parse`

```mojo
def parse(data: Span[UInt8]) raises -> Self
```

Validate a whole encoded document and keep it.

#### `Bson.add`

```mojo
def add(var self, key: String, value: BsonValue) raises -> Self
```

Append a field and return the document, for chaining.

#### `Bson.put`

```mojo
def put(mut self, key: String, value: BsonValue) raises
```

Append a field.

#### `Bson.encoded`

```mojo
def encoded(self) -> List[UInt8]
```

The document as BSON bytes.

#### `Bson.with_first`

```mojo
def with_first(self, key: String, value: BsonValue) raises -> Self
```

A copy with `key` put first (a generated `_id`).

#### `Bson.find`

```mojo
def find(self, key: String) -> Optional[BsonValue]
```

The value of a top-level field, or None.

#### `Bson.get`

```mojo
def get(self, key: String) raises -> BsonValue
```

#### `Bson.has`

```mojo
def has(self, key: String) -> Bool
```

#### `Bson.is_null`

```mojo
def is_null(self, key: String) -> Bool
```

True when the field is missing or null.

#### `Bson.string`

```mojo
def string(self, key: String) raises -> String
```

#### `Bson.int`

```mojo
def int(self, key: String) raises -> Int
```

#### `Bson.float`

```mojo
def float(self, key: String) raises -> Float64
```

#### `Bson.bool`

```mojo
def bool(self, key: String) raises -> Bool
```

#### `Bson.doc`

```mojo
def doc(self, key: String) raises -> Self
```

#### `Bson.array`

```mojo
def array(self, key: String) raises -> List[BsonValue]
```

#### `Bson.keys`

```mojo
def keys(self) -> List[String]
```

#### `Bson.values`

```mojo
def values(self) -> List[BsonValue]
```

#### `Bson.__len__`

```mojo
def __len__(self) -> Int
```

#### `Bson.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Relaxed Extended JSON, for logs and debugging.

### `BsonArray`

```mojo
struct BsonArray
```

An array under construction: `BsonArray().append(1).append("two")`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Sized`

#### `BsonArray.__init__`

```mojo
def __init__(out self)
```

#### `BsonArray.append`

```mojo
def append(var self, value: BsonValue) -> Self
```

#### `BsonArray.push`

```mojo
def push(mut self, value: BsonValue)
```

#### `BsonArray.__len__`

```mojo
def __len__(self) -> Int
```

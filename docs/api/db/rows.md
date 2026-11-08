# `dodo.db.rows`

Result sets from the SQL drivers, and reading them into structs.

Every SQL driver (PostgreSQL, MySQL, SQLite, ClickHouse) returns `Rows`.
Cells keep the form the driver read them in (text, a native integer or
float, or raw bytes), and the getters convert on the way out, so a column
reads the same whichever database it came from.

```mojo
@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String
    var note: Optional[String]

var rows = db.query("select id, name, note from users where id > $1", 10)
for row in rows:
    print(row.int("id"), row.string("name"))
var users = rows.to[User]()            # columns matched to fields by name
var one = db.query("...", 1).one[User]()
```

## Aliases

### `CELL_TEXT`

```mojo
comptime CELL_TEXT = UInt8(0)
```

The server's text form: `42`, `9.5`, `t`, `2026-11-02`.

### `CELL_INT`

```mojo
comptime CELL_INT = UInt8(1)
```

A 64-bit integer, 8 bytes little-endian.

### `CELL_FLOAT`

```mojo
comptime CELL_FLOAT = UInt8(2)
```

A 64-bit float, 8 bytes little-endian.

### `CELL_BYTES`

```mojo
comptime CELL_BYTES = UInt8(3)
```

Raw bytes (`bytea`, `BLOB`).

## Structs

### `Column`

```mojo
struct Column
```

A result column: its name and the database's name for its type.

Fields:

- `name` (`String`)
- `type_name` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `Column.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `Rows`

```mojo
struct Rows
```

The rows a statement returned, plus what it changed.

`affected` is the number of rows a write changed; `last_insert_id` is
the generated key MySQL and SQLite report (0 elsewhere).

Fields:

- `columns` (`List[Column]`)
- `affected` (`Int`)
- `last_insert_id` (`Int`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`, `Sized`, `Writable`

#### `Rows.__init__`

```mojo
def __init__(out self)
```

#### `Rows.__getitem__`

```mojo
def __getitem__(ref self, index: Int) raises -> Row[origin_of(self)]
```

#### `Rows.add_column`

```mojo
def add_column(mut self, name: String, type_name: String)
```

#### `Rows.push_null`

```mojo
def push_null(mut self)
```

#### `Rows.push_text`

```mojo
def push_text(mut self, text: Span[UInt8])
```

#### `Rows.push_bytes`

```mojo
def push_bytes(mut self, data: Span[UInt8])
```

#### `Rows.push_int`

```mojo
def push_int(mut self, value: Int)
```

#### `Rows.push_float`

```mojo
def push_float(mut self, value: Float64)
```

#### `Rows.end_row`

```mojo
def end_row(mut self) raises
```

Close the row just pushed; it must have one cell per column.

#### `Rows.__len__`

```mojo
def __len__(self) -> Int
```

#### `Rows.column_index`

```mojo
def column_index(self, name: String) raises -> Int
```

The position of the column called `name`.

#### `Rows.__iter__`

```mojo
def __iter__(ref self) -> RowsIter[origin_of(self)]
```

#### `Rows.is_null`

```mojo
def is_null(self, row: Int, column: Int) raises -> Bool
```

#### `Rows.get_int`

```mojo
def get_int(self, row: Int, column: Int) raises -> Int
```

#### `Rows.get_float`

```mojo
def get_float(self, row: Int, column: Int) raises -> Float64
```

#### `Rows.get_bool`

```mojo
def get_bool(self, row: Int, column: Int) raises -> Bool
```

#### `Rows.get_string`

```mojo
def get_string(self, row: Int, column: Int) raises -> String
```

#### `Rows.get_bytes`

```mojo
def get_bytes(self, row: Int, column: Int) raises -> List[UInt8]
```

#### `Rows.to`

```mojo
def to[T: Deinitable & Movable](self) raises -> List[T]
```

Every row as a `T`, filling each field from the column of the same name. A field typed `Optional[...]` takes NULL; any other field raises on NULL. Extra columns are ignored.

#### `Rows.one`

```mojo
def one[T: Deinitable & Movable](self) raises -> T
```

The first row as a `T`; raises when there are no rows.

#### `Rows.first`

```mojo
def first[T: Deinitable & Movable](self) raises -> Optional[T]
```

The first row as a `T`, or None when there are no rows.

#### `Rows.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `Row`

```mojo
struct Row[mut: Bool, //, origin: Origin[mut=mut]]
```

One row of a `Rows`. Columns are found by name or position.

Fields:

- `index` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Row.__init__`

```mojo
def __init__(out self, ref[origin] rows: Rows, index: Int)
```

#### `Row.is_null`

```mojo
def is_null(self, column: Int) raises -> Bool
```

```mojo
def is_null(self, name: String) raises -> Bool
```

#### `Row.int`

```mojo
def int(self, column: Int) raises -> Int
```

```mojo
def int(self, name: String) raises -> Int
```

#### `Row.float`

```mojo
def float(self, column: Int) raises -> Float64
```

```mojo
def float(self, name: String) raises -> Float64
```

#### `Row.bool`

```mojo
def bool(self, column: Int) raises -> Bool
```

```mojo
def bool(self, name: String) raises -> Bool
```

#### `Row.string`

```mojo
def string(self, column: Int) raises -> String
```

```mojo
def string(self, name: String) raises -> String
```

#### `Row.bytes`

```mojo
def bytes(self, column: Int) raises -> List[UInt8]
```

```mojo
def bytes(self, name: String) raises -> List[UInt8]
```

#### `Row.get`

```mojo
def get[T: Deinitable & Movable](self, name: String) raises -> T
```

The column as `T`: any type a struct field may have in `to[T]`.

### `RowsIter`

```mojo
struct RowsIter[mut: Bool, //, origin: Origin[mut=mut]]
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Iterator`, `Movable`

Aliases:

- `Element = Row[origin]`

#### `RowsIter.__init__`

```mojo
def __init__(out self, ref[origin] rows: Rows)
```

#### `RowsIter.__iter__`

```mojo
def __iter__(self) -> Self
```

#### `RowsIter.__has_next__`

```mojo
def __has_next__(self) -> Bool
```

#### `RowsIter.__next__`

```mojo
def __next__(mut self) -> Row[origin]
```

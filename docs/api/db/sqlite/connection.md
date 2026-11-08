# `dodo.db.sqlite.connection`

One connection to an SQLite database file, through libsqlite3.

## Aliases

### `DB`

```mojo
comptime DB = "sqlite"
```

## Structs

### `SqliteConfig`

```mojo
struct SqliteConfig
```

Which file and how to open it.

Usually built from a URL:

- `sqlite:///var/app/data.db`: an absolute path.
- `sqlite://data.db`: relative to the working directory.
- `sqlite://:memory:`: a private in-memory database. Every connection
  would get its own, so a pool of one is used.

URL options:

- `mode`: `rwc` (default: read, write, create), `rw`, `ro`.
- `busy_timeout_ms` (default 5000): how long a write waits for
  another connection's lock before failing with `SQLITE_BUSY`.
- `journal_mode` (default `wal`, so readers don't block the writer;
  `keep` leaves the file's mode alone). WAL also sets
  `synchronous=NORMAL`, the pairing SQLite recommends.
- `foreign_keys` (default `on`).

Fields:

- `path` (`String`)
- `mode` (`String`)
- `busy_timeout_ms` (`Int`)
- `journal_mode` (`String`)
- `foreign_keys` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `SqliteConfig.__init__`

```mojo
def __init__(out self, path: String = ":memory:")
```

#### `SqliteConfig.from_url`

```mojo
def from_url(url: String) raises -> Self
```

#### `SqliteConfig.in_memory`

```mojo
def in_memory(self) -> Bool
```

#### `SqliteConfig.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `SqliteConnection`

```mojo
struct SqliteConnection
```

An open database handle. Not safe to share between threads; a `Sqlite` pool hands each caller its own.

Implemented traits: `AnyType`, `Connection`, `Deinitable`, `Movable`

Aliases:

- `Config = SqliteConfig`

#### `SqliteConnection.__init__`

```mojo
def __init__(out self, var api: Api, db: Int)
```

#### `SqliteConnection.open`

```mojo
def open(config: SqliteConfig) raises -> Self
```

#### `SqliteConnection.query`

```mojo
def query(mut self, sql: String, params: List[Param]) raises -> Rows
```

Run one statement with `?` parameters; return its rows, `affected` and `last_insert_id`. More than one statement is refused, so a value spliced into the SQL can't add another.

#### `SqliteConnection.execute`

```mojo
def execute(mut self, sql: String, params: List[Param]) raises -> Int
```

Run one statement; return how many rows it changed.

#### `SqliteConnection.execute_script`

```mojo
def execute_script(mut self, sql: String) raises -> Int
```

Run several `;`-separated statements without parameters (schema setup). Returns the rows changed by the last one.

#### `SqliteConnection.in_transaction`

```mojo
def in_transaction(self) -> Bool
```

#### `SqliteConnection.ping`

```mojo
def ping(mut self) -> Bool
```

#### `SqliteConnection.broken`

```mojo
def broken(self) -> Bool
```

#### `SqliteConnection.reset`

```mojo
def reset(mut self) -> Bool
```

#### `SqliteConnection.close`

```mojo
def close(mut self)
```

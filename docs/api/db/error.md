# `dodo.db.error`

The one error every database driver raises.

## Structs

### `DbError`

```mojo
struct DbError
```

A database call failed.

`kind` says what part failed, so a caller can branch on it as a group:

- `CONNECT`: the server could not be reached.
- `AUTH`: the server rejected the credentials.
- `IO`: the connection broke mid-call. The connection is closed.
- `PROTOCOL`: the server sent something the driver can't read. The
  connection is closed.
- `SERVER`: the server ran the call and refused it (bad SQL, a
  constraint, a missing table). The connection stays usable.
- `DECODE`: a value could not be read as the type asked for.
- `POOL_TIMEOUT`: no connection came free in time.
- `USAGE`: the call itself was wrong (bad URL, unknown column).

`code` is the database's own code when it gave one: the SQLSTATE for
PostgreSQL, the error number for MySQL and MariaDB, the extended
result code for SQLite, the error code for MongoDB and ClickHouse, the
error prefix (`WRONGTYPE`) for Redis.

```mojo
try:
    _ = db.execute("insert into users (email) values ($1)", email)
except e:
    if e.is_duplicate():
        return conflict("email already registered")
    raise e
```

Fields:

- `kind` (`Int`)
- `code` (`String`)
- `message` (`String`)
- `database` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

Aliases:

- `CONNECT = 1`
- `AUTH = 2`
- `IO = 3`
- `PROTOCOL = 4`
- `SERVER = 5`
- `DECODE = 6`
- `POOL_TIMEOUT = 7`
- `USAGE = 8`

#### `DbError.connect`

```mojo
def connect(database: String, message: String) -> Self
```

#### `DbError.auth`

```mojo
def auth(database: String, message: String, code: String = "") -> Self
```

#### `DbError.io`

```mojo
def io(database: String, message: String) -> Self
```

#### `DbError.protocol`

```mojo
def protocol(database: String, message: String) -> Self
```

#### `DbError.server`

```mojo
def server(database: String, code: String, message: String) -> Self
```

#### `DbError.decode`

```mojo
def decode(message: String) -> Self
```

#### `DbError.usage`

```mojo
def usage(database: String, message: String) -> Self
```

#### `DbError.breaks_connection`

```mojo
def breaks_connection(self) -> Bool
```

Whether the connection that raised this can't be used again.

#### `DbError.is_duplicate`

```mojo
def is_duplicate(self) -> Bool
```

Whether a unique constraint or primary key refused the write.

#### `DbError.kind_name`

```mojo
def kind_name(self) -> String
```

#### `DbError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write `postgres server error 23505: duplicate key ...`.

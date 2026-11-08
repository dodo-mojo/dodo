# `dodo.db.postgres.connection`

One blocking connection to PostgreSQL or CockroachDB.

## Structs

### `PgConfig`

```mojo
struct PgConfig
```

Where and how to connect.

Usually built from a URL:

`postgres://user:password@host:5432/database?sslmode=prefer`

URL options:

- `sslmode`, as in libpq: `disable`; `prefer` (default: TLS when the
  server offers it); `require` (TLS or fail); `verify-full` (TLS, and
  the certificate must be trusted and name the host). Only
  `verify-full` stops an active man in the middle.
- `sslrootcert`: a CA bundle for `verify-full` against a private CA.
- `connect_timeout_ms` (default 5000) and `timeout_ms`, the longest a
  read or write may wait (default 30000; 0 waits forever).
- `application_name`: shown in `pg_stat_activity`.

Fields:

- `host` (`String`)
- `port` (`Int`)
- `user` (`String`)
- `password` (`String`)
- `database` (`String`)
- `sslmode` (`String`)
- `tls` (`TlsConfig`)
- `connect_timeout_ms` (`Int`)
- `timeout_ms` (`Int`)
- `application` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `PgConfig.__init__`

```mojo
def __init__(out self)
```

#### `PgConfig.from_url`

```mojo
def from_url(url: String) raises -> Self
```

#### `PgConfig.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `PgConnection`

```mojo
struct PgConnection
```

A session with the server. Not safe to share between threads; a `Postgres` pool hands each caller its own.

Fields:

- `server_version` (`String`)

Implemented traits: `AnyType`, `Connection`, `Deinitable`, `Movable`

Aliases:

- `Config = PgConfig`

#### `PgConnection.__init__`

```mojo
def __init__(out self, var stream: DbStream)
```

#### `PgConnection.open`

```mojo
def open(config: PgConfig) raises -> Self
```

#### `PgConnection.query`

```mojo
def query(mut self, sql: String, params: List[Param]) raises -> Rows
```

Run one statement with `$1`-style parameters; return its rows.

#### `PgConnection.execute`

```mojo
def execute(mut self, sql: String, params: List[Param]) raises -> Int
```

Run one statement; return how many rows it changed.

#### `PgConnection.execute_script`

```mojo
def execute_script(mut self, sql: String) raises -> Int
```

Run several `;`-separated statements without parameters, as one implicit transaction. Returns the last statement's row count.

#### `PgConnection.in_transaction`

```mojo
def in_transaction(self) -> Bool
```

#### `PgConnection.ping`

```mojo
def ping(mut self) -> Bool
```

#### `PgConnection.broken`

```mojo
def broken(self) -> Bool
```

#### `PgConnection.reset`

```mojo
def reset(mut self) -> Bool
```

#### `PgConnection.close`

```mojo
def close(mut self)
```

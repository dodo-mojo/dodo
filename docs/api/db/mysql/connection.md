# `dodo.db.mysql.connection`

One blocking connection to MySQL or MariaDB.

## Structs

### `MySqlConfig`

```mojo
struct MySqlConfig
```

Where and how to connect.

Usually built from a URL:

`mysql://user:password@host:3306/database?ssl_mode=preferred`

URL options:

- `ssl_mode`, as in the mysql client: `disabled`; `preferred`
  (default: TLS when the server offers it); `required` (TLS or fail);
  `verify_identity` (TLS, and the certificate must be trusted and name
  the host). Only `verify_identity` stops an active man in the middle.
- `ssl_ca`: a CA bundle for `verify_identity` against a private CA.
- `connect_timeout_ms` (default 5000) and `timeout_ms` (default 30000).

Fields:

- `host` (`String`)
- `port` (`Int`)
- `user` (`String`)
- `password` (`String`)
- `database` (`String`)
- `ssl_mode` (`String`)
- `tls` (`TlsConfig`)
- `connect_timeout_ms` (`Int`)
- `timeout_ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `MySqlConfig.__init__`

```mojo
def __init__(out self)
```

#### `MySqlConfig.from_url`

```mojo
def from_url(url: String) raises -> Self
```

#### `MySqlConfig.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `MySqlConnection`

```mojo
struct MySqlConnection
```

A session with the server. A `MySql` pool hands each caller its own.

Fields:

- `server_version` (`String`)

Implemented traits: `AnyType`, `Connection`, `Deinitable`, `Movable`

Aliases:

- `Config = MySqlConfig`

#### `MySqlConnection.__init__`

```mojo
def __init__(out self, var stream: DbStream)
```

#### `MySqlConnection.open`

```mojo
def open(config: MySqlConfig) raises -> Self
```

#### `MySqlConnection.query`

```mojo
def query(mut self, sql: String, params: List[Param]) raises -> Rows
```

Run one statement with `?` placeholders; return its rows.

#### `MySqlConnection.execute`

```mojo
def execute(mut self, sql: String, params: List[Param]) raises -> Int
```

Run one statement; return how many rows it changed.

#### `MySqlConnection.execute_script`

```mojo
def execute_script(mut self, sql: String) raises -> Int
```

Run several `;`-separated statements without parameters. Multi statements are switched on for this call only.

#### `MySqlConnection.in_transaction`

```mojo
def in_transaction(self) -> Bool
```

#### `MySqlConnection.ping`

```mojo
def ping(mut self) -> Bool
```

#### `MySqlConnection.broken`

```mojo
def broken(self) -> Bool
```

#### `MySqlConnection.reset`

```mojo
def reset(mut self) -> Bool
```

#### `MySqlConnection.close`

```mojo
def close(mut self)
```

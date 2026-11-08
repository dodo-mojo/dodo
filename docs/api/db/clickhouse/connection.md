# `dodo.db.clickhouse.connection`

One HTTP keep-alive connection to a ClickHouse server.

## Structs

### `ClickHouseConfig`

```mojo
struct ClickHouseConfig
```

Where and how to connect.

Usually built from a URL:

`clickhouse://user:password@host:8123/database` (HTTP), or
`clickhouses://user:password@host:8443/database` (HTTPS).

URL options:

- `tls_verify` (`clickhouses://` only): `true` (default: the
  certificate must be trusted and name the host) or `false`.
- `tls_ca`: a CA bundle for a server with a private CA.
- `connect_timeout_ms` (default 5000) and `timeout_ms` (default
  300000; analytical queries run long).
- Any other option is passed on as a ClickHouse setting, for
  example `max_execution_time=60`.

Fields:

- `host` (`String`)
- `port` (`Int`)
- `user` (`String`)
- `password` (`String`)
- `database` (`String`)
- `use_tls` (`Bool`)
- `tls` (`TlsConfig`)
- `connect_timeout_ms` (`Int`)
- `timeout_ms` (`Int`)
- `settings` (`List[Tuple[String, String]]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `ClickHouseConfig.__init__`

```mojo
def __init__(out self)
```

#### `ClickHouseConfig.from_url`

```mojo
def from_url(url: String) raises -> Self
```

#### `ClickHouseConfig.base_url`

```mojo
def base_url(self) -> String
```

#### `ClickHouseConfig.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `ClickHouseConnection`

```mojo
struct ClickHouseConnection
```

An HTTP client with one keep-alive connection. Not safe to share between threads; a `ClickHouse` pool hands each caller its own.

Implemented traits: `AnyType`, `Connection`, `Deinitable`, `Movable`

Aliases:

- `Config = ClickHouseConfig`

#### `ClickHouseConnection.__init__`

```mojo
def __init__(out self, var client: HttpClient, config: ClickHouseConfig)
```

#### `ClickHouseConnection.open`

```mojo
def open(config: ClickHouseConfig) raises -> Self
```

#### `ClickHouseConnection.query`

```mojo
def query(mut self, sql: String, params: List[Param]) raises -> Rows
```

Run one statement with `{p1:Type}` parameters; return its rows. `affected` is the rows an INSERT wrote.

#### `ClickHouseConnection.execute`

```mojo
def execute(mut self, sql: String, params: List[Param]) raises -> Int
```

#### `ClickHouseConnection.execute_script`

```mojo
def execute_script(mut self, sql: String) raises -> Int
```

Run `;`-separated statements one by one (ClickHouse takes one per request). Returns the rows the last one wrote.

#### `ClickHouseConnection.ping`

```mojo
def ping(mut self) -> Bool
```

#### `ClickHouseConnection.broken`

```mojo
def broken(self) -> Bool
```

#### `ClickHouseConnection.reset`

```mojo
def reset(mut self) -> Bool
```

#### `ClickHouseConnection.close`

```mojo
def close(mut self)
```

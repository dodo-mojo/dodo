# `dodo.db.redis.connection`

One connection to a Redis or Valkey server.

## Structs

### `RedisConfig`

```mojo
struct RedisConfig
```

Where and how to connect.

Usually built from a URL:

`redis://user:password@host:6379/0`, or `rediss://` for TLS.

The user may be left out (`redis://:password@host`). The path is the
database number. URL options:

- `ssl_cert_reqs` (`rediss://` only): `required` (default: the
  certificate must be trusted and name the host) or `none` (encrypt
  without checking it).
- `ssl_ca_certs`: a CA bundle for a server with a private CA.
- `connect_timeout_ms` (default 5000) and `timeout_ms` (default 30000).

Fields:

- `host` (`String`)
- `port` (`Int`)
- `user` (`String`)
- `password` (`String`)
- `database` (`Int`)
- `use_tls` (`Bool`)
- `tls` (`TlsConfig`)
- `connect_timeout_ms` (`Int`)
- `timeout_ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `RedisConfig.__init__`

```mojo
def __init__(out self)
```

#### `RedisConfig.from_url`

```mojo
def from_url(url: String) raises -> Self
```

#### `RedisConfig.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `RedisConnection`

```mojo
struct RedisConnection
```

A session with the server. Not safe to share between threads; a `Redis` pool hands each caller its own.

Implemented traits: `AnyType`, `Connection`, `Deinitable`, `Movable`

Aliases:

- `Config = RedisConfig`

#### `RedisConnection.__init__`

```mojo
def __init__(out self, var stream: DbStream)
```

#### `RedisConnection.open`

```mojo
def open(config: RedisConfig) raises -> Self
```

#### `RedisConnection.command`

```mojo
def command(mut self, args: List[Param]) raises -> RedisReply
```

Run one command; raise if the server answers with an error.

#### `RedisConnection.pipeline`

```mojo
def pipeline(mut self, commands: List[List[Param]]) raises -> List[RedisReply]
```

Send every command in one write, then read every reply. Error replies come back in the list rather than raising, so one failed command doesn't hide the others' results.

#### `RedisConnection.ping`

```mojo
def ping(mut self) -> Bool
```

#### `RedisConnection.broken`

```mojo
def broken(self) -> Bool
```

#### `RedisConnection.reset`

```mojo
def reset(mut self) -> Bool
```

#### `RedisConnection.close`

```mojo
def close(mut self)
```

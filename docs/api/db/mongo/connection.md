# `dodo.db.mongo.connection`

One connection to a MongoDB server.

## Structs

### `MongoConfig`

```mojo
struct MongoConfig
```

Where and how to connect.

Usually built from a URL:

`mongodb://user:password@host:27017/database?authSource=admin`

One host only: replica-set seed lists and `mongodb+srv://` are not
supported yet. URL options (MongoDB's own names):

- `authSource`: the database holding the user (default: the URL's
  database, else `admin`).
- `tls=true`: TLS from the first byte. The certificate must be trusted
  and name the host, unless `tlsAllowInvalidCertificates=true`.
- `tlsCAFile`: a CA bundle for a server with a private CA.
- `connectTimeoutMS` (default 5000), `socketTimeoutMS` (default 30000).
- `appName`: shown in the server's logs and `currentOp`.

Fields:

- `host` (`String`)
- `port` (`Int`)
- `user` (`String`)
- `password` (`String`)
- `database` (`String`)
- `auth_source` (`String`)
- `use_tls` (`Bool`)
- `tls` (`TlsConfig`)
- `connect_timeout_ms` (`Int`)
- `timeout_ms` (`Int`)
- `app_name` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `MongoConfig.__init__`

```mojo
def __init__(out self)
```

#### `MongoConfig.from_url`

```mojo
def from_url(url: String) raises -> Self
```

#### `MongoConfig.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `MongoConnection`

```mojo
struct MongoConnection
```

A session with the server. Not safe to share between threads; a `Mongo` pool hands each caller its own.

Fields:

- `max_document_size` (`Int`): The server's largest document, from `hello`.

Implemented traits: `AnyType`, `Connection`, `Deinitable`, `Movable`

Aliases:

- `Config = MongoConfig`

#### `MongoConnection.__init__`

```mojo
def __init__(out self, var stream: DbStream)
```

#### `MongoConnection.open`

```mojo
def open(config: MongoConfig) raises -> Self
```

#### `MongoConnection.command`

```mojo
def command(mut self, database: String, command: Bson) raises -> Bson
```

Run one command against `database`; raise if `ok` isn't 1.

#### `MongoConnection.run`

```mojo
def run(mut self, database: String, command: Bson) raises -> Bson
```

Run one command; return the reply as it came, errors included.

#### `MongoConnection.ping`

```mojo
def ping(mut self) -> Bool
```

#### `MongoConnection.broken`

```mojo
def broken(self) -> Bool
```

#### `MongoConnection.reset`

```mojo
def reset(mut self) -> Bool
```

#### `MongoConnection.close`

```mojo
def close(mut self)
```

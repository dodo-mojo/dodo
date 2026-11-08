# `dodo.db.pool`

A thread-safe, bounded connection pool shared by every driver.

A pool opens connections lazily, up to `max_size`, and hands one out at a
time. The handle (`Pool`) is cheap to copy and every copy shares the same
connections, so a pool can sit in the app state and be used from every
worker and offload thread.

A checked-out connection comes back when its `Pooled` guard is destroyed.
One that failed mid-call (`broken()`) or outlived `max_lifetime_ms` is
closed instead. A connection that sat idle longer than `idle_ping_ms` is
pinged before it is handed out, and replaced if the ping fails.

## Structs

### `PoolOptions`

```mojo
struct PoolOptions
```

How a pool sizes and checks its connections.

Fields:

- `max_size` (`Int`): Connections open at once, idle or in use.
- `acquire_timeout_ms` (`Int`): How long a caller waits for a free connection before an error.
- `idle_ping_ms` (`Int`): Ping a connection idle longer than this before handing it out.
- `max_lifetime_ms` (`Int`): Close a connection older than this when it comes back. 0: never.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `PoolOptions.__init__`

```mojo
def __init__(out self)
```

#### `PoolOptions.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `Pool`

```mojo
struct Pool[C: Connection]
```

Connections to one database, shared by every copy of the handle.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Pool.__init__`

```mojo
def __init__(out self, config: C.Config, options: PoolOptions = PoolOptions())
```

#### `Pool.acquire`

```mojo
def acquire(self) raises -> Pooled[C]
```

A connection for the caller alone, until the guard is destroyed.

#### `Pool.open_count`

```mojo
def open_count(self) -> Int
```

Connections open now, idle or in use.

#### `Pool.idle_count`

```mojo
def idle_count(self) -> Int
```

Connections open and waiting in the pool.

### `Pooled`

```mojo
struct Pooled[C: Connection]
```

A checked-out connection. Destroying it gives the connection back.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Pooled.__init__`

```mojo
def __init__(out self, state: ArcPointer[_PoolState[C]], var conn: C, born_ms: Int)
```

#### `Pooled.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `Pooled.conn`

```mojo
def conn(ref self) -> ref[self_is_mut._conn] C
```

The connection itself.

## Traits

### `Connection`

```mojo
trait Connection
```

What a driver's connection gives the pool.

Inherits from: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `Config`

#### `Connection.open`

```mojo
def open(config: Self.Config) raises -> Self
```

Connect and authenticate.

#### `Connection.ping`

```mojo
def ping(mut self) -> Bool
```

A cheap round trip; False when the connection is unusable.

#### `Connection.broken`

```mojo
def broken(self) -> Bool
```

Whether an earlier call left the connection unusable.

#### `Connection.reset`

```mojo
def reset(mut self) -> Bool
```

Undo session state before reuse (an open transaction, a selected database). False when that failed and the connection should close.

#### `Connection.close`

```mojo
def close(mut self)
```

Say goodbye to the server, best effort. Never raises.

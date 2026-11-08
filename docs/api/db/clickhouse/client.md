# `dodo.db.clickhouse.client`

The ClickHouse pool most code uses.

## Structs

### `ClickHouse`

```mojo
struct ClickHouse
```

A pool of HTTP connections to ClickHouse.

Cheap to copy; every copy shares the connections, so keep one in the
app state. Parameters are positional and named `p1`, `p2`, ... in the
SQL, each with its ClickHouse type:

```mojo
var ch = ClickHouse("clickhouse://app:secret@localhost:8123/analytics")
var rows = ch.query(
    "select path, count() as hits from visits where day = {p1:Date}"
    " group by path order by hits desc limit {p2:UInt32}",
    "2026-11-02", 10,
)
```

Dates and times come back as text in UTC (`2026-11-02 10:30:00`);
arrays, tuples and maps as ClickHouse literals (`['a', 'b']`).
ClickHouse has no transactions, so there is no `transaction()`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `ClickHouse.__init__`

```mojo
def __init__(out self, url: String, options: PoolOptions = PoolOptions()) raises
```

```mojo
def __init__(out self, config: ClickHouseConfig, options: PoolOptions = PoolOptions())
```

#### `ClickHouse.query`

```mojo
def query(self, sql: String, *params: Param) raises -> Rows
```

Run one statement; return its rows.

#### `ClickHouse.execute`

```mojo
def execute(self, sql: String, *params: Param) raises -> Int
```

Run one statement; return the rows an INSERT wrote.

#### `ClickHouse.execute_script`

```mojo
def execute_script(self, sql: String) raises -> Int
```

Run `;`-separated statements without parameters (schema setup).

#### `ClickHouse.connection`

```mojo
def connection(self) raises -> Pooled[ClickHouseConnection]
```

#### `ClickHouse.open_count`

```mojo
def open_count(self) -> Int
```

#### `ClickHouse.idle_count`

```mojo
def idle_count(self) -> Int
```

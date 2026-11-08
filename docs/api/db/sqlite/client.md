# `dodo.db.sqlite.client`

The SQLite pool most code uses, and transactions on it.

## Structs

### `Sqlite`

```mojo
struct Sqlite
```

A pool of connections to one SQLite database file.

Cheap to copy; every copy shares the connections, so keep one in the
app state. Each call checks a connection out and gives it back. Many
connections read at once; SQLite lets one write at a time, and a
writer waits up to `busy_timeout_ms` for the lock.

```mojo
var db = Sqlite("sqlite:///var/app/data.db")
_ = db.execute_script("create table if not exists users (id integer primary key, name text)")
var id = db.query("insert into users (name) values (?)", "ada").last_insert_id
var users = db.query("select id, name from users").to[User]()
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Sqlite.__init__`

```mojo
def __init__(out self, url: String, options: PoolOptions = PoolOptions()) raises
```

```mojo
def __init__(out self, config: SqliteConfig, options: PoolOptions = PoolOptions())
```

#### `Sqlite.query`

```mojo
def query(self, sql: String, *params: Param) raises -> Rows
```

Run one statement; return its rows, `affected` and `last_insert_id`.

#### `Sqlite.execute`

```mojo
def execute(self, sql: String, *params: Param) raises -> Int
```

Run one statement; return how many rows it changed.

#### `Sqlite.execute_script`

```mojo
def execute_script(self, sql: String) raises -> Int
```

Run `;`-separated statements without parameters (schema setup).

#### `Sqlite.transaction`

```mojo
def transaction(self) raises -> SqliteTransaction
```

Start a write transaction on a connection of its own. It takes the write lock up front (BEGIN IMMEDIATE), so two transactions can't deadlock upgrading from read to write. It rolls back unless `commit` is called.

#### `Sqlite.migrate`

```mojo
def migrate(self, migrations: Migrations) raises -> List[Int]
```

Run the migrations that haven't run yet, in version order, and return their versions (ADR-0010).

Each migration runs in a transaction with its `dodo_migrations`
row, so one that fails leaves nothing behind. Safe when several
processes start at once: each migration still runs once.

#### `Sqlite.connection`

```mojo
def connection(self) raises -> Pooled[SqliteConnection]
```

A connection for several calls in a row.

#### `Sqlite.open_count`

```mojo
def open_count(self) -> Int
```

#### `Sqlite.idle_count`

```mojo
def idle_count(self) -> Int
```

### `SqliteTransaction`

```mojo
struct SqliteTransaction
```

Statements that commit or roll back together. Destroying it without `commit` rolls back.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `SqliteTransaction.__init__`

```mojo
def __init__(out self, var conn: Pooled[SqliteConnection])
```

#### `SqliteTransaction.query`

```mojo
def query(mut self, sql: String, *params: Param) raises -> Rows
```

#### `SqliteTransaction.execute`

```mojo
def execute(mut self, sql: String, *params: Param) raises -> Int
```

#### `SqliteTransaction.execute_script`

```mojo
def execute_script(mut self, sql: String) raises -> Int
```

Run `;`-separated statements without parameters, inside the transaction.

#### `SqliteTransaction.commit`

```mojo
def commit(mut self) raises
```

#### `SqliteTransaction.rollback`

```mojo
def rollback(mut self) raises
```

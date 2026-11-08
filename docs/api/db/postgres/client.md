# `dodo.db.postgres.client`

The PostgreSQL pool most code uses, and transactions on it.

## Structs

### `Postgres`

```mojo
struct Postgres
```

A pool of connections to PostgreSQL or CockroachDB.

Cheap to copy; every copy shares the connections, so keep one in the
app state. Each call checks a connection out and gives it back.

```mojo
var db = Postgres("postgres://dodo:secret@localhost:5432/app")
var rows = db.query("select id, name from users where id = $1", 42)
var n = db.execute("update users set name = $1 where id = $2", "ada", 42)

var tx = db.transaction()
_ = tx.execute("insert into audit (msg) values ($1)", "renamed")
tx.commit()
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Postgres.__init__`

```mojo
def __init__(out self, url: String, options: PoolOptions = PoolOptions()) raises
```

```mojo
def __init__(out self, config: PgConfig, options: PoolOptions = PoolOptions())
```

#### `Postgres.query`

```mojo
def query(self, sql: String, *params: Param) raises -> Rows
```

Run one statement; return its rows.

#### `Postgres.execute`

```mojo
def execute(self, sql: String, *params: Param) raises -> Int
```

Run one statement; return how many rows it changed.

#### `Postgres.execute_script`

```mojo
def execute_script(self, sql: String) raises -> Int
```

Run `;`-separated statements without parameters (schema setup).

#### `Postgres.transaction`

```mojo
def transaction(self) raises -> PgTransaction
```

Start a transaction on a connection of its own. It rolls back unless `commit` is called.

#### `Postgres.migrate`

```mojo
def migrate(self, migrations: Migrations) raises -> List[Int]
```

Run the migrations that haven't run yet, in version order, and return their versions (ADR-0010).

Each migration runs in a transaction with its `dodo_migrations`
row, so one that fails leaves nothing behind. Safe when several
processes start at once: each migration still runs once.

#### `Postgres.connection`

```mojo
def connection(self) raises -> Pooled[PgConnection]
```

A connection for several calls in a row (session settings, temporary tables). It goes back to the pool when destroyed.

#### `Postgres.open_count`

```mojo
def open_count(self) -> Int
```

#### `Postgres.idle_count`

```mojo
def idle_count(self) -> Int
```

### `PgTransaction`

```mojo
struct PgTransaction
```

Statements that commit or roll back together. Destroying it without `commit` rolls back.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `PgTransaction.__init__`

```mojo
def __init__(out self, var conn: Pooled[PgConnection])
```

#### `PgTransaction.query`

```mojo
def query(mut self, sql: String, *params: Param) raises -> Rows
```

#### `PgTransaction.execute`

```mojo
def execute(mut self, sql: String, *params: Param) raises -> Int
```

#### `PgTransaction.execute_script`

```mojo
def execute_script(mut self, sql: String) raises -> Int
```

Run `;`-separated statements without parameters, inside the transaction.

#### `PgTransaction.commit`

```mojo
def commit(mut self) raises
```

#### `PgTransaction.rollback`

```mojo
def rollback(mut self) raises
```

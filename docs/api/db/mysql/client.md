# `dodo.db.mysql.client`

The MySQL pool most code uses, and transactions on it.

## Structs

### `MySql`

```mojo
struct MySql
```

A pool of connections to MySQL or MariaDB.

Cheap to copy; every copy shares the connections, so keep one in the
app state. Each call checks a connection out and gives it back.

```mojo
var db = MySql("mysql://dodo:secret@localhost:3306/app")
var rows = db.query("select id, name from users where id = ?", 42)
var id = db.query("insert into users (name) values (?)", "ada").last_insert_id
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `MySql.__init__`

```mojo
def __init__(out self, url: String, options: PoolOptions = PoolOptions()) raises
```

```mojo
def __init__(out self, config: MySqlConfig, options: PoolOptions = PoolOptions())
```

#### `MySql.query`

```mojo
def query(self, sql: String, *params: Param) raises -> Rows
```

Run one statement; return its rows, `affected` and `last_insert_id`.

#### `MySql.execute`

```mojo
def execute(self, sql: String, *params: Param) raises -> Int
```

Run one statement; return how many rows it changed.

#### `MySql.execute_script`

```mojo
def execute_script(self, sql: String) raises -> Int
```

Run `;`-separated statements without parameters (schema setup).

#### `MySql.transaction`

```mojo
def transaction(self) raises -> MySqlTransaction
```

Start a transaction on a connection of its own. It rolls back unless `commit` is called.

#### `MySql.migrate`

```mojo
def migrate(self, migrations: Migrations) raises -> List[Int]
```

Run the migrations that haven't run yet, in version order, and return their versions (ADR-0010).

MySQL and MariaDB commit each DDL statement as it runs, so this
holds a named lock (`GET_LOCK`) for the whole run instead of a
transaction. Safe when several processes start at once. A
migration that fails halfway keeps the statements before the
failure; keep one DDL statement per migration.

#### `MySql.connection`

```mojo
def connection(self) raises -> Pooled[MySqlConnection]
```

A connection for several calls in a row.

#### `MySql.open_count`

```mojo
def open_count(self) -> Int
```

#### `MySql.idle_count`

```mojo
def idle_count(self) -> Int
```

### `MySqlTransaction`

```mojo
struct MySqlTransaction
```

Statements that commit or roll back together. Destroying it without `commit` rolls back.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `MySqlTransaction.__init__`

```mojo
def __init__(out self, var conn: Pooled[MySqlConnection])
```

#### `MySqlTransaction.query`

```mojo
def query(mut self, sql: String, *params: Param) raises -> Rows
```

#### `MySqlTransaction.execute`

```mojo
def execute(mut self, sql: String, *params: Param) raises -> Int
```

#### `MySqlTransaction.commit`

```mojo
def commit(mut self) raises
```

#### `MySqlTransaction.rollback`

```mojo
def rollback(mut self) raises
```

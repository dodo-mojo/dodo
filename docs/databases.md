# Databases

`dodo.db` talks to PostgreSQL, CockroachDB, MySQL, MariaDB, SQLite, Redis, Valkey, MongoDB and ClickHouse. Every driver is written in Mojo except SQLite, which wraps the `libsqlite3` that pixi installs. Why they are built this way: [ADR-0009](adr/0009-database-drivers.md).

| Import | Database | URL |
|---|---|---|
| `dodo.db.postgres.Postgres` | PostgreSQL, CockroachDB | `postgres://user:pass@host:5432/db` |
| `dodo.db.mysql.MySql` | MySQL, MariaDB | `mysql://user:pass@host:3306/db` |
| `dodo.db.sqlite.Sqlite` | SQLite | `sqlite:///abs/path.db`, `sqlite://rel.db`, `sqlite://:memory:` |
| `dodo.db.redis.Redis` | Redis, Valkey | `redis://user:pass@host:6379/0`, `rediss://` for TLS |
| `dodo.db.mongo.Mongo` | MongoDB | `mongodb://user:pass@host:27017/db` |
| `dodo.db.clickhouse.ClickHouse` | ClickHouse (HTTP) | `clickhouse://user:pass@host:8123/db`, `clickhouses://` for TLS |

Each of these is a connection pool. It is cheap to copy and every copy shares the same connections, so make one at startup and keep it in the app state.

## In an App

A database call blocks its thread for a round trip. Register every route that uses one with `blocking=True`: it then runs on the offload pool and the worker's event loop keeps serving other connections.

```mojo
from dodo import App, AppState, PathParams, Request
from dodo.db.postgres import Postgres


@fieldwise_init
struct Db(AppState):
    var pg: Postgres


@fieldwise_init
struct UserPath(PathParams):
    var id: Int


@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String


def get_user(req: Request, path: UserPath, db: Db) raises -> User:
    return db.pg.query("select id, name from users where id = $1", path.id).one[User]()


def main() raises:
    var app = App(state=Db(Postgres("postgres://app:secret@localhost:5432/app")))
    app.get["/users/{id}"](get_user, blocking=True)
    app.serve(port=8080)
```

Without `blocking=True` the query runs on the event loop and stalls every connection on that worker until it returns. A handler struct gets the same effect from `Offload(handler)`.

Size the pool to the offload pool: `ServerConfig.offload_threads` (one per core by default) is how many blocking handlers run at once, and `PoolOptions.max_size` (default 10) is how many connections they can hold.

## SQL: queries, parameters and rows

PostgreSQL, MySQL and SQLite share one API:

```mojo
var rows = db.query("select id, name from users where active = $1", True)
var changed = db.execute("update users set name = $1 where id = $2", "ada", 42)
_ = db.execute_script("create table t (id int); create index on t (id);")
```

- Placeholders are `$1, $2, ...` for PostgreSQL and `?` for MySQL and SQLite. Values travel apart from the SQL text, so they can't change the statement. Never build SQL by joining strings.
- A parameter can be an `Int`, `Float64`, `Bool`, `String`, an `Optional` of those (empty is `NULL`), `Param.null()` or `Param.bytes(span)`.
- `execute` returns the number of rows changed. `execute_script` runs several statements with no parameters, for migrations.

`query` returns `Rows`. Read a cell by column name or index, or fill a struct whose fields match the column names:

```mojo
for row in rows:
    print(row.int("id"), row.string("name"), row.is_null("email"))

var users = rows.to[User]()           # every row
var user = rows.one[User]()           # the first row; raises if there is none
var maybe = rows.first[User]()        # Optional[User]
```

A field that is `Optional[T]` takes `NULL`; any other field raises `DbError.DECODE` on `NULL`. So does a value that doesn't read as the type asked for (`"tea"` as an `Int`, a number past `Int` range).

### Transactions

```mojo
var tx = db.transaction()
_ = tx.execute("update accounts set balance = balance - $1 where id = $2", 100, 1)
_ = tx.execute("update accounts set balance = balance + $1 where id = $2", 100, 2)
tx.commit()
```

A transaction holds one connection until `commit` or `rollback`. Dropping it without either rolls back, including when an error unwinds past it. SQLite starts it with `BEGIN IMMEDIATE`, so two writers wait on the busy timeout instead of failing halfway.

To run several statements on one connection without a transaction (a session setting, a temporary table), check one out with `db.connection()`. It goes back to the pool when the guard is dropped.

## Redis and Valkey

```mojo
from dodo.db.redis import Redis, RedisPipeline

var cache = Redis("redis://:secret@localhost:6379/0")
cache.set("greeting", "hello", ttl_ms=60_000)
var hello = cache.get("greeting")            # Optional[String]
var views = cache.incr("views")
var reply = cache.command("ZADD", "board", 10, "ada")

var p = RedisPipeline()
p.add("INCR", "views")
p.add("EXPIRE", "views", 60)
var replies = cache.run(p)                   # one round trip
var atomic = cache.run_transaction(p)        # MULTI ... EXEC
```

Typed helpers cover strings, counters, expiry, hashes, lists, sets and `PUBLISH`; `command` runs anything else. `AUTH`, `SELECT`, `SUBSCRIBE` and other commands that would change a pooled connection for its next user are refused: put the user, password and database in the URL.

## MongoDB

```mojo
from dodo.db.mongo import Bson, Mongo

var mongo = Mongo("mongodb://app:secret@localhost:27017/app")
var users = mongo.collection("users")
_ = users.create_index(Bson().add("email", 1), unique=True)
var id = users.insert_one(Bson().add("email", "ada@example.com").add("score", 9.5))
var ada = users.find_one(Bson().add("email", "ada@example.com"))
var top = users.find(sort=Bson().add("score", -1), limit=10).to[User]()
_ = users.update_one(Bson().add("_id", id), Bson().add("$set", Bson().add("score", 10)))
```

Documents are `Bson` values; `Documents.to[T]()` fills structs by field name the way `Rows` does. `mongo.command(...)` runs any database command. One server at a time: replica sets, `mongodb+srv://` and multi-document transactions are not supported yet.

## ClickHouse

```mojo
from dodo.db.clickhouse import ClickHouse

var ch = ClickHouse("clickhouse://app:secret@localhost:8123/analytics")
var rows = ch.query(
    "select path, count() as hits from visits where day = {p1:Date}"
    " group by path order by hits desc limit {p2:UInt32}",
    "2026-11-02", 10,
)
```

Parameters are named `p1, p2, ...` with their ClickHouse type and are sent apart from the SQL. Results come back as `Rows`. Dates and times are text in UTC. ClickHouse has no transactions. Unknown URL options are passed on as ClickHouse settings (`?max_execution_time=60`).

## Connections and TLS

Each URL takes options for timeouts and TLS. TLS defaults follow each database's own client:

| Database | Default | Strict verification |
|---|---|---|
| PostgreSQL | `sslmode=prefer`: TLS when the server offers it | `sslmode=verify-full` (+ `sslrootcert=`) |
| MySQL, MariaDB | `ssl_mode=preferred` | `ssl_mode=verify_identity` (+ `ssl_ca=`) |
| Redis | plain; `rediss://` verifies | `ssl_cert_reqs=none` turns verification off |
| MongoDB | plain; `tls=true` verifies | `tlsAllowInvalidCertificates=true` turns it off |
| ClickHouse | plain; `clickhouses://` verifies | `tls_verify=false` turns it off |

`prefer`/`require` (and the MySQL equivalents) encrypt but don't check the certificate, the same as libpq and the mysql client. Only `verify-full` and `verify_identity` stop an active man in the middle; use them across any network you don't control.

`connect_timeout_ms` (default 5000) and `timeout_ms` (default 30000; 300000 for ClickHouse) bound connecting and each read or write. The per-database options are in the `*Config` docstrings.

Pool behaviour is set with `PoolOptions`, passed after the URL:

```mojo
from dodo.db import PoolOptions

var opts = PoolOptions()
opts.max_size = 20
opts.acquire_timeout_ms = 2_000
var db = Postgres(url, opts)
```

An idle connection older than `idle_ping_ms` is pinged before it is handed out; one older than `max_lifetime_ms` is closed when it comes back. A connection that broke mid-call is closed, never reused. One that comes back inside a transaction is rolled back first.

## Errors

Every driver raises `DbError`. Branch on `kind`, or on `is_duplicate()` for unique violations in any database:

```mojo
try:
    _ = db.execute("insert into users (email) values ($1)", email)
except e:
    if e.is_duplicate():
        return conflict("email already registered")
    raise e
```

Kinds: `CONNECT`, `AUTH`, `IO`, `PROTOCOL`, `SERVER`, `DECODE`, `POOL_TIMEOUT`, `USAGE`. `code` holds the database's own code (SQLSTATE, MySQL error number, SQLite extended code, MongoDB or ClickHouse code, Redis error prefix). Messages never include the password.

## Testing

`pixi run tests` covers the parts that need no server: SQLite, BSON, the wire codecs, URLs, rows and errors. `pixi run tests-db` starts every database in Docker (`tests/live/db/compose.yaml`) and runs the driver suites against them, TLS included. Set `DODO_DB_NO_COMPOSE=1` when the containers are already up.

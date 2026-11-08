# `dodo.db`

Database drivers, written in Mojo (ADR-0009).

```
dodo.db.postgres    PostgreSQL and CockroachDB
dodo.db.mysql       MySQL and MariaDB
dodo.db.sqlite      SQLite (libsqlite3)
dodo.db.redis       Redis and Valkey
dodo.db.mongo       MongoDB
dodo.db.clickhouse  ClickHouse (HTTP interface)
```

Shared here: `DbError`, `Param`, `Rows` and `Row` for the SQL drivers,
and the `Pool` every driver keeps its connections in.

Calls block their thread for a round trip. In an `App`, register routes
that use a database with `blocking=True`, so they run on the offload pool
instead of a worker's event loop.

## Packages

- [`dodo.db.clickhouse`](clickhouse/index.md): ClickHouse, over its HTTP interface.
- [`dodo.db.mongo`](mongo/index.md): MongoDB, over OP_MSG with BSON.
- [`dodo.db.mysql`](mysql/index.md): MySQL and MariaDB, over the MySQL client/server protocol.
- [`dodo.db.postgres`](postgres/index.md): PostgreSQL and CockroachDB, over the PostgreSQL wire protocol v3.
- [`dodo.db.redis`](redis/index.md): Redis and Valkey, over RESP2.
- [`dodo.db.sqlite`](sqlite/index.md): SQLite, through the libsqlite3 that pixi installs.

## Modules

- [`dodo.db.error`](error.md): The one error every database driver raises.
- [`dodo.db.migrate`](migrate.md): Schema migrations for the SQL drivers (ADR-0010).
- [`dodo.db.param`](param.md): Query parameters: one value sent to the server apart from the SQL text.
- [`dodo.db.pool`](pool.md): A thread-safe, bounded connection pool shared by every driver.
- [`dodo.db.rows`](rows.md): Result sets from the SQL drivers, and reading them into structs.

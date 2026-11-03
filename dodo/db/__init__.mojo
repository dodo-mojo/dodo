"""Database drivers, written in Mojo (ADR-0009).

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
"""

from .error import DbError
from .param import Param
from .pool import Pool, PoolOptions, Pooled
from .rows import Column, Row, Rows

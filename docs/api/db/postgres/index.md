# `dodo.db.postgres`

PostgreSQL and CockroachDB, over the PostgreSQL wire protocol v3.

```mojo
from dodo.db.postgres import Postgres

var db = Postgres("postgres://dodo:secret@localhost:5432/app")
var users = db.query("select id, name from users where active = $1", True).to[User]()
```

Parameters travel apart from the SQL text, so they can't change the
statement. Authentication: SCRAM-SHA-256, MD5, cleartext and trust. See
ADR-0009.

## Modules

- [`dodo.db.postgres.client`](client.md): The PostgreSQL pool most code uses, and transactions on it.
- [`dodo.db.postgres.connection`](connection.md): One blocking connection to PostgreSQL or CockroachDB.
- [`dodo.db.postgres.protocol`](protocol.md): PostgreSQL frontend/backend protocol v3, sans I/O.

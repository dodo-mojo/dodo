# `dodo.db.sqlite`

SQLite, through the libsqlite3 that pixi installs.

```mojo
from dodo.db.sqlite import Sqlite

var db = Sqlite("sqlite:///var/app/data.db")
var rows = db.query("select id, name from users where id = ?", 42)
```

Files open in WAL mode with foreign keys on by default. Values are bound
to `?` placeholders, never spliced into the SQL. See ADR-0009.

## Modules

- [`dodo.db.sqlite.client`](client.md): The SQLite pool most code uses, and transactions on it.
- [`dodo.db.sqlite.connection`](connection.md): One connection to an SQLite database file, through libsqlite3.

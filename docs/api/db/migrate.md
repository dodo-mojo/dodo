# `dodo.db.migrate`

Schema migrations for the SQL drivers (ADR-0010).

A migration is a version, a name and SQL. Keep them as files named
`<version>_<name>.sql` and run them at startup, before serving:

```mojo
from dodo.db.migrate import Migrations
from dodo.db.postgres import Postgres

def main() raises:
    var db = Postgres("postgres://app:secret@localhost/app")
    var applied = db.migrate(Migrations.from_dir("migrations"))
    print("applied", len(applied), "migrations")
```

`Postgres`, `MySql` and `Sqlite` each have `migrate`. It records every
migration it runs in a `dodo_migrations` table and runs each one once,
even when several processes start at the same time. This module only
plans: it checks the migrations against that table and says what to run.

## Aliases

### `MAX_RACES`

```mojo
comptime MAX_RACES = 100
```

How many times one `migrate` call yields a version to another process before it gives up. Each lost race means that process made progress.

## Structs

### `Migration`

```mojo
struct Migration
```

One schema change: a version, a name for people, and SQL.

Fields:

- `version` (`Int`)
- `name` (`String`)
- `sql` (`String`)
- `checksum` (`String`): Hex SHA-256 of `sql`, with `\r\n` line endings read as `\n`.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `Migration.__init__`

```mojo
def __init__(out self, version: Int, name: String, sql: String) raises
```

#### `Migration.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `AppliedMigration`

```mojo
struct AppliedMigration
```

A row of the `dodo_migrations` table.

Fields:

- `version` (`Int`)
- `name` (`String`)
- `checksum` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `AppliedMigration.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `Migrations`

```mojo
struct Migrations
```

The migrations an app knows, kept in version order.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Sized`

#### `Migrations.__init__`

```mojo
def __init__(out self)
```

#### `Migrations.__getitem__`

```mojo
def __getitem__(self, index: Int) -> Migration
```

A copy of the migration at `index`, in version order.

#### `Migrations.add`

```mojo
def add(mut self, version: Int, name: String, sql: String) raises
```

Add a migration. Versions must be unique; the order of calls doesn't matter.

#### `Migrations.from_dir`

```mojo
def from_dir(path: String) raises -> Self
```

Read every `<version>_<name>.sql` file in `path`.

`0001_create_users.sql` is version 1, named "create users".
Other files are skipped, and so are names starting with `.`; a
`.sql` file without a version is an error.

#### `Migrations.__len__`

```mojo
def __len__(self) -> Int
```

## Functions

### `plan`

```mojo
def plan(migrations: Migrations, applied: List[AppliedMigration], database: String) raises -> List[Migration]
```

The migrations still to run, in order.

`applied` is what the `dodo_migrations` table holds. Raises a `USAGE`
error, and plans nothing, when:

- a migration that ran has changed since (its checksum differs);
- the table has a version the app doesn't know;
- a migration that hasn't run has a lower version than one that has.

### `checksum_of`

```mojo
def checksum_of(sql: String) raises -> String
```

Hex SHA-256 of `sql` with `\r\n` read as `\n`, so a checkout with Windows line endings matches one without.

### `lost_race`

```mojo
def lost_race(error: DbError) -> Bool
```

Whether another process ran the same migration first: its row already exists (a duplicate key), or the database aborted this transaction in its favour (PostgreSQL and CockroachDB SQLSTATE 40001 or 40P01).

### `failed`

```mojo
def failed(migration: Migration, error: DbError, note: String = "") -> DbError
```

`error`, with the migration that raised it named in the message.

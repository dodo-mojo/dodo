# ADR-0010: Database migrations

- Status: accepted
- Date: 2026-11-02

## Context

ADR-0009 shipped the SQL drivers without a way to change a schema over time. Today an app runs `execute_script("create table if not exists ...")` at startup, which can't add a column to a table that already exists, and nothing records which changes a database has seen.

An app usually runs several processes, so two of them can start at once and both try to change the schema. The three SQL protocols differ here:

- PostgreSQL and SQLite run DDL inside a transaction and roll it back on error. CockroachDB does too, with limits (a column added in a transaction can't be used later in that same transaction), but since 25.1 it commits an open transaction before each DDL statement by default (`autocommit_before_ddl`). Checked against CockroachDB 25.2: without turning that off, a failed migration's tracking row stays committed.
- MySQL and MariaDB commit each DDL statement on its own (implicit commit). A migration that fails halfway leaves the statements before the failure applied.

## Decision

1. **Plain SQL files, forward only.** A migration is a version number, a name and SQL text. `Migrations.from_dir("migrations")` reads files named `<version>_<name>.sql` (`0001_create_users.sql`); `Migrations().add(1, "create users", sql)` builds the list in code. No down migrations: to undo a change, write a new migration.
2. **Planning is separate from running.** `dodo.db.migrate` holds the planner: given the migrations the app knows and the rows in the database's tracking table, it returns what to run or a `DbError`. It never touches a database, so its rules are unit-tested without one.
3. **The planner refuses, it doesn't guess.** A run stops with a `USAGE` error when:
   - a migration that already ran changed since (its SHA-256 checksum differs; line endings are normalized first, so a Windows checkout matches);
   - the database has a version the app doesn't know (an older build pointed at a newer database);
   - a new version is lower than one already applied (two branches merged out of order). Renumber the new file.
4. **A tracking table per database**, `dodo_migrations`: `version` (primary key), `name`, `checksum`, `applied_at`. Each driver creates it if missing.
5. **One call per driver**: `db.migrate(migrations)` on `Postgres`, `MySql` and `Sqlite` returns the versions it applied. It runs each pending migration in order:
   - **PostgreSQL, CockroachDB, SQLite:** one transaction per migration. It inserts the migration's row first, then runs the SQL, then commits. On CockroachDB the transaction sets `autocommit_before_ddl = false` (`SET LOCAL`, so the pooled connection keeps its own setting). A second process that tries the same version waits on that row (SQLite: on `BEGIN IMMEDIATE`), then fails with a duplicate key or a serialization error; the driver rolls back, rereads the table and carries on. A failed migration rolls back completely, row and all.
   - **MySQL, MariaDB:** DDL can't be rolled back, so the driver holds a named lock (`GET_LOCK('dodo_migrations', ...)`) on one connection for the whole run, runs each migration's SQL, then records its row. A migration that fails halfway leaves its earlier statements applied and no row; the error says so. Keep one DDL statement per migration on these databases.
6. **Run at startup, before serving.** `migrate` blocks, like every driver call. Call it in `main` before `app.serve()`. A separate CLI (`dodo migrate`) can wrap the same call later.

## Consequences

- Schema changes are reviewed SQL files in the repo, applied once per database, in order, safely from several processes at once.
- No ORM or schema diffing, which matches ADR-0009 (no query builder). Writing the SQL is the app's job.
- MySQL and MariaDB apps can be left half-migrated by a failing multi-statement migration. The guide says to keep one statement per migration there.
- Redis, MongoDB and ClickHouse get no `migrate`. They have no fixed schema (Redis, MongoDB), or apps there manage tables differently (ClickHouse); add one when someone asks.

## Alternatives considered

- **Down migrations:** most teams roll forward in production; a down script is rarely tested and gives false confidence.
- **PostgreSQL advisory locks:** a session lock on a pooled connection has to be released on every path, and the row-first transaction already makes concurrent runners wait, with no extra state.
- **Allow out-of-order versions:** hides merge mistakes; renumbering a file is cheap.
- **Embedding the SQL at compile time:** Mojo has no `include_str`. Reading a directory at startup works today; the files can be shipped next to the binary.

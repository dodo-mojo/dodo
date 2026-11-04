# ADR-0009: Native database drivers

- Status: accepted
- Date: 2026-11-02

## Context

A web backend needs a database, and dodo has no way to reach one. The only route today is Python interop under `Offload`: slow, a Python environment at runtime, and undocumented. Mojo has no mature database drivers of its own.

The first version covers one database of each common kind:

| Kind | Databases | Protocol |
|---|---|---|
| Relational | PostgreSQL, CockroachDB | PostgreSQL wire protocol v3 (CockroachDB speaks it) |
| Relational | MySQL, MariaDB | MySQL client/server protocol |
| Embedded | SQLite | C library, no wire protocol |
| Key-value | Redis, Valkey | RESP2 |
| Document | MongoDB | OP_MSG with BSON |
| Analytics | ClickHouse | HTTP interface |

Every server above runs in Docker for the tests (`tests/live/db/compose.yaml`). Probes in [research/db-spikes](../../research/db-spikes) check each protocol against the real server before the production code is written.

## Decision

1. **Native Mojo, no C client libraries.** Each wire protocol is written in Mojo. SQLite is the exception: it is a library, not a server, so `dodo.db.sqlite` calls `libsqlite3` (conda-forge `libsqlite`) through FFI.
2. **Protocol and I/O are separate.** Each protocol's encoder and decoder is sans-I/O: bytes in, messages and bytes out, no sockets (checked by `pixi run check-sans-io`). A thin connection type drives it over `TcpStream` or `TlsStream`. Outgoing calls on the event loop (ADR-0006) can later reuse the same codecs without a rewrite.
3. **Blocking connections first, from offloaded routes.** A connection blocks its thread for one round trip. Routes that use a database run on the offload pool (ADR-0004) so they never stall a worker's event loop: `blocking=True` on an App route, or `Offload(handler)` on a handler struct. Usage guide: [`docs/databases.md`](../databases.md).
4. **Layout.** One package, `dodo.db`, with a subpackage per protocol: `dodo.db.postgres` (also CockroachDB), `dodo.db.mysql` (also MariaDB), `dodo.db.sqlite`, `dodo.db.redis`, `dodo.db.mongo`, `dodo.db.clickhouse`. The `dodo.db` root holds what they share: `Pool`, `DbError`, `Param`, `Rows`, `Row` and `rows.to[T]()`, which fills user structs from columns by name through reflection, the way `deserialize_json` does. Each driver's client (`Postgres`, `MySql`, `Sqlite`, `Redis`, `Mongo`, `ClickHouse`) is a cheap-to-copy handle on a pool. MongoDB results (`Documents`) and ClickHouse results reuse `to[T]()` too.
5. **Parameters never touch the SQL text.** Values go to the server separately from the statement: PostgreSQL's extended query protocol, MySQL prepared statements, SQLite `bind`, ClickHouse query parameters (`{p1:UInt64}`, `{p2:String}`, positional). Each driver keeps its database's own placeholder syntax (`$1`, `?`, `{p1:Type}`); dodo does not rewrite SQL. A plain `query` runs exactly one statement (PostgreSQL's extended protocol, MySQL without multi-statements, SQLite refusing a second statement, ClickHouse's HTTP interface); `execute_script` runs several, without parameters. Redis arguments are binary-safe bulk strings, and MongoDB filters are BSON documents, never strings.
6. **One pool type.** `Pool[C]` is thread-safe and bounded: it opens connections lazily up to `max_size`, checks out with a timeout, pings a connection that sat idle, and closes one past its maximum lifetime. A checked-out connection comes back to the pool when its guard is destroyed; one that failed mid-query is closed instead. A pool lives in the app state, built once and shared by every worker.
7. **Authentication.** PostgreSQL: SCRAM-SHA-256, MD5, cleartext and trust. MySQL: `caching_sha2_password` (over TLS, or RSA-OAEP with the server's key when cleartext) and `mysql_native_password`. MongoDB: SCRAM-SHA-256. Redis: `AUTH` with an optional user name (ACL). ClickHouse: the `X-ClickHouse-User` and `X-ClickHouse-Key` headers. Hashes, PBKDF2 and RSA come from the OpenSSL that `dodo.tls` already loads (`dodo.crypto.digest`, `dodo.crypto.rsa`).
8. **TLS** through `dodo.tls` for every network driver, with each database's usual defaults. PostgreSQL and MySQL match libpq and the mysql client: by default they encrypt when the server offers TLS, without checking the certificate (`TlsVerify.ENCRYPT_ONLY`, which prints no warning); `require`/`required` insists on TLS; `verify-full`/`verify_identity` checks the certificate and host name. Redis (`rediss://`), MongoDB (`tls=true`) and ClickHouse (`clickhouses://`) verify by default when TLS is asked for, with an opt-out.
9. **Not in v1.** No ORM or query builder (design section 1). No migrations tool (since added: ADR-0010), PostgreSQL `COPY` or `LISTEN/NOTIFY`, MongoDB replica-set discovery, `mongodb+srv://`, SCRAM-SHA-1, transactions or change streams, Redis Cluster, Sentinel or pub/sub (a pooled connection refuses `SUBSCRIBE`, `MONITOR`, `SELECT`, `AUTH` and `HELLO`), ClickHouse bulk inserts in a binary format, 128- and 256-bit ClickHouse integers and decimals, or the ClickHouse native TCP protocol. Each can be added on the same codecs.

## Consequences

- No new native dependency except `libsqlite`, and every driver works the same on Linux and macOS.
- dodo owns six protocol implementations. Each has unit tests with no server (`tests/db/`) and a suite against the real server in Docker (`tests/live/db/`); fuzzers are still to come (`TODO.md`).
- The Docker suite runs as its own task (`pixi run tests-db`), not in `pixi run tests`, so the main suite still runs without Docker. SQLite needs no server, so its tests are in the main suite. A CI job that starts the databases is still to come.
- Dates and times come back as text (`2026-11-02 10:30:00`), in UTC for ClickHouse. A typed date API can come later without changing the wire code.
- A request waiting on the database holds an offload thread until ADR-0006 moves database calls onto the event loop. Size `offload_threads` for the number of queries in flight.

## Alternatives considered

- FFI to C client libraries (libpq, hiredis, libmongoc, libmysqlclient): quicker to start, but heavy native dependencies, blocking only, and hard to move onto the event loop later.
- Python drivers through interop: slow, needs a Python environment at runtime, and goes against dodo's speed goal.
- One shared SQL dialect with rewritten placeholders: hides each database's own syntax and adds a parser on every query.

# ADR-0011: PostgreSQL LISTEN/NOTIFY and COPY

- Status: proposed
- Date: 2026-11-05

## Context

ADR-0009 left PostgreSQL's `LISTEN/NOTIFY` and `COPY` out of v1. Bloop, dodo's first real app (github.com/anubhav-qt/bloop, ADRs 0031 and 0033 there), needs both:

- **Notifications**: Bloop's scheduler wakes a chat when a record is stored for it. Polling the database adds up to a poll interval of delay to every wake, and a query per interval forever. `LISTEN/NOTIFY` tells it at once, on commit.
- **Bulk loads**: exchange files (bhavcopies) and years of daily prices are thousands to millions of rows. One `INSERT` per row is a round trip each; `COPY` streams them in one statement.

What the protocol does (PostgreSQL docs, Frontend/Backend Protocol, "Asynchronous Operations" and "COPY Operations"):

- A session that ran `LISTEN ch` gets a `NotificationResponse` (`A`: sender pid, channel, payload) when any session commits a `NOTIFY ch` or `pg_notify(ch, payload)`. Notifications are sent only on commit, identical ones in one transaction are sent once, and a payload is at most 8,000 bytes. They can arrive between queries or in the middle of reading another query's results. A session that is gone gets nothing, and nothing is kept for it.
- `COPY ... FROM STDIN` answers `CopyInResponse` (`G`); the client sends `CopyData` (`d`) messages, then `CopyDone` (`c`) or `CopyFail` (`f`). `COPY ... TO STDOUT` answers `CopyOutResponse` (`H`), then `CopyData` messages and `CopyDone`. Both end with `CommandComplete` and `ReadyForQuery`. `COPY` takes no parameters, so it runs over the simple query protocol.

Today `PgConnection._read_results` drops `A` messages, and any `G` or `H` would fail as unexpected.

## Decision

**Listening**

1. **A listener owns its connection.** `PgListener` holds one connection of its own, outside the pool: a pooled connection that listened would carry notifications into whoever checks it out next. Made from a URL or config (`PgListener(url)`), or from a pool's config (`db.listener()`).
2. **`listen(channel)`, `unlisten(channel)`, `unlisten_all()`.** `LISTEN` takes an identifier, not a parameter, so the channel is quoted as an identifier (double quotes, inner quotes doubled, NUL refused), never pasted into the SQL as is.
3. **`wait(timeout_ms) -> PgEvent`.** Blocks until one of these, which it returns:
   - `NOTIFICATION` with `channel`, `payload` and `sender_pid`;
   - `TIMEOUT` when nothing came in time;
   - `RECONNECTED` after the connection broke and the listener opened a new one and listened again on every channel. Notifications sent while it was away are lost, so this tells the caller to catch up.
   Notifications that arrive while `listen` reads its own result are queued and returned by the next `wait`, in order.
4. **It reconnects by itself.** A broken connection is reopened with backoff (100 ms doubling to 5 s), and `wait` never raises for it. It raises only for errors a retry can't fix: bad configuration, failed authentication, a refused `LISTEN`.
5. **Nudges, not data.** The guide says it plainly: a notification says "look again", and the reader rereads from a position it stores. A missed one then costs one timeout, never data. `db.notify(channel, payload)` runs `select pg_notify($1, $2)` and refuses a payload over 8,000 bytes with a `USAGE` error.
6. **Blocking, like the rest of v1.** Run a listener on a thread of its own or an offloaded handler (ADR-0004). The codec stays sans-I/O (`protocol.parse_notification`), so the event-loop version from ADR-0006 reuses it.

**Copying**

7. **`copy_in(sql, data) -> Int`** sends `data` (bytes, in the text or CSV format the SQL names) and returns the number of rows copied. **`copy_in_start(sql) -> PgCopyIn`** streams instead: `write(chunk)` any number of times, then `finish() -> Int`, or `abort(reason)`, which sends `CopyFail` and leaves the connection usable. A `PgCopyIn` dropped without `finish` aborts.
8. **`copy_out(sql) -> List[UInt8]`** returns everything; **`copy_out_start(sql) -> PgCopyOut`** streams it with `next_chunk() -> Optional[List[UInt8]]`.
9. **On the pool and in transactions.** `Postgres` and `PgTransaction` both have them. A server error mid-copy is raised after `ReadyForQuery`, so the connection goes back to the pool clean.
10. **Text and CSV formats in this ADR.** The binary format can come later on the same messages.

**Tests**

- Unit tests with no server: parsing `A`, `G`, `H`, `d`, `c`; identifier quoting; the payload limit; the copy state machine refusing a `write` after `finish`.
- Live tests against PostgreSQL in Docker (`tests/live/db/`): a notification from another session; none before commit; one for duplicates in a transaction; `TIMEOUT`; `RECONNECTED` after `pg_terminate_backend` of the listener's pid; a `COPY` of a million rows; a bad row failing the copy and leaving the connection usable; `copy_out` of what `copy_in` wrote.
- CockroachDB has no `LISTEN/NOTIFY`, so its `listen` returns the server's error; `COPY FROM STDIN` works there in text and CSV, and is tested on both.

## Consequences

- Apps get push wakes and bulk loads without a C client library.
- Each listener costs one server connection for as long as it runs.
- A listener that falls behind is the app's to handle: the server queues notifications for a slow session (up to 8 GB by default) and fails `NOTIFY` once that queue is full. The guide says to keep `wait` loops short and do the work elsewhere.
- `PgConnection` must now pass `A` messages it reads mid-query to whoever wants them. Pooled connections never listen, so for them it still drops them.

## Alternatives considered

- **Listening on a pooled connection**: the next borrower would get someone else's notifications, and returning the connection would need `UNLISTEN *`.
- **Event-loop listener now**: needs ADR-0006's outgoing calls on the loop, which aren't built. The sans-I/O codec keeps the door open.
- **Polling in the app**: up to an interval of delay on every wake and a query per interval forever.
- **Multi-row `INSERT` instead of `COPY`**: still parses and plans each statement, caps at 65,535 parameters, and is slower for bulk loads (to be measured against `COPY` in the live suite).

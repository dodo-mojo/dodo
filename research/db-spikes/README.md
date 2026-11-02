# Database driver spikes

Throwaway clients that check each wire protocol against the real server before the production drivers in `dodo/db/` were written (ADR-0009). Each one runs against `tests/live/db/compose.yaml`:

```bash
docker compose -f tests/live/db/compose.yaml up -d --wait
pixi run mojo run -I . research/db-spikes/pg_spike.mojo
```

| Spike | Server | Checked |
|---|---|---|
| `lang_probe.mojo` | none | Variadic `*params: Param` with `@implicit` conversions, associated types in traits, a guard whose destructor runs |
| `crypto_probe.mojo` | none | SHA-1, SHA-256, MD5, HMAC-SHA256, PBKDF2 against RFC test vectors |
| `pg_spike.mojo` | PostgreSQL 17, CockroachDB 25.2 | Startup, SCRAM-SHA-256 with server signature check, trust auth, extended query with text params, NULL, Unicode, errors with recovery, wrong password |
| `mysql_spike.mojo` | MySQL 8.4, MariaDB 11.8 | Handshake v10, `caching_sha2_password` fast path and full auth over RSA, `mysql_native_password`, text and binary result sets, prepared statements with NULL params, dates and microseconds |
| `redis_spike.mojo` | Redis 7 | `NOAUTH`, `AUTH`, pipelining 11 commands in one write, binary-safe values with CRLF, nil, integers, arrays, errors |
| `mongo_spike.mojo` | MongoDB 8 | OP_MSG, BSON writer and reader, `hello`, SCRAM-SHA-256 through `saslStart`/`saslContinue`, insert, find with a filter, update, count, write errors |
| `clickhouse_spike.mojo` | ClickHouse 25.8 | HTTP with auth headers, `{name:Type}` params as `param_*` URL fields, `RowBinaryWithNamesAndTypes` (Nullable, Bool, Date, DateTime64, Array), errors |
| `sqlite_spike.mojo` | SQLite 3.54 (libsqlite3) | Open file and `:memory:`, prepare, bind int, float, text, blob and NULL, step, typed columns, constraint errors |

## Findings that shaped the drivers

- **Mojo frees a value right after its last use**, and taking a buffer's address counts as that use. A C call made after it reads freed memory. Keep the buffer alive past the call (`_ = buf^`), and give C its out-parameters as heap cells (`List[Int](length=1)`), never the address of a local. The same rule covers `OwnedDLHandle`: a handle whose last use is a symbol lookup is closed before the call, which crashed the SQLite spike on close. The SQLite driver keeps one handle for the process.
- **CockroachDB** speaks PostgreSQL closely enough that the same code ran unchanged. Its `int` is `int8` (OID 20), not `int4`.
- **MySQL** answers `caching_sha2_password` with the fast path once a user's hash is cached, and with full authentication (RSA over cleartext) the first time. Both paths need to work; `root` exercised the second. MariaDB 11.8 still defaults to `mysql_native_password`. Both servers support `CLIENT_DEPRECATE_EOF`.
- **MongoDB** reports a duplicate key as `writeErrors` inside a reply with `ok: 1`. The driver has to treat that as a failure.
- **ClickHouse** answers an unknown table with HTTP 404, not 500. The `X-ClickHouse-Exception-Code` header is the reliable error signal.
- **Windows reserves ports at random above 49152** (`netsh int ipv4 show excludedportrange protocol=tcp`), so the test ports sit in the 43000s to 48000s.

# `dodo.db.redis`

Redis and Valkey, over RESP2.

```mojo
from dodo.db.redis import Redis

var cache = Redis("redis://:secret@localhost:6379/0")
cache.set("greeting", "hello", ttl_ms=60_000)
print(cache.get("greeting").value())
```

Every argument goes as a binary-safe bulk string. Pipelines send many
commands in one round trip; `run_transaction` wraps them in MULTI/EXEC.
See ADR-0009.

## Modules

- [`dodo.db.redis.client`](client.md): The Redis pool most code uses, with typed helpers for common commands.
- [`dodo.db.redis.connection`](connection.md): One connection to a Redis or Valkey server.
- [`dodo.db.redis.protocol`](protocol.md): RESP2, the Redis wire protocol, without I/O.

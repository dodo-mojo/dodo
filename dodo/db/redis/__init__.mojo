"""Redis and Valkey, over RESP2.

```mojo
from dodo.db.redis import Redis

var cache = Redis("redis://:secret@localhost:6379/0")
cache.set("greeting", "hello", ttl_ms=60_000)
print(cache.get("greeting").value())
```

Every argument goes as a binary-safe bulk string. Pipelines send many
commands in one round trip; `run_transaction` wraps them in MULTI/EXEC.
See ADR-0009.
"""

from .client import Redis, RedisPipeline
from .connection import RedisConfig, RedisConnection
from .protocol import RedisReply

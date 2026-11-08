# `dodo.db.redis.client`

The Redis pool most code uses, with typed helpers for common commands.

## Structs

### `Redis`

```mojo
struct Redis
```

A pool of connections to Redis or Valkey.

Cheap to copy; every copy shares the connections, so keep one in the
app state. Each call checks a connection out and gives it back.

```mojo
var cache = Redis("redis://:secret@localhost:6379/0")
cache.set("session:42", token, ttl_ms=3_600_000)
var token = cache.get("session:42")        # Optional[String]
var hits = cache.incr("hits")
var reply = cache.command("ZADD", "board", 120, "ada")
```

Pub/Sub, MONITOR and blocking reads that need a connection of their
own are not supported yet.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Redis.__init__`

```mojo
def __init__(out self, url: String, options: PoolOptions = PoolOptions()) raises
```

```mojo
def __init__(out self, config: RedisConfig, options: PoolOptions = PoolOptions())
```

#### `Redis.command`

```mojo
def command(self, *args: Param) raises -> RedisReply
```

Run one command: `command("HSET", "user:1", "name", "ada")`. Raises `DbError` (kind `SERVER`, code `WRONGTYPE` and so on) when the server answers with an error.

#### `Redis.run`

```mojo
def run(self, pipeline: RedisPipeline) raises -> List[RedisReply]
```

Send every queued command in one round trip; return one reply per command. Errors come back as error replies, not raised.

#### `Redis.run_transaction`

```mojo
def run_transaction(self, pipeline: RedisPipeline) raises -> List[RedisReply]
```

Run the queued commands atomically with MULTI and EXEC, in one round trip, and return their replies. Raises if any command was refused before running, in which case none ran.

#### `Redis.connection`

```mojo
def connection(self) raises -> Pooled[RedisConnection]
```

A connection for several calls in a row (WATCH, then MULTI).

#### `Redis.get`

```mojo
def get(self, key: String) raises -> Optional[String]
```

#### `Redis.get_bytes`

```mojo
def get_bytes(self, key: String) raises -> Optional[List[UInt8]]
```

#### `Redis.set`

```mojo
def set(self, key: String, value: Param, ttl_ms: Int = Int(0)) raises
```

Set a value, with an expiry when `ttl_ms` > 0.

#### `Redis.set_if_absent`

```mojo
def set_if_absent(self, key: String, value: Param, ttl_ms: Int = Int(0)) raises -> Bool
```

Set only when the key doesn't exist (a lock, a dedupe marker). True when it was set.

#### `Redis.delete`

```mojo
def delete(self, key: String) raises -> Bool
```

True when the key existed.

#### `Redis.exists`

```mojo
def exists(self, key: String) raises -> Bool
```

#### `Redis.incr`

```mojo
def incr(self, key: String, by: Int = Int(1)) raises -> Int
```

Add to a counter, starting from 0; return the new value.

#### `Redis.expire`

```mojo
def expire(self, key: String, ttl_ms: Int) raises -> Bool
```

True when the key exists and now expires.

#### `Redis.ttl_ms`

```mojo
def ttl_ms(self, key: String) raises -> Int
```

Milliseconds left; -1 when the key never expires, -2 when it doesn't exist.

#### `Redis.hset`

```mojo
def hset(self, key: String, field: String, value: Param) raises -> Bool
```

True when the field is new.

#### `Redis.hget`

```mojo
def hget(self, key: String, field: String) raises -> Optional[String]
```

#### `Redis.hgetall`

```mojo
def hgetall(self, key: String) raises -> Dict[String, String]
```

#### `Redis.lpush`

```mojo
def lpush(self, key: String, value: Param) raises -> Int
```

Push onto the head; return the new length.

#### `Redis.rpush`

```mojo
def rpush(self, key: String, value: Param) raises -> Int
```

Push onto the tail; return the new length.

#### `Redis.lrange`

```mojo
def lrange(self, key: String, start: Int = Int(0), stop: Int = Int(-1)) raises -> List[String]
```

#### `Redis.sadd`

```mojo
def sadd(self, key: String, member: Param) raises -> Bool
```

True when the member is new.

#### `Redis.smembers`

```mojo
def smembers(self, key: String) raises -> List[String]
```

#### `Redis.publish`

```mojo
def publish(self, channel: String, message: Param) raises -> Int
```

Return how many subscribers got the message.

#### `Redis.open_count`

```mojo
def open_count(self) -> Int
```

#### `Redis.idle_count`

```mojo
def idle_count(self) -> Int
```

### `RedisPipeline`

```mojo
struct RedisPipeline
```

Commands to send in one round trip with `Redis.run` or `Redis.run_transaction`.

```mojo
var p = RedisPipeline()
p.add("INCR", "views")
p.add("EXPIRE", "views", 60)
var replies = cache.run_transaction(p)
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `RedisPipeline.__init__`

```mojo
def __init__(out self)
```

#### `RedisPipeline.add`

```mojo
def add(mut self, *args: Param)
```

#### `RedisPipeline.__len__`

```mojo
def __len__(self) -> Int
```

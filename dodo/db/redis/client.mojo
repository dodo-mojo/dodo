"""The Redis pool most code uses, with typed helpers for common commands."""

from std.collections import Dict, Optional

from ..error import DbError
from ..param import Param, params_of
from ..pool import Pool, PoolOptions, Pooled
from .connection import RedisConfig, RedisConnection
from .protocol import DB, RedisReply, reply_error


struct Redis(Copyable):
    """A pool of connections to Redis or Valkey.

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
    """

    var _pool: Pool[RedisConnection]

    def __init__(
        out self, url: String, options: PoolOptions = PoolOptions()
    ) raises DbError:
        self._pool = Pool[RedisConnection](RedisConfig.from_url(url), options)

    def __init__(
        out self, config: RedisConfig, options: PoolOptions = PoolOptions()
    ):
        self._pool = Pool[RedisConnection](config, options)

    # ── Any command ─────────────────────────────────────────────────────────

    def command(self, *args: Param) raises DbError -> RedisReply:
        """Run one command: `command("HSET", "user:1", "name", "ada")`.
        Raises `DbError` (kind `SERVER`, code `WRONGTYPE` and so on) when
        the server answers with an error."""
        return self._run(params_of(args))

    def _run(self, args: List[Param]) raises DbError -> RedisReply:
        var conn = self._pool.acquire()
        return conn.conn().command(args)

    def run(self, pipeline: RedisPipeline) raises DbError -> List[RedisReply]:
        """Send every queued command in one round trip; return one reply
        per command. Errors come back as error replies, not raised."""
        var conn = self._pool.acquire()
        return conn.conn().pipeline(pipeline._commands)

    def run_transaction(
        self, pipeline: RedisPipeline
    ) raises DbError -> List[RedisReply]:
        """Run the queued commands atomically with MULTI and EXEC, in one
        round trip, and return their replies. Raises if any command was
        refused before running, in which case none ran."""
        var commands = List[List[Param]]()
        commands.append(_args("MULTI"))
        for ref c in pipeline._commands:
            commands.append(c.copy())
        commands.append(_args("EXEC"))
        var conn = self._pool.acquire()
        var replies = conn.conn().pipeline(commands)
        for i in range(len(replies) - 1):
            if replies[i].is_error():
                raise reply_error(replies[i])
        var result = replies[len(replies) - 1].copy()
        if result.is_error():
            raise reply_error(result)
        if result.is_nil():
            raise DbError.server(DB, "EXECABORT", "a watched key changed")
        return result.items()

    def connection(self) raises DbError -> Pooled[RedisConnection]:
        """A connection for several calls in a row (WATCH, then MULTI)."""
        return self._pool.acquire()

    # ── Strings ─────────────────────────────────────────────────────────────

    def get(self, key: String) raises DbError -> Optional[String]:
        var reply = self._run(_args("GET", key))
        if reply.is_nil():
            return None
        return reply.string()

    def get_bytes(self, key: String) raises DbError -> Optional[List[UInt8]]:
        var reply = self._run(_args("GET", key))
        if reply.is_nil():
            return None
        return reply.bytes()

    def set(self, key: String, value: Param, ttl_ms: Int = 0) raises DbError:
        """Set a value, with an expiry when `ttl_ms` > 0."""
        var args = _args("SET", key)
        args.append(value.copy())
        if ttl_ms > 0:
            args.append("PX")
            args.append(ttl_ms)
        _ = self._run(args)

    def set_if_absent(
        self, key: String, value: Param, ttl_ms: Int = 0
    ) raises DbError -> Bool:
        """Set only when the key doesn't exist (a lock, a dedupe marker).
        True when it was set."""
        var args = _args("SET", key)
        args.append(value.copy())
        args.append("NX")
        if ttl_ms > 0:
            args.append("PX")
            args.append(ttl_ms)
        return not self._run(args).is_nil()

    def delete(self, key: String) raises DbError -> Bool:
        """True when the key existed."""
        return self._run(_args("DEL", key)).int() > 0

    def exists(self, key: String) raises DbError -> Bool:
        return self._run(_args("EXISTS", key)).int() > 0

    def incr(self, key: String, by: Int = 1) raises DbError -> Int:
        """Add to a counter, starting from 0; return the new value."""
        var args = _args("INCRBY", key)
        args.append(by)
        return self._run(args).int()

    def expire(self, key: String, ttl_ms: Int) raises DbError -> Bool:
        """True when the key exists and now expires."""
        var args = _args("PEXPIRE", key)
        args.append(ttl_ms)
        return self._run(args).int() == 1

    def ttl_ms(self, key: String) raises DbError -> Int:
        """Milliseconds left; -1 when the key never expires, -2 when it
        doesn't exist."""
        return self._run(_args("PTTL", key)).int()

    # ── Hashes, lists, sets ─────────────────────────────────────────────────

    def hset(
        self, key: String, field: String, value: Param
    ) raises DbError -> Bool:
        """True when the field is new."""
        var args = _args("HSET", key)
        args.append(field)
        args.append(value.copy())
        return self._run(args).int() == 1

    def hget(
        self, key: String, field: String
    ) raises DbError -> Optional[String]:
        var args = _args("HGET", key)
        args.append(field)
        var reply = self._run(args)
        if reply.is_nil():
            return None
        return reply.string()

    def hgetall(self, key: String) raises DbError -> Dict[String, String]:
        var items = self._run(_args("HGETALL", key)).strings()
        var out = Dict[String, String]()
        var i = 0
        while i + 1 < len(items):
            out[items[i]] = items[i + 1]
            i += 2
        return out^

    def lpush(self, key: String, value: Param) raises DbError -> Int:
        """Push onto the head; return the new length."""
        var args = _args("LPUSH", key)
        args.append(value.copy())
        return self._run(args).int()

    def rpush(self, key: String, value: Param) raises DbError -> Int:
        """Push onto the tail; return the new length."""
        var args = _args("RPUSH", key)
        args.append(value.copy())
        return self._run(args).int()

    def lrange(
        self, key: String, start: Int = 0, stop: Int = -1
    ) raises DbError -> List[String]:
        var args = _args("LRANGE", key)
        args.append(start)
        args.append(stop)
        return self._run(args).strings()

    def sadd(self, key: String, member: Param) raises DbError -> Bool:
        """True when the member is new."""
        var args = _args("SADD", key)
        args.append(member.copy())
        return self._run(args).int() == 1

    def smembers(self, key: String) raises DbError -> List[String]:
        return self._run(_args("SMEMBERS", key)).strings()

    def publish(self, channel: String, message: Param) raises DbError -> Int:
        """Return how many subscribers got the message."""
        var args = _args("PUBLISH", channel)
        args.append(message.copy())
        return self._run(args).int()

    def open_count(self) -> Int:
        return self._pool.open_count()

    def idle_count(self) -> Int:
        return self._pool.idle_count()


struct RedisPipeline(Copyable):
    """Commands to send in one round trip with `Redis.run` or
    `Redis.run_transaction`.

    ```mojo
    var p = RedisPipeline()
    p.add("INCR", "views")
    p.add("EXPIRE", "views", 60)
    var replies = cache.run_transaction(p)
    ```
    """

    var _commands: List[List[Param]]

    def __init__(out self):
        self._commands = List[List[Param]]()

    def add(mut self, *args: Param):
        self._commands.append(params_of(args))

    def __len__(self) -> Int:
        return len(self._commands)


def _args(name: String) -> List[Param]:
    var out = List[Param]()
    out.append(name)
    return out^


def _args(name: String, key: String) -> List[Param]:
    var out = _args(name)
    out.append(key)
    return out^

"""Live tests: dodo.db.redis against Redis 7 and Valkey 8 in Docker.

    docker compose -f tests/live/db/compose.yaml up -d --wait
    pixi run tests-db
"""

from std.os import getenv
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, Param, PoolOptions
from dodo.db.redis import Redis, RedisPipeline, RedisReply


def redis_url() -> String:
    return getenv("DODO_TEST_REDIS", "redis://:dodo-test@127.0.0.1:46379/0")


def valkey_url() -> String:
    return getenv("DODO_TEST_VALKEY", "valkey://:dodo-test@127.0.0.1:46380/0")


def check_strings(db: Redis) raises:
    _ = db.command("FLUSHDB")
    var tricky = String("line1\r\n$5\r\n*2 héllo 🦤")
    db.set("k", tricky)
    assert_equal(db.get("k").value(), tricky)
    assert_false(Bool(db.get("missing")))
    assert_false(db.set_if_absent("k", "other"))
    assert_true(db.set_if_absent("fresh", "v", ttl_ms=60_000))
    var ttl = db.ttl_ms("fresh")
    assert_true(ttl > 0 and ttl <= 60_000)
    assert_equal(db.ttl_ms("k"), -1)
    assert_equal(db.ttl_ms("missing"), -2)
    assert_true(db.expire("k", 30_000))
    assert_true(db.exists("k"))
    assert_true(db.delete("k"))
    assert_false(db.delete("k"))

    var blob = List[UInt8]()
    for i in range(256):
        blob.append(UInt8(i))
    db.set("blob", Param.bytes(blob))
    var back = db.get_bytes("blob").value().copy()
    assert_equal(len(back), 256)
    for i in range(256):
        assert_equal(Int(back[i]), i)

    assert_equal(db.incr("n"), 1)
    assert_equal(db.incr("n", 41), 42)
    assert_equal(db.command("GET", "n").int(), 42)
    db.set("f", 2.5)
    assert_equal(db.command("INCRBYFLOAT", "f", 0.5).string(), "3")
    db.set("b", True)
    assert_equal(db.get("b").value(), "1")


def check_collections(db: Redis) raises:
    _ = db.command("DEL", "h", "l", "s")
    assert_true(db.hset("h", "name", "ada"))
    assert_false(db.hset("h", "name", "grace"))
    _ = db.hset("h", "age", 36)
    assert_equal(db.hget("h", "name").value(), "grace")
    assert_false(Bool(db.hget("h", "none")))
    var all = db.hgetall("h")
    assert_equal(len(all), 2)
    assert_equal(all["age"], "36")
    _ = db.rpush("l", "b")
    _ = db.rpush("l", "c")
    assert_equal(db.lpush("l", "a"), 3)
    var items = db.lrange("l")
    assert_equal(len(items), 3)
    assert_equal(items[0], "a")
    assert_equal(items[2], "c")
    assert_true(db.sadd("s", "x"))
    assert_false(db.sadd("s", "x"))
    assert_equal(len(db.smembers("s")), 1)
    assert_equal(db.publish("nobody-listens", "hi"), 0)


def check_replies(db: Redis) raises:
    var status = db.command("PING")
    assert_equal(status.kind(), RedisReply.STATUS)
    assert_equal(status.string(), "PONG")
    var nested = db.command("EVAL", "return {1, {'a', {2, 'b'}}, false}", 0)
    assert_equal(len(nested), 3)
    assert_equal(nested[0].int(), 1)
    assert_equal(nested[1][0].string(), "a")
    assert_equal(nested[1][1][0].int(), 2)
    assert_equal(nested[1][1][1].string(), "b")
    assert_true(nested[2].is_nil())
    assert_equal(String(nested), "[(integer) 1, [a, [(integer) 2, b]], (nil)]")
    var failed = False
    try:
        _ = nested[3]
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "index past the end should fail")


def check_errors(db: Redis) raises:
    db.set("str", "v")
    var failed = False
    try:
        _ = db.command("LPUSH", "str", "x")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
        assert_equal(e.code, "WRONGTYPE")
    assert_true(failed, "wrong type should fail")
    failed = False
    try:
        _ = db.command("NOSUCHCOMMAND")
    except e:
        failed = True
        assert_equal(e.code, "ERR")
    assert_true(failed, "unknown command should fail")
    failed = False
    try:
        _ = db.command("subscribe", "news")
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "SUBSCRIBE should be refused on a pooled connection")
    failed = False
    try:
        _ = db.command("SET", "k", Param.null())
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "NULL has no Redis form")
    # The connection survived every error above.
    assert_equal(db.command("PING").string(), "PONG")


def check_pipeline(db: Redis) raises:
    _ = db.command("DEL", "p", "str")
    db.set("str", "v")
    var p = RedisPipeline()
    for _ in range(100):
        p.add("INCR", "p")
    p.add("LPUSH", "str", "x")
    p.add("GET", "p")
    var replies = db.run(p)
    assert_equal(len(replies), 102)
    assert_equal(replies[99].int(), 100)
    assert_true(replies[100].is_error())
    assert_equal(replies[100].error_code(), "WRONGTYPE")
    assert_equal(replies[101].int(), 100)


def check_transaction(db: Redis) raises:
    _ = db.command("DEL", "t", "tl")
    var p = RedisPipeline()
    p.add("INCR", "t")
    p.add("RPUSH", "tl", "a", "b")
    p.add("LRANGE", "tl", 0, -1)
    var replies = db.run_transaction(p)
    assert_equal(len(replies), 3)
    assert_equal(replies[0].int(), 1)
    assert_equal(replies[2].strings()[1], "b")

    var bad = RedisPipeline()
    bad.add("INCR", "t")
    bad.add("SET", "only-one-arg")
    var failed = False
    try:
        _ = db.run_transaction(bad)
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
    assert_true(
        failed, "a command refused at queue time aborts the transaction"
    )
    assert_equal(db.get("t").value(), "1")


def leave_mid_transaction(db: Redis) raises:
    var conn = db.connection()
    _ = conn.conn().command(_list("WATCH", "w"))
    _ = conn.conn().command(_list("MULTI"))
    _ = conn.conn().command(_list("SET", "w", "queued"))


def check_reset(url: String) raises:
    """A connection returned mid-MULTI or mid-WATCH is cleaned up."""
    var db = Redis(url, pool_of(1))
    _ = db.command("DEL", "w")
    leave_mid_transaction(db)
    assert_equal(db.command("PING").string(), "PONG")
    assert_false(Bool(db.get("w")), "the queued SET was discarded")


def _list(*args: Param) -> List[Param]:
    var out = List[Param]()
    for a in args:
        out.append(a.copy())
    return out^


def check_large(db: Redis) raises:
    var big = String()
    for _ in range(100_000):
        big += "0123456789"
    db.set("big", big)
    assert_equal(db.get("big").value().byte_length(), 1_000_000)
    _ = db.command("DEL", "many")
    var p = RedisPipeline()
    for i in range(20_000):
        p.add("RPUSH", "many", i)
    _ = db.run(p)
    var many = db.lrange("many")
    assert_equal(len(many), 20_000)
    assert_equal(many[19_999], "19999")


def pool_of(size: Int) -> PoolOptions:
    var options = PoolOptions()
    options.max_size = size
    options.acquire_timeout_ms = 300
    return options^


def check_pool_limits(url: String) raises:
    var db = Redis(url, pool_of(1))
    var held = db.connection()
    var failed = False
    try:
        _ = db.command("PING")
    except e:
        failed = True
        assert_equal(e.kind, DbError.POOL_TIMEOUT)
    assert_true(failed, "second checkout should time out")
    _ = held^
    assert_equal(db.command("PING").string(), "PONG")
    assert_equal(db.open_count(), 1)


def check_databases() raises:
    var zero = Redis("redis://:dodo-test@127.0.0.1:46379/0")
    var one = Redis("redis://:dodo-test@127.0.0.1:46379/1")
    zero.set("where", "zero")
    one.set("where", "one")
    assert_equal(zero.get("where").value(), "zero")
    assert_equal(one.get("where").value(), "one")


def check_auth() raises:
    var failed = False
    try:
        _ = Redis("redis://:wrong@127.0.0.1:46379").command("PING")
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
        assert_equal(e.code, "WRONGPASS")
    assert_true(failed, "wrong password should fail")
    failed = False
    try:
        _ = Redis("redis://127.0.0.1:46379").command("PING")
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
        assert_equal(e.code, "NOAUTH")
    assert_true(failed, "no password should fail")
    failed = False
    try:
        _ = Redis("redis://:x@127.0.0.1:1?connect_timeout_ms=500").command(
            "PING"
        )
    except e:
        failed = True
        assert_equal(e.kind, DbError.CONNECT)
    assert_true(failed, "closed port should fail")


def run_suite(label: String, url: String) raises:
    var db = Redis(url)
    check_strings(db)
    check_collections(db)
    check_replies(db)
    check_errors(db)
    check_pipeline(db)
    check_transaction(db)
    check_reset(url)
    check_large(db)
    check_pool_limits(url)
    print("  ", label, ": ok")


def test_redis() raises:
    run_suite("redis", redis_url())
    check_databases()
    check_auth()


def test_valkey() raises:
    run_suite("valkey", valkey_url())


def main() raises:
    test_redis()
    test_valkey()
    print("test_redis: 2 passed")

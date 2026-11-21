"""Fuzz harness: Redis and Valkey replies (RESP2).

Feeds the input to `read_reply` through a replayed `DbStream`, the way a
connection reads a server, one reply after another until the bytes run
out. Every reply is then walked: nested arrays, strings, integers, error
codes. A hostile server must get a `DbError`, never a crash.

Run:
    pixi run fuzz resp
"""

from mozz import fuzz, FuzzConfig
from dodo.db._stream import DbStream
from dodo.db.redis.connection import read_reply
from dodo.db.redis.protocol import RedisReply


def target_replies(data: List[UInt8]) raises:
    var stream = DbStream(replay=Span(data), database="redis")
    while stream.available() > 0:
        _walk(read_reply(stream))


def _walk(reply: RedisReply) raises:
    _ = String(reply)
    _ = reply.kind_name()
    _ = reply.error_code()
    if reply.kind() == RedisReply.ARRAY:
        for item in reply.items():
            _walk(item)
        return
    try:
        _ = reply.string()
    except:
        pass
    try:
        _ = reply.int()
    except:
        pass


def _seed(text: String) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


def main() raises:
    print("[mozz] fuzzing RESP replies\n")
    var seeds = List[List[UInt8]]()
    seeds.append(_seed("+OK\r\n"))
    seeds.append(_seed("-WRONGTYPE Operation against a key\r\n"))
    seeds.append(_seed(":42\r\n:-7\r\n"))
    seeds.append(_seed("$5\r\nhello\r\n$0\r\n\r\n$-1\r\n"))
    seeds.append(_seed("*3\r\n$1\r\na\r\n*2\r\n:1\r\n$-1\r\n-ERR x\r\n"))
    seeds.append(_seed("*-1\r\n*0\r\n"))
    fuzz(
        target_replies,
        FuzzConfig(
            max_runs=200_000,
            seed=0,
            verbose=True,
            crash_dir=".mozz_crashes/resp",
            max_input_len=1024,
        ),
        seeds,
    )

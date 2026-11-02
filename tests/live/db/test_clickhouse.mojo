"""Live tests: dodo.db.clickhouse against ClickHouse 25.8 in Docker.

    docker compose -f tests/live/db/compose.yaml up -d --wait
    pixi run tests-db
"""

from std.collections import Optional
from std.os import getenv
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, Param, PoolOptions
from dodo.db.clickhouse import ClickHouse


def clickhouse_url() -> String:
    return getenv(
        "DODO_TEST_CLICKHOUSE",
        "clickhouse://dodo:dodo-test@127.0.0.1:48123/dodo",
    )


@fieldwise_init
struct Event(Movable):
    var id: UInt64
    var name: String
    var score: Float64
    var active: Bool
    var note: Optional[String]


def setup(ch: ClickHouse) raises:
    _ = ch.execute_script(
        "drop table if exists events; create table events (id UInt64, name"
        " String, score Float64, active Bool, note Nullable(String), day Date,"
        " at DateTime64(3), tags Array(String)) engine = MergeTree order by id"
    )


def check_round_trip(ch: ClickHouse) raises:
    setup(ch)
    var evil = String(
        "bob'); drop table events;-- \\ tab\there\nnewline héllo 🦤"
    )
    var written = ch.execute(
        (
            "insert into events values ({p1:UInt64}, {p2:String}, {p3:Float64},"
            " {p4:Bool}, {p5:Nullable(String)}, {p6:Date}, {p7:DateTime64(3)},"
            " {p8:Array(String)})"
        ),
        1,
        evil,
        -1.25,
        True,
        Param.null(),
        "2026-11-02",
        "2026-11-02 10:30:00.123",
        "['a','b c']",
    )
    assert_equal(written, 1)
    _ = ch.execute(
        "insert into events (id, name, score, active, note, day, at, tags)"
        " values (2, 'ada', 9.5, false, 'n', '2000-01-01', '2000-01-01"
        " 00:00:00', [])"
    )
    var rows = ch.query(
        "select * from events where id >= {p1:UInt64} order by id", 1
    )
    assert_equal(len(rows), 2)
    assert_equal(rows[0].string("name"), evil)
    assert_true(rows[0].bool("active"))
    assert_true(rows[0].is_null("note"))
    assert_equal(rows[0].string("day"), "2026-11-02")
    assert_equal(rows[0].string("at"), "2026-11-02 10:30:00.123")
    assert_equal(rows[0].string("tags"), "['a', 'b c']")
    assert_equal(rows[1].string("tags"), "[]")
    assert_equal(rows.columns[6].type_name, "DateTime64(3)")
    var events = rows.to[Event]()
    assert_equal(events[1].name, "ada")
    assert_equal(events[1].note.value(), "n")
    assert_false(events[1].active)
    var summary = ch.query(
        "select count() as n, avg(score) as mean from events"
    )
    assert_equal(summary[0].int("n"), 2)
    assert_equal(summary[0].float("mean"), 4.125)


def check_types(ch: ClickHouse) raises:
    var row = ch.query(
        "select toUInt64(18446744073709551615) as big, toInt8(-5) as small,"
        " toFloat32(1.5) as f32, toDate32('1900-01-02') as old,"
        " toDateTime('2026-11-02 10:30:00', 'UTC') as dt,"
        " toUUID('61f0c404-5cb3-11e7-907b-a6006ad3dba0') as id,"
        " toIPv4('10.0.0.1') as ip, toDecimal64(-12.345, 3) as money, CAST('b',"
        " 'Enum8(\\'a\\' = 1, \\'b\\' = 2)') as kind, (1, 'x') as pair,"
        " map('k', 1) as m, toFixedString('ab', 3) as fixed, [[1, 2], [3]] as"
        " nested, toLowCardinality('lc') as lc, NULL as nothing"
    )[0]
    assert_equal(row.string("big"), "18446744073709551615")
    assert_equal(row.int("small"), -5)
    assert_equal(row.float("f32"), 1.5)
    assert_equal(row.string("old"), "1900-01-02")
    assert_equal(row.string("dt"), "2026-11-02 10:30:00")
    assert_equal(row.string("id"), "61f0c404-5cb3-11e7-907b-a6006ad3dba0")
    assert_equal(row.string("ip"), "10.0.0.1")
    assert_equal(row.string("money"), "-12.345")
    assert_equal(row.string("kind"), "b")
    assert_equal(row.string("pair"), "(1, 'x')")
    assert_equal(row.string("m"), "{'k': 1}")
    assert_equal(row.bytes("fixed").__len__(), 3)
    assert_equal(row.string("nested"), "[[1, 2], [3]]")
    assert_equal(row.string("lc"), "lc")
    assert_true(row.is_null("nothing"))


def check_errors(ch: ClickHouse) raises:
    var failed = False
    try:
        _ = ch.query("selec 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
        assert_equal(e.code, "62")
    assert_true(failed, "bad SQL should fail")
    failed = False
    try:
        _ = ch.query("select * from no_such_table")
    except e:
        failed = True
        assert_equal(e.code, "60")
    assert_true(failed, "missing table should fail")
    failed = False
    try:
        _ = ch.query("select 1; drop table events")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
    assert_true(failed, "stacked statements should be refused")
    failed = False
    try:
        _ = ch.query("select {p1:UInt8}", 1, 2)
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "an unused parameter should fail")
    failed = False
    try:
        _ = ch.query("select {p1:UInt8} as x", "not a number")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
    assert_true(failed, "a value that doesn't parse as the type should fail")
    # Failing halfway through a result is still an error, not a short body.
    failed = False
    try:
        _ = ch.query(
            "select throwIf(number = 50000, 'boom') from numbers(100000)"
        )
    except e:
        failed = True
        assert_equal(e.code, "395")
    assert_true(failed, "an error mid-result should fail")
    assert_equal(ch.query("select 1 + {p1:UInt8} as two", 1)[0].int("two"), 2)


def check_large(ch: ClickHouse) raises:
    var big = String()
    for _ in range(10_000):
        big += "0123456789"
    assert_equal(
        ch.query("select {p1:String} as big", big)[0]
        .string("big")
        .byte_length(),
        100_000,
    )
    var many = ch.query("select number as n from numbers(200000)")
    assert_equal(len(many), 200_000)
    assert_equal(many[199_999].int("n"), 199_999)


def pool_of(size: Int) -> PoolOptions:
    var options = PoolOptions()
    options.max_size = size
    options.acquire_timeout_ms = 300
    return options^


def check_pool_limits(url: String) raises:
    var ch = ClickHouse(url, pool_of(1))
    var held = ch.connection()
    var failed = False
    try:
        _ = ch.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.POOL_TIMEOUT)
    assert_true(failed, "second checkout should time out")
    _ = held^
    for _ in range(20):
        assert_equal(ch.query("select 1 as one")[0].int("one"), 1)
    assert_equal(ch.open_count(), 1)


def check_auth_and_settings() raises:
    var failed = False
    try:
        _ = ClickHouse("clickhouse://dodo:wrong@127.0.0.1:48123/dodo").query(
            "select 1"
        )
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
        assert_equal(e.code, "516")
    assert_true(failed, "wrong password should fail")
    failed = False
    try:
        _ = ClickHouse(
            "clickhouse://dodo:x@127.0.0.1:1/dodo?connect_timeout_ms=500"
        ).query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.CONNECT)
    assert_true(failed, "closed port should fail")
    var limited = ClickHouse(
        "clickhouse://dodo:dodo-test@127.0.0.1:48123/dodo?max_result_rows=10&result_overflow_mode=throw"
    )
    failed = False
    try:
        _ = limited.query("select number from numbers(100)")
    except e:
        failed = True
        assert_equal(e.code, "396")
    assert_true(failed, "URL settings should reach the server")


def test_clickhouse() raises:
    var ch = ClickHouse(clickhouse_url())
    check_round_trip(ch)
    check_types(ch)
    check_errors(ch)
    check_large(ch)
    check_pool_limits(clickhouse_url())
    check_auth_and_settings()
    print("   clickhouse : ok")


def main() raises:
    test_clickhouse()
    print("test_clickhouse: 1 passed")

"""Tests for the database wire codecs, with no server: framing, auth
hashes against known values, and refusing malformed input."""

from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, Param, Rows
from dodo.db._bytes import ByteReader
from dodo.db.clickhouse import protocol as ch
from dodo.db.mongo import Bson, BsonArray
from dodo.db.mongo import protocol as mongo
from dodo.db.mysql import protocol as mysql
from dodo.db.postgres import protocol as pg
from dodo.db.redis import protocol as redis


def hex(data: List[UInt8]) -> String:
    comptime digits = "0123456789abcdef"
    var out = String()
    for b in data:
        out += digits[byte=Int(b >> 4)]
        out += digits[byte=Int(b & 15)]
    return out^


def bytes_of(text: String) -> List[UInt8]:
    return List[UInt8](text.as_bytes())


# ── PostgreSQL ──────────────────────────────────────────────────────────────


def test_pg_md5_password() raises:
    var salt: List[UInt8] = [1, 2, 3, 4]
    var message = pg.md5_password("dodo", "secret", Span(salt))
    # 'p', Int32 length, then the hash and a NUL.
    assert_equal(Int(message[0]), ord("p"))
    var text = String(from_utf8_lossy=Span(message)[5 : len(message) - 1])
    assert_equal(text, "md57de1a2fef389d3b9477c0dbe01dcc3ea")


def test_pg_framing() raises:
    var header: List[UInt8] = [UInt8(ord("Z")), 0, 0, 0, 5]
    assert_equal(pg.frame_length(Span(header)), 1)
    for bad in [3, 0x7FFFFFFF]:
        var h: List[UInt8] = [
            UInt8(ord("D")),
            UInt8((bad >> 24) & 255),
            UInt8((bad >> 16) & 255),
            UInt8((bad >> 8) & 255),
            UInt8(bad & 255),
        ]
        var failed = False
        try:
            _ = pg.frame_length(Span(h))
        except e:
            failed = True
            assert_equal(e.kind, DbError.PROTOCOL)
        assert_true(failed, String("length ", bad, " should be refused"))
    assert_equal(pg.parse_command_tag(Span(bytes_of("INSERT 0 2\0"))), 2)
    assert_equal(pg.parse_command_tag(Span(bytes_of("UPDATE 15\0"))), 15)
    assert_equal(pg.parse_command_tag(Span(bytes_of("CREATE TABLE\0"))), 0)


def test_pg_error_response() raises:
    var body = bytes_of(
        "SERROR\0C23505\0Mduplicate key\0Dkey (id)=(1) exists\0\0"
    )
    var error = pg.parse_error(Span(body))
    assert_equal(error.kind, DbError.SERVER)
    assert_equal(error.code, "23505")
    assert_true(error.message.find("duplicate key") >= 0)
    assert_true(error.is_duplicate())
    var broken = pg.parse_error(Span(bytes_of("SERROR\0C2350")))
    assert_equal(broken.kind, DbError.PROTOCOL)


def test_pg_refuses_nul_in_sql() raises:
    var failed = False
    try:
        _ = pg.simple_query("select 1\0; drop table x")
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "a NUL in SQL text should be refused")


# ── MySQL ───────────────────────────────────────────────────────────────────


def test_mysql_scrambles() raises:
    var nonce = List[UInt8]()
    for i in range(1, 21):
        nonce.append(UInt8(i))
    assert_equal(
        hex(mysql.scramble("mysql_native_password", "secret", Span(nonce))),
        "b32bb3a583e1340c0a1108d58b1be49781ad8c2f",
    )
    assert_equal(
        hex(mysql.scramble("caching_sha2_password", "secret", Span(nonce))),
        "746ebe205d56a0707acb3e796e834e0dd7b1d61743b26bd5202c7a623230c7c9",
    )
    assert_equal(
        len(mysql.scramble("caching_sha2_password", "", Span(nonce))), 0
    )
    var failed = False
    try:
        _ = mysql.scramble("mysql_clear_password", "secret", Span(nonce))
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
    assert_true(failed, "an unsupported plugin should fail")


def test_mysql_lenenc() raises:
    for value in [0, 250, 251, 0xFFFF, 0x10000, 0xFFFFFF, 0x1000000, 1 << 40]:
        var out = List[UInt8]()
        mysql.put_lenenc(out, value)
        var r = ByteReader(Span(out), "mysql")
        assert_equal(mysql.read_lenenc(r), value)
        assert_true(r.done())


def test_mysql_frames_split_at_16mb() raises:
    var payload = List[UInt8](length=0xFFFFFF, fill=7)
    var framed = mysql.frame(Span(payload), 0)
    # A full packet, then an empty one to say it ended.
    assert_equal(len(framed[0]), 4 + 0xFFFFFF + 4)
    assert_equal(framed[1], 2)
    var small = mysql.frame(Span(bytes_of("hi")), 3)
    assert_equal(len(small[0]), 6)
    assert_equal(Int(small[0][3]), 3)


def test_mysql_err_and_ok() raises:
    var err = List[UInt8]()
    err.append(0xFF)
    err.append(0x26)  # 1062, little endian
    err.append(0x04)
    err.extend("#23000Duplicate entry".as_bytes())
    var error = mysql.parse_error(Span(err))
    assert_equal(error.code, "1062")
    assert_equal(error.message, "Duplicate entry")
    assert_true(error.is_duplicate())
    var denied: List[UInt8] = [0xFF, 0x15, 0x04]
    assert_equal(mysql.parse_error(Span(denied)).kind, DbError.AUTH)
    var ok: List[UInt8] = [0x00, 0x03, 0xFC, 0x00, 0x01, 0x02, 0x00, 0x00, 0x00]
    var parsed = mysql.parse_ok(Span(ok))
    assert_equal(parsed.affected, 3)
    assert_equal(parsed.last_insert_id, 256)


# ── Redis ───────────────────────────────────────────────────────────────────


def test_redis_encode() raises:
    var out = List[UInt8]()
    var args: List[Param] = ["SET", "k\r\n", 42, True]
    redis.encode(out, args)
    assert_equal(
        String(from_utf8_lossy=Span(out)),
        "*4\r\n$3\r\nSET\r\n$3\r\nk\r\n\r\n$2\r\n42\r\n$1\r\n1\r\n",
    )
    var failed = False
    try:
        var with_null: List[Param] = ["SET", Param.null()]
        redis.encode(out, with_null)
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "NULL has no Redis form")
    var lower: List[Param] = ["subscribe", "x"]
    assert_true(redis.is_refused(redis.command_name(lower)))
    var get: List[Param] = ["get", "x"]
    assert_false(redis.is_refused(redis.command_name(get)))


def test_redis_lengths() raises:
    assert_equal(redis.parse_length(Span(bytes_of("$-1"))), -1)
    assert_equal(redis.parse_length(Span(bytes_of(":1234"))), 1234)
    for bad in ["$", "$1x", "*99999999999999999999", ":-"]:
        var failed = False
        try:
            _ = redis.parse_length(Span(bytes_of(bad)))
        except e:
            failed = True
            assert_equal(e.kind, DbError.PROTOCOL)
        assert_true(failed, bad + " should be refused")


# ── MongoDB ─────────────────────────────────────────────────────────────────


def test_mongo_op_msg() raises:
    var message = mongo.op_msg(7, Bson().add("ping", 1))
    var header = mongo.parse_header(Span(message)[0:16])
    assert_equal(header.length, len(message))
    assert_equal(header.opcode, 2013)
    var body = mongo.parse_body(Span(message)[16:])
    assert_equal(body.int("ping"), 1)

    # With the checksum flag, the last four bytes are not part of the body.
    var with_sum = List[UInt8](Span(message)[16:])
    with_sum[0] = 1
    with_sum.extend([0, 0, 0, 0])
    assert_equal(mongo.parse_body(Span(with_sum)).int("ping"), 1)

    var bad_op = message.copy()
    bad_op[12] = 1
    var failed = False
    try:
        _ = mongo.parse_header(Span(bad_op)[0:16])
    except e:
        failed = True
        assert_equal(e.kind, DbError.PROTOCOL)
    assert_true(failed, "OP_REPLY should be refused")


def test_mongo_replies() raises:
    mongo.check_ok(Bson().add("ok", 1.0))
    var failed = False
    try:
        mongo.check_ok(
            Bson()
            .add("ok", 0.0)
            .add("code", 18)
            .add("errmsg", "bad")
            .add("codeName", "AuthenticationFailed")
        )
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
        assert_equal(e.code, "18")
    assert_true(failed, "code 18 is an auth failure")
    failed = False
    try:
        var dup = (
            Bson().add("code", 11000).add("errmsg", "E11000 duplicate key")
        )
        var errors = BsonArray().append(dup)
        mongo.check_write(
            Bson().add("n", 0).add("writeErrors", errors).add("ok", 1.0)
        )
    except e:
        failed = True
        assert_true(e.is_duplicate())
    assert_true(failed, "a write error should raise")


# ── ClickHouse ──────────────────────────────────────────────────────────────


def test_clickhouse_params() raises:
    assert_equal(
        ch.percent_encode("a b&c=d/é".as_bytes()), "a%20b%26c%3Dd%2F%C3%A9"
    )
    var escaped = ch.escape_value("tab\there\\ new\nline")
    assert_equal(
        String(from_utf8_lossy=Span(escaped)), "tab\\there\\\\ new\\nline"
    )
    assert_equal(
        String(from_utf8_lossy=Span(ch.escape_value(Param.null()))), "\\N"
    )
    var params: List[Param] = [1, "x"]
    var settings = List[Tuple[String, String]]()
    var query = ch.query_string(
        "db", settings, params, "select {p1:UInt8}, {p2:String}"
    )
    assert_true(query.find("&param_p1=1") >= 0)
    assert_true(query.find("&param_p2=x") >= 0)
    var failed = False
    try:
        _ = ch.query_string("db", settings, params, "select {p1:UInt8}")
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "an unused parameter should be refused")
    assert_equal(
        ch.written_rows('{"read_rows":"0","written_rows":"12","x":"1"}'), 12
    )


def test_clickhouse_split_script() raises:
    var parts = ch.split_script(
        "create table t (s String default ';'); -- a; comment\n insert into t"
        " values ('a;b');; /* x; */ select 1"
    )
    assert_equal(len(parts), 3)
    assert_equal(parts[0], "create table t (s String default ';')")
    assert_equal(parts[2], "/* x; */ select 1")


def put_varuint(mut out: List[UInt8], value: Int):
    var v = value
    while v >= 0x80:
        out.append(UInt8((v & 0x7F) | 0x80))
        v >>= 7
    out.append(UInt8(v))


def put_string(mut out: List[UInt8], text: String):
    put_varuint(out, text.byte_length())
    out.extend(text.as_bytes())


def put_le(mut out: List[UInt8], value: Int, n: Int):
    for i in range(n):
        out.append(UInt8((value >> (8 * i)) & 0xFF))


def test_clickhouse_row_binary() raises:
    var body = List[UInt8]()
    put_varuint(body, 6)
    for name in ["id", "note", "tags", "day", "at", "price"]:
        put_string(body, name)
    for type_name in [
        "UInt64",
        "Nullable(String)",
        "Array(Int32)",
        "Date",
        "DateTime64(3, 'UTC')",
        "Decimal(9, 2)",
    ]:
        put_string(body, type_name)
    # Row 1
    put_le(body, -1, 8)  # UInt64 max
    body.append(0)
    put_string(body, "hi")
    put_varuint(body, 2)
    put_le(body, -1, 4)
    put_le(body, 7, 4)
    put_le(body, 20757, 2)  # 2026-10-31
    put_le(body, 1_000_123, 8)  # 1970-01-01 00:16:40.123
    put_le(body, -1234, 4)  # -12.34
    # Row 2
    put_le(body, 5, 8)
    body.append(1)
    put_varuint(body, 0)
    put_le(body, 0, 2)
    put_le(body, -1, 8)
    put_le(body, 5, 4)
    var rows = ch.decode(Span(body))
    assert_equal(len(rows), 2)
    assert_equal(rows[0].string("id"), "18446744073709551615")
    assert_equal(rows[0].string("note"), "hi")
    assert_equal(rows[0].string("tags"), "[-1, 7]")
    assert_equal(rows[0].string("day"), "2026-10-31")
    assert_equal(rows[0].string("at"), "1970-01-01 00:16:40.123")
    assert_equal(rows[0].string("price"), "-12.34")
    assert_equal(rows[1].int("id"), 5)
    assert_true(rows[1].is_null("note"))
    assert_equal(rows[1].string("tags"), "[]")
    assert_equal(rows[1].string("day"), "1970-01-01")
    assert_equal(rows[1].string("at"), "1969-12-31 23:59:59.999")
    assert_equal(rows[1].string("price"), "0.05")

    var truncated = List[UInt8](Span(body)[0 : len(body) - 3])
    var failed = False
    try:
        _ = ch.decode(Span(truncated))
    except e:
        failed = True
        assert_equal(e.kind, DbError.PROTOCOL)
    assert_true(failed, "a truncated body should be refused")


def main() raises:
    test_pg_md5_password()
    test_pg_framing()
    test_pg_error_response()
    test_pg_refuses_nul_in_sql()
    test_mysql_scrambles()
    test_mysql_lenenc()
    test_mysql_frames_split_at_16mb()
    test_mysql_err_and_ok()
    test_redis_encode()
    test_redis_lengths()
    test_mongo_op_msg()
    test_mongo_replies()
    test_clickhouse_params()
    test_clickhouse_split_script()
    test_clickhouse_row_binary()
    print("test_wire_codecs: 15 passed")

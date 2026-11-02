"""Tests for the parts of dodo.db every driver shares: URLs, errors,
parameters, rows and the bounds-checked byte reader."""

from std.collections import Optional
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, Param, Rows
from dodo.db._bytes import ByteReader
from dodo.db._url import DbUrl


@fieldwise_init
struct Item(Movable):
    var id: Int
    var name: String
    var price: Float64
    var on_sale: Bool
    var note: Optional[String]


def test_url_parts() raises:
    var url = DbUrl.parse(
        "postgres://ada:p%40ss%3Aw%2Frd@db.example.com:6543/app?sslmode=require&x=a%26b",
        5432,
    )
    assert_equal(url.scheme, "postgres")
    assert_equal(url.user, "ada")
    assert_equal(url.password, "p@ss:w/rd")
    assert_equal(url.host, "db.example.com")
    assert_equal(url.port, 6543)
    assert_equal(url.database, "app")
    assert_equal(url.option("sslmode", ""), "require")
    assert_equal(url.option("x", ""), "a&b")
    assert_equal(url.option("missing", "dflt"), "dflt")
    # The password never shows up in logs.
    assert_true(String(url).find("p@ss") < 0)

    var bare = DbUrl.parse("redis://localhost", 6379)
    assert_equal(bare.port, 6379)
    assert_equal(bare.user, "")
    assert_equal(bare.database, "")
    var v6 = DbUrl.parse("mysql://u@[::1]:3307/d", 3306)
    assert_equal(v6.host, "::1")
    assert_equal(v6.port, 3307)


def test_url_errors() raises:
    for bad in [
        "no-scheme",
        "postgres://h:0/d",
        "postgres://h:70000/d",
        "postgres://h:port/d",
    ]:
        var failed = False
        try:
            _ = DbUrl.parse(bad, 5432)
        except e:
            failed = True
            assert_equal(e.kind, DbError.USAGE)
            # A rejected URL's password must not leak into the message.
            assert_true(String(e).find("secret") < 0)
        assert_true(failed, bad + " should be refused")
    var failed = False
    try:
        _ = DbUrl.parse(
            "postgres://u:secret@h/d?timeout_ms=abc", 5432
        ).int_option("timeout_ms", 1)
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "a non-numeric option should fail")


def test_errors() raises:
    assert_true(DbError.server("postgres", "23505", "dup").is_duplicate())
    assert_false(DbError.server("postgres", "23503", "fk").is_duplicate())
    assert_true(DbError.server("mysql", "1062", "dup").is_duplicate())
    assert_true(DbError.server("sqlite", "2067", "dup").is_duplicate())
    assert_true(DbError.server("sqlite", "1555", "dup").is_duplicate())
    assert_true(DbError.server("mongo", "11000", "dup").is_duplicate())
    assert_false(DbError.io("postgres", "23505").is_duplicate())
    assert_true(DbError.io("x", "m").breaks_connection())
    assert_true(DbError.protocol("x", "m").breaks_connection())
    assert_false(DbError.server("x", "1", "m").breaks_connection())
    assert_false(DbError.decode("m").breaks_connection())
    assert_equal(
        String(DbError.server("postgres", "42P01", "relation does not exist")),
        "postgres server error 42P01: relation does not exist",
    )


def test_params() raises:
    var values: List[Param] = [
        42,
        2.5,
        True,
        "x",
        Param.null(),
        Optional[Int](None),
        Optional[String]("s"),
    ]
    assert_equal(values[0].as_text(), "42")
    assert_equal(values[1].as_text(), "2.5")
    assert_equal(values[2].as_text(), "true")
    assert_equal(values[3].as_text(), "x")
    assert_true(values[4].is_null())
    assert_true(values[5].is_null())
    assert_equal(values[6].as_text(), "s")
    var raw = Param.bytes("ab".as_bytes())
    assert_equal(raw.kind, Param.BYTES)
    assert_equal(String(raw), "<2 bytes>")


def sample() raises -> Rows:
    var rows = Rows()
    rows.add_column("id", "int8")
    rows.add_column("name", "text")
    rows.add_column("price", "float8")
    rows.add_column("on_sale", "bool")
    rows.add_column("note", "text")
    rows.push_int(1)
    rows.push_text("tea".as_bytes())
    rows.push_float(2.5)
    rows.push_text("t".as_bytes())
    rows.push_null()
    rows.end_row()
    rows.push_text("2".as_bytes())
    rows.push_text("cake".as_bytes())
    rows.push_text("4".as_bytes())
    rows.push_int(0)
    rows.push_text("fresh".as_bytes())
    rows.end_row()
    return rows^


def test_rows_typed_reads() raises:
    var rows = sample()
    assert_equal(len(rows), 2)
    assert_equal(rows[0].int("id"), 1)
    assert_equal(rows[1].int("id"), 2)
    assert_equal(rows[1].float("price"), 4.0)
    assert_true(rows[0].bool("on_sale"))
    assert_false(rows[1].bool("on_sale"))
    assert_true(rows[0].is_null("note"))
    var items = rows.to[Item]()
    assert_equal(items[1].name, "cake")
    assert_false(Bool(items[0].note))
    assert_equal(items[1].note.value(), "fresh")
    assert_equal(rows.first[Item]().value().name, "tea")


def expect_failure(kind: Int, why: String, rows: Rows, column: String) raises:
    var failed = False
    try:
        _ = rows[0].int(column)
    except e:
        failed = True
        assert_equal(e.kind, kind, why)
    assert_true(failed, why)


def test_rows_errors() raises:
    var rows = sample()
    expect_failure(DbError.DECODE, "text is not an int", rows, "name")
    expect_failure(DbError.DECODE, "null is not an int", rows, "note")
    expect_failure(DbError.USAGE, "no such column", rows, "nope")
    var empty = Rows()
    empty.add_column("id", "")
    var failed = False
    try:
        _ = empty.one[Item]()
    except e:
        failed = True
    assert_true(failed, "one() with no rows should fail")
    assert_false(Bool(empty.first[Item]()))

    var huge = Rows()
    huge.add_column("n", "numeric")
    huge.push_text("99999999999999999999".as_bytes())
    huge.end_row()
    expect_failure(DbError.DECODE, "past Int range", huge, "n")

    var short = Rows()
    short.add_column("a", "")
    short.add_column("b", "")
    short.push_int(1)
    failed = False
    try:
        short.end_row()
    except e:
        failed = True
    assert_true(failed, "a row missing a cell should be refused")


def test_byte_reader_bounds() raises:
    var data: List[UInt8] = [1, 2, 3, 0x41, 0]
    var r = ByteReader(Span(data), "test")
    assert_equal(r.be(2), 0x0102)
    assert_equal(r.u8(), 3)
    assert_equal(r.cstr(), "A")
    assert_true(r.done())
    var failed = False
    try:
        _ = r.u8()
    except e:
        failed = True
        assert_equal(e.kind, DbError.PROTOCOL)
    assert_true(failed, "reading past the end should fail")
    var unterminated: List[UInt8] = [0x41, 0x42]
    var r2 = ByteReader(Span(unterminated), "test")
    failed = False
    try:
        _ = r2.cstr()
    except e:
        failed = True
    assert_true(failed, "a string with no NUL should fail")
    var r3 = ByteReader(Span(data), "test")
    failed = False
    try:
        _ = r3.bytes(6)
    except e:
        failed = True
    assert_true(failed, "a slice past the end should fail")


def main() raises:
    test_url_parts()
    test_url_errors()
    test_errors()
    test_params()
    test_rows_typed_reads()
    test_rows_errors()
    test_byte_reader_bounds()
    print("test_db_core: 7 passed")

"""Tests for the BSON codec in dodo.db.mongo: building, reading, and
refusing malformed documents."""

from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError
from dodo.db.mongo import Bson, BsonArray, BsonValue


def test_round_trip_every_type() raises:
    var blob = List[UInt8]()
    for i in range(256):
        blob.append(UInt8(i))
    var doc = (
        Bson()
        .add("i32", -7)
        .add("i64", 1 << 40)
        .add("long", BsonValue.int64(3))
        .add("f", 2.5)
        .add("s", "héllo 🦤")
        .add("t", True)
        .add("n", BsonValue.null())
        .add("b", BsonValue.binary(blob))
        .add("d", BsonValue.date_ms(-1000))
        .add("o", BsonValue.object_id("0123456789ABCDEF01234567"))
        .add("a", BsonArray().append(1).append("x"))
        .add("doc", Bson().add("inner", 1))
    )
    var parsed = Bson.parse(Span(doc.encoded()))
    assert_equal(len(parsed), 12)
    assert_equal(parsed.int("i32"), -7)
    assert_equal(parsed.get("i32").type_name(), "int")
    assert_equal(parsed.int("i64"), 1 << 40)
    assert_equal(parsed.get("i64").type_name(), "long")
    assert_equal(parsed.get("long").type_name(), "long")
    assert_equal(parsed.float("f"), 2.5)
    assert_equal(parsed.float("i32"), -7.0)
    assert_equal(parsed.string("s"), "héllo 🦤")
    assert_true(parsed.bool("t"))
    assert_true(parsed.is_null("n"))
    assert_true(parsed.is_null("missing"))
    assert_false(parsed.has("missing"))
    assert_equal(len(parsed.get("b").as_bytes()), 256)
    assert_equal(parsed.int("d"), -1000)
    assert_equal(parsed.get("o").object_id_hex(), "0123456789abcdef01234567")
    assert_equal(parsed.array("a")[1].as_string(), "x")
    assert_equal(parsed.doc("doc").int("inner"), 1)
    var keys = parsed.keys()
    assert_equal(keys[0], "i32")
    assert_equal(keys[11], "doc")


def test_text_form() raises:
    var doc = (
        Bson()
        .add("name", 'say "hi"\n')
        .add("n", 1)
        .add("tags", BsonArray().append("a").append(BsonValue.null()))
        .add("o", BsonValue.object_id("0123456789abcdef01234567"))
    )
    assert_equal(
        String(doc),
        (
            '{"name": "say \\"hi\\"\\n", "n": 1, "tags": ["a", null],'
            ' "o": {"$oid": "0123456789abcdef01234567"}}'
        ),
    )


def test_wrong_type_reads_fail() raises:
    var doc = Bson().add("s", "x").add("f", 1.5)
    for key in ["s", "missing"]:
        var failed = False
        try:
            _ = doc.int(key)
        except e:
            failed = True
            assert_equal(e.kind, DbError.DECODE)
        assert_true(failed, "int(" + key + ") should fail")
    var failed = False
    try:
        _ = doc.int("f")
    except e:
        failed = True
    assert_true(failed, "1.5 is not an integer")


def test_generated_ids_differ() raises:
    var a = BsonValue.new_object_id().object_id_hex()
    var b = BsonValue.new_object_id().object_id_hex()
    assert_equal(a.byte_length(), 24)
    assert_true(a != b)
    var with_id = Bson().add("x", 1).with_first("_id", 5)
    assert_equal(with_id.keys()[0], "_id")
    for bad in ["123", "zz23456789abcdef01234567"]:
        var failed = False
        try:
            _ = BsonValue.object_id(bad)
        except e:
            failed = True
            assert_equal(e.kind, DbError.USAGE)
        assert_true(failed, bad + " is not an ObjectId")


def test_nul_in_key_refused() raises:
    var failed = False
    try:
        _ = Bson().add("a\0b", 1)
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "a NUL in a key should be refused")


def expect_malformed(data: List[UInt8], why: String) raises:
    var failed = False
    try:
        _ = Bson.parse(Span(data))
    except e:
        failed = True
        assert_equal(e.kind, DbError.PROTOCOL, why)
    assert_true(failed, why)


def le32(n: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for i in range(4):
        out.append(UInt8((n >> (8 * i)) & 0xFF))
    return out^


def test_malformed_documents_refused() raises:
    var good = Bson().add("s", "abc").add("d", Bson().add("x", 1)).encoded()
    _ = Bson.parse(Span(good))

    expect_malformed(List[UInt8](), "empty")
    expect_malformed(List[UInt8](good[0 : len(good) - 1]), "truncated")
    var wrong_length = good.copy()
    wrong_length[0] = UInt8(Int(wrong_length[0]) + 1)
    expect_malformed(wrong_length, "length header says more than there is")
    var no_trailer = good.copy()
    no_trailer[len(no_trailer) - 1] = 1
    expect_malformed(no_trailer, "missing trailing NUL")

    # {"s": string whose length runs past the document}
    var long_string = List[UInt8]()
    long_string.extend(Span(le32(16)))
    long_string.append(0x02)
    long_string.append(UInt8(ord("s")))
    long_string.append(0)
    long_string.extend(Span(le32(100)))
    long_string.extend("abc".as_bytes())
    long_string.append(0)
    long_string.append(0)
    expect_malformed(long_string, "string length past the end")

    var unknown = List[UInt8]()
    unknown.extend(Span(le32(8)))
    unknown.append(0x42)
    unknown.append(UInt8(ord("k")))
    unknown.append(0)
    unknown.append(0)
    expect_malformed(unknown, "unknown type byte")

    var bad_bool = List[UInt8]()
    bad_bool.extend(Span(le32(9)))
    bad_bool.append(0x08)
    bad_bool.append(UInt8(ord("k")))
    bad_bool.append(0)
    bad_bool.append(7)
    bad_bool.append(0)
    expect_malformed(bad_bool, "boolean other than 0 or 1")


def test_deep_nesting_refused() raises:
    var doc = Bson().add("x", 1)
    for _ in range(120):
        doc = Bson().add("d", doc)
    expect_malformed(doc.encoded(), "nested past the limit")


def main() raises:
    test_round_trip_every_type()
    test_text_form()
    test_wrong_type_reads_fail()
    test_generated_ids_differ()
    test_nul_in_key_refused()
    test_malformed_documents_refused()
    test_deep_nesting_refused()
    print("test_bson: 7 passed")

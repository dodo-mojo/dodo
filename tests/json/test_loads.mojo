"""``loads`` parses through simdjson and returns the usual ``Value``s."""

from std.testing import assert_equal, assert_false, assert_raises, assert_true

from dodo.json import dumps, loads
from dodo.json.ffi.simdjson import simdjson_available


def test_simdjson_library_is_loaded() raises:
    assert_true(
        simdjson_available(),
        "libdodo_simdjson.so is not installed; run the pixi activation",
    )


def test_scalars() raises:
    assert_true(loads("null").is_null())
    assert_true(loads("true").bool_value())
    assert_false(loads("false").bool_value())
    assert_equal(loads("42").int_value(), 42)
    assert_equal(loads("-7").int_value(), -7)
    assert_equal(loads("2.5").float_value(), 2.5)
    assert_equal(loads("1e3").float_value(), 1000.0)
    assert_equal(loads('"hi"').string_value(), "hi")


def test_wide_integers() raises:
    assert_equal(loads("9223372036854775807").int_value(), Int64.MAX)
    assert_equal(loads("-9223372036854775808").int_value(), Int64.MIN)
    assert_equal(loads("576460752303423488").int_value(), 576460752303423488)
    var wide = loads("18446744073709551615")
    assert_true(wide.is_uint())
    assert_equal(wide.uint_value(), UInt64.MAX)


def test_integer_wider_than_64_bits_becomes_a_float() raises:
    var value = loads("18446744073709551616")
    assert_true(value.is_float())
    assert_equal(value.float_value(), 18446744073709551616.0)


def test_string_escapes_and_unicode() raises:
    assert_equal(loads('"a\\nb\\t\\"c\\\\"').string_value(), 'a\nb\t"c\\')
    assert_equal(loads('"\\u00e9\\u20ac"').string_value(), "é€")
    assert_equal(loads('"\\ud83d\\ude00"').string_value(), "\U0001F600")
    assert_equal(loads('"café"').string_value(), "café")


def test_containers() raises:
    var value = loads('{"a":[1,2,3],"b":{"c":"d"},"e":[],"f":{}}')
    assert_true(value.is_object())
    assert_equal(len(value["a"]), 3)
    assert_equal(value["a"][2].int_value(), 3)
    assert_equal(value["b"]["c"].string_value(), "d")
    assert_equal(len(value["e"]), 0)
    assert_equal(len(value["f"]), 0)


def test_duplicate_keys_and_empty_key() raises:
    assert_equal(dumps(loads('{"":1}')), '{"":1}')
    assert_equal(loads('{"a":1,"a":2}').object_count(), 2)


def test_bytes_overload() raises:
    var text = String('{"k":[true,null]}')
    var value = loads(text.as_bytes())
    assert_true(value["k"][0].bool_value())
    assert_true(value["k"][1].is_null())


def test_round_trip() raises:
    var text = '{"a":[1,2.5,"x",true,null],"b":{"c":-3}}'
    assert_equal(dumps(loads(text)), text)


def test_invalid_json_raises() raises:
    with assert_raises():
        _ = loads("{")
    with assert_raises():
        _ = loads("[1,]")
    with assert_raises():
        _ = loads("")
    with assert_raises():
        _ = loads("1 2")


def test_invalid_utf8_bytes_raise() raises:
    var bad = [UInt8(0x22), 0xFF, 0x22]
    with assert_raises():
        _ = loads(Span(bad))


def test_parse_error_names_the_position() raises:
    try:
        _ = loads('{"a": }')
    except error:
        assert_true("line 1" in String(error))
        return
    assert_true(False, "expected an error")


def test_many_parses_on_one_thread() raises:
    for i in range(2000):
        var value = loads('{"n":' + String(i) + "}")
        assert_equal(Int(value["n"].int_value()), i)


def main() raises:
    test_simdjson_library_is_loaded()
    test_scalars()
    test_wide_integers()
    test_integer_wider_than_64_bits_becomes_a_float()
    test_string_escapes_and_unicode()
    test_containers()
    test_duplicate_keys_and_empty_key()
    test_bytes_overload()
    test_round_trip()
    test_invalid_json_raises()
    test_invalid_utf8_bytes_raise()
    test_parse_error_names_the_position()
    test_many_parses_on_one_thread()
    print("test_loads: 13 passed")

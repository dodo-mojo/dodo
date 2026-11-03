"""`serialize_json` and `deserialize_json`: struct fields to JSON and back."""

from std.collections import Dict, Optional
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)

from dodo.json import (
    Value,
    deserialize_json,
    deserialize_value,
    loads,
    serialize_json,
    serialize_value,
    try_deserialize_json,
)
from dodo.json.reflection import JsonDeserializable, JsonSerializable


@fieldwise_init
struct Point(Defaultable, Movable):
    var x: Int
    var y: Int

    def __init__(out self):
        self.x = 0
        self.y = 0


@fieldwise_init
struct Scalars(Movable):
    var i: Int
    var wide: Int64
    var small: UInt8
    var flag: Bool
    var ratio: Float64
    var name: String


@fieldwise_init
struct Line(Movable):
    var start: Point
    var end: Point
    var label: Optional[String]


@fieldwise_init
struct Containers(Movable):
    var ints: List[Int]
    var names: List[String]
    var points: List[Point]
    var grid: List[List[Int]]
    var maybe: List[Optional[Int]]
    var scores: Dict[String, Int]


@fieldwise_init
struct Optionals(Movable):
    var a: Optional[Int]
    var b: Optional[String]
    var c: Optional[List[Int]]


@fieldwise_init
struct Raw(Movable):
    var id: Int
    var extra: Value


@fieldwise_init
struct Rgb(JsonDeserializable, JsonSerializable, Movable):
    var r: Int

    def to_json_value(self) raises -> Value:
        return loads(String('"r=', self.r, '"'))

    @staticmethod
    def from_json_value(json: Value) raises -> Self:
        var text = json.string_value()
        return Self(atol(text[byte=2:]))


@fieldwise_init
struct Painted(Movable):
    var color: Rgb


def _error_of[T: Movable & Deinitable](json: String) -> String:
    try:
        _ = deserialize_json[T](json)
    except e:
        return String(e)
    return String("")


# Serialize


def test_serialize_flat_struct() raises:
    assert_equal(serialize_json(Point(1, -2)), '{"x":1,"y":-2}')


def test_serialize_scalars() raises:
    var text = serialize_json(Scalars(1, Int64.MAX, 255, True, 2.5, "hi"))
    assert_equal(
        text,
        '{"i":1,"wide":9223372036854775807,"small":255,"flag":true,'
        + '"ratio":2.5,"name":"hi"}',
    )


def test_serialize_escapes_strings() raises:
    var value = Scalars(0, 0, 0, False, 0.0, 'a"b\\c\nd')
    var back = deserialize_json[Scalars](serialize_json(value))
    assert_equal(back.name, 'a"b\\c\nd')
    assert_true('a\\"b' in serialize_json(value))


def test_serialize_absent_optional_is_null() raises:
    var line = Line(Point(1, 2), Point(3, 4), None)
    assert_equal(
        serialize_json(line),
        '{"start":{"x":1,"y":2},"end":{"x":3,"y":4},"label":null}',
    )


def test_serialize_custom_override() raises:
    assert_equal(serialize_json(Painted(Rgb(9))), '{"color":"r=9"}')


def test_serialize_pretty_parses_back() raises:
    var text = serialize_json[pretty=True](Point(1, 2))
    assert_true("\n" in text)
    var back = deserialize_json[Point](text)
    assert_equal(back.x, 1)
    assert_equal(back.y, 2)


def test_serialize_value_matches_text() raises:
    var value = serialize_value(Point(5, 6))
    assert_equal(deserialize_value[Point](value).y, 6)


# Round trips


def test_round_trip_containers() raises:
    var points = List[Point]()
    points.append(Point(1, 2))
    var scores = Dict[String, Int]()
    scores["a"] = 1
    var original = Containers(
        [1, 2, 3],
        ["x", "y"],
        points^,
        [[1], [], [2, 3]],
        [Optional[Int](1), Optional[Int](None)],
        scores^,
    )
    var back = deserialize_json[Containers](serialize_json(original))
    assert_equal(len(back.ints), 3)
    assert_equal(back.ints[2], 3)
    assert_equal(back.names[1], "y")
    assert_equal(back.points[0].y, 2)
    assert_equal(len(back.grid[1]), 0)
    assert_equal(back.grid[2][1], 3)
    assert_equal(back.maybe[0].value(), 1)
    assert_false(back.maybe[1])
    assert_equal(back.scores["a"], 1)


def test_round_trip_unicode() raises:
    var value = Scalars(0, 0, 0, False, 0.0, "héllo 🦤")
    var back = deserialize_json[Scalars](serialize_json(value))
    assert_equal(back.name, "héllo 🦤")


def test_round_trip_float_precision() raises:
    var value = Scalars(0, 0, 0, False, 0.1, "")
    assert_equal(deserialize_json[Scalars](serialize_json(value)).ratio, 0.1)


def test_value_field_passes_through() raises:
    var parsed = deserialize_json[Raw]('{"id":1,"extra":{"k":[1,true]}}')
    assert_equal(parsed.id, 1)
    assert_equal(serialize_json(parsed), '{"id":1,"extra":{"k":[1,true]}}')


def test_custom_deserialize_override() raises:
    assert_equal(deserialize_json[Painted]('{"color":"r=42"}').color.r, 42)


# Deserialize shape


def test_unknown_keys_are_skipped() raises:
    var p = deserialize_json[Point]('{"z":{"deep":[1,2]},"x":1,"y":2,"w":null}')
    assert_equal(p.x, 1)
    assert_equal(p.y, 2)


def test_field_order_does_not_matter() raises:
    assert_equal(deserialize_json[Point]('{"y":2,"x":1}').x, 1)


def test_duplicate_key_keeps_first() raises:
    assert_equal(deserialize_json[Point]('{"x":1,"x":9,"y":2}').x, 1)


def test_escaped_key_matches_field() raises:
    assert_equal(deserialize_json[Point]('{"\\u0078":7,"y":2}').x, 7)


def test_absent_and_null_optionals_are_none() raises:
    var absent = deserialize_json[Optionals]("{}")
    assert_false(absent.a)
    assert_false(absent.b)
    assert_false(absent.c)
    var nulls = deserialize_json[Optionals]('{"a":null,"b":null,"c":null}')
    assert_false(nulls.a)
    assert_false(nulls.b)
    assert_false(nulls.c)


def test_present_optionals_hold_values() raises:
    var given = deserialize_json[Optionals]('{"a":1,"b":"s","c":[2]}')
    assert_equal(given.a.value(), 1)
    assert_equal(given.b.value(), "s")
    assert_equal(given.c.value()[0], 2)


def test_bytes_overload() raises:
    var text = String('{"x":1,"y":2}')
    assert_equal(deserialize_json[Point](text.as_bytes()).y, 2)


# Deserialize errors


def test_missing_field_names_it() raises:
    var message = _error_of[Point]('{"x":1}')
    assert_true("missing required field 'y'" in message, message)


def test_wrong_type_names_the_field() raises:
    var message = _error_of[Point]('{"x":"one","y":2}')
    assert_true("field 'x'" in message, message)


def test_nested_error_names_the_path() raises:
    var message = _error_of[Line](
        '{"start":{"x":"bad","y":2},"end":{"x":1,"y":2}}'
    )
    assert_true("field 'start'" in message, message)
    assert_true("field 'x'" in message, message)


def test_error_after_written_field_is_clean() raises:
    # A later bad field must destroy the strings already written.
    for _ in range(100):
        var message = _error_of[Scalars](
            '{"name":"a long enough string to live on the heap, really",'
            + '"i":"bad"}'
        )
        assert_true("field 'i'" in message, message)


def test_invalid_json_raises() raises:
    for bad in ["", "{", '{"x":', '{"x":1,}', "[1,2]", "null", "nope"]:
        assert_true(len(_error_of[Point](String(bad)).as_bytes()) > 0, bad)


def test_trailing_garbage_raises() raises:
    assert_true(len(_error_of[Point]('{"x":1,"y":2} x').as_bytes()) > 0)


def test_int_out_of_range_raises() raises:
    assert_true(
        len(_error_of[Point]('{"x":9223372036854775808,"y":2}').as_bytes()) > 0
    )


def test_float_into_int_raises() raises:
    assert_true(len(_error_of[Point]('{"x":1.5,"y":2}').as_bytes()) > 0)


def test_null_into_required_raises() raises:
    assert_true(len(_error_of[Point]('{"x":null,"y":2}').as_bytes()) > 0)


def test_narrow_int_out_of_range_raises() raises:
    var json = '{"i":0,"wide":0,"small":256,"flag":false,"ratio":0,"name":""}'
    assert_true("field 'small'" in _error_of[Scalars](json))


def test_deep_nesting_raises_cleanly() raises:
    var deep = String("[" * 100000)
    assert_true(len(_error_of[Point](deep).as_bytes()) > 0)


def test_try_deserialize() raises:
    assert_equal(try_deserialize_json[Point]('{"x":1,"y":2}').value().x, 1)
    assert_false(try_deserialize_json[Point]('{"x":1}'))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

"""``loads`` through simdjson and through the pure-Mojo parser must agree."""

from std.testing import assert_equal, assert_not_equal, assert_true

from dodo.json import dumps
from dodo.json.parser import (
    parse_mojo_bytes,
    parse_mojo_string,
    parse_simdjson_bytes,
    parse_simdjson_string,
    simdjson_accepts,
)


def _nested_arrays(depth: Int) -> String:
    var text = String()
    for _ in range(depth):
        text += "["
    text += "1"
    for _ in range(depth):
        text += "]"
    return text^


def _nested_objects(depth: Int) -> String:
    var text = String()
    for _ in range(depth):
        text += '{"k":'
    text += "1"
    for _ in range(depth):
        text += "}"
    return text^


def _inputs() -> List[String]:
    var inputs = List[String]()
    inputs.append("null")
    inputs.append("true")
    inputs.append("false")
    inputs.append("0")
    inputs.append("-0")
    inputs.append("42")
    inputs.append("-17")
    inputs.append("3.14159")
    inputs.append("-2.5e10")
    inputs.append("1E-7")
    inputs.append("0.1")
    inputs.append("1e308")
    inputs.append("3.14159265358979323846264338327950288419716939937510")
    inputs.append("0.000000000000000000000000000000000000001234567890123456789")
    inputs.append("9223372036854775807")
    inputs.append("-9223372036854775808")
    inputs.append("9223372036854775808")
    inputs.append("18446744073709551615")
    inputs.append("18446744073709551616")
    inputs.append("99999999999999999999999999")
    inputs.append("-99999999999999999999999999")
    inputs.append("[123456789012345678901234567890]")
    inputs.append("576460752303423487")
    inputs.append("576460752303423488")
    inputs.append("-576460752303423488")
    inputs.append("-576460752303423489")
    inputs.append('""')
    inputs.append('"hello"')
    inputs.append('"quote \\" backslash \\\\ slash \\/"')
    inputs.append('"tab\\t newline\\n return\\r form\\f back\\b"')
    inputs.append('"\\u0041\\u00e9\\u20ac"')
    inputs.append('"\\ud83d\\ude00"')
    inputs.append('"café 中文 \U0001F600"')
    inputs.append("[]")
    inputs.append("{}")
    inputs.append("[[]]")
    inputs.append("[{}]")
    inputs.append('{"a":[]}')
    inputs.append("[1,2,3]")
    inputs.append(" [ 1 , 2 , 3 ] ")
    inputs.append('{"a":1,"b":[true,null,"x"],"c":{"d":2.5}}')
    inputs.append('{"a":1,"a":2}')
    inputs.append('{"":1}')
    inputs.append('{"k\\n\\u00e9":"v"}')
    inputs.append('[1, 2.5, "s", true, false, null, [], {}]')
    inputs.append(_nested_arrays(50))
    inputs.append(_nested_objects(50))
    inputs.append(_nested_arrays(500))

    # Invalid inputs.
    inputs.append("")
    inputs.append("   ")
    inputs.append("nul")
    inputs.append("tru")
    inputs.append("True")
    inputs.append("[1,2,]")
    inputs.append("[1 2]")
    inputs.append("[")
    inputs.append("]")
    inputs.append("{")
    inputs.append('{"a"}')
    inputs.append('{"a":}')
    inputs.append('{"a":1,}')
    inputs.append("{a:1}")
    inputs.append("{'a':1}")
    inputs.append('"unterminated')
    inputs.append('"bad escape \\q"')
    inputs.append('"bad unicode \\u12"')
    inputs.append('"lone surrogate \\ud800"')
    inputs.append('"lone low surrogate \\ude00"')
    inputs.append('"raw\nnewline"')
    inputs.append('"raw\ttab"')
    inputs.append("01")
    inputs.append("-")
    inputs.append("1.")
    inputs.append(".5")
    inputs.append("1e")
    inputs.append("+1")
    inputs.append("0x10")
    inputs.append("NaN")
    inputs.append("Infinity")
    inputs.append("1 2")
    inputs.append("{} x")
    inputs.append("[] []")
    inputs.append("null null")
    inputs.append("1}")
    inputs.append("[1}")
    inputs.append('{"a":1]')
    inputs.append("// comment\n1")
    return inputs^


def _result_via_simdjson(text: String) -> String:
    try:
        return dumps(parse_simdjson_string(text))
    except:
        return "<error>"


def _result_via_mojo(text: String) -> String:
    try:
        return dumps(parse_mojo_string(text.copy()))
    except:
        return "<error>"


def test_parsers_agree_on_valid_and_invalid_inputs() raises:
    var disagreements = String()
    for text in _inputs():
        var simdjson_result = _result_via_simdjson(text)
        var mojo_result = _result_via_mojo(text)
        if simdjson_result != mojo_result:
            disagreements += "input: " + text + "\n"
            disagreements += "  simdjson: " + simdjson_result + "\n"
            disagreements += "  mojo:     " + mojo_result + "\n"
    assert_equal(disagreements, "")


def test_simdjson_never_accepts_what_the_mojo_parser_rejects() raises:
    for text in _inputs():
        if simdjson_accepts(text.as_bytes()):
            assert_not_equal(
                _result_via_mojo(text), "<error>", "accepted: " + text
            )


def test_deep_nesting_is_rejected_or_parsed_the_same() raises:
    var deep = _nested_arrays(5000)
    var simdjson_result = _result_via_simdjson(deep)
    var mojo_result = _result_via_mojo(deep)
    assert_equal(simdjson_result, mojo_result)


def _bad_utf8_inputs() -> List[List[UInt8]]:
    var inputs = List[List[UInt8]]()
    # Lone continuation byte inside a string.
    inputs.append([UInt8(0x22), 0x80, 0x22])
    # Truncated two-byte sequence.
    inputs.append([UInt8(0x22), 0xC3, 0x22])
    # Overlong encoding of '/'.
    inputs.append([UInt8(0x22), 0xC0, 0xAF, 0x22])
    # UTF-16 surrogate encoded as UTF-8.
    inputs.append([UInt8(0x22), 0xED, 0xA0, 0x80, 0x22])
    # Above U+10FFFF.
    inputs.append([UInt8(0x22), 0xF5, 0x80, 0x80, 0x80, 0x22])
    # Invalid byte outside any string.
    inputs.append([UInt8(0x5B), 0xFF, 0x5D])
    return inputs^


def test_both_parsers_reject_invalid_utf8_bytes() raises:
    for bytes in _bad_utf8_inputs():
        var simdjson_rejected = False
        try:
            _ = parse_simdjson_bytes(Span(bytes))
        except:
            simdjson_rejected = True
        assert_true(simdjson_rejected, "simdjson accepted bad UTF-8")

        var mojo_rejected = False
        try:
            _ = parse_mojo_bytes(Span(bytes))
        except:
            mojo_rejected = True
        assert_true(mojo_rejected, "the Mojo parser accepted bad UTF-8")


def main() raises:
    test_parsers_agree_on_valid_and_invalid_inputs()
    test_simdjson_never_accepts_what_the_mojo_parser_rejects()
    test_deep_nesting_is_rejected_or_parsed_the_same()
    test_both_parsers_reject_invalid_utf8_bytes()
    print("test_loads_differential: 4 passed")

"""``loads`` falls back to the pure-Mojo parser when the library is missing.

Runs in its own process: it points DODO_LIB_DIR at an empty directory
before the first ``loads``, and the library lookup is cached per process.
"""

from std.os import setenv
from std.testing import assert_equal, assert_false, assert_raises, assert_true

from dodo.json import dumps, loads
from dodo.json.ffi.simdjson import simdjson_available


def test_fallback_parses_and_rejects() raises:
    assert_true(setenv("DODO_LIB_DIR", "/nonexistent/dodo-lib"))
    assert_false(simdjson_available())

    var text = '{"a":[1,2.5,"x\\u00e9",true,null],"b":{"c":-3}}'
    assert_equal(
        dumps(loads(text)), '{"a":[1,2.5,"xé",true,null],"b":{"c":-3}}'
    )
    assert_equal(loads("18446744073709551615").uint_value(), UInt64.MAX)

    with assert_raises():
        _ = loads("[1,]")
    var bad = [UInt8(0x22), 0xFF, 0x22]
    with assert_raises():
        _ = loads(Span(bad))


def main() raises:
    test_fallback_parses_and_rejects()
    print("test_loads_fallback: 1 passed")

"""Tests for Fuzzable implementations.

Covers: in-range values, boundary bias presence, minimize contracts, and
FuzzableString UTF-8 validity.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_not_equal,
    TestSuite,
)
from mozz.rng import Xoshiro256
from mozz.arbitrary import (
    FuzzableBool,
    FuzzableUInt8,
    FuzzableUInt16,
    FuzzableUInt32,
    FuzzableUInt64,
    FuzzableInt,
    FuzzableString,
    FuzzableBytes,
)

comptime _N = 2_000


def test_fuzzable_bool_range() raises:
    """FuzzableBool.generate() must produce both True and False."""
    var rng = Xoshiro256(seed=1)
    var saw_true = False
    var saw_false = False
    for _ in range(200):
        if FuzzableBool.generate(rng):
            saw_true = True
        else:
            saw_false = True
    assert_true(saw_true)
    assert_true(saw_false)


def test_fuzzable_bool_minimize() raises:
    """Bool.minimize(True) must contain False; minimize(False) must be empty."""
    var minimized_true = FuzzableBool.minimize(True)
    assert_equal(len(minimized_true), 1)
    assert_false(minimized_true[0])
    assert_equal(len(FuzzableBool.minimize(False)), 0)


def test_fuzzable_uint8_range() raises:
    """FuzzableUInt8.generate() must stay in [0, 255]."""
    var rng = Xoshiro256(seed=2)
    for _ in range(_N):
        var v = FuzzableUInt8.generate(rng)
        assert_true(Int(v) >= 0 and Int(v) <= 255)


def test_fuzzable_uint8_boundary_bias() raises:
    """FuzzableUInt8 must hit boundary values (0 and 255) within 2000 runs."""
    var rng = Xoshiro256(seed=3)
    var saw_zero = False
    var saw_max = False
    for _ in range(_N):
        var v = FuzzableUInt8.generate(rng)
        if v == 0:
            saw_zero = True
        if v == 255:
            saw_max = True
    assert_true(saw_zero)
    assert_true(saw_max)


def test_fuzzable_uint8_minimize() raises:
    """UInt8.minimize(v) must always contain 0 for v > 0; empty for v == 0."""
    assert_equal(len(FuzzableUInt8.minimize(0)), 0)
    var minimized = FuzzableUInt8.minimize(100)
    var has_zero = False
    for i in range(len(minimized)):
        if minimized[i] == 0:
            has_zero = True
            break
    assert_true(has_zero)


def test_fuzzable_uint16_range() raises:
    """FuzzableUInt16.generate() must stay in [0, 65535]."""
    var rng = Xoshiro256(seed=4)
    for _ in range(_N):
        assert_true(UInt32(FuzzableUInt16.generate(rng)) <= 65535)


def test_fuzzable_uint16_boundary() raises:
    """FuzzableUInt16 must produce 0 and 65535 within 2000 runs."""
    var rng = Xoshiro256(seed=5)
    var saw_zero = False
    var saw_max = False
    for _ in range(_N):
        var v = FuzzableUInt16.generate(rng)
        if v == 0:
            saw_zero = True
        if v == 65535:
            saw_max = True
    assert_true(saw_zero)
    assert_true(saw_max)


def test_fuzzable_uint32_range() raises:
    """FuzzableUInt32.generate() must stay in [0, 2^32-1]."""
    var rng = Xoshiro256(seed=6)
    for _ in range(_N):
        assert_true(UInt64(FuzzableUInt32.generate(rng)) <= 0xFFFFFFFF)


def test_fuzzable_uint64_range() raises:
    """FuzzableUInt64.generate() must complete without error."""
    var rng = Xoshiro256(seed=7)
    for _ in range(_N):
        _ = FuzzableUInt64.generate(rng)


def test_fuzzable_int_boundary() raises:
    """FuzzableInt must produce 0 within 2000 runs."""
    var rng = Xoshiro256(seed=8)
    var saw_zero = False
    for _ in range(_N):
        if FuzzableInt.generate(rng) == 0:
            saw_zero = True
            break
    assert_true(saw_zero)


def test_fuzzable_int_minimize() raises:
    """FuzzableInt.minimize(n) must include 0; minimize(0) must be empty."""
    var minimized = FuzzableInt.minimize(1000)
    var has_zero = False
    for i in range(len(minimized)):
        if minimized[i] == 0:
            has_zero = True
            break
    assert_true(has_zero)
    assert_equal(len(FuzzableInt.minimize(0)), 0)


def test_fuzzable_string_not_empty_sometimes() raises:
    """FuzzableString must produce non-empty strings sometimes."""
    var rng = Xoshiro256(seed=9)
    var saw_nonempty = False
    for _ in range(200):
        if FuzzableString.generate(rng).byte_length() > 0:
            saw_nonempty = True
            break
    assert_true(saw_nonempty)


def test_fuzzable_string_length_bound() raises:
    """FuzzableString must produce strings of at most 512 bytes."""
    var rng = Xoshiro256(seed=10)
    for _ in range(500):
        assert_true(FuzzableString.generate(rng).byte_length() <= 512)


def test_fuzzable_string_minimize() raises:
    """FuzzableString.minimize must include empty string for non-empty input."""
    var minimized = FuzzableString.minimize("hello world")
    var has_empty = False
    for i in range(len(minimized)):
        if minimized[i].byte_length() == 0:
            has_empty = True
            break
    assert_true(has_empty)
    assert_equal(len(FuzzableString.minimize("")), 0)


def test_fuzzable_bytes_range() raises:
    """FuzzableBytes.generate() must return bytes all in [0, 255]."""
    var rng = Xoshiro256(seed=11)
    for _ in range(500):
        var bs = FuzzableBytes.generate(rng)
        for i in range(len(bs)):
            assert_true(Int(bs[i]) >= 0 and Int(bs[i]) <= 255)


def test_fuzzable_bytes_length_bound() raises:
    """FuzzableBytes must produce lists of at most 256 bytes."""
    var rng = Xoshiro256(seed=12)
    for _ in range(500):
        assert_true(len(FuzzableBytes.generate(rng)) <= 256)


def test_fuzzable_bytes_minimize() raises:
    """FuzzableBytes.minimize must include the empty list for non-empty input.
    """
    var data: List[UInt8] = [0x01, 0x02, 0x03, 0x04]
    var minimized = FuzzableBytes.minimize(data)
    var has_empty = False
    for i in range(len(minimized)):
        if len(minimized[i]) == 0:
            has_empty = True
            break
    assert_true(has_empty)


def main() raises:
    print("=" * 60)
    print("test_arbitrary.mojo")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

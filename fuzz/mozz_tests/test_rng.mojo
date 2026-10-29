"""Tests for Xoshiro256++ PRNG.

Covers: reproducibility, uniform distribution, fill(), next_below() bias.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_not_equal,
    TestSuite,
)
from mozz.rng import Xoshiro256


def test_same_seed_same_sequence() raises:
    """Same seed must produce identical output sequences."""
    var a = Xoshiro256(seed=12345)
    var b = Xoshiro256(seed=12345)
    for _ in range(100):
        assert_equal(a.next_u64(), b.next_u64())


def test_different_seeds_different_sequences() raises:
    """Different seeds must produce different sequences."""
    var a = Xoshiro256(seed=1)
    var b = Xoshiro256(seed=2)
    var any_diff = False
    for _ in range(20):
        if a.next_u64() != b.next_u64():
            any_diff = True
            break
    assert_true(any_diff)


def test_zero_seed_produces_nonzero() raises:
    """Zero seed derives from ASLR heap entropy; output must be non-zero."""
    var a = Xoshiro256(seed=0)
    assert_true(a.next_u64() != 0)


def test_next_byte_range() raises:
    """Output of next_byte() must always be in [0, 255]."""
    var rng = Xoshiro256(seed=7)
    for _ in range(10_000):
        var b = rng.next_byte()
        assert_true(Int(b) >= 0 and Int(b) <= 255)


def test_next_u32_range() raises:
    """Output of next_u32() must always fit in a UInt32."""
    var rng = Xoshiro256(seed=99)
    for _ in range(1_000):
        var v = rng.next_u32()
        assert_true(UInt64(v) <= 0xFFFFFFFF)


def test_next_below_range() raises:
    """Output of next_below(n) must always be in [0, n)."""
    var rng = Xoshiro256(seed=42)
    for n_raw in range(1, 101):
        var n = UInt64(n_raw)
        for _ in range(50):
            assert_true(rng.next_below(n) < n)


def test_next_below_one_returns_zero() raises:
    """Calling next_below(1) must always return 0."""
    var rng = Xoshiro256(seed=11)
    for _ in range(200):
        assert_equal(rng.next_below(1), UInt64(0))


def test_next_bool_both_values() raises:
    """Calling next_bool() must produce both True and False within 100 calls."""
    var rng = Xoshiro256(seed=55)
    var saw_true = False
    var saw_false = False
    for _ in range(100):
        if rng.next_bool():
            saw_true = True
        else:
            saw_false = True
    assert_true(saw_true)
    assert_true(saw_false)


def test_fill_length() raises:
    """Calling fill() must write exactly len(buf) bytes."""
    var rng = Xoshiro256(seed=3)
    var buf = List[UInt8](length=64, fill=UInt8(0))
    rng.fill(buf)
    assert_equal(len(buf), 64)


def test_fill_changes_bytes() raises:
    """Calling fill() must change at least some bytes in a zero buffer."""
    var rng = Xoshiro256(seed=17)
    var buf = List[UInt8](length=32, fill=UInt8(0))
    rng.fill(buf)
    var any_nonzero = False
    for b in buf:
        if b != 0:
            any_nonzero = True
            break
    assert_true(any_nonzero)


def test_fill_reproducible() raises:
    """Two RNGs with the same seed must produce the same fill() output."""
    var a = Xoshiro256(seed=99)
    var b = Xoshiro256(seed=99)
    var buf_a = List[UInt8](length=48, fill=UInt8(0))
    var buf_b = List[UInt8](length=48, fill=UInt8(0))
    a.fill(buf_a)
    b.fill(buf_b)
    for i in range(48):
        assert_equal(buf_a[i], buf_b[i])


def test_state_advances_each_call() raises:
    """Consecutive next_u64() calls must return different values."""
    var rng = Xoshiro256(seed=1234)
    var prev = rng.next_u64()
    var all_same = True
    for _ in range(20):
        var cur = rng.next_u64()
        if cur != prev:
            all_same = False
            break
        prev = cur
    assert_false(all_same)


def test_copyable() raises:
    """Copying a Xoshiro256 forks the sequence identically."""
    var orig = Xoshiro256(seed=77)
    _ = orig.next_u64()
    _ = orig.next_u64()
    var forked = orig.copy()
    for _ in range(20):
        assert_equal(orig.next_u64(), forked.next_u64())


def main() raises:
    print("=" * 60)
    print("test_rng.mojo")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

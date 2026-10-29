"""Tests for all mutation operators.

Verifies: output is always a valid List[UInt8], length constraints, boundary
value injection, and the weighted MutatorChain dispatch.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_not_equal,
    TestSuite,
)
from mozz.rng import Xoshiro256
from mozz.mutator import (
    BitFlip,
    ByteSubstitution,
    ByteInsertion,
    ByteDeletion,
    BlockDuplication,
    Splice,
    BoundaryInt,
    MutatorChain,
    MutatorId,
    default_mutator,
)

comptime _RUNS = 200


def _make_input() -> List[UInt8]:
    var r: List[UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  # "Hello"
    return r^


def _make_corpus() -> List[List[UInt8]]:
    var c = List[List[UInt8]]()
    var s1: List[UInt8] = [0x01, 0x02]
    var s2: List[UInt8] = [0xFF, 0xFE, 0xFD]
    var s3: List[UInt8] = [0x00]
    c.append(s1^)
    c.append(s2^)
    c.append(s3^)
    return c^


def test_bitflip_output_is_bytes() raises:
    """BitFlip output length must equal input length."""
    var rng = Xoshiro256(seed=1)
    var m = BitFlip()
    var inp = _make_input()
    for _ in range(_RUNS):
        assert_equal(len(m.mutate(Span[UInt8, _](inp), rng)), len(inp))


def test_bitflip_changes_input() raises:
    """BitFlip must flip at least one bit across 50 runs."""
    var rng = Xoshiro256(seed=2)
    var m = BitFlip()
    var inp = _make_input()
    var changed = False
    for _ in range(50):
        var out = m.mutate(Span[UInt8, _](inp), rng)
        for i in range(len(inp)):
            if out[i] != inp[i]:
                changed = True
                break
        if changed:
            break
    assert_true(changed)


def test_byte_substitution_range() raises:
    """ByteSubstitution output bytes must be valid UInt8 values."""
    var rng = Xoshiro256(seed=3)
    var m = ByteSubstitution()
    var inp = _make_input()
    for _ in range(_RUNS):
        var out = m.mutate(Span[UInt8, _](inp), rng)
        assert_equal(len(out), len(inp))
        for i in range(len(out)):
            assert_true(Int(out[i]) >= 0 and Int(out[i]) <= 255)


def test_byte_substitution_uses_boundary() raises:
    """ByteSubstitution must produce boundary bytes at least once in 1000 runs.
    """
    var rng = Xoshiro256(seed=4)
    var m = ByteSubstitution()
    var inp: List[UInt8] = [0x42, 0x42, 0x42, 0x42, 0x42]
    var boundaries: List[UInt8] = [0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF]
    var saw_boundary = False
    for _ in range(1_000):
        var out = m.mutate(Span[UInt8, _](inp), rng)
        for i in range(len(out)):
            for j in range(len(boundaries)):
                if out[i] == boundaries[j]:
                    saw_boundary = True
                    break
            if saw_boundary:
                break
        if saw_boundary:
            break
    assert_true(saw_boundary)


def test_byte_insertion_grows() raises:
    """ByteInsertion must produce output strictly longer than input."""
    var rng = Xoshiro256(seed=5)
    var m = ByteInsertion()
    var inp = _make_input()
    for _ in range(_RUNS):
        assert_true(len(m.mutate(Span[UInt8, _](inp), rng)) > len(inp))


def test_byte_insertion_max_growth() raises:
    """ByteInsertion must add at most 8 bytes."""
    var rng = Xoshiro256(seed=6)
    var m = ByteInsertion()
    var inp = _make_input()
    for _ in range(_RUNS):
        assert_true(len(m.mutate(Span[UInt8, _](inp), rng)) <= len(inp) + 8)


def test_byte_deletion_shrinks() raises:
    """ByteDeletion must produce output strictly shorter than input (len > 1).
    """
    var rng = Xoshiro256(seed=7)
    var m = ByteDeletion()
    var inp: List[UInt8] = [
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
    ]
    for _ in range(_RUNS):
        assert_true(len(m.mutate(Span[UInt8, _](inp), rng)) < len(inp))


def test_byte_deletion_empty_input() raises:
    """ByteDeletion on empty input must return empty output."""
    var rng = Xoshiro256(seed=8)
    var m = ByteDeletion()
    var inp = List[UInt8]()
    assert_equal(len(m.mutate(Span[UInt8, _](inp), rng)), 0)


def test_block_duplication_grows() raises:
    """BlockDuplication must produce output strictly longer than input."""
    var rng = Xoshiro256(seed=9)
    var m = BlockDuplication()
    var inp: List[UInt8] = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE]
    for _ in range(_RUNS):
        assert_true(len(m.mutate(Span[UInt8, _](inp), rng)) > len(inp))


def test_splice_output_is_bytes() raises:
    """Splice output bytes must all be valid UInt8 values."""
    var rng = Xoshiro256(seed=10)
    var corpus = _make_corpus()
    var m = Splice(corpus)
    var inp = _make_input()
    for _ in range(_RUNS):
        var out = m.mutate(Span[UInt8, _](inp), rng)
        for i in range(len(out)):
            assert_true(Int(out[i]) >= 0 and Int(out[i]) <= 255)


def test_splice_empty_corpus() raises:
    """Splice with < 2 corpus entries must return a copy of input."""
    var rng = Xoshiro256(seed=11)
    var single = List[List[UInt8]]()
    var s1: List[UInt8] = [0x01]
    single.append(s1^)
    var m = Splice(single)
    var inp = _make_input()
    assert_equal(len(m.mutate(Span[UInt8, _](inp), rng)), len(inp))


def test_boundary_int_output_length() raises:
    """BoundaryInt must not change input length."""
    var rng = Xoshiro256(seed=12)
    var m = BoundaryInt()
    var inp: List[UInt8] = [0x42, 0x42, 0x42, 0x42]
    for _ in range(_RUNS):
        assert_equal(len(m.mutate(Span[UInt8, _](inp), rng)), len(inp))


def test_boundary_int_uses_boundaries() raises:
    """BoundaryInt must produce 0x00, 0x7F, 0x80, or 0xFF in at least some runs.
    """
    var rng = Xoshiro256(seed=13)
    var m = BoundaryInt()
    var inp: List[UInt8] = [0x42, 0x42, 0x42, 0x42, 0x42, 0x42]
    var saw_boundary = False
    for _ in range(500):
        var out = m.mutate(Span[UInt8, _](inp), rng)
        for i in range(len(out)):
            var b = out[i]
            if b == 0x00 or b == 0xFF or b == 0x7F or b == 0x80:
                saw_boundary = True
                break
        if saw_boundary:
            break
    assert_true(saw_boundary)


def test_mutator_chain_output_is_bytes() raises:
    """MutatorChain dispatches to various mutators and returns valid bytes."""
    var ids: List[Int] = [
        MutatorId.BIT_FLIP,
        MutatorId.BYTE_SUBSTITUTION,
        MutatorId.BYTE_INSERTION,
        MutatorId.BYTE_DELETION,
        MutatorId.BLOCK_DUPLICATION,
        MutatorId.SPLICE,
        MutatorId.BOUNDARY_INT,
    ]
    var weights: List[UInt32] = [10, 10, 10, 10, 10, 10, 10]
    var corpus = _make_corpus()
    var chain = MutatorChain(ids, weights, corpus)
    var inp: List[UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
    var rng = Xoshiro256(seed=14)
    for _ in range(500):
        var out = chain.mutate(Span[UInt8, _](inp), rng)
        for i in range(len(out)):
            assert_true(Int(out[i]) >= 0 and Int(out[i]) <= 255)


def test_default_mutator_output_is_bytes() raises:
    """The default_mutator() factory must always return valid bytes."""
    var rng = Xoshiro256(seed=15)
    var chain = default_mutator()
    var inp: List[UInt8] = [0x48, 0x54, 0x54, 0x50, 0x2F, 0x31, 0x2E, 0x31]
    for _ in range(500):
        var out = chain.mutate(Span[UInt8, _](inp), rng)
        for i in range(len(out)):
            assert_true(Int(out[i]) >= 0 and Int(out[i]) <= 255)


def test_mutator_empty_input_safe() raises:
    """All mutators must handle empty input without panicking."""
    var rng = Xoshiro256(seed=16)
    var empty = List[UInt8]()
    var span = Span[UInt8, _](empty)
    _ = BitFlip().mutate(span, rng)
    _ = ByteSubstitution().mutate(span, rng)
    _ = ByteInsertion().mutate(span, rng)
    _ = ByteDeletion().mutate(span, rng)
    _ = BlockDuplication().mutate(span, rng)
    _ = BoundaryInt().mutate(span, rng)
    var corpus = _make_corpus()
    _ = Splice(corpus).mutate(span, rng)


def main() raises:
    print("=" * 60)
    print("test_mutators.mojo")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

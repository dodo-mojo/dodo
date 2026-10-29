"""Tests for Corpus seed management.

Covers: default seeds, deduplication, pick(), add(), max size eviction.
"""

from std.testing import (
    assert_equal,
    assert_true,
    assert_false,
    assert_not_equal,
    TestSuite,
)
from mozz.rng import Xoshiro256
from mozz.corpus import Corpus, MAX_CORPUS_SIZE, _fnv1a64


def test_default_has_four_seeds() raises:
    """Corpus.default() must contain exactly 4 seeds."""
    var c = Corpus.default()
    assert_equal(c.size(), 4)


def test_add_new_seed() raises:
    """Adding a new seed must increase size by 1."""
    var c = Corpus.default()
    var before = c.size()
    var seed: List[UInt8] = [0x01, 0x02, 0x03]
    c.add(seed)
    assert_equal(c.size(), before + 1)


def test_dedup() raises:
    """Adding an identical seed twice must not grow the corpus."""
    var c = Corpus.default()
    var seed: List[UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
    c.add(seed)
    var after_first = c.size()
    c.add(seed)
    assert_equal(c.size(), after_first)


def test_dedup_empty() raises:
    """Default corpus already has an empty seed; adding [] again is a noop."""
    var c = Corpus.default()
    var before = c.size()
    c.add(List[UInt8]())
    assert_equal(c.size(), before)


def test_pick_in_range() raises:
    """Returned seed from pick() must be one that was added."""
    var c = Corpus(List[List[UInt8]]())
    var s1: List[UInt8] = [0xAA]
    var s2: List[UInt8] = [0xBB]
    var s3: List[UInt8] = [0xCC]
    c.add(s1)
    c.add(s2)
    c.add(s3)
    var rng = Xoshiro256(seed=42)
    for _ in range(200):
        var picked = c.pick(rng)
        assert_equal(len(picked), 1)
        var v = picked[0]
        assert_true(v == 0xAA or v == 0xBB or v == 0xCC)


def test_pick_empty_corpus() raises:
    """Calling pick() on an empty corpus must return an empty list."""
    var c = Corpus(List[List[UInt8]]())
    var rng = Xoshiro256(seed=1)
    assert_equal(len(c.pick(rng)), 0)


def test_max_size_eviction() raises:
    """Adding beyond MAX_CORPUS_SIZE must evict the oldest entry."""
    var c = Corpus(List[List[UInt8]]())
    for i in range(MAX_CORPUS_SIZE):
        var entry: List[UInt8] = [UInt8(i % 256), UInt8(i // 256)]
        c.add(entry)
    assert_equal(c.size(), MAX_CORPUS_SIZE)
    var extra: List[UInt8] = [0xFF, 0xFE, 0xFD, 0xFC]
    c.add(extra)
    assert_equal(c.size(), MAX_CORPUS_SIZE)


def test_fnv1a_different_inputs() raises:
    """FNV-1a must return different hashes for different inputs."""
    var d1: List[UInt8] = [0x01]
    var d2: List[UInt8] = [0x02]
    var d3 = List[UInt8]()
    var a = _fnv1a64(Span[UInt8, _](d1))
    var b = _fnv1a64(Span[UInt8, _](d2))
    var empty = _fnv1a64(Span[UInt8, _](d3))
    assert_not_equal(a, b)
    assert_not_equal(a, empty)
    assert_not_equal(b, empty)


def test_fnv1a_same_input() raises:
    """FNV-1a must return the same hash for the same input."""
    var data: List[UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]
    assert_equal(_fnv1a64(Span[UInt8, _](data)), _fnv1a64(Span[UInt8, _](data)))


def test_pick_covers_all_seeds() raises:
    """Repeated pick() calls must eventually cover every seed in a small corpus.
    """
    var c = Corpus(List[List[UInt8]]())
    var s1: List[UInt8] = [0x01]
    var s2: List[UInt8] = [0x02]
    var s3: List[UInt8] = [0x03]
    c.add(s1)
    c.add(s2)
    c.add(s3)
    var rng = Xoshiro256(seed=77)
    var seen0 = False
    var seen1 = False
    var seen2 = False
    for _ in range(1_000):
        var p = c.pick(rng)
        if len(p) == 1:
            if p[0] == 0x01:
                seen0 = True
            elif p[0] == 0x02:
                seen1 = True
            elif p[0] == 0x03:
                seen2 = True
    assert_true(seen0 and seen1 and seen2)


def test_constructor_from_list() raises:
    """Corpus(seeds) constructor must accept and deduplicate seeds."""
    var seeds = List[List[UInt8]]()
    var s1: List[UInt8] = [0x01]
    var s2: List[UInt8] = [0x02]
    var s3: List[UInt8] = [0x01]
    seeds.append(s1^)
    seeds.append(s2^)
    seeds.append(s3^)
    var c = Corpus(seeds)
    assert_equal(c.size(), 2)


def main() raises:
    print("=" * 60)
    print("test_corpus.mojo")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

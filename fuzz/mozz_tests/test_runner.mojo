"""Tests for the fuzz() runner.

Uses deliberate toy parsers with known bugs to verify that the runner
finds crashes, classifies rejections correctly, and runs cleanly.
"""

from std.testing import assert_equal, assert_true, assert_false, TestSuite
from mozz.runner import fuzz, FuzzConfig, _is_crash


# ── Toy parsers (no test_ prefix, excluded from discovery) ───────────────────


def safe_parser(data: List[UInt8]) raises:
    """Always rejects gracefully, never panics."""
    if len(data) == 0:
        return
    if data[0] == 0xFF:
        raise Error("invalid magic byte")
    if len(data) > 100:
        raise Error("input too long")


def always_ok(data: List[UInt8]) raises:
    """Accepts every input without error."""
    _ = data


def crasher(data: List[UInt8]) raises:
    """Simulates an assertion failure on input [0x00, 0xFF, ...]."""
    if len(data) >= 2 and data[0] == 0x00 and data[1] == 0xFF:
        raise Error("assertion failed: unexpected header")


def panic_on_empty(data: List[UInt8]) raises:
    """Raises 'index out of bounds' for empty input."""
    if len(data) == 0:
        raise Error("index out of bounds: empty input")


# ── Tests ─────────────────────────────────────────────────────────────────────


def test_is_crash_classification() raises:
    """_is_crash must correctly classify known crash markers."""
    assert_true(_is_crash("assertion failed: bad state"))
    assert_true(_is_crash("index out of bounds: len=0"))
    assert_true(_is_crash("null pointer dereference"))
    assert_true(_is_crash("stack overflow"))
    assert_true(_is_crash("panic: unreachable code"))
    assert_false(_is_crash("invalid magic byte"))
    assert_false(_is_crash("input too long"))
    assert_false(_is_crash("EOF"))
    assert_false(_is_crash(""))


def test_runner_no_crash_safe_parser() raises:
    """Calling fuzz() must not raise when the target never crashes."""
    fuzz(
        safe_parser,
        FuzzConfig(
            max_runs=200,
            seed=1,
            verbose=False,
            crash_dir=".mozz_crashes/test_safe",
        ),
    )


def test_runner_no_crash_always_ok() raises:
    """Calling fuzz() on a target that accepts everything must not raise."""
    fuzz(
        always_ok,
        FuzzConfig(
            max_runs=100,
            seed=2,
            verbose=False,
            crash_dir=".mozz_crashes/test_ok",
        ),
    )


def test_runner_finds_crash() raises:
    """Calling fuzz() must find the crash in 'crasher' within 50k runs."""
    var found = False
    var seeds = List[List[UInt8]]()
    var seed_bytes: List[UInt8] = [0x00, 0xFF]
    seeds.append(seed_bytes^)
    try:
        fuzz(
            crasher,
            FuzzConfig(
                max_runs=50_000,
                seed=42,
                verbose=False,
                crash_dir=".mozz_crashes/test_crasher",
            ),
            seeds,
        )
    except e:
        var msg = String(e)
        if msg.find("crash") >= 0 or msg.find("mozz") >= 0:
            found = True
    assert_true(found)


def test_runner_finds_panic_empty() raises:
    """Calling fuzz() must find the empty-input bug in 'panic_on_empty'."""
    var found = False
    try:
        fuzz(
            panic_on_empty,
            FuzzConfig(
                max_runs=1_000,
                seed=7,
                verbose=False,
                crash_dir=".mozz_crashes/test_empty",
            ),
        )
    except e:
        var msg = String(e)
        if msg.find("crash") >= 0 or msg.find("mozz") >= 0:
            found = True
    assert_true(found)


def test_fuzz_config_defaults() raises:
    """FuzzConfig() default values must match the specification."""
    var cfg = FuzzConfig()
    assert_equal(cfg.max_runs, 100_000)
    assert_equal(cfg.max_input_len, 65_540)
    assert_equal(cfg.seed, UInt64(0))
    assert_equal(cfg.crash_dir, ".mozz_crashes")
    assert_true(cfg.verbose)
    assert_equal(cfg.timeout_ms, 0)


def test_fuzz_config_custom() raises:
    """FuzzConfig with custom values must store them correctly."""
    var cfg = FuzzConfig(
        max_runs=500,
        seed=99,
        verbose=False,
        crash_dir="custom-crashes",
        corpus_dir="my-corpus",
        max_input_len=1024,
    )
    assert_equal(cfg.max_runs, 500)
    assert_equal(cfg.seed, UInt64(99))
    assert_false(cfg.verbose)
    assert_equal(cfg.crash_dir, "custom-crashes")
    assert_equal(cfg.corpus_dir, "my-corpus")
    assert_equal(cfg.max_input_len, 1024)


def test_runner_user_seeds() raises:
    """Extra seeds passed to fuzz() must be used without crashing."""
    var seeds = List[List[UInt8]]()
    var s1: List[UInt8] = [0x48, 0x54, 0x54, 0x50]  # "HTTP"
    var s2: List[UInt8] = [0x47, 0x45, 0x54, 0x20]  # "GET "
    seeds.append(s1^)
    seeds.append(s2^)
    fuzz(
        safe_parser,
        FuzzConfig(
            max_runs=100,
            seed=5,
            verbose=False,
            crash_dir=".mozz_crashes/test_seeds",
        ),
        seeds,
    )


def main() raises:
    print("=" * 60)
    print("test_runner.mojo")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

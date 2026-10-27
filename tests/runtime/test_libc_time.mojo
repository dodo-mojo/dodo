"""Tests for the libc time FFI in ``dodo.runtime._libc_time``.

An older Mojo passed the argument of an inferred-signature
``external_call["usleep"]`` wrongly, so a 1 ms sleep took ~1.5 s.
Mojo 1.2.0 no longer does, on its own or with thousands of threads
in the process, but these tests keep checking the wall-clock
semantics so a regression shows up here first.

The upper bounds are generous: kernel scheduling, CI noise and debug
builds can all push a sleep past its request. The tests fail when a
sleep returns *too quickly* (no sleep happened) or takes orders of
magnitude too long (the old stretch is back).
"""

from std.ffi import c_int, external_call
from std.testing import (
    assert_equal,
    assert_true,
    TestSuite,
)
from std.time import monotonic

from dodo.runtime import libc_usleep, libc_nanosleep_ms, monotonic_now_ms
from dodo.runtime._thread import ThreadHandle, _OpaquePtr


# ── Helpers ────────────────────────────────────────────────────────────────


@always_inline
def _elapsed_ms_since(t0: Int) -> Int:
    """Monotonic ms since ``t0`` (a previous ``monotonic()`` value)."""
    return Int((monotonic() - t0) // 1_000_000)


# ── libc_usleep ────────────────────────────────────────────────────────────


def test_usleep_small_returns_zero() raises:
    var rc = libc_usleep(10_000)
    assert_equal(rc, 0)


def test_usleep_zero_is_noop() raises:
    var t0 = monotonic()
    var rc = libc_usleep(0)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_equal(rc, 0)
    assert_true(elapsed_ms < 5)


def test_usleep_negative_is_noop() raises:
    var t0 = monotonic()
    var rc = libc_usleep(-100)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_equal(rc, 0)
    assert_true(elapsed_ms < 5)


def test_usleep_10ms_takes_at_least_5ms() raises:
    """10 ms request must take at least 5 ms wall-clock — catches
    the ZERO-extension bug class. Upper bound is loose (50 ms) to
    survive CI scheduling jitter."""
    var t0 = monotonic()
    var rc = libc_usleep(10_000)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_equal(rc, 0)
    assert_true(
        elapsed_ms >= 5,
        "usleep(10ms) returned in <5ms — likely no actual sleep",
    )
    assert_true(
        elapsed_ms < 200,
        "usleep(10ms) took >=200ms — the old sleep stretch is back",
    )


# ── libc_nanosleep_ms ──────────────────────────────────────────────────────


def test_nanosleep_zero_is_noop() raises:
    var t0 = monotonic()
    var rc = libc_nanosleep_ms(0)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_equal(rc, 0)
    assert_true(elapsed_ms < 5)


def test_nanosleep_negative_is_noop() raises:
    var t0 = monotonic()
    var rc = libc_nanosleep_ms(-25)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_equal(rc, 0)
    assert_true(elapsed_ms < 5)


def test_nanosleep_50ms_within_budget() raises:
    """50 ms request takes 25-500 ms wall-clock — the lower bound
    catches "no sleep happened" and the upper bound catches the old
    sleep stretch."""
    var t0 = monotonic()
    var rc = libc_nanosleep_ms(50)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_equal(rc, 0)
    assert_true(
        elapsed_ms >= 25,
        "nanosleep_ms(50) returned in <25ms — likely no actual sleep",
    )
    assert_true(
        elapsed_ms < 500,
        "nanosleep_ms(50) took >=500ms — the old sleep stretch is back",
    )


def test_nanosleep_200ms_takes_at_least_100ms() raises:
    """Multi-100ms budget. Catches multiplier-style bugs that
    smaller sleeps can't distinguish from kernel jitter."""
    var t0 = monotonic()
    var rc = libc_nanosleep_ms(200)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_equal(rc, 0)
    assert_true(
        elapsed_ms >= 100,
        "nanosleep_ms(200) took <100ms — bug",
    )
    assert_true(
        elapsed_ms < 1500,
        "nanosleep_ms(200) took >=1500ms — the old sleep stretch is back",
    )


# ── monotonic_now_ms ─────────────────────────────────────────────


def test_monotonic_is_non_decreasing() raises:
    """The steady clock never runs backwards across consecutive reads."""
    var a = monotonic_now_ms()
    var b = monotonic_now_ms()
    assert_true(b >= a, "monotonic_now_ms went backwards")


def test_monotonic_tracks_a_sleep() raises:
    """A ~50 ms sleep advances the steady clock by at least 25 ms and
    not absurdly more (catches a unit / scaling bug in the wrapper)."""
    var t0 = monotonic_now_ms()
    _ = libc_nanosleep_ms(50)
    var elapsed = monotonic_now_ms() - t0
    assert_true(
        elapsed >= 25,
        "monotonic_now_ms advanced <25ms over a 50ms sleep",
    )
    assert_true(
        elapsed < 2000,
        "monotonic_now_ms advanced >=2000ms over a 50ms sleep — scaling bug",
    )


# ── Stress: 100x 1ms sleeps must total <300ms wall ────────────────────────


def test_hundred_one_ms_sleeps_within_2000ms() raises:
    """100 sequential nanosleep_ms(1) calls must total under
    2000 ms (20 ms per call upper bound). The bound is generous
    on purpose: under-loaded GitHub Actions runners have been
    observed to take ~7-8 ms per 1 ms sleep (kernel scheduling
    on a contended VM). The test still catches the old ~1000x sleep
    stretch (which would push the total past 100,000 ms) and any
    per-call overhead in the tens of milliseconds.
    """
    var t0 = monotonic()
    for _ in range(100):
        _ = libc_nanosleep_ms(1)
    var elapsed_ms = _elapsed_ms_since(t0)
    assert_true(
        elapsed_ms < 2000,
        "100x nanosleep_ms(1) totaled "
        + String(elapsed_ms)
        + "ms; expected <2000ms (the old sleep stretch would"
        + " push this past 100,000ms)",
    )


# ── Many threads: sleeps stay accurate in a busy process ───────────────────

comptime _PARKED_THREADS = 500


def _park_on_pipe(arg: _OpaquePtr) -> _OpaquePtr:
    """Block in ``read`` until the pipe's write end is closed."""
    var byte = UInt8(0)
    _ = external_call["read", Int](c_int(Int(arg)), Pointer(to=byte), 1)
    return arg


def test_one_ms_sleeps_stay_accurate_with_many_threads() raises:
    """Sleeps are as accurate with hundreds of threads in the process.

    The code once assumed a sleep stretched ~1000x in a multi-threaded
    process and avoided sleeping there. 50 sleeps of 1 ms with 500
    parked threads must total under 1000 ms (the stretch would take
    about 50 s).
    """
    var fds = List[c_int](length=2, fill=0)
    if external_call["pipe", c_int](fds.unsafe_ptr()) != 0:
        raise Error("pipe() failed")
    var parked = List[ThreadHandle]()
    for _ in range(_PARKED_THREADS):
        parked.append(
            ThreadHandle.spawn_os[_park_on_pipe](
                _OpaquePtr(unsafe_from_address=Int(fds[0]))
            )
        )

    var t0 = monotonic()
    for _ in range(50):
        _ = libc_nanosleep_ms(1)
    var elapsed_ms = _elapsed_ms_since(t0)

    _ = external_call["close", c_int](fds[1])
    for i in range(len(parked)):
        parked[i].join()
    _ = external_call["close", c_int](fds[0])

    assert_true(
        elapsed_ms >= 25,
        "50x nanosleep_ms(1) took <25ms — likely no actual sleep",
    )
    assert_true(
        elapsed_ms < 1000,
        "50x nanosleep_ms(1) with "
        + String(_PARKED_THREADS)
        + " threads took "
        + String(elapsed_ms)
        + "ms; expected <1000ms",
    )


def main() raises:
    print("=" * 60)
    print("test_libc_time.mojo — libc time FFI semantics")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

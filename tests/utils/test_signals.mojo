"""Tests for dodo.utils.signals. Changes process-wide signal handling, so
it runs as its own process (see EXCLUDE in gen_test_aggregates.py)."""

from std.testing import TestSuite, assert_equal, assert_true
from std.time import perf_counter_ns

from dodo.utils import getpid, kill
from dodo.utils.process import run, spawn
from dodo.utils.signals import (
    stop_watching_signals,
    take_signal,
    wait_for_signal,
    watch_signals,
)


def test_nothing_recorded_at_start() raises:
    watch_signals()
    assert_equal(take_signal(), 0)


def test_sigterm_recorded_once() raises:
    watch_signals()
    _ = kill(getpid(), 15)
    assert_equal(take_signal(), 15)
    assert_equal(take_signal(), 0)


def test_sigint_recorded() raises:
    watch_signals()
    _ = kill(getpid(), 2)
    assert_equal(take_signal(), 2)


def test_sighup_recorded() raises:
    watch_signals()
    _ = kill(getpid(), 1)
    assert_equal(take_signal(), 1)


def test_repeated_signals_keep_the_last() raises:
    watch_signals()
    _ = kill(getpid(), 2)
    _ = kill(getpid(), 2)
    _ = kill(getpid(), 15)
    assert_equal(take_signal(), 15)
    assert_equal(take_signal(), 0)


def test_watch_twice_clears_old_signal() raises:
    watch_signals()
    _ = kill(getpid(), 2)
    watch_signals()
    assert_equal(take_signal(), 0)


def test_child_gets_default_handling() raises:
    watch_signals()
    var status = run(["sh", "-c", "kill -TERM $$"])
    assert_equal(status.signal, 15)
    assert_equal(take_signal(), 0)


def test_stop_then_watch_again() raises:
    stop_watching_signals()
    watch_signals()
    _ = kill(getpid(), 15)
    assert_equal(take_signal(), 15)


def _ms_since(started: Int) -> Int:
    return Int((perf_counter_ns() - started) // 1_000_000)


def test_wait_returns_at_once_for_a_recorded_signal() raises:
    watch_signals()
    _ = kill(getpid(), 15)
    var started = perf_counter_ns()
    wait_for_signal(5_000)
    var took = _ms_since(started)
    assert_true(took < 1_000, String("waited ", took, " ms"))
    assert_equal(take_signal(), 15)


def test_wait_without_a_signal_lasts_its_timeout() raises:
    watch_signals()
    var started = perf_counter_ns()
    wait_for_signal(100)
    var took = _ms_since(started)
    assert_true(took >= 90, String("returned after ", took, " ms"))
    assert_equal(take_signal(), 0)


def test_wait_wakes_for_a_signal_sent_meanwhile() raises:
    watch_signals()
    var sender = spawn(["sh", "-c", String("sleep 0.2; kill -TERM ", getpid())])
    var started = perf_counter_ns()
    wait_for_signal(10_000)
    var took = _ms_since(started)
    _ = sender.wait()
    assert_true(took < 5_000, String("waited ", took, " ms"))
    assert_equal(take_signal(), 15)


def test_a_signal_taken_before_watching_again_does_not_end_a_wait() raises:
    watch_signals()
    _ = kill(getpid(), 2)
    _ = take_signal()
    watch_signals()
    var started = perf_counter_ns()
    wait_for_signal(100)
    var took = _ms_since(started)
    assert_true(took >= 90, String("returned after ", took, " ms"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

"""Tests for dodo.utils.signals. Changes process-wide signal handling, so
it runs as its own process (see EXCLUDE in gen_test_aggregates.py)."""

from std.testing import TestSuite, assert_equal

from dodo.utils import getpid, kill
from dodo.utils.process import run
from dodo.utils.signals import stop_watching_signals, take_signal, watch_signals


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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

"""Deferred idle-timer reaping for the reactor loops.

A loop advances its timer wheel right after ``poll`` but reaps the
connections whose timers fired only after it has handled that poll's
events. These tests pin the decision made in between: a fired connection is
reaped only if nothing re-armed, cleared or replaced its timer since it
fired. (The wire-level behaviour is covered by
``test_server_lifecycle.test_waiting_request_is_served_even_if_its_idle_timer_expired_meanwhile``.)
"""

from std.collections import Dict
from std.testing import assert_equal, assert_true, TestSuite

from dodo.http._reactor.lifecycle import (
    _arm_accept_timer,
    _arm_idle_timer,
    _collect_fired_timers,
    _expired_idle_conns,
    _set_idle_timer,
)
from dodo.runtime import TimerWheel
from dodo.runtime._libc_time import monotonic_now_ms


struct _Fixture(Movable):
    """A wheel plus the loop's ``conns`` / ``timers`` bookkeeping for a few
    fake connections, each with an idle timer due at ``after_ms``."""

    var wheel: TimerWheel
    var conns: Dict[Int, Int]
    var timers: Dict[Int, UInt64]

    def __init__(out self):
        self.wheel = TimerWheel(now_ms=UInt64(1000))
        self.conns = Dict[Int, Int]()
        self.timers = Dict[Int, UInt64]()

    def add(mut self, fd: Int, after_ms: Int) raises:
        self.conns[fd] = fd * 10
        self.timers[fd] = self.wheel.schedule(
            after_ms, UInt64(fd), self.wheel.tick_ms()
        )

    def rearm(mut self, fd: Int, after_ms: Int) raises:
        """What ``_apply_step`` does on a step that sets a new idle timeout."""
        _ = self.wheel.cancel(self.timers[fd])
        self.timers[fd] = self.wheel.schedule(
            after_ms, UInt64(fd), self.wheel.tick_ms()
        )

    def advance_to(
        mut self, now_ms: Int, mut fds: List[Int], mut ids: List[UInt64]
    ) raises:
        _collect_fired_timers(UInt64(now_ms), self.wheel, self.timers, fds, ids)

    def expired(self, fds: List[Int], ids: List[UInt64]) raises -> List[Int]:
        return _expired_idle_conns(fds, ids, self.conns, self.timers)


def test_collecting_fired_timers_closes_nothing() raises:
    var f = _Fixture()
    f.add(7, 500)
    f.add(8, 900)
    var fds = List[Int]()
    var ids = List[UInt64]()
    f.advance_to(2000, fds, ids)
    assert_equal(len(fds), 2)
    assert_true(7 in f.conns and 8 in f.conns, "collect must not reap")


def test_unchanged_connection_is_reaped() raises:
    var f = _Fixture()
    f.add(7, 500)
    var fds = List[Int]()
    var ids = List[UInt64]()
    f.advance_to(1600, fds, ids)
    var out = f.expired(fds, ids)
    assert_equal(len(out), 1)
    assert_equal(out[0], 7)


def test_only_the_timers_that_fired_are_candidates() raises:
    var f = _Fixture()
    f.add(7, 500)
    f.add(8, 5000)
    var fds = List[Int]()
    var ids = List[UInt64]()
    f.advance_to(1600, fds, ids)
    var out = f.expired(fds, ids)
    assert_equal(len(out), 1)
    assert_equal(out[0], 7)


def test_rearmed_connection_is_spared() raises:
    """The request waiting behind the busy handler was served, which re-armed
    the connection's idle timer."""
    var f = _Fixture()
    f.add(7, 500)
    var fds = List[Int]()
    var ids = List[UInt64]()
    f.advance_to(1600, fds, ids)
    f.rearm(7, 500)
    assert_equal(len(f.expired(fds, ids)), 0)


def test_connection_whose_timer_was_cleared_is_spared() raises:
    """A step with ``idle_timeout_ms == 0`` (response in flight) drops the
    timer entry; the connection is active, not idle."""
    var f = _Fixture()
    f.add(7, 500)
    var fds = List[Int]()
    var ids = List[UInt64]()
    f.advance_to(1600, fds, ids)
    _ = f.timers.pop(7)
    assert_equal(len(f.expired(fds, ids)), 0)


def test_connection_closed_meanwhile_is_not_reaped_twice() raises:
    var f = _Fixture()
    f.add(7, 500)
    var fds = List[Int]()
    var ids = List[UInt64]()
    f.advance_to(1600, fds, ids)
    _ = f.conns.pop(7)
    _ = f.timers.pop(7)
    assert_equal(len(f.expired(fds, ids)), 0)


def test_reused_fd_number_is_never_reaped_by_the_old_timer() raises:
    """The old connection closed and the kernel handed its fd number to a
    new one, which has its own, later timer. The expired timer must not close
    the new connection."""
    var f = _Fixture()
    f.add(7, 500)
    var fds = List[Int]()
    var ids = List[UInt64]()
    f.advance_to(1600, fds, ids)
    _ = f.conns.pop(7)
    _ = f.timers.pop(7)
    f.add(7, 500)
    assert_equal(len(f.expired(fds, ids)), 0)


def test_connection_without_a_timer_entry_is_reaped_if_untouched() raises:
    """A fired timer that ``timers`` never tracked keeps the previous
    behaviour: the connection is reaped unless something gave it a timer."""
    var f = _Fixture()
    f.conns[9] = 90
    var fds: List[Int] = [9]
    var ids: List[UInt64] = [UInt64(0)]
    var out = f.expired(fds, ids)
    assert_equal(len(out), 1)
    f.timers[9] = f.wheel.schedule(500, UInt64(9), f.wheel.tick_ms())
    assert_equal(len(f.expired(fds, ids)), 0)


# ── Arming counts from the clock, not from the wheel's last tick ──


struct _Stale(Movable):
    """A wheel that last moved 800 ms ago, as after a long handler."""

    var wheel: TimerWheel
    var timers: Dict[Int, UInt64]
    var now: UInt64

    def __init__(out self):
        self.now = UInt64(monotonic_now_ms())
        self.wheel = TimerWheel(now_ms=self.now - 800)
        self.timers = Dict[Int, UInt64]()

    def fired_by(mut self, ms_from_now: Int) raises -> Int:
        var fired = List[UInt64]()
        self.wheel.advance(self.now + UInt64(ms_from_now), fired)
        return len(fired)


def test_arming_counts_from_the_clock() raises:
    var s = _Stale()
    var counted_from = _arm_idle_timer(7, s.wheel, s.timers, 1000)
    assert_true(counted_from >= s.now, "counted from the wheel's tick")
    assert_equal(s.fired_by(999), 0, "fired early")
    assert_equal(s.fired_by(1100), 1)


def test_arming_again_replaces_the_old_timer() raises:
    var s = _Stale()
    _ = _arm_idle_timer(7, s.wheel, s.timers, 100)
    _ = _arm_idle_timer(7, s.wheel, s.timers, 1000)
    assert_equal(s.wheel.active_count(), 1)
    assert_equal(s.fired_by(999), 0, "the old 100 ms timer fired")


def test_a_step_rearms_clears_or_leaves_the_timer() raises:
    var s = _Stale()
    _set_idle_timer(7, s.wheel, s.timers, 1000)
    assert_equal(s.fired_by(999), 0, "fired early")
    _set_idle_timer(7, s.wheel, s.timers, -1)
    assert_true(7 in s.timers, "a negative timeout must leave the timer")
    _set_idle_timer(7, s.wheel, s.timers, 0)
    assert_true(7 not in s.timers)
    assert_equal(s.wheel.active_count(), 0)


def test_an_accepted_connection_counts_from_the_clock() raises:
    var s = _Stale()
    _arm_accept_timer(9, s.wheel, s.timers, 1000)
    assert_equal(s.fired_by(999), 0, "fired early")
    assert_equal(s.fired_by(1100), 1)


def main() raises:
    print("=" * 60)
    print("test_idle_timer_reap.mojo - deferred idle-timer reaping")
    print("=" * 60)
    TestSuite.discover_tests[__functions_in_module()]().run()

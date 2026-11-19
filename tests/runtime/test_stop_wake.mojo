"""Tests for waking a worker's reactor on stop.

A reactor advertises its wake fd in the worker's stats cell; the
scheduler writes it when it sets the stop flag, so a worker parked in a
long ``poll`` sees the flag at once. The slot must never let a wake land
on an fd the reactor already closed.
"""

from std.memory import Layout, Pointer, alloc
from std.testing import TestSuite, assert_equal, assert_true
from std.time import perf_counter_ns

from dodo.runtime import Event, Frontend, Reactor, Scheduler
from dodo.runtime._libc_time import libc_nanosleep_ms
from dodo.runtime._thread import ThreadHandle, _OpaquePtr
from dodo.runtime.scheduler_stats import (
    WORKER_STAT_SLOTS,
    WORKER_STAT_WAKE_FD,
    WORKER_STATUS_CLEAN,
    WORKER_STAT_STATUS,
    advertise_wake_fd,
    load_stop_flag,
    load_worker_stat,
    store_worker_stat,
    wake_worker,
    withdraw_wake_fd,
)
from dodo.net import SocketAddr


def _new_cell() -> Int:
    var p = alloc(Layout[Int64](count=WORKER_STAT_SLOTS)).unsafe_leak()
    for i in range(WORKER_STAT_SLOTS):
        p[unsafe_offset=i] = Int64(0)
    return Int(p)


def _woke(mut reactor: Reactor) raises -> Bool:
    """Whether a wake is waiting on ``reactor``."""
    var events = List[Event]()
    _ = reactor.poll(0, events)
    for i in range(len(events)):
        if events[i].is_wakeup():
            return True
    return False


def test_a_zeroed_cell_advertises_nothing() raises:
    var cell = _new_cell()
    # Must not write to fd 0 or anywhere else.
    wake_worker(cell)
    assert_equal(load_worker_stat(cell, WORKER_STAT_WAKE_FD), 0)
    wake_worker(0)
    withdraw_wake_fd(0)


def test_an_advertised_reactor_is_woken() raises:
    var cell = _new_cell()
    var reactor = Reactor()
    reactor.advertise_wake_fd(cell)
    assert_equal(
        load_worker_stat(cell, WORKER_STAT_WAKE_FD), reactor.wake_fd() + 1
    )
    assert_true(not _woke(reactor))
    wake_worker(cell)
    assert_true(_woke(reactor))
    # The slot is back to the fd, so a second wake works too.
    wake_worker(cell)
    assert_true(_woke(reactor))


def test_a_destroyed_reactor_withdraws_its_fd() raises:
    var cell = _new_cell()
    var reactor = Reactor()
    reactor.advertise_wake_fd(cell)
    _ = reactor^
    assert_equal(load_worker_stat(cell, WORKER_STAT_WAKE_FD), 0)
    wake_worker(cell)


def test_a_withdrawn_fd_is_not_woken() raises:
    var cell = _new_cell()
    var reactor = Reactor()
    reactor.advertise_wake_fd(cell)
    withdraw_wake_fd(cell)
    wake_worker(cell)
    assert_true(not _woke(reactor))


def test_advertising_again_moves_the_fd() raises:
    var first = _new_cell()
    var second = _new_cell()
    var reactor = Reactor()
    reactor.advertise_wake_fd(first)
    reactor.advertise_wake_fd(second)
    assert_equal(load_worker_stat(first, WORKER_STAT_WAKE_FD), 0)
    wake_worker(second)
    assert_true(_woke(reactor))


def _free_slot_later(arg: _OpaquePtr) -> _OpaquePtr:
    """Thread body: play a wake in progress for 100 ms, then end it."""
    var cell = Int(arg)
    _ = libc_nanosleep_ms(100)
    store_worker_stat(cell, WORKER_STAT_WAKE_FD, 7)
    return arg


def test_withdraw_waits_out_a_wake_in_progress() raises:
    var cell = _new_cell()
    # -1 is the slot's "a wake is being written" state.
    store_worker_stat(cell, WORKER_STAT_WAKE_FD, -1)
    var started = perf_counter_ns()
    var thread = ThreadHandle.spawn_os[_free_slot_later](
        _OpaquePtr(unsafe_from_address=cell)
    )
    withdraw_wake_fd(cell)
    var waited_ms = (perf_counter_ns() - started) // 1_000_000
    thread.join()
    assert_true(waited_ms >= 90, String("returned after ", waited_ms, " ms"))
    assert_equal(load_worker_stat(cell, WORKER_STAT_WAKE_FD), 0)


@fieldwise_init
struct _ParkedFrontend(Copyable, Frontend):
    """Parks each worker in a 10 s poll, so only a wake ends it soon."""

    var tag: Int

    def run_worker(
        mut self,
        listener_fd: Int,
        mut stopping: Bool,
        stats_addr: Int,
        extra_fds: List[Int] = List[Int](),
    ):
        try:
            var reactor = Reactor()
            reactor.advertise_wake_fd(stats_addr)
            var stopping_addr = Int(Pointer[Bool, _](to=stopping))
            var events = List[Event]()
            while not load_stop_flag(stopping_addr):
                events.clear()
                _ = reactor.poll(10_000, events)
        except:
            pass
        store_worker_stat(stats_addr, WORKER_STAT_STATUS, WORKER_STATUS_CLEAN)


def test_shutdown_wakes_workers_parked_in_poll() raises:
    var scheduler = Scheduler[_ParkedFrontend].start(
        addr=SocketAddr.localhost(0), frontend=_ParkedFrontend(0), num_workers=4
    )
    # Let every worker reach its poll.
    _ = libc_nanosleep_ms(200)
    var started = perf_counter_ns()
    scheduler.shutdown()
    var took_ms = (perf_counter_ns() - started) // 1_000_000
    assert_true(took_ms < 2_000, String("shutdown took ", took_ms, " ms"))


def test_drain_wakes_workers_parked_in_poll() raises:
    var scheduler = Scheduler[_ParkedFrontend].start(
        addr=SocketAddr.localhost(0), frontend=_ParkedFrontend(0), num_workers=2
    )
    _ = libc_nanosleep_ms(200)
    var started = perf_counter_ns()
    var reports = scheduler.drain(5_000)
    var took_ms = (perf_counter_ns() - started) // 1_000_000
    scheduler.shutdown()
    assert_equal(len(reports), 2)
    assert_true(took_ms < 2_000, String("drain took ", took_ms, " ms"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

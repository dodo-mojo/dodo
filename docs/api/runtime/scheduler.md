# `dodo.runtime.scheduler`

Multicore scheduler: 1 shared listener, N reactors, N workers.

Runs N single-threaded reactor loops in parallel, one per worker thread,
all sharing a *single* listener fd. Each worker registers the
listener fd in its own reactor with ``EPOLLEXCLUSIVE`` (on Linux
>= 4.5) so the kernel wakes exactly one worker per accept event.
On macOS / kqueue the flag is unavailable and registration falls
back to plain ``register`` — the practical behaviour is similar
because non-blocking ``accept`` returns ``EAGAIN`` on the losers.

This is the redesign of the multicore path. the prior implementation
used N independent listeners bound with ``SO_REUSEPORT``; the
kernel then distributed accepted connections across workers by
hashing each connection's 4-tuple to one of the N listeners. That
scheme has a known fairness gap under bursty arrival: a
256-connection storm from a wrk2-style load generator can land
80+ conns on one worker and 30 on another, producing
hundreds-of-millisecond head-of-line tail latency on the
overloaded worker(s). ``benchmark/configs/throughput_mc``
shows the failure mode at p99 ≈ 1.7 s; the
``EPOLLEXCLUSIVE``-based shared-listener design collapses the
same workload's p99 to the millisecond range.

Shutdown path: ``shutdown()`` flips a heap-allocated ``Bool`` that
every worker polls on each reactor iteration. A stable heap address
is used (instead of a field on the ``Scheduler`` struct) so the flag
survives the NRVO-or-not move from ``Scheduler.start`` back to the
caller. The main thread joins all workers, and only then closes the
shared listener fd (once), before ``shutdown()`` returns.

The listener is never closed to wake the workers. On Linux an fd that
is also registered in a worker's ``epoll`` instance is kept alive by
the kernel, so ``close()`` from another thread triggers no ``EPOLLHUP``
and the workers stay blocked in ``epoll_wait`` until the 100 ms poll
timeout fires; and closing it early let a worker that polled a batch
before it saw the flag ``accept`` on a reused number. The
heap flag is what breaks the loop.

This module is :trait:`Frontend`-generic: every worker calls
:meth:`Frontend.run_worker` once with its assigned listener fd
and the shared stopping flag. The frontend value is moved
(per-worker copies are made via ``F.copy()``; if that's expensive
users should wrap their handler's expensive state behind an
``Pointer`` or a similar shared-reference holder).

The scheduler depends only on the :trait:`dodo.runtime.Frontend`
trait; concrete impls live where their protocol does
(:class:`dodo.http.frontend.HttpFrontend`,
:class:`dodo.http.frontend.StreamFrontend`).

Known limitations:

- The stopping flag is a heap-allocated byte written from the main
  thread and read from each worker through ``Atomic[UInt8]``
  release-store / acquire-load (``store_stop_flag`` /
  ``load_stop_flag``). This gives the workers a proper happens-before
  edge on shutdown and lowers to a plain ``mov`` on x86-64 (TSO) and
  to ``stlr`` / ``ldar`` on ARM64. The per-iteration re-materialisation
  of the pointer inside the frontend's serving loop still defeats the
  optimiser's LICM so every iteration re-reads the flag.
- Worker panics that escape :meth:`Frontend.run_worker` are caught and
  discarded in ``_worker_entry`` because pthread has no exception
  channel. ``is_running()`` still reports ``True`` until the
  ``ThreadHandle`` is joined, which is a mildly wrong signal for a
  worker that crashed rather than shut down cleanly. Plumbing a
  per-worker error cell back to the Scheduler is also scheduled for a future release.
  .

## Structs

### `ShutdownReport`

```mojo
struct ShutdownReport
```

Per-worker drain summary returned by :meth:`Scheduler.drain`.

Originally defined under ``dodo.http.server`` and imported back
by the scheduler; promoted into :mod:`dodo.runtime` to break
the runtime → http import cycle. ``dodo.http.server`` re-exports
this type so the public ``dodo.http.ShutdownReport`` surface is
unchanged.

The per-worker registry that would let us count individual
in-flight connections lives on each worker's stack today;
until that registry is published back through a shared
atomic, ``in_flight_at_deadline`` is the coarse 0/1 signal
driven by whether the worker's join completed inside the
budget.

Fields:
    drained: Connections that completed their in-flight work
        inside the drain timeout. Best-effort.
    timed_out: Connections that were force-closed because the
        drain timeout elapsed before they finished. Best-effort.
    in_flight_at_deadline: Connections still alive at the
        instant the timeout fired (== ``timed_out`` after the
        force-close completes).
    crashed: 1 if this worker's last run exited crashed (poll
        failure) rather than cleanly, else 0. Mirrors the
        per-worker slot behind ``crashed_worker_count()`` so a
        caller can attribute a crash to a specific worker.

Fields:

- `drained` (`Int`)
- `timed_out` (`Int`)
- `in_flight_at_deadline` (`Int`)
- `crashed` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

### `Scheduler`

```mojo
struct Scheduler[F: Frontend]
```

Owns ``num_workers`` workers, each running a frontend's serving loop sharing a single listener fd (or its own SO_REUSEPORT listener when the strategy demands).

Usage:
    ```mojo
    from dodo.http import HttpFrontend
    var frontend = HttpFrontend(handler^, config^)
    var s = Scheduler[HttpFrontend[MyHandler]].start(
        addr, frontend^, num_workers=4
    )
    # ... server running ...
    s.shutdown()
    ```

Notes:
- The scheduler stores the workers' ``ThreadHandle`` values and
  a heap-allocated stopping flag. ``shutdown()`` writes through
  that heap address and joins all workers.
- The stopping flag lives on the heap (not on this struct) so
  its address survives the move from ``Scheduler.start`` back
  to the caller; every worker captures that address once at
  spawn time.
- **Listener strategy.** Default: each worker pre-binds
  its own ``SO_REUSEPORT`` listener (the kernel hashes
  new 4-tuples to one of N pre-bound listeners; matches
  actix_web's listener strategy and gives the highest
  steady-state throughput on dev-box workloads). Opt out
  by exporting ``DODO_REUSEPORT_WORKERS=0`` before
  ``start`` to switch to a single shared listener bound
  via ``bind_shared`` and registered with
  ``Reactor.register_exclusive`` (``EPOLLEXCLUSIVE`` on
  Linux >= 4.5) — the kernel wakes one worker per
  accept event, idle workers absorb spikes, p99.99 σ
  is uniformly tighter under sustained load for 7-22 %
  less req/s depending on path (see
  ``docs/benchmark.md``).
- The frontend value is cloned into each worker via
  ``F.copy()``.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Scheduler.__init__`

```mojo
def __init__(out self)
```

Build an empty scheduler; use ``Scheduler.start`` instead.

#### `Scheduler.start`

```mojo
def start(addr: SocketAddr, var frontend: F, num_workers: Int, pin_cores: Bool = True, extra_addrs: List[SocketAddr] = List(), listener_fds: List[Int] = List()) raises -> Self
```

Spawn ``num_workers`` threads sharing one listener.

The scheduler binds its listener(s) according to the
``DODO_REUSEPORT_WORKERS`` env knob and the number of addresses, then hands one fd
per worker into :meth:`Frontend.run_worker`. The frontend
encapsulates everything protocol-specific (handler,
request config, HTTP/2 settings, auto-protocol toggle,
backend selection); the runtime layer no longer knows
any of those flags exist.

Args:

- `addr`: Address the listener(s) bind.
- `frontend`: Per-worker run target. Cloned per worker via :meth:`Frontend.copy`.
- `num_workers`: Number of worker threads. Must be in ``1..=256``; values outside that range raise. The upper bound is a defensive guard against runaway ``pthread_create`` + heap allocation.
- `pin_cores`: If ``True`` (default), pin worker N to core ``N % num_cpus``. No-op on macOS.
- `extra_addrs`: Additional addresses to serve. Each worker gets its own ``SO_REUSEPORT`` listener on every one, so N addresses x M workers binds N*M listeners, all serially on this thread. Empty (default) preserves the single-address behaviour exactly. Every extra address must be bindable with ``SO_REUSEPORT``, so any earlier listener on it must either be closed or be handed over through ``listener_fds``.
- `listener_fds`: Listeners the caller already bound, as bare fds: ``addr``'s first, then one per extra address in order. Empty (default) means the scheduler binds every listener itself. When given, worker 0 serves them next to new ``SO_REUSEPORT`` listeners (or, with one shared listener, every worker does), so the addresses are never left without a listener. A single one without ``SO_REUSEPORT`` is shared by every worker. The scheduler owns them from the call on and closes them, also when ``start`` raises.

Returns: A running ``Scheduler`` whose workers will continue to serve until ``shutdown()`` is called.

Raises: Error: If ``num_workers`` is outside ``1..=256``, if the listener fails to bind, or if spawning a worker fails; partially-started workers are best-effort joined before re-raising.

#### `Scheduler.shutdown`

```mojo
def shutdown(mut self) raises
```

Signal every worker to stop and wait for them to join.

Flips the heap-allocated stopping flag (what breaks the
workers' loops), joins all worker threads, records the crash
count, and frees every worker context, listener (the shared
one is closed here, after the join), stats cell, and the
stopping-flag heap cell. Idempotent — a second call finds the state empty
and is a no-op.

#### `Scheduler.is_running`

```mojo
def is_running(self) -> Bool
```

Return True if any worker has not yet joined.

Note: this only tracks join state. To tell a crash from a
clean shutdown after the workers have joined, read
``crashed_worker_count()`` (populated by ``shutdown`` /
``drain`` from the per-worker exit-status cells).

#### `Scheduler.crashed_worker_count`

```mojo
def crashed_worker_count(self) -> Int
```

Number of workers whose last run exited crashed (poll failure), captured during the most recent ``shutdown`` / ``drain``. 0 after a clean shutdown.

#### `Scheduler.drain`

```mojo
def drain(mut self, timeout_ms: Int) raises -> List[ShutdownReport]
```

Graceful multi-worker shutdown.

Broadcasts the stopping flag to every worker, closes every
worker's listener socket, waits up to ``timeout_ms`` for
workers to drain in-flight work, then joins. Returns one
``ShutdownReport`` per worker — best-effort counts based on
whether the worker joined inside the timeout.

Each worker publishes its live-connection count to a shared
per-worker stats cell on every reactor iteration (release
store), so once the worker joins the Scheduler reads a real
``in_flight_at_deadline`` (acquire load) instead of the old
fabricated 0 / 1. Those remaining connections are force-closed
during the worker's graceful-shutdown pass, so ``timed_out``
mirrors that count. ``drained`` stays a coarse budget signal
(1 when a positive drain budget was given, 0 on a hard cut):
the reactor does not count naturally-completed connections, so
an exact "finished vs cut" split is not available in this
force-close model.

``timeout_ms`` bounds the wait. A worker whose thread has not
returned by then (a handler that will not finish) is detached
and reported with ``drained == 0``; its context, stats cell and
listeners (its own, not the joined workers'), the shared listener
(opt-out shape), and the shared stop flag, are left allocated, since the
thread may still be using them. ``timeout_ms <= 0`` is a hard stop: no drain window,
and every worker is joined, as ``shutdown()`` does.

Args:

- `timeout_ms`: Max ms to wait for the workers to drain.

Returns: ``List[ShutdownReport]`` of length ``num_workers`` (the count at start time). ``in_flight_at_deadline`` / ``timed_out`` are the real per-worker live-connection counts; ``drained`` is the budget signal.

## Functions

### `default_worker_count`

```mojo
def default_worker_count() -> Int
```

Sensible default worker count: ``num_cpus()``.

For IO-bound HTTP plaintext the best throughput is usually
num_cpus workers; CPU-heavy handlers may prefer num_cpus // 2 to
leave headroom for the kernel network stack.

# `dodo.runtime`

``dodo.runtime`` — event-loop primitives for the Stage 1 reactor.

Public exports, by area:

- Reactor: ``Reactor``, ``Event``, ``INTEREST_READ``,
  ``INTEREST_WRITE``, ``EVENT_READABLE``, ``EVENT_WRITABLE``,
  ``EVENT_ERROR``, ``EVENT_HUP``, ``WAKEUP_TOKEN``, ``LISTENER_TOKEN``.
- Scheduling: ``Scheduler``, ``Frontend``, ``TimerWheel``,
  ``num_cpus``, ``default_worker_count``, ``block_in_pool``.
- Buffers and memory: ``Pool``, ``BufferPool``, ``BufferHandle``,
  ``IoVecBuf``, ``writev_buf``.
- Cross-worker handoff: ``HandoffQueue``, ``WorkerHandoffPool``,
  ``HandoffPolicy``.
- Misc: ``DateCache`` and the time helpers.

Read the module source for the authoritative list; names here that are
not re-exported from this barrel carry no stability guarantee.

``Reactor`` wraps ``epoll`` (Linux) and ``kqueue`` (macOS) behind a uniform
API. Use it to build single-threaded servers that handle many concurrent
connections from one OS thread. See the module docstring on ``Reactor`` for
an end-to-end example.

For multicore servers, use ``HttpServer.serve(handler, num_workers=N)``
with ``N >= 2`` and size ``N`` with ``num_cpus()`` (total logical CPUs) or
``default_worker_count()`` (sensible default for IO-bound handlers).

## Modules

- [`dodo.runtime.blocking`](blocking.md): Blocking-escape hatch: ``block_in_pool``.
- [`dodo.runtime.buffer_pool`](buffer_pool.md): Per-worker, size-class-bucketed buffer pool.
- [`dodo.runtime.date_cache`](date_cache.md): Per-worker monotonic Date-header cache.
- [`dodo.runtime.event`](event.md): Event primitives for the dodo reactor.
- [`dodo.runtime.frontend`](frontend.md): Worker-target trait for the multicore :class:`Scheduler`.
- [`dodo.runtime.handoff`](handoff.md): Cross-worker connection handoff.
- [`dodo.runtime.iovec`](iovec.md): ``writev(2)`` vectored-I/O primitive.
- [`dodo.runtime.pool`](pool.md): Typed heap-allocator wrapper.
- [`dodo.runtime.reactor`](reactor.md): Reactor: the event-loop core powering dodo's single-threaded HTTP server.
- [`dodo.runtime.reuseport`](reuseport.md): ``SO_REUSEPORT`` helpers for thread-per-core listeners.
- [`dodo.runtime.scheduler`](scheduler.md): Multicore scheduler: 1 shared listener, N reactors, N workers.
- [`dodo.runtime.scheduler_stats`](scheduler_stats.md): Cross-thread stop flag and per-worker stats cell.
- [`dodo.runtime.timer_wheel`](timer_wheel.md): Hashed timing wheel for the dodo reactor.
- [`dodo.runtime.watchdog`](watchdog.md): Deadline watchdog: a background thread that flips Cancel cells on expiry.

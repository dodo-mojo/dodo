# `dodo.runtime.blocking`

Blocking-escape hatch: ``block_in_pool``.

The reactor's hot path is single-threaded per worker; any
blocking syscall (synchronous DB query, libc ``getaddrinfo``,
file I/O on a slow disk, CPU-heavy compute) freezes the worker
for the duration. The fix is to offload the blocking work to
another thread:

```mojo
var rows = block_in_pool[List[Row]](
    lambda: db.query("SELECT ..."),
    cancel,
)
```

The handler stays in straight-line code; ``cancel`` short-
circuits if the request is cancelled mid-blocking-call.

Implementation: one dedicated OS thread per call.

Each ``block_in_pool[T]`` call runs ``work()`` on a fresh pthread
(``ThreadHandle.spawn_os``), surfaces the result back through a
heap-allocated task struct, and joins the thread.

Notes on the design:

1. Not an AsyncRT task. A reactor worker is itself a pool task, and
   a pool join donates the waiting thread: it runs queued tasks,
   its own ``work()`` included, so ``work()`` would block the very
   reactor it was meant to spare. ``pthread_join`` only waits. The
   price is a ``pthread_create`` per call (~30-50 µs on Linux
   x86_64), small next to work worth offloading. ADR-0004's pool
   replaces this.
2. A blocking ``work()`` holds its own thread, never a pool worker,
   so it cannot starve the reactors or the stdlib's tasks.
3. The MAX_POOL_SIZE cap (32) is enforced process-wide via a
   kernel-backed POSIX named semaphore shared by ``block_in_pool``
   and ``resolve_async``: a call that would exceed the cap raises
   "pool saturated" instead of spawning the over-limit thread, so a
   fan-out burst cannot thread-bomb the process. The mechanism is
   fail-closed (if the semaphore cannot be opened, e.g. under fd
   exhaustion, the call is refused with the same error rather than
   running uncapped) and per-process (keyed by pid, since Mojo has no
   module-level mutable globals).

What the split actually buys:

- Blocking syscalls inside ``work()`` run on their own thread, so
  the kernel can schedule other reactor workers onto the freed CPU
  while the syscall is waiting.
- Multi-worker parallelism: N concurrent connections on N
  reactor workers each calling ``block_in_pool`` get up to N
  parallel ``work()`` executions, instead of being serialised
  inside each reactor worker.

What it does NOT buy (and why):

- The submitter (handler) thread is still blocked while
  ``work()`` runs. The synchronous public signature
  ``def block_in_pool[T](work, cancel) raises -> T`` requires
  this — to release the reactor's connection-loop while
  ``work()`` is in flight we'd need either Mojo async or a
  new "park this connection" reactor state.

Cancel contract (unchanged from the in-thread fallback):

- **Pre-flight:** if ``cancel`` is already flipped at entry,
  raise immediately without spawning anything.
- **In-flight:** the user's ``work()`` is responsible for
  polling ``cancel`` if it wants to short-circuit mid-call
  (the work runs on another thread that can read the cancel
  cell directly). The library cannot preempt — Mojo doesn't
  expose preemption and thread cancellation is unsafe under
  the borrow checker.
- **Post-flight:** the submitter joins the task until
  ``work()`` returns; on join it checks the cancel cell
  one more time. If the cell flipped while ``work()`` ran,
  raise with a "cancelled mid-flight (<reason>)" message
  instead of returning a now-stale result.

Why join rather than poll-on-done-flag:

Polling a done flag would let a mid-flight cancel raise before
``work()`` returns, but every poll interval adds latency to every
call, and the caller is blocked either way. Joining wakes the
caller the moment ``work()`` returns, so per-call latency is the
spawn + work + join cost.

The trade-off is that mid-flight cancel no longer raises
*before* ``work()`` returns; it raises *after*. Handlers that
care about fast-cancel during long work can poll ``cancel``
inside ``work()``.

## Aliases

### `MAX_POOL_SIZE`

```mojo
comptime MAX_POOL_SIZE = Int(32)
```

## Functions

### `block_in_pool`

```mojo
def block_in_pool[T: Deinitable & Movable](work: def() raises thin -> T, cancel: Cancel) raises -> T
```

Run ``work()`` on another thread; wait for its result on the calling thread.

``work()`` runs on a fresh OS thread, never on the caller's (see
the module docstring for why it is not a pool task).

Pre-flight: if ``cancel`` is already flipped at entry, raise
without spawning anything.

On success, returns the ``T`` produced by ``work()``. If
``work()`` raises, the error is propagated (truncated to
``_ERR_BUF_CAP - 1`` bytes if longer).

Mid-flight: if ``cancel.cancelled()`` flips before the
worker thread completes, raise with a "cancelled mid-flight
(<reason>)" message. The worker thread runs to completion
in the background; the submitter does not wait for it.

Post-flight: if the cell flipped while ``work()`` ran (but
the submitter still saw ``done_flag`` first), raise with a
"cancelled mid-flight (<reason>)" message instead of
returning the now-stale result.

Args:

- `work`: Zero-arg callable returning ``T``.
- `cancel`: Per-request cancel token.

Returns: The ``T`` produced by ``work()``.

Raises: Error: Pre-flight cancel, mid-flight cancel, post-flight cancel, or ``work()`` raised.

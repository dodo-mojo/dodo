# `dodo.runtime.watchdog`

Deadline watchdog: a background thread that flips Cancel cells on expiry.

Mojo cannot preempt synchronous code -- a handler that never yields
runs to completion on its worker no matter what. The reactor can only
observe a deadline at the points it owns (request-read edges, streaming
writable edges). To give a *time-based* deadline any teeth against a
handler that at least cooperatively polls its ``Cancel`` token, a
separate OS thread must watch the clock and flip the cell; the worker
thread is busy inside the handler and cannot watch its own deadline.

That is exactly what :struct:`DeadlineWatchdog` does (the K2 mechanism
the assessment names): one background thread polls a fixed table of
``(deadline_ms, cancel_cell_addr)`` slots and, when a slot's deadline
passes, writes ``CancelReason.TIMEOUT`` into that cell with a release
store -- the same cell + ordering :struct:`dodo.http.cancel.CancelCell`
uses, so a ``CancelHandler`` polling ``cancel.cancelled()`` observes it.

This is cooperative, not true preemption: a handler that never checks
its cancel token is still not interruptible (a Mojo language limit, not
a design choice) -- for those, ``PostHocDeadline`` still refuses the
too-late response. What the watchdog adds is real mid-flight
cancellation for handlers that *do* cooperate, which the on-worker
reactor cannot deliver by itself.

## Aliases

### `WATCHDOG_MAX_SLOTS`

```mojo
comptime WATCHDOG_MAX_SLOTS = Int(256)
```

Deadline slots (one per worker; matches the scheduler worker cap).

## Structs

### `DeadlineWatchdog`

```mojo
struct DeadlineWatchdog
```

One background thread enforcing per-slot deadlines.

Arm a slot with ``arm(slot, budget_ms, cancel_addr)`` before running
a cooperative handler and ``disarm(slot)`` after it returns; the
watchdog flips the cell if the budget elapses first. ``stop()``
halts and joins the thread. For a process-lifetime server watchdog,
construct once and leak it (never ``stop``) -- one background thread
for the process is negligible.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `DeadlineWatchdog.__init__`

```mojo
def __init__(out self, poll_ms: Int = Int(1)) raises
```

Allocate the control block and spawn the watchdog thread.

#### `DeadlineWatchdog.arm`

```mojo
def arm(self, slot: Int, budget_ms: Int, cancel_addr: Int)
```

Arm ``slot`` to flip the cell at ``cancel_addr`` in ``budget_ms`` from now. A budget that is already spent (``<= 0`` or in the past) fires at the next poll; one that would overflow never fires.

#### `DeadlineWatchdog.disarm`

```mojo
def disarm(self, slot: Int) -> Bool
```

Disarm ``slot``; ``True`` if the watchdog had already fired it. See :func:`watchdog_disarm`.

#### `DeadlineWatchdog.stop`

```mojo
def stop(mut self) raises
```

Stop the watchdog thread, join it, and free the block.

## Functions

### `watchdog_arm`

```mojo
def watchdog_arm(block: Int, slot: Int, budget_ms: Int, cancel_addr: Int)
```

Arm ``slot`` on the watchdog control block at ``block`` to flip the cell at ``cancel_addr`` after ``budget_ms``. A slot that is still armed is disarmed first (as :func:`watchdog_disarm` does, without reporting a fire), so a previous request's deadline can never fire into this request's cell; calling ``watchdog_disarm`` before re-arming remains the way to learn whether the previous request was cancelled. The address is stored before the deadline so the poller never sees a deadline without its target.

### `watchdog_disarm`

```mojo
def watchdog_disarm(block: Int, slot: Int) -> Bool
```

Disarm ``slot`` and return whether the watchdog fired on it.

When this returns, the poller is done with the slot: either it was
disarmed first and will not fire, or it has already written the
cancel cell. A late fire can no longer land after a re-arm. The
old disarm was a plain store: a poll past its deadline check still
wrote TIMEOUT into the cell afterwards, cancelling the next request
that reused it, and its own "fire once" store then wiped that
request's deadline.

### `spawn_leaked_watchdog`

```mojo
def spawn_leaked_watchdog(poll_ms: Int = Int(1)) raises -> Int
```

Spawn a process-lifetime watchdog thread and return its control- block address. The thread + block are intentionally leaked (never stopped/freed) -- one background thread for the process life. Use the returned address with ``watchdog_arm`` / ``watchdog_disarm``.

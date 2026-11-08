# `dodo.runtime.timer_wheel`

Hashed timing wheel for the dodo reactor.

Manages per-connection timeouts in user space, independent of the kernel.
We manage timeouts here (rather than via ``SO_RCVTIMEO`` /
``SO_SNDTIMEO`` on sockets) because a non-blocking reactor integrates
cleaner with a single shared monotonic clock than with many per-socket
options, and because per-fd timer fd registration would explode fd usage
on large connection counts.

Design:
- **Single-level wheel, 512 slots, 1 ms per slot.** Covers any timeout up
  to ~512 ms in the wheel itself; longer timeouts go to an overflow list
  and get "promoted" into the wheel on each advance.
- **O(1) schedule** into the wheel slot or the overflow list.
- **O(1) cancel** (mark as inactive in a dict; physical removal on fire).
- **O(k) advance** where k = number of slots to traverse plus overflow
  entries to promote. In practice k is 1-2 per millisecond in a steady
  state.

Usage::

```mojo
from dodo.runtime import TimerWheel
var tw = TimerWheel(now_ms=monotonic_ms())

var tid = tw.schedule(after_ms=500, token=UInt64(0x1234))
# ... later ...
_ = tw.cancel(tid)

# On every reactor iteration:
var fired = List[UInt64]()
tw.advance(monotonic_ms(), fired)
# dispatch each token in `fired` as a timeout
```

## Structs

### `TimerWheel`

```mojo
struct TimerWheel
```

Fixed-size hashed timing wheel with an overflow list.

Thread-unsafe; intended to be driven by the reactor on a single thread.
Cross-thread cancellation is a Stage 2+ concern.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `TimerWheel.__init__`

```mojo
def __init__(out self, now_ms: UInt64 = UInt64(0))
```

Create a wheel anchored at the given monotonic time.

Args:

- `now_ms`: Absolute millisecond value representing "now" at construction. Subsequent ``advance`` / ``schedule`` times must be expressed on the same clock.

#### `TimerWheel.schedule`

```mojo
def schedule(mut self, after_ms: Int, token: UInt64) raises -> UInt64
```

Schedule a timer to fire after ``after_ms`` milliseconds.

``after_ms <= 0`` is clamped to 1 — timers fire on the next
``advance``, not on the current tick (``advance`` processes each
tick *after* incrementing the clock, so a timer placed in the
current slot would only fire after a full rotation).

Args:

- `after_ms`: Delay in milliseconds relative to the current tick.
- `token`: Arbitrary user value reported back via ``advance``.

Returns: A unique timer ID that can be passed to ``cancel``.

#### `TimerWheel.cancel`

```mojo
def cancel(mut self, id: UInt64) raises -> Bool
```

Cancel a previously-scheduled timer.

Safe to call for already-fired or never-scheduled IDs; returns
False in those cases. The cancellation is lazy: the entry is
flagged inactive and physically removed the next time the slot
containing it is processed by ``advance``.

Args:

- `id`: Timer ID returned by ``schedule``.

Returns: True if a matching active timer was cancelled; False if the ID was already fired, already cancelled, or never scheduled.

#### `TimerWheel.advance`

```mojo
def advance(mut self, now_ms: UInt64, mut fired: List[UInt64]) raises
```

Advance the wheel to ``now_ms``, appending fired tokens to ``fired``.

Each tick (millisecond) between the current time and ``now_ms`` is
processed in order:

1. The current slot's entry list is drained; entries that are
   still ``active`` append their token to ``fired`` and are then
   removed from ``_entries``. Cancelled entries are silently
   removed.
2. Any overflow entries whose ``fire_at_ms`` now fits within one
   rotation are promoted into the appropriate wheel slot.

``now_ms`` must be monotonically non-decreasing across calls.
Regressing it is undefined behaviour.

A gap longer than one rotation is not walked tick by tick: the
wheel jumps to ``now_ms`` and re-buckets what is left, so the
cost follows the number of timers, not the length of the gap.
Timers due within one rotation are reported in fire order;
overflow timers due in the same jump come after them.

Args:

- `now_ms`: Current absolute millisecond time (same clock as ``now_ms`` passed to ``__init__``).
- `fired`: Output list; fired tokens are appended. The caller does not need to clear it first.

#### `TimerWheel.now_ms`

```mojo
def now_ms(self) -> UInt64
```

Return the current tick time tracked by the wheel.

#### `TimerWheel.active_count`

```mojo
def active_count(self) raises -> Int
```

Return the number of scheduled-and-not-yet-cancelled timers.

Inactive (cancelled but not yet reaped) entries are excluded.

#### `TimerWheel.next_fire_ms`

```mojo
def next_fire_ms(self) -> UInt64
```

Absolute time of the soonest scheduled fire, or ``now_ms`` + 2^32 if no timers are scheduled.

Sizing the reactor poll timeout: the reactor sleeps at most until
this time so the wheel can fire pending timers on its next
``advance``. Cost is a bounded scan of the wheel slots
(``_WHEEL_SLOTS`` = 512), independent of the number of active
timers -- the earlier O(n) ``_entries`` scan is gone.

The result is a *lower bound*: a slot may hold only lazily
cancelled ids, in which case the reactor wakes one tick early
and re-polls (harmless). It is never later than the true next
fire, so a timer can never be missed.

Overflow timers (more than one rotation out) are only re-examined
-- promoted into the wheel, and fired if due -- at the next slot-0
boundary, ``_WHEEL_SLOTS - _current_slot`` ticks away. While the
overflow list is non-empty the hint is therefore capped at that
boundary, both for the slot scan and for the fallback:
a full-rotation fallback would be up to 511 ms late.

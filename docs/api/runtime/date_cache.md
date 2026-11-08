# `dodo.runtime.date_cache`

Per-worker monotonic Date-header cache.

`Date: <IMF-fixdate>` per RFC 9110 §6.6.1 / RFC 5322 §3.3:

```mojo
Sun, 06 Nov 1994 08:49:37 GMT       ; 29 bytes, fixed width
```

Naive implementations call ``time(NULL) + gmtime_r(...) + strftime(...)``
once per response, paying ~3 syscalls / library calls + a TZ lookup on
every keep-alive request. Under TFB plaintext at 220K req/s + 4 workers,
that's ~880K Date-header formats / s — measurable.

This cache amortises the formatting cost to **once per second per
worker**: each access compares a cached "epoch second" against the
current ``CLOCK_REALTIME`` second; on a miss it re-formats the buffer
in place, on a hit it returns the same 29-byte buffer immediately.

Per-worker, not shared: each reactor worker holds its own ``DateCache``
in worker-local storage. There is no cross-thread contention, no atomic,
no mutex. The trade-off is ``num_workers`` formats / s instead of one;
at typical worker counts (1–32) that's negligible.

Algorithm: branch-free Howard Hinnant ``civil_from_days`` inverse for
the year/month/day decomposition (same routine
``dodo.http.structured_logger`` uses for ISO-8601 timestamps and
``dodo.http.conditional`` uses for HTTP-date parsing), then a 29-byte
direct write into a stack / heap buffer. No allocations on the hot
path past first construction.

The cache exposes ``current_bytes`` (returns a borrow over the cached
buffer) and ``current_string`` (allocates a fresh `String` copy when
the caller needs ownership). Middleware that emits ``Date`` headers
into a wire buffer should prefer ``current_bytes`` to avoid a per-
request copy — the underlying 29-byte buffer is stable until the
next ``refresh()`` call from the same worker.

Example:

```mojo
var cache = DateCache()
cache.refresh()  # idempotent; no-op when already on the current second
var buf = cache.current_bytes()  # Span[UInt8, ...]
# ... copy buf into wire buffer with memcpy ...
```

The cache is **not** thread-safe. Each worker constructs its own.

## Structs

### `CivilTime`

```mojo
struct CivilTime
```

Civil (Gregorian) date-time + day-of-week derived from a Unix epoch second.

Fields:
    year: Civil year (e.g. ``2026``).
    month: Civil month, 1..12.
    day: Civil day-of-month, 1..31.
    hour: Hour-of-day, 0..23.
    minute: Minute-of-hour, 0..59.
    second: Second-of-minute, 0..59.
    day_of_week: 0=Sun, 1=Mon, ..., 6=Sat.

The ``day_of_week`` is derived directly from Unix days
(epoch was a Thursday → ``+4`` offset before mod-7); callers
that don't need it can ignore the field.

Fields:

- `year` (`Int`)
- `month` (`Int`)
- `day` (`Int`)
- `hour` (`Int`)
- `minute` (`Int`)
- `second` (`Int`)
- `day_of_week` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

### `DateCache`

```mojo
struct DateCache
```

Per-worker IMF-fixdate cache.

Holds a 29-byte buffer rendered for the most-recently-observed
``CLOCK_REALTIME`` second. ``refresh()`` recomputes the buffer
iff the wall-clock second has advanced; subsequent
``current_bytes`` / ``current_string`` calls return the cached
formatting.

Construction primes the buffer immediately so
``current_bytes()`` is always safe to call.

The cache is **per-worker**, not process-shared. Each reactor
worker constructs its own; there's no atomic / mutex / lock.

Fields:
    _buf: ``List[UInt8]`` of fixed length 29 holding the
          currently-cached IMF-fixdate bytes.
    _epoch_second: The Unix-epoch second the buffer was rendered
                   for. ``-1`` until the first ``refresh()``.

Usage:

    ```mojo
    var cache = DateCache()
    # ... per-request:
    cache.refresh()
    var date_bytes = cache.current_bytes()
    # memcpy date_bytes into the wire buffer
    ```

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `DateCache.__init__`

```mojo
def __init__(out self)
```

Construct a primed cache rendered for the current second.

#### `DateCache.refresh`

```mojo
def refresh(mut self)
```

Re-render the buffer iff the wall-clock second has advanced.

This is the only operation that calls ``clock_gettime`` —
per-request consumers that just want the cached bytes call
``current_bytes()`` directly without a refresh check (they
accept up-to-1-second staleness, the cost of *not* doing
``clock_gettime`` per request).

Server hot paths typically call ``refresh()`` once per
reactor tick (or once per ``N`` requests) and then read
the cached bytes for every response within that window.

#### `DateCache.current_bytes`

```mojo
def current_bytes(self) -> Span[UInt8, origin_of(self._buf)]
```

Return a borrow over the cached 29-byte IMF-fixdate buffer.

The returned span is stable until the next ``refresh()``
call on this cache from this worker.

#### `DateCache.current_string`

```mojo
def current_string(self) -> String
```

Return a freshly-allocated ``String`` copy of the cached IMF-fixdate.

Most hot paths should prefer ``current_bytes()`` + memcpy
into the wire buffer; this convenience helper is for callers
that want a ``String`` (e.g. assigning into a ``HeaderMap``).

#### `DateCache.epoch_second`

```mojo
def epoch_second(self) -> Int
```

Return the Unix-epoch second the buffer is currently rendered for, or ``-1`` if the cache has not been refreshed.

Mostly useful for tests that pin the freshness invariant.

## Functions

### `civil_to_unix_seconds`

```mojo
def civil_to_unix_seconds(y: Int, m: Int, d: Int, hh: Int, mm: Int, ss: Int) -> Int
```

Return Unix epoch seconds for ``(y, m, d, hh, mm, ss)`` UTC.

Howard Hinnant's ``days_from_civil`` (forward) identity. The
intermediate cast of ``m - 3`` into a year-shifted month
folds February's leap-day handling into the year arithmetic.

Args:

- `y`: Civil year (e.g. ``2026``).
- `m`: Civil month, 1..12.
- `d`: Civil day-of-month, 1..31.
- `hh`: Hour-of-day, 0..23.
- `mm`: Minute-of-hour, 0..59.
- `ss`: Second-of-minute, 0..59.

Returns: Unix-epoch seconds (signed; negative for dates before 1970-01-01).

### `unix_seconds_to_civil`

```mojo
def unix_seconds_to_civil(unix_secs: Int) -> CivilTime
```

Decompose a Unix epoch second into a :class:`CivilTime`.

Howard Hinnant's ``civil_from_days`` (inverse) identity,
branch-free over the proleptic Gregorian calendar.

Args:

- `unix_secs`: Unix-epoch seconds (signed; negative is fine).

Returns: :class:`CivilTime` with the year/month/day/hour/minute/ second/day_of_week decomposition.

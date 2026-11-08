# `dodo.http.reliability`

Reliability middleware: ``Retry`` / ``PostHocDeadline`` / ``RateLimit`` / ``CircuitBreaker`` policies.

A reliability middleware wraps an inner ``Handler`` and adds a
policy that improves the chance the call succeeds in the face of
transient failures (transient upstream 5xx, slow handlers, etc).

- :class:`Retry[Inner]` — re-invoke the inner handler when it
  raises or returns a 5xx response, up to ``max_attempts`` times.
  Caller-tunable retry set (any 5xx by default; bounded to GET /
  HEAD / OPTIONS / TRACE / PUT / DELETE -- the RFC 9110 §9.2.2
  idempotent set -- by passing ``retry_only_idempotent=True``).
  Optional exponential backoff with full jitter spaces attempts.
- :class:`PostHocDeadline[Inner]` — bound the wall-clock time the
  inner handler may consume **measured after it returns**: the
  middleware records the entry timestamp, runs the inner handler
  to completion, then compares elapsed time against the budget
  and replaces the response with a 504 if the budget was
  exceeded. **It does not preempt the inner handler** -- Mojo
  cannot preempt synchronous code (see ``dodo/http/cancel.mojo``),
  so a genuinely runaway synchronous handler runs to completion on
  its worker; reactor-enforced cancellation exists only at the
  peer-FIN, shutdown, and streaming-edge boundaries, not inside a
  synchronous handler body. This is the K2 model limit.
- :class:`RateLimit[Inner]` — token-bucket admission control:
  reject with ``429 Too Many Requests`` once the per-second rate
  (with burst) is exceeded. State is a leaked, atomic heap cell
  shared across worker copies (ponytail: process-lifetime leak of
  one small cell per middleware instance; the atomics keep it
  race-free, so N workers enforce an approximate shared rate).
- :class:`CircuitBreaker[Inner]` — trip to ``503`` after
  ``failure_threshold`` consecutive failures (5xx or raise), then
  fast-fail for ``cooldown_ms`` before letting one probe through.
  Same leaked-atomic-cell state model as ``RateLimit``.

Each middleware is generic over its inner ``Handler`` so the
chain stays monomorphised -- no virtual dispatch.

## Structs

### `RetryPolicy`

```mojo
struct RetryPolicy
```

Tunable retry policy.

- ``max_attempts``: total number of inner-handler invocations
  (so ``max_attempts=3`` means 1 initial + 2 retries).
- ``retry_only_idempotent``: when True, retries are gated on
  the request method being one of GET / HEAD / OPTIONS / TRACE
  / PUT / DELETE (the RFC 9110 §9.2.2 idempotent set). When
  False, every 5xx triggers a retry regardless of method.
- ``initial_backoff_ms``: when > 0, sleep this many milliseconds
  before retry attempt #2. Each subsequent attempt scales the
  backoff by ``backoff_multiplier`` (capped at
  ``max_backoff_ms``). The actual sleep is "full jitter" --
  a uniform random draw in ``[0, capped_backoff_ms]`` -- which
  is the AWS-recommended default for retry storms (see
  <https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/>).
  ``0`` (the default) disables sleeps and matches the previous
  "tight loop" behaviour.
- ``backoff_multiplier``: per-attempt scaling factor. Defaults
  to ``2`` (binary exponential backoff: 100ms -> 200ms ->
  400ms -> ...).
- ``max_backoff_ms``: cap on the un-jittered backoff before
  ``random_ui64`` draws the actual sleep. Defaults to
  ``2_000`` (2 s); set to a small value to keep tail latency
  bounded.

Defaults: ``max_attempts=3``, ``retry_only_idempotent=True``,
``initial_backoff_ms=0`` (no sleep), ``backoff_multiplier=2``,
``max_backoff_ms=2_000``.

Fields:

- `max_attempts` (`Int`)
- `retry_only_idempotent` (`Bool`)
- `initial_backoff_ms` (`Int`)
- `backoff_multiplier` (`Int`)
- `max_backoff_ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `RetryPolicy.__init__`

```mojo
def __init__(out self)
```

### `Retry`

```mojo
struct Retry[Inner: Handler & Copyable]
```

Retry the inner handler on transient failure.

A response with status >= 500 triggers a retry; a raised
exception is also treated as a transient failure (the
inner handler re-runs from scratch). The last attempt's
outcome (response or exception) is propagated unchanged when
all attempts are exhausted.

By default the middleware does NOT sleep between attempts and
retries fire as fast as the inner handler returns.

**Backoff blocks the worker.** The inner handler runs on the
reactor thread, so the sleep between attempts does too: every
other connection on that worker waits it out. Keep
``max_backoff_ms`` small on a server, or retry in the client that
calls the flaky dependency instead of around the handler. Set
``RetryPolicy.initial_backoff_ms`` to enable binary
exponential backoff with full jitter (the AWS-recommended
default for retry storms): the sleep before retry N is drawn
uniformly from ``[0, min(initial_backoff_ms * 2 ** (N - 2),
max_backoff_ms)]``. ``RateLimit[Inner]`` composed inside
``Retry`` remains the canonical way to express richer
pacing policies.

Fields:

- `inner` (`Inner`)
- `policy` (`RetryPolicy`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Retry.__init__`

```mojo
def __init__(out self, var inner: Inner, var policy: RetryPolicy = RetryPolicy())
```

#### `Retry.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Retry.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Retry.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Retry.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

### `PostHocDeadline`

```mojo
struct PostHocDeadline[Inner: Handler & Copyable]
```

Post-hoc wall-clock deadline check.

The middleware records the entry timestamp, runs the inner
handler **to completion**, and compares elapsed time against
``budget_ms`` after serve() returns. If the budget was
exceeded, the response is replaced with a 504 Gateway
Timeout; otherwise the inner response passes through
unchanged.

The check is post-hoc by design -- it does **not** preempt
the inner handler. A genuinely runaway handler still ties
up the worker for the full natural duration; the 504 only
suppresses its response. Tight cancel-cell wiring (the
reactor flips a Cancel cell that the inner handler observes
and short-circuits on) would need reactor cooperation, which
it does not have.

For codec-style sans-I/O handlers and the common case where
misbehaving inners simply return slightly late, this
primitive is enough: handlers that genuinely overrun
surface as 504 to the client, and an external operator
monitor sees both the elapsed time and the substituted
status. ``budget_ms <= 0`` is the explicit "always trip"
sentinel and bypasses the inner handler entirely.

Fields:

- `inner` (`Inner`)
- `budget_ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `PostHocDeadline.__init__`

```mojo
def __init__(out self, var inner: Inner, budget_ms: Int = Int(30000))
```

#### `PostHocDeadline.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `PostHocDeadline.may_block`

```mojo
def may_block(self) -> Bool
```

#### `PostHocDeadline.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `PostHocDeadline.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

### `RateLimit`

```mojo
struct RateLimit[Inner: Handler & Copyable]
```

Token-bucket rate limiter.

Admits up to ``rate_per_sec`` requests per second with a bucket
depth of ``burst`` (defaults to ``rate_per_sec``). Once the
bucket is empty the middleware short-circuits with ``429 Too
Many Requests`` without invoking the inner handler.

``rate_per_sec <= 0`` disables the limiter (pass-through). The
refill is exact for any idle time as long as ``burst * 1e9`` and
``rate_per_sec`` stay below 2^62 (``burst`` under about 4.6e9
tokens). The
bucket lives in a leaked atomic cell (see module docstring):
worker copies share it, so the enforced rate is approximately
global rather than strictly per-worker.

Fields:

- `inner` (`Inner`)
- `rate_per_sec` (`Int`)
- `burst` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `RateLimit.__init__`

```mojo
def __init__(out self, var inner: Inner, rate_per_sec: Int, burst: Int = Int(0))
```

#### `RateLimit.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `RateLimit.may_block`

```mojo
def may_block(self) -> Bool
```

#### `RateLimit.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `RateLimit.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

### `CircuitBreaker`

```mojo
struct CircuitBreaker[Inner: Handler & Copyable]
```

Trip open after consecutive failures, fast-fail during cooldown.

Counts consecutive failures (a raised exception or a ``>= 500``
response). After ``failure_threshold`` in a row the breaker
opens: every call fast-fails with ``503 Service Unavailable``
for ``cooldown_ms``, counted from the moment the failing call
returned (not from when it started, so a slow failure does not
use up the cooldown). The first call after cooldown is a probe
(half-open) and is the only call let through while it is in
flight: the others fast-fail with ``503``. Success closes the
breaker, another failure re-opens it.

``failure_threshold <= 0`` disables the breaker (pass-through).
State lives in a leaked atomic cell (see module docstring).

Fields:

- `inner` (`Inner`)
- `failure_threshold` (`Int`)
- `cooldown_ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `CircuitBreaker.__init__`

```mojo
def __init__(out self, var inner: Inner, failure_threshold: Int, cooldown_ms: Int = Int(5000))
```

#### `CircuitBreaker.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `CircuitBreaker.may_block`

```mojo
def may_block(self) -> Bool
```

#### `CircuitBreaker.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `CircuitBreaker.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

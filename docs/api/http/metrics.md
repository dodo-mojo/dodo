# `dodo.http.metrics`

Prometheus-text-exposition metrics middleware.

``Metrics[Inner]`` is a request-counting / latency-histogramming
middleware that wraps any inner ``Handler`` and emits Prometheus
text-format exposition compatible with the v0.0.4 spec
(https://prometheus.io/docs/instrumenting/exposition_formats/).

Why text-format and not the protobuf shape:

- Every Prometheus client + Grafana data source supports text.
- Zero protobuf dependency, zero schema stake-down.
- Cheap to render — one ``String`` build per scrape, which is on
  the scrape budget (15s default), not the request hot path.

Counters tracked (matching the de facto Prometheus HTTP-server
contract — Caddy, nginx-prometheus-exporter, Envoy stats):

- ``dodo_http_requests_total{method,status}`` — request count
  partitioned by method label and status-code label.
- ``dodo_http_request_duration_seconds_bucket{le}`` — histogram
  of request latency in seconds across the canonical Prometheus
  default-bucket layout (``0.005``, ``0.01``, ``0.025``, ``0.05``,
  ``0.1``, ``0.25``, ``0.5``, ``1``, ``2.5``, ``5``, ``10``,
  ``+Inf``). Same bucket boundaries hyper / actix-web / nginx all
  emit, so PromQL queries written against any of them just work.
- ``dodo_http_request_duration_seconds_sum`` /
  ``..._count`` — histogram totals.
- ``dodo_http_requests_in_flight`` — gauge of currently-serving
  requests.
- ``dodo_http_request_errors_total`` — counter of errors raised
  by the inner handler.

Concurrency note:

Mojo's ``Atomic`` cells are NOT ``Copyable``, so they
can't live inside a ``List`` / ``Array``. Putting 160
``Atomic`` cells as separate struct fields would explode the
declaration; an ``Pointer[Atomic, ...]`` heap allocation
would re-introduce the lifetime-management surface that the
``Movable``-only registry is trying to avoid.

The shape is therefore **per-worker, plain ``UInt64``**
counters. dodo's HTTP server already monomorphises one
``Handler`` instance per worker pthread, so each worker owns
its own ``MetricsRegistry`` — counters are never shared across
worker threads, no atomic increment required.

For multi-worker aggregation (i.e. exposing a process-wide
``/metrics``), caller wires a small aggregator that snapshots
every worker's registry and concatenates the rendered text. The
cells are not ``Atomic`` because ``Atomic`` is not ``Copyable``.

Cardinality discipline:

Status-code labels are kept in a small fixed table (200, 201,
204, 301, 302, 304, 400, 401, 403, 404, 412, 429, 500, 502,
503; ``other`` for the rest). Method labels are kept to the RFC
9110 set (GET, HEAD, POST, PUT, PATCH, DELETE, CONNECT,
OPTIONS, TRACE; ``other`` for the rest). This bounds cardinality
to ``10 methods × 16 statuses = 160 series`` total — under the
Prometheus advisory of ~10K series per server, with three orders
of magnitude headroom for downstream apps to add their own
business metrics.

Render cost:

The ``MetricsRegistry.render()`` snapshot allocates one output
``String`` sized for the worst case (~6 KB at 160
``method×status`` series + 13 latency buckets + 4 totals). On a
15 s scrape interval against a 4-worker EPYC node serving 220 K
req/s, the cost rounds to zero (<5 µs amortised per request).

## Structs

### `MetricsRegistry`

```mojo
struct MetricsRegistry
```

Counter / gauge / histogram aggregate.

The registry is the storage backing one ``Metrics[Inner]``
middleware. It is per-worker (see module docstring "Concurrency
note" for why); aggregation across workers is the caller's
job at the ``/metrics`` scrape endpoint.

All counters are plain ``UInt64``. Wrap-around is bounded by
``2^64`` requests (~580 years at 1 G req/s).

Fields:

- `requests_total` (`List[UInt64]`): Flat ``[method × status]`` table; index = ``method_idx * _STATUS_COUNT + status_idx``.
- `duration_buckets` (`List[UInt64]`): Histogram bucket counts; flat over the 13-bucket layout. Each bucket holds the CUMULATIVE count of requests with latency ``<= le[i]`` (Prometheus convention).
- `duration_sum_micros` (`UInt64`): Cumulative latency in microseconds. Renders as seconds in the exposition output.
- `duration_count` (`UInt64`): Cumulative request count for the histogram (= the value of the ``+Inf`` bucket).
- `in_flight` (`UInt64`): Gauge of currently-serving requests. Bumped on entry, decremented on exit; ``Metrics.serve`` decrements via the ``except`` path so a raised ``Exception`` still drops the gauge.
- `errors_total` (`UInt64`): Counter of errors raised by the inner handler.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `MetricsRegistry.__init__`

```mojo
def __init__(out self)
```

#### `MetricsRegistry.record`

```mojo
def record(mut self, method_idx: Int, status_idx: Int, latency_micros: UInt64)
```

Record a successful request-served event.

#### `MetricsRegistry.record_error`

```mojo
def record_error(mut self, latency_micros: UInt64)
```

Record an error from the inner handler. The error is also bucketed into the latency histogram so a slow-then- raise handler shows up in the latency graph too.

#### `MetricsRegistry.enter`

```mojo
def enter(mut self)
```

Bump the in-flight gauge on request entry.

#### `MetricsRegistry.exit`

```mojo
def exit(mut self)
```

Drop the in-flight gauge on request completion (success or error).

#### `MetricsRegistry.render`

```mojo
def render(self) -> String
```

Snapshot the registry as a Prometheus text-format exposition body.

### `Metrics`

```mojo
struct Metrics[Inner: Handler & Copyable]
```

Prometheus-text-exposition middleware around an inner handler.

The inner ``Handler`` is wrapped with a counter / histogram
update on every served request. The registry lives on the
heap (allocated via :class:`dodo.runtime.pool.Pool`) and the
middleware holds the address as an ``Int`` — copies of the
middleware therefore share the same registry, which matches
the per-worker singleton pattern (one ``Metrics[Inner]`` per
worker pthread, one ``MetricsRegistry`` per ``Metrics``).

The shared-registry shape lets ``serve`` mutate counters
through the immutable-``self`` ``Handler`` contract: we
re-materialise the typed pointer via
``Pool[MetricsRegistry].get_ptr(self.registry_addr)`` and
mutate the cell through it. The cell is leaked at process
exit (the worker pthread lives the lifetime of the server,
so nothing meaningful to free); a future ``ArcPointer``
upgrade can swap the leak for ref-counting.

Pair with a small handler that returns
``Pool[MetricsRegistry].get_ptr(metrics.registry_addr)[].render()``
on the ``/metrics`` route to expose to a Prometheus scraper.

Fields:

- `inner` (`Inner`)
- `registry_addr` (`Int`): Heap address of the shared :class:`MetricsRegistry` cell. Allocated in ``__init__``; intentionally leaked at process exit (see struct doc).

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Metrics.__init__`

```mojo
def __init__(out self, var inner: Inner)
```

#### `Metrics.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Metrics.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Metrics.route_list`

```mojo
def route_list(self) raises -> List[RouteInfo]
```

#### `Metrics.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

#### `Metrics.render`

```mojo
def render(self) -> String
```

Convenience accessor that snapshots the underlying registry as Prometheus text exposition. Equivalent to ``Pool[MetricsRegistry].get_ptr(self.registry_addr)[].render()`` but keeps callers pointer-free.

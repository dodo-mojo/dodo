# `dodo.http.sse`

Server-Sent Events (W3C SSE / RFC 9110 ``text/event-stream``).

This module promotes the ``ChunkSource`` SSE pattern that example 24
demonstrated to a first-class dodo primitive:

- :class:`SseEvent` — a single SSE record (data + optional id +
  optional event-type + optional retry interval).
- :func:`format_sse_event` — serialise an event to the wire bytes
  prescribed by `WHATWG HTML §9.2.6
  <https://html.spec.whatwg.org/multipage/server-sent-events.html#parsing-an-event-stream>`__.
- :class:`SseChannel` — a small in-memory FIFO + cancel-aware
  ``ChunkSource`` wrapper. The handler ``push``-es events; the
  reactor drains buffered events on each writable edge and gets an
  empty chunk once the FIFO runs dry.
- :func:`sse_response` — the canonical "give me a Response with
  the right headers wired up" helper, paired with
  :class:`SseStreamingResponse[B]` for the streaming-body variant.

What this fixes vs example 24:

1. The handler doesn't have to roll its own ``ChunkSource`` for
   every endpoint — :class:`SseChannel` is the 80% case (a queue
   that real systems push events into).
2. Wire serialisation is centralised and spec-conformant: each
   ``data`` field that contains ``\n`` is split into multiple
   ``data:`` lines per WHATWG §9.2.4; trailing ``\n\n`` is
   always emitted as the event terminator; ``id:`` /
   ``event:`` / ``retry:`` lines are emitted only when set.
3. Response headers are spec-correct out of the box:
   ``Content-Type: text/event-stream``, ``Cache-Control: no-cache``,
   ``Connection: keep-alive``, ``X-Accel-Buffering: no`` (the
   nginx-specific knob that disables proxy-side buffering, which
   would otherwise trickle events to the client in 4 KiB lumps).

Example:

```mojo
from dodo.http import (
    SseChannel, SseEvent, SseStreamingResponse, sse_response,
)

def stream(req: Request) raises -> Response:
    # Bounded source: emit 5 events then close.
    var ch = SseChannel()
    for i in range(5):
        ch.push(SseEvent.data("tick=" + String(i)))
    ch.close()
    return sse_response(ch)
```

Reactor adoption: same as example 24 — wires through the existing
``ChunkedBody[SseChannel]`` path; no new reactor surface.

## Aliases

### `SSE_HEARTBEAT_MS`

```mojo
comptime SSE_HEARTBEAT_MS = Int(15000)
```

Minimum gap between ``: keep-alive`` comments on an idle channel.

## Structs

### `SseEvent`

```mojo
struct SseEvent
```

A single Server-Sent Event.

Fields:
    data: Event payload. May contain newlines — they're split
        into multiple ``data:`` lines on the wire per
        WHATWG §9.2.4.
    event_type: Optional event-type name. Default empty (the
        client default of ``"message"`` applies).
    id: Optional event id (for ``Last-Event-Id`` resumption).
        Default empty.
    retry_ms: Optional reconnection backoff hint, in
        milliseconds. Default ``-1`` (don't emit a ``retry:``
        line).

Constructors:

```mojo
- :meth:`SseEvent.data` — the 80% case (just data).
- :meth:`SseEvent.named` — typed event with explicit
  event-type.
```

Fields:

- `data` (`String`)
- `event_type` (`String`)
- `id` (`String`)
- `retry_ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `SseEvent.message`

```mojo
def message(payload: String) -> Self
```

Construct an event with just a ``data`` payload (no explicit event-type — the client default ``"message"`` applies).

#### `SseEvent.named`

```mojo
def named(event_type: String, payload: String) -> Self
```

Construct an event with a named ``event:`` type.

### `SseChannel`

```mojo
struct SseChannel
```

An in-memory FIFO of :class:`SseEvent` values + a closed flag.

Pattern:

1. Handler creates an :class:`SseChannel`.
2. Handler ``push``-es events (synchronously or from a
   background pthread; the channel itself is **not**
   thread-safe — wrap with a mutex if you cross threads).
3. Handler ``close``-s the channel when the stream ends.
4. Reactor drains buffered events via :meth:`next` on each
   writable edge; when the buffer is empty AND the channel is
   closed, ``next`` returns ``None`` to signal end-of-stream.

For an open-ended stream (heartbeat / metric tap / ...), don't
call ``close`` — the connection lives until either the client
disconnects (peer FIN ⇒ reactor flips ``cancel``) or the
request-deadline fires.

Known ceiling -- an idle open channel still wakes the reactor.
    ``next`` no longer emits bytes on every writable edge (see the
    ``SSE_HEARTBEAT_MS`` gate), but the connection keeps write
    interest armed, epoll is level-triggered, and the socket stays
    writable, so the reactor re-dispatches it and gets an empty
    chunk back. That costs CPU on an otherwise idle stream.

    Fixing it needs a way to park a live-but-idle source, which
    dodo does not have yet, by either of two routes. (1) Teach the
    timer wheel to wake rather than reap: today every fired timer
    goes to ``_cleanup_conn_unified``, which closes the connection,
    so there is no "call me back in N ms" timer to drop write
    interest against. (2) Back the channel with an eventfd and drive
    it through ``AsyncChunkSource`` / ``ChunkPoll.pending(fd)`` in
    ``dodo.http.async_body``, which is built for exactly this and
    is not yet wired into the reactor.

Thread safety:

```mojo
Not thread-safe. Push from the reactor's pthread or
synchronise externally.
```

Implemented traits: `AnyType`, `ChunkSource`, `Copyable`, `Deinitable`, `Movable`

#### `SseChannel.__init__`

```mojo
def __init__(out self)
```

#### `SseChannel.push`

```mojo
def push(mut self, var event: SseEvent)
```

Append an event to the FIFO.

#### `SseChannel.close`

```mojo
def close(mut self)
```

Mark the channel closed. The reactor's :meth:`next` call will return ``None`` once the buffer is drained.

#### `SseChannel.is_closed`

```mojo
def is_closed(self) -> Bool
```

#### `SseChannel.pending`

```mojo
def pending(self) -> Int
```

Return the count of events buffered but not yet yielded.

#### `SseChannel.next`

```mojo
def next(mut self, cancel: Cancel) raises -> Optional[List[UInt8]]
```

Yield the next event's wire bytes, an empty chunk when the channel is open but idle, or ``None`` to signal end-of-stream.

Returns ``None`` immediately if cancel is set OR the
channel is closed AND the buffer is drained.

An idle open channel yields a comment-line heartbeat
(``": keep-alive\n\n"``, ignored by the WHATWG parser because
it starts with ``:``) at most once per ``SSE_HEARTBEAT_MS``, and
an empty chunk in between. Reactors read the empty chunk as
"nothing right now" and stop draining, so an idle stream costs no
bandwidth: without the gate, the reactor's coalescing loop would
pull a full batch of heartbeats on every writable edge.

### `SseStreamingResponse`

```mojo
struct SseStreamingResponse
```

A streaming-body :class:`Response` analogue for an open-ended SSE channel.

Pairs ``response`` (status + headers) with ``body``
(:class:`ChunkedBody[SseChannel]`) so the reactor's streaming
code path can drain buffered events on a writable edge. Unlike
:func:`sse_response`, this never blocks the handler — it
captures the channel and returns immediately; events pushed
to the channel after the handler returns are flushed by the
reactor on the next writable edge.

Reactor adoption: a Router/Handler can stream SSE by returning
``stream_response(channel)`` -- the reactor pulls framed chunks in
bounded batches via ``Response.body_stream``, on HTTP/1.1, HTTP/2
and TLS alike. This ``SseStreamingResponse`` wrapper remains
for the ``serve_streaming`` entry point.

Fields:

- `response` (`Response`)
- `body` (`ChunkedBody[SseChannel]`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `SseStreamingResponse.of`

```mojo
def of(channel: SseChannel) raises -> Self
```

Construct a :class:`SseStreamingResponse` carrying ``channel`` as its ChunkedBody source.

## Functions

### `format_sse_event`

```mojo
def format_sse_event(event: SseEvent) -> List[UInt8]
```

Serialise ``event`` to its on-wire byte representation.

Wire shape (terminated by ``\n\n``):

```mojo
``[id: <id>\n][event: <event_type>\n][retry: <ms>\n]
data: <line0>\n[data: <line1>\n]...\n``
```

A ``data`` field containing ``\n`` is split into multiple
``data:`` lines (the WHATWG §9.2.4 parser concatenates them
back with a single ``\n`` separator on the receiving side).
A trailing ``\n`` inside ``data`` produces a final empty
``data:`` line — that is intentional and matches what every
other SSE library does (Tornado, Sanic, axum-extra).

### `sse_response`

```mojo
def sse_response(channel: SseChannel) raises -> Response
```

Build a :class:`Response` whose body is a one-shot snapshot of every event currently buffered in ``channel``.

Use this when the handler can produce all events synchronously
before returning (the typical "metrics endpoint" /
"history-replay" / "test fixture" shape). For an open-ended
stream that lives past the handler return, build a
:class:`SseStreamingResponse` instead.

Drains the channel synchronously; returns a :class:`Response`
with the SSE wire bytes inline + the spec-correct headers.

### `stream_sse_response`

```mojo
def stream_sse_response(var channel: SseChannel, status: Int = Int(200)) raises -> Response
```

Build a streaming SSE :class:`Response` from ``channel``.

This is the canonical way to serve SSE through the normal
``Handler`` / ``Router`` path: the returned ``Response`` carries the
channel on ``body_stream`` plus the spec-correct SSE headers, and
streams over both HTTP/1.1 (chunked transfer-encoding) and HTTP/2
(DATA frames) with no SSE-specific reactor code.

Unlike :func:`sse_response` (a synchronous, ``Content-Length``
snapshot that requires a closed channel), the channel may stay open:
the reactor drains whatever is buffered on each writable edge and
keeps the connection warm with a ``": keep-alive"`` comment at most
once per ``SSE_HEARTBEAT_MS`` while idle, until the channel is
closed or the peer disconnects. Prefer this over the legacy
:class:`SseStreamingResponse`, which only fed the ``serve_streaming``
entry point.

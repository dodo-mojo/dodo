# Outgoing calls

A handler that calls other services (another API, a model server) is
written in steps, so the worker can run its calls on the event loop and
serve other requests while they are out (ADR-0006).

## Writing one

```mojo
from std.collections import Optional
from dodo.http import Calling, Calls, OnLoop, Request, Response, Router, ok


@fieldwise_init
struct Dash(Calling, Copyable):
    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("http://auth.internal/token")
        return None  # wait for the reply

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        if calls.round() == 1:
            var token = calls.reply(0).text()
            _ = calls.get("http://api.internal/a?token=" + token)
            _ = calls.get("http://api.internal/b?token=" + token)
            return None  # one more round
        return ok(calls.reply(1).text() + calls.reply(2).text())


def main() raises:
    var r = Router()
    r.get("/dash", OnLoop(Dash()))
```

- `start` runs first. It returns the response, or asks for calls and
  returns `None`.
- The calls of one round run side by side. When every reply is back,
  `finish` runs. It returns the response, or asks for the next round.
- `calls.get(url)`, `calls.post(url, body)` and `calls.send(request)`
  return the reply's number. Numbers count across rounds: the first call
  of round two follows the last call of round one.
- Each call has a `timeout_ms` (30 s by default).
- A request may make at most 32 rounds (`MAX_ROUNDS`).
- `App` takes the same handler: `app.get["/dash"](OnLoop(Dash()))`.

## Replies

A failed call does not raise. Its reply says why, so `finish` decides
what the client sees.

| `reply.error` | Meaning |
|---|---|
| `CallError.NONE` | A response came back; `status`, `headers`, `body`, `text()` |
| `CallError.CONNECT` | DNS failed, the connection was refused, or connect timed out |
| `CallError.TIMEOUT` | The call took longer than its `timeout_ms` |
| `CallError.CANCELLED` | The request was cancelled first (client left, handler timeout, stop) |
| `CallError.BAD_URL` | Not a full `http://` or `https://` URL |
| `CallError.FAILED` | Anything else: TLS, a broken reply, a reset |

`reply.ok()` is true for a 2xx response. `reply.failed()` is true when
there is no response at all.

## Middleware

Every built-in middleware takes part in both steps. Its before-part
(checks, limits, a cache lookup, a CORS preflight) runs once in `start`
and can answer early, so no call goes out. Its after-part (headers,
logging, compression, metrics) runs once on the response, whichever step
returns it. `Retry` starts the inner steps over on a 5xx.

A custom middleware that wraps a calling handler forwards five methods:

```mojo
struct Tagged[Inner: Handler & Copyable](Copyable, Handler):
    var inner: Self.Inner

    def serve(self, req: Request) raises -> Response:
        return _tag(self.inner.serve(req).lower())

    def may_call(self) -> Bool:
        return self.inner.may_call()

    def calling(self, req: Request) raises -> Bool:
        return self.inner.calling(req)

    def start(self, req: Request, mut calls: Calls) raises -> Optional[Response]:
        var answer = self.inner.start(req, calls)
        if answer:
            return _tag(answer.take())
        return None

    def finish(self, req: Request, mut calls: Calls) raises -> Optional[Response]:
        var answer = self.inner.finish(req, calls)
        if answer:
            return _tag(answer.take())
        return None
```

State that the after-part needs from the before-part goes in a note:
`calls.note("my.key", value)` in `start`, `calls.note("my.key")` in
`finish`.

A middleware that forwards none of them still works: its `calling` says
no, so the server calls its `serve`, which runs the steps with blocking
calls.

## Where the calls run today

`OnLoop.serve` runs the steps with the blocking `HttpClient`, one call
after another. Every server loop uses that path until it runs calls on
the loop itself. `TestClient` runs the steps the way a server will.

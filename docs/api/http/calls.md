# `dodo.http.calls`

``Calls``: the outgoing HTTP calls a handler makes while it serves a request (ADR-0006).

A handler that calls other services is written in steps. ``start`` asks
for calls and returns ``None``; the server runs them side by side and
then calls ``finish`` with every reply. ``finish`` either returns the
response or asks for more calls (the next round) and returns ``None``.

```mojo
from dodo.http import Calling, Calls, OnLoop, Request, Response, ok

@fieldwise_init
struct Dash(Calling, Copyable):
    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("http://auth.internal/token")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        if calls.round() == 1:
            var token = calls.reply(0).text()
            _ = calls.get("http://api.internal/a?token=" + token)
            _ = calls.get("http://api.internal/b?token=" + token)
            return None
        return ok(calls.reply(1).text() + calls.reply(2).text())

r.get("/dash", OnLoop(Dash()))
```

A failed call does not raise: its reply says why (``CallError``), so
``finish`` decides what the client sees.

## Aliases

### `MAX_ROUNDS`

```mojo
comptime MAX_ROUNDS = 32
```

The most rounds of calls one request may make. A handler that keeps asking for more is a bug, so the request fails instead of looping.

### `DEFAULT_CALL_TIMEOUT_MS`

```mojo
comptime DEFAULT_CALL_TIMEOUT_MS = 30000
```

How long one call may take, from connect to the last body byte.

## Structs

### `CallError`

```mojo
struct CallError
```

Why a call has no response. ``NONE`` when it has one.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `NONE = 0`: The call got a response (any status).
- `CONNECT = 1`: The server could not be reached: DNS, refused, or connect timeout.
- `TIMEOUT = 2`: The call took longer than its ``timeout_ms``.
- `CANCELLED = 3`: The request was cancelled first: the client left, the handler timed out, or the server is stopping.
- `FAILED = 4`: Anything else: TLS, a broken reply, a reset connection.
- `BAD_URL = 5`: The URL is not a full ``http://`` or ``https://`` URL.

### `CallReply`

```mojo
struct CallReply
```

What one outgoing call returned: a response, or why there is none.

Fields:

- `status` (`Int`): The response status, or ``0`` when the call failed.
- `headers` (`HeaderMap`): The response headers; empty when the call failed.
- `body` (`List[UInt8]`): The response body; empty when the call failed.
- `error` (`Int`): A ``CallError`` code; ``CallError.NONE`` when there is a response.
- `message` (`String`): What went wrong, for logs; empty when there is a response.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `CallReply.__init__`

```mojo
def __init__(out self, var resp: ResponseImpl)
```

```mojo
def __init__(out self, *, error: Int, message: String)
```

#### `CallReply.ok`

```mojo
def ok(self) -> Bool
```

Whether the call got a response with a 2xx status.

#### `CallReply.failed`

```mojo
def failed(self) -> Bool
```

Whether the call got no response at all.

#### `CallReply.text`

```mojo
def text(self) -> String
```

The body as text; empty when the call failed.

### `OutgoingCall`

```mojo
struct OutgoingCall
```

One call a handler asked for, not sent yet.

Fields:

- `request` (`Request`): The request to send; ``url`` is a full URL.
- `timeout_ms` (`Int`): How long the call may take in all.
- `tls` (`TlsConfig`): How an ``https://`` call checks the server: the setting on ``OnLoop``, or the default (OpenSSL's default CA bundle).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `OutgoingCall.__init__`

```mojo
def __init__(out self, var request: Request, timeout_ms: Int, tls: TlsConfig = TlsConfig(Int(1), String(""), String(""), String(""), String(""), List(), True))
```

### `Calls`

```mojo
struct Calls
```

The calls of one request: what is asked for, what came back, and notes that middleware keeps between ``start`` and ``finish``.

Replies are numbered in the order the calls were asked for, across
every round: the first call of round two follows the last of round one.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Calls.__init__`

```mojo
def __init__(out self)
```

#### `Calls.get`

```mojo
def get(mut self, url: String, timeout_ms: Int = Int(30000)) -> Int
```

Ask for a ``GET`` of ``url``. Returns the reply's number.

#### `Calls.post`

```mojo
def post(mut self, url: String, body: String, content_type: String = "application/json", timeout_ms: Int = Int(30000)) raises -> Int
```

Ask for a ``POST`` of ``body`` to ``url``. Returns the reply's number.

#### `Calls.send`

```mojo
def send(mut self, var req: Request, timeout_ms: Int = Int(30000)) -> Int
```

Ask for ``req`` with any method, headers and body. ``req.url`` is a full ``http://`` or ``https://`` URL. Returns the reply's number.

#### `Calls.use_tls`

```mojo
def use_tls(mut self, tls: TlsConfig)
```

Check ``https://`` servers with ``tls`` for the calls asked for from now on. ``OnLoop`` sets this from its ``tls`` setting.

#### `Calls.round`

```mojo
def round(self) -> Int
```

How many rounds of calls have come back: ``1`` in the first ``finish``, ``2`` in the next, and so on.

#### `Calls.count`

```mojo
def count(self) -> Int
```

How many replies have come back so far.

#### `Calls.reply`

```mojo
def reply(self, number: Int) raises -> ref[self._replies["element"]] CallReply
```

The reply to call ``number``, counted from 0 across rounds.

#### `Calls.note`

```mojo
def note(mut self, key: String, value: String)
```

Keep ``value`` under ``key`` until the request is answered. Middleware uses this to carry what its ``start`` learned to its ``finish``.

```mojo
def note(self, key: String) -> String
```

The note kept under ``key``, or empty when there is none.

#### `Calls.waiting`

```mojo
def waiting(self) -> Int
```

How many calls are asked for and not sent yet.

#### `Calls.take_waiting`

```mojo
def take_waiting(mut self) -> List[OutgoingCall]
```

Hand over the calls asked for since the last round. Their replies must come back through ``add_reply`` in the same order.

#### `Calls.add_reply`

```mojo
def add_reply(mut self, var reply: CallReply)
```

Record the next reply.

#### `Calls.restart`

```mojo
def restart(mut self)
```

Forget every call and reply, keeping the notes, so a wrapper such as ``Retry`` can run its inner handler's steps again from ``start``.

#### `Calls.end_round`

```mojo
def end_round(mut self) raises
```

Mark the round's replies as all back, before ``finish`` runs. Raises once a request has made ``MAX_ROUNDS`` rounds.

## Functions

### `no_response_and_no_calls`

```mojo
def no_response_and_no_calls() -> Error
```

The error for a ``start`` or ``finish`` that returns ``None`` without asking for a call, which would wait forever.

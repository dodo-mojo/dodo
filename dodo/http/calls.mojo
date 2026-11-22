"""``Calls``: the outgoing HTTP calls a handler makes while it serves a
request (ADR-0006).

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
"""

from std.collections import Dict, Optional

from dodo.tls.config import TlsConfig

from .headers import HeaderMap
from .request import Method, Request
from .response import Response


comptime MAX_ROUNDS = 32
"""The most rounds of calls one request may make. A handler that keeps
asking for more is a bug, so the request fails instead of looping."""

comptime DEFAULT_CALL_TIMEOUT_MS = 30_000
"""How long one call may take, from connect to the last body byte."""


struct CallError:
    """Why a call has no response. ``NONE`` when it has one."""

    comptime NONE = 0
    """The call got a response (any status)."""
    comptime CONNECT = 1
    """The server could not be reached: DNS, refused, or connect timeout."""
    comptime TIMEOUT = 2
    """The call took longer than its ``timeout_ms``."""
    comptime CANCELLED = 3
    """The request was cancelled first: the client left, the handler timed
    out, or the server is stopping."""
    comptime FAILED = 4
    """Anything else: TLS, a broken reply, a reset connection."""
    comptime BAD_URL = 5
    """The URL is not a full ``http://`` or ``https://`` URL."""


struct CallReply(Movable):
    """What one outgoing call returned: a response, or why there is none."""

    var status: Int
    """The response status, or ``0`` when the call failed."""
    var headers: HeaderMap
    """The response headers; empty when the call failed."""
    var body: List[UInt8]
    """The response body; empty when the call failed."""
    var error: Int
    """A ``CallError`` code; ``CallError.NONE`` when there is a response."""
    var message: String
    """What went wrong, for logs; empty when there is a response."""

    def __init__(out self, var resp: Response):
        self.status = resp.status
        self.headers = HeaderMap()
        self.body = List[UInt8]()
        swap(self.headers, resp.headers)
        swap(self.body, resp.body)
        self.error = CallError.NONE
        self.message = String()

    def __init__(out self, *, error: Int, message: String):
        self.status = 0
        self.headers = HeaderMap()
        self.body = List[UInt8]()
        self.error = error
        self.message = message

    def ok(self) -> Bool:
        """Whether the call got a response with a 2xx status."""
        if self.error != CallError.NONE:
            return False
        return self.status >= 200 and self.status < 300

    def failed(self) -> Bool:
        """Whether the call got no response at all."""
        return self.error != CallError.NONE

    def text(self) -> String:
        """The body as text; empty when the call failed."""
        return String(unsafe_from_utf8=Span(self.body))


struct OutgoingCall(Movable):
    """One call a handler asked for, not sent yet."""

    var request: Request
    """The request to send; ``url`` is a full URL."""
    var timeout_ms: Int
    """How long the call may take in all."""
    var tls: TlsConfig
    """How an ``https://`` call checks the server: the setting on
    ``OnLoop``, or the default (OpenSSL's default CA bundle)."""

    def __init__(
        out self,
        var request: Request,
        timeout_ms: Int,
        tls: TlsConfig = TlsConfig(),
    ):
        self.request = request^
        self.timeout_ms = timeout_ms
        self.tls = tls.copy()


struct Calls(Movable):
    """The calls of one request: what is asked for, what came back, and
    notes that middleware keeps between ``start`` and ``finish``.

    Replies are numbered in the order the calls were asked for, across
    every round: the first call of round two follows the last of round one.
    """

    var _waiting: List[OutgoingCall]
    var _replies: List[CallReply]
    var _round: Int
    var _notes: Dict[String, String]
    var _tls: TlsConfig

    def __init__(out self):
        self._waiting = List[OutgoingCall]()
        self._replies = List[CallReply]()
        self._round = 0
        self._notes = Dict[String, String]()
        self._tls = TlsConfig()

    # ── Asking for calls ────────────────────────────────────────────────────

    def get(
        mut self, url: String, timeout_ms: Int = DEFAULT_CALL_TIMEOUT_MS
    ) -> Int:
        """Ask for a ``GET`` of ``url``. Returns the reply's number."""
        return self.send(Request(method=Method.GET, url=url), timeout_ms)

    def post(
        mut self,
        url: String,
        body: String,
        content_type: String = "application/json",
        timeout_ms: Int = DEFAULT_CALL_TIMEOUT_MS,
    ) raises -> Int:
        """Ask for a ``POST`` of ``body`` to ``url``. Returns the reply's
        number."""
        var req = Request(
            method=Method.POST, url=url, body=List[UInt8](body.as_bytes())
        )
        req.headers.set("Content-Type", content_type)
        return self.send(req^, timeout_ms)

    def send(
        mut self, var req: Request, timeout_ms: Int = DEFAULT_CALL_TIMEOUT_MS
    ) -> Int:
        """Ask for ``req`` with any method, headers and body. ``req.url``
        is a full ``http://`` or ``https://`` URL. Returns the reply's
        number."""
        var number = len(self._replies) + len(self._waiting)
        self._waiting.append(OutgoingCall(req^, timeout_ms, self._tls))
        return number

    def use_tls(mut self, tls: TlsConfig):
        """Check ``https://`` servers with ``tls`` for the calls asked for
        from now on. ``OnLoop`` sets this from its ``tls`` setting."""
        self._tls = tls.copy()

    # ── Reading replies ─────────────────────────────────────────────────────

    def round(self) -> Int:
        """How many rounds of calls have come back: ``1`` in the first
        ``finish``, ``2`` in the next, and so on."""
        return self._round

    def count(self) -> Int:
        """How many replies have come back so far."""
        return len(self._replies)

    def reply(
        self, number: Int
    ) raises -> ref[origin_of(self._replies[0])] CallReply:
        """The reply to call ``number``, counted from 0 across rounds."""
        if number < 0 or number >= len(self._replies):
            raise Error(
                String(
                    "no reply ",
                    number,
                    ": ",
                    len(self._replies),
                    " replies so far",
                )
            )
        return self._replies[number]

    # ── Notes ───────────────────────────────────────────────────────────────

    def note(mut self, key: String, value: String):
        """Keep ``value`` under ``key`` until the request is answered.
        Middleware uses this to carry what its ``start`` learned to its
        ``finish``."""
        self._notes[key] = value

    def note(self, key: String) -> String:
        """The note kept under ``key``, or empty when there is none."""
        var found = self._notes.get(key)
        if found:
            return found.value()
        return String()

    # ── For the code that runs the calls ────────────────────────────────────

    def waiting(self) -> Int:
        """How many calls are asked for and not sent yet."""
        return len(self._waiting)

    def take_waiting(mut self) -> List[OutgoingCall]:
        """Hand over the calls asked for since the last round. Their
        replies must come back through ``add_reply`` in the same order."""
        var out = self._waiting^
        self._waiting = List[OutgoingCall]()
        return out^

    def add_reply(mut self, var reply: CallReply):
        """Record the next reply."""
        self._replies.append(reply^)

    def restart(mut self):
        """Forget every call and reply, keeping the notes, so a wrapper
        such as ``Retry`` can run its inner handler's steps again from
        ``start``."""
        self._waiting = List[OutgoingCall]()
        self._replies = List[CallReply]()
        self._round = 0

    def end_round(mut self) raises:
        """Mark the round's replies as all back, before ``finish`` runs.
        Raises once a request has made ``MAX_ROUNDS`` rounds."""
        self._round += 1
        if self._round > MAX_ROUNDS:
            raise Error(
                String(
                    "a request made more than ", MAX_ROUNDS, " rounds of calls"
                )
            )


def no_response_and_no_calls() -> Error:
    """The error for a ``start`` or ``finish`` that returns ``None``
    without asking for a call, which would wait forever."""
    return Error("start or finish returned no response and asked for no calls")

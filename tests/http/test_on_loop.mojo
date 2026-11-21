"""Tests for ``Calls``, ``OnLoop`` and the router's steps (ADR-0006),
through the blocking steps runner every server loop falls back to."""

from std.collections import Optional
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from dodo.http import (
    App,
    CallError,
    CallReply,
    Calling,
    Calls,
    HttpServer,
    OnLoop,
    Request,
    Response,
    Router,
    ok,
)
from dodo.http.calls import MAX_ROUNDS
from dodo.http.cancel import CancelCell, CancelReason
from dodo.http.on_loop import serve_steps_blocking
from dodo.net import SocketAddr
from dodo.tcp import TcpListener
from dodo.testing import TestClient, fork_server, kill_forked_server


# ── A backend to call ───────────────────────────────────────────────────────


def _backend() raises -> Router:
    var r = Router()
    r.get("/token", _token)
    r.get("/a", _a)
    r.get("/b", _b)
    r.post("/echo", _echo)
    return r^


def _token(req: Request) raises -> Response:
    return ok("tok")


def _a(req: Request) raises -> Response:
    return ok("A:" + req.url)


def _b(req: Request) raises -> Response:
    return ok("B")


def _echo(req: Request) raises -> Response:
    var body = String(unsafe_from_utf8=Span(req.body))
    return ok(req.headers.get("content-type") + "|" + body)


def _closed_url() raises -> String:
    """A URL on a port nobody listens on."""
    var listener = TcpListener.bind(SocketAddr.localhost(0))
    var port = Int(listener.local_addr().port)
    listener.close()
    return String("http://127.0.0.1:", port, "/")


# ── Handlers in steps ───────────────────────────────────────────────────────


@fieldwise_init
struct _Dash(Calling, Copyable):
    """Logs in, then fetches two things with the token."""

    var base: String

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get(self.base + "/token")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        if calls.round() == 1:
            var token = calls.reply(0).text()
            _ = calls.get(self.base + "/a?t=" + token)
            _ = calls.get(self.base + "/b")
            return None
        return ok(calls.reply(1).text() + "|" + calls.reply(2).text())


@fieldwise_init
struct _Post(Calling, Copyable):
    var url: String

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.post(self.url, '{"x":1}')
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return ok(calls.reply(0).text())


@fieldwise_init
struct _Kinds(Calling, Copyable):
    """Makes one call to each URL and answers with the error kinds."""

    var urls: List[String]
    var timeout_ms: Int

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        for url in self.urls:
            _ = calls.get(url, timeout_ms=self.timeout_ms)
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        var out = String()
        for i in range(calls.count()):
            if i > 0:
                out += ","
            out += String(calls.reply(i).error)
        return ok(out)


@fieldwise_init
struct _AnswerAtOnce(Calling, Copyable):
    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return ok("no calls needed")

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        raise Error("finish must not run")


@fieldwise_init
struct _Forgets(Calling, Copyable):
    """Returns ``None`` without asking for a call."""

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return None


@fieldwise_init
struct _Forever(Calling, Copyable):
    """Asks for another round every time."""

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("not a url")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("not a url")
        return None


@fieldwise_init
struct _Param(Calling, Copyable):
    """Answers with the ``id`` path parameter and the path it saw, from
    ``finish``."""

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("not a url")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return ok(req.param("id") + " " + req.url)


def _hello(req: Request) raises -> Response:
    return ok("hello")


# ── Calls ───────────────────────────────────────────────────────────────────


def test_replies_are_numbered_across_rounds() raises:
    var calls = Calls()
    assert_equal(calls.get("http://x/1"), 0)
    assert_equal(calls.get("http://x/2"), 1)
    assert_equal(calls.waiting(), 2)
    var first = calls.take_waiting()
    assert_equal(len(first), 2)
    assert_equal(calls.waiting(), 0)
    calls.add_reply(CallReply(ok("one")))
    calls.add_reply(CallReply(error=CallError.TIMEOUT, message="slow"))
    calls.end_round()
    assert_equal(calls.round(), 1)
    assert_equal(calls.count(), 2)
    assert_equal(calls.post("http://x/3", "{}"), 2)
    assert_equal(calls.reply(0).text(), "one")
    assert_true(calls.reply(0).ok())
    assert_true(calls.reply(1).failed())
    assert_false(calls.reply(1).ok())
    assert_equal(calls.reply(1).status, 0)
    assert_equal(calls.reply(1).message, "slow")
    with assert_raises(contains="no reply 2"):
        _ = calls.reply(2)
    with assert_raises(contains="no reply -1"):
        _ = calls.reply(-1)


def test_a_reply_with_an_error_status_is_not_ok_but_not_failed() raises:
    var reply = CallReply(Response(status=503))
    assert_false(reply.ok())
    assert_false(reply.failed())
    assert_equal(reply.status, 503)


def test_notes_and_restart() raises:
    var calls = Calls()
    assert_equal(calls.note("missing"), "")
    calls.note("k", "v")
    calls.note("k", "w")
    assert_equal(calls.note("k"), "w")
    _ = calls.get("http://x/")
    _ = calls.take_waiting()
    calls.add_reply(CallReply(ok("x")))
    calls.end_round()
    _ = calls.get("http://x/again")
    calls.restart()
    assert_equal(calls.count(), 0)
    assert_equal(calls.round(), 0)
    assert_equal(calls.waiting(), 0)
    assert_equal(calls.note("k"), "w")
    assert_equal(calls.get("http://x/"), 0)


def test_rounds_are_capped() raises:
    var calls = Calls()
    for _ in range(MAX_ROUNDS):
        calls.end_round()
    with assert_raises(contains="rounds of calls"):
        calls.end_round()


# ── The blocking steps runner ───────────────────────────────────────────────


def test_two_rounds_of_calls() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var base = String("http://127.0.0.1:", Int(srv.local_addr().port))
    var pid = fork_server(srv^, _backend())
    var body: String
    var served: String
    try:
        var h = OnLoop(_Dash(base))
        body = serve_steps_blocking(h, Request.test_get("/dash")).text()
        served = h.serve(Request.test_get("/dash")).text()
    finally:
        kill_forked_server(pid)
    assert_equal(body, "A:/a?t=tok|B")
    assert_equal(served, body)


def test_post_sends_the_body_and_content_type() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var url = String("http://127.0.0.1:", Int(srv.local_addr().port), "/echo")
    var pid = fork_server(srv^, _backend())
    var body: String
    try:
        body = serve_steps_blocking(
            OnLoop(_Post(url)), Request(method="POST", url="/")
        ).text()
    finally:
        kill_forked_server(pid)
    assert_equal(body, 'application/json|{"x":1}')


def test_failed_calls_say_why() raises:
    var silent = TcpListener.bind(SocketAddr.localhost(0))
    var silent_url = String(
        "http://127.0.0.1:", Int(silent.local_addr().port), "/"
    )
    var urls: List[String] = [
        _closed_url(),
        silent_url,
        "not a url",
        "ftp://x/",
        "http://no-such-host.invalid/",
    ]
    var body = serve_steps_blocking(
        OnLoop(_Kinds(urls^, 300)), Request.test_get("/")
    ).text()
    silent.close()
    var expected = String(
        CallError.CONNECT,
        ",",
        CallError.TIMEOUT,
        ",",
        CallError.BAD_URL,
        ",",
        CallError.BAD_URL,
        ",",
        CallError.CONNECT,
    )
    assert_equal(body, expected)


def test_a_cancelled_request_sends_nothing() raises:
    var cell = CancelCell()
    var req = Request.test_get("/")
    req.cancel = cell.handle()
    cell.flip(CancelReason.PEER_CLOSED)
    var urls: List[String] = [_closed_url(), "not a url"]
    var body = serve_steps_blocking(OnLoop(_Kinds(urls^, 300)), req).text()
    assert_equal(body, String(CallError.CANCELLED, ",", CallError.CANCELLED))


def test_start_may_answer_without_calls() raises:
    var resp = serve_steps_blocking(
        OnLoop(_AnswerAtOnce()), Request.test_get("/")
    )
    assert_equal(resp.text(), "no calls needed")


def test_no_response_and_no_calls_raises() raises:
    with assert_raises(contains="asked for no calls"):
        _ = serve_steps_blocking(OnLoop(_Forgets()), Request.test_get("/"))


def test_endless_rounds_raise() raises:
    with assert_raises(contains="rounds of calls"):
        _ = serve_steps_blocking(OnLoop(_Forever()), Request.test_get("/"))


def test_a_handler_without_steps_is_served() raises:
    var r = Router()
    r.get("/", _hello)
    assert_false(r.calling(Request.test_get("/")))
    var resp = serve_steps_blocking(r, Request.test_get("/"))
    assert_equal(resp.text(), "hello")


# ── Router, mount, App, TestClient ──────────────────────────────────────────


def _router() raises -> Router:
    var r = Router()
    r.get("/hello", _hello)
    r.get("/user/{id}", OnLoop(_Param()))
    return r^


def test_router_asks_the_matched_route() raises:
    var r = _router()
    assert_true(r.may_call())
    assert_true(r.calling(Request.test_get("/user/7")))
    assert_false(r.calling(Request.test_get("/hello")))
    assert_false(r.calling(Request.test_get("/nowhere")))
    assert_false(r.calling(Request(method="POST", url="/user/7")))
    assert_false(Router().may_call())


def test_router_runs_the_steps_with_path_params() raises:
    var r = _router()
    var resp = serve_steps_blocking(r, Request.test_get("/user/7"))
    assert_equal(resp.text(), "7 /user/7")
    var bad = serve_steps_blocking(r, Request.test_get("/user/%zz"))
    assert_equal(bad.status, 400)


def test_router_start_serves_routes_without_steps() raises:
    var r = _router()
    var calls = Calls()
    var hello = r.start(Request.test_get("/hello"), calls)
    assert_equal(hello.value().text(), "hello")
    var missing = r.start(Request.test_get("/nowhere"), calls)
    assert_equal(missing.value().status, 404)
    var wrong = r.start(Request(method="POST", url="/hello"), calls)
    assert_equal(wrong.value().status, 405)
    assert_equal(calls.waiting(), 0)
    with assert_raises(contains="no route makes calls"):
        _ = r.finish(Request.test_get("/hello"), calls)


def test_route_list_marks_calls() raises:
    var routes = _router().route_list()
    assert_equal(len(routes), 2)
    assert_false(routes[0].calls)
    assert_true(routes[1].calls)
    assert_false(routes[1].blocking)


def test_a_mount_strips_its_prefix_in_every_step() raises:
    var root = Router()
    root.mount("/api", _router())
    assert_true(root.may_call())
    assert_true(root.calling(Request.test_get("/api/user/9?q=1")))
    assert_false(root.calling(Request.test_get("/api/hello")))
    var resp = serve_steps_blocking(root, Request.test_get("/api/user/9?q=1"))
    assert_equal(resp.text(), "9 /user/9?q=1")
    var routes = root.route_list()
    assert_equal(routes[1].path, "/api/user/{id}")
    assert_true(routes[1].calls)


def test_app_routes_a_handler_struct() raises:
    var app = App()
    app.get["/user/{id}"](OnLoop(_Param()))
    app.get["/hello"](_hello)
    assert_true(app.may_call())
    assert_true(app.calling(Request.test_get("/user/3")))
    assert_false(app.calling(Request.test_get("/hello")))
    var resp = serve_steps_blocking(app, Request.test_get("/user/3"))
    assert_equal(resp.text(), "3 /user/3")
    assert_true(app.route_list()[0].calls)


def test_test_client_runs_the_steps() raises:
    var client = TestClient(_router())
    var resp = client.get("/user/5")
    assert_equal(resp.text(), "5 /user/5")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

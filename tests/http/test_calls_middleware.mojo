"""Every built-in middleware runs its before-part in ``start`` and its
after-part on the response, whichever step returns it (ADR-0006).

The handlers here ask for a call to ``not a url``, which fails at once
with ``CallError.BAD_URL``, so each request goes start, round, finish
without a network."""

from std.collections import Optional
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from dodo.http import (
    CallError,
    Calling,
    Calls,
    CatchPanic,
    Compress,
    Conditional,
    Cors,
    CorsConfig,
    Handler,
    Logger,
    OnLoop,
    PathInt,
    Request,
    RequestId,
    Response,
    StructuredLogger,
    ok,
)
from dodo.http._shared_handler import SharedHandler
from dodo.http.cache import Cache, InMemoryCacheStore
from dodo.http.extract import Extracted
from dodo.http.metrics import Metrics, MetricsRegistry
from dodo.http.on_loop import serve_steps_blocking
from dodo.http.reliability import (
    CircuitBreaker,
    PostHocDeadline,
    RateLimit,
    Retry,
)
from dodo.runtime.pool import Pool


@fieldwise_init
struct _Answer(Calling, Copyable):
    """One failing call, then ``status`` with ``body`` from ``finish``."""

    var status: Int
    var body: String
    var cache_control: String

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("not a url")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        if calls.reply(0).error != CallError.BAD_URL:
            raise Error("the call should have failed with BAD_URL")
        var resp = Response(status=self.status)
        resp.body = List[UInt8](self.body.as_bytes())
        if self.cache_control != "":
            resp.headers.set("Cache-Control", self.cache_control)
        return resp^


def _answer(
    status: Int = 200, body: String = "done", cache_control: String = ""
) -> OnLoop[_Answer]:
    return OnLoop(_Answer(status, body, cache_control))


@fieldwise_init
struct _Raises(Calling, Copyable):
    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("not a url")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        raise Error("finish failed")


@fieldwise_init
struct _FailsOnce(Calling, Copyable):
    """``503`` on the first attempt, then ``200`` with how many replies
    the second attempt sees."""

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("not a url")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        if calls.note("test.failed") == "":
            calls.note("test.failed", "yes")
            return Response(status=503)
        return ok(String("replies=", calls.count()))


def _get(url: String) -> Request:
    return Request(method="GET", url=url)


def _steps[H: Handler](handler: H, req: Request) raises -> Response:
    assert_true(handler.calling(req), "the stack must forward calling")
    return serve_steps_blocking(handler, req)


def test_logger_and_structured_logger() raises:
    var logged = Logger(_answer())
    assert_true(logged.may_call())
    assert_equal(_steps(logged, _get("/")).text(), "done")
    var structured = StructuredLogger(_answer())
    assert_true(structured.may_call())
    assert_equal(_steps(structured, _get("/")).text(), "done")
    with assert_raises(contains="finish failed"):
        _ = _steps(Logger(OnLoop(_Raises())), _get("/"))
    with assert_raises(contains="finish failed"):
        _ = _steps(StructuredLogger(OnLoop(_Raises())), _get("/"))


def test_request_id_reaches_the_response() raises:
    var h = RequestId(_answer())
    var req = _get("/")
    req.headers.set("X-Request-Id", "abc")
    assert_equal(_steps(h, req).headers.get("x-request-id"), "abc")
    var fresh = _steps(h, _get("/")).headers.get("x-request-id")
    assert_true(fresh.startswith("req-"))


def test_compress_encodes_the_final_response() raises:
    var h = Compress(_answer(body=String("a") * 4096))
    var req = _get("/")
    req.headers.set("Accept-Encoding", "gzip")
    var resp = _steps(h, req)
    assert_equal(resp.headers.get("content-encoding"), "gzip")
    assert_true(len(resp.body) < 4096)


def test_catch_panic_turns_a_raise_in_finish_into_500() raises:
    var resp = _steps(CatchPanic(OnLoop(_Raises())), _get("/"))
    assert_equal(resp.status, 500)


def test_cors_answers_a_preflight_without_calls() raises:
    var h = Cors(_answer(), CorsConfig.permissive())
    var preflight = Request(method="OPTIONS", url="/")
    preflight.headers.set("Origin", "https://app.test")
    preflight.headers.set("Access-Control-Request-Method", "POST")
    var calls = Calls()
    var early = h.start(preflight, calls)
    assert_equal(early.value().status, 204)
    assert_equal(calls.waiting(), 0)
    var req = _get("/")
    req.headers.set("Origin", "https://app.test")
    var resp = _steps(h, req)
    assert_equal(resp.text(), "done")
    assert_true(resp.headers.contains("access-control-allow-origin"))


def test_conditional_answers_304_after_the_calls() raises:
    var h = Conditional.with_auto_etag(_answer())
    var etag = _steps(h, _get("/")).headers.get("etag")
    assert_true(etag != "")
    var again = _get("/")
    again.headers.set("If-None-Match", etag)
    assert_equal(_steps(h, again).status, 304)


def test_metrics_count_a_request_once() raises:
    var m = Metrics(_answer())
    _ = _steps(m, _get("/"))
    var reg = Pool[MetricsRegistry].get_ptr(m.registry_addr)
    assert_equal(Int(reg[].duration_count), 1)
    assert_equal(Int(reg[].in_flight), 0)
    with assert_raises(contains="finish failed"):
        _ = _steps(Metrics(OnLoop(_Raises())), _get("/"))


def test_metrics_leave_a_parked_request_in_flight() raises:
    var m = Metrics(_answer())
    var calls = Calls()
    _ = m.start(_get("/"), calls)
    var reg = Pool[MetricsRegistry].get_ptr(m.registry_addr)
    assert_equal(Int(reg[].in_flight), 1)
    assert_equal(Int(reg[].duration_count), 0)


def test_retry_starts_the_steps_over() raises:
    var resp = _steps(Retry(OnLoop(_FailsOnce())), _get("/"))
    assert_equal(resp.status, 200)
    assert_equal(resp.text(), "replies=1")
    var no_retry = _steps(
        Retry(OnLoop(_FailsOnce())), Request(method="POST", url="/")
    )
    assert_equal(no_retry.status, 503)
    var always = _steps(Retry(_answer(status=500)), _get("/"))
    assert_equal(always.status, 500)
    with assert_raises(contains="finish failed"):
        _ = _steps(Retry(OnLoop(_Raises())), _get("/"))


def test_deadline_checks_the_final_response() raises:
    assert_equal(
        _steps(PostHocDeadline(_answer(), 60_000), _get("/")).status, 200
    )
    var calls = Calls()
    var refused = PostHocDeadline(_answer(), 0).start(_get("/"), calls)
    assert_equal(refused.value().status, 504)
    assert_equal(calls.waiting(), 0)


def test_rate_limit_refuses_in_start() raises:
    var h = RateLimit(_answer(), rate_per_sec=1, burst=1)
    assert_equal(_steps(h, _get("/")).status, 200)
    var calls = Calls()
    assert_equal(h.start(_get("/"), calls).value().status, 429)
    assert_equal(calls.waiting(), 0)


def test_circuit_breaker_counts_the_final_response() raises:
    var h = CircuitBreaker(_answer(status=500), failure_threshold=1)
    assert_equal(_steps(h, _get("/")).status, 500)
    var calls = Calls()
    assert_equal(h.start(_get("/"), calls).value().status, 503)
    assert_equal(calls.waiting(), 0)
    var raising = CircuitBreaker(OnLoop(_Raises()), failure_threshold=1)
    with assert_raises(contains="finish failed"):
        _ = _steps(raising, _get("/"))
    assert_equal(raising.start(_get("/"), calls).value().status, 503)


def test_cache_stores_the_final_response() raises:
    var h = Cache[OnLoop[_Answer], InMemoryCacheStore](
        _answer(cache_control="max-age=60"), InMemoryCacheStore()
    )
    assert_equal(_steps(h, _get("/x")).text(), "done")
    var calls = Calls()
    var hit = h.start(_get("/x"), calls)
    assert_equal(hit.value().headers.get("x-cache"), "HIT")
    assert_equal(calls.waiting(), 0)


@fieldwise_init
struct _ById(Copyable, Defaultable, Handler):
    """A handler with an extractor field that serves in steps itself."""

    var id: PathInt["id"]

    def __init__(out self):
        self.id = PathInt["id"]()

    def serve(self, req: Request) raises -> Response:
        return ok("serve")

    def may_call(self) -> Bool:
        return True

    def calling(self, req: Request) raises -> Bool:
        return True

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get("not a url")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return ok(String("id=", self.id.value.value()))


def test_extracted_fills_the_fields_for_each_step() raises:
    var h = Extracted[_ById]()
    var req = _get("/")
    req.params_mut()["id"] = "42"
    assert_equal(_steps(h, req).text(), "id=42")
    var bad = _get("/")
    bad.params_mut()["id"] = "x"
    assert_equal(_steps(h, bad).status, 400)


def test_shared_handler_forwards_the_steps() raises:
    var h = SharedHandler(_answer())
    assert_true(h.may_call())
    assert_equal(_steps(h, _get("/")).text(), "done")


def test_a_full_stack_answers_like_serve() raises:
    var h = Logger(
        RequestId(Compress(Cors(_answer(), CorsConfig.permissive())))
    )
    var req = _get("/")
    req.headers.set("X-Request-Id", "id-1")
    req.headers.set("Origin", "https://app.test")
    var stepped = _steps(h, req)
    var served = h.serve(req)
    assert_equal(stepped.status, served.status)
    assert_equal(stepped.text(), served.text())
    assert_equal(stepped.headers.get("x-request-id"), "id-1")
    assert_equal(
        stepped.headers.get("access-control-allow-origin"),
        served.headers.get("access-control-allow-origin"),
    )


def test_offload_keeps_its_requests_off_the_steps() raises:
    from dodo.http import Offload

    var h = Offload(_answer())
    assert_false(h.may_call())
    assert_false(h.calling(_get("/")))
    assert_equal(serve_steps_blocking(h, _get("/")).text(), "done")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

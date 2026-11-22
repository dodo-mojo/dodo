"""Outgoing calls on the server's own loop, end to end (ADR-0006): a
request parks while its calls run, and the worker serves others."""

from std.collections import Optional
from std.testing import TestSuite, assert_equal, assert_true

from dodo.http import (
    Calling,
    Calls,
    HttpClient,
    HttpServer,
    OnLoop,
    Request,
    Response,
    Router,
    ServerConfig,
    ok,
)
from dodo.net import SocketAddr
from dodo.runtime import Pool
from dodo.runtime._libc_time import monotonic_now_ms
from dodo.runtime._thread import ThreadHandle, _OpaquePtr, _null_ptr
from dodo.runtime.scheduler_stats import store_stop_flag
from dodo.tcp import TcpStream
from dodo.testing import fork_server, kill_forked_server
from dodo.tls import TlsConfig
from dodo.utils import exit, fork, usleep


# ── The backend the front server calls ─────────────────────────────────────


def _backend() raises -> Router:
    var r = Router()
    r.get("/token", _token)
    r.get("/a", _a)
    r.get("/b", _b)
    r.get("/slow", _slow)
    return r^


def _token(req: Request) raises -> Response:
    return ok("tok")


def _a(req: Request) raises -> Response:
    return ok("A:" + req.url)


def _b(req: Request) raises -> Response:
    return ok("B")


def _slow(req: Request) raises -> Response:
    usleep(600_000)
    return ok("slow")


# ── The front server ───────────────────────────────────────────────────────


@fieldwise_init
struct _Dash(Calling, Copyable):
    """Logs in, then fetches two things side by side with the token."""

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
struct _Slow(Calling, Copyable):
    var base: String

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get(self.base + "/slow")
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        return ok(calls.reply(0).text())


@fieldwise_init
struct _Fetch(Calling, Copyable):
    """Fetches one URL and answers with its body, or why it failed."""

    var url: String

    def start(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        _ = calls.get(self.url)
        return None

    def finish(
        self, req: Request, mut calls: Calls
    ) raises -> Optional[Response]:
        ref reply = calls.reply(0)
        if reply.failed():
            return ok("failed: " + reply.message)
        return ok(reply.text())


def _ping(req: Request) raises -> Response:
    return ok("pong")


def _front(base: String) raises -> Router:
    var r = Router()
    r.get("/dash", OnLoop(_Dash(base)))
    r.get("/slow", OnLoop(_Slow(base)))
    r.get("/ping", _ping)
    return r^


struct _Servers:
    """A backend and a front server that calls it, each forked."""

    var backend: Int
    var front: Int
    var url: String

    def __init__(out self, config: ServerConfig = ServerConfig()) raises:
        var back = HttpServer.bind(SocketAddr.localhost(0))
        var base = String("http://127.0.0.1:", Int(back.local_addr().port))
        self.backend = fork_server(back^, _backend())
        var front = HttpServer.bind(SocketAddr.localhost(0), config.copy())
        var port = Int(front.local_addr().port)
        self.url = String("http://127.0.0.1:", port)
        self.front = fork_server(front^, _front(base))

    def stop(self):
        kill_forked_server(self.front)
        kill_forked_server(self.backend)


struct _StopLater(Movable):
    """Where a server's stop flag is, and when to set it."""

    var flag_addr: Int
    var delay_us: Int

    def __init__(out self, flag_addr: Int, delay_us: Int):
        self.flag_addr = flag_addr
        self.delay_us = delay_us


def _stop_later(arg: _OpaquePtr) -> _OpaquePtr:
    var stop = Pool[_StopLater].get_ptr(Int(arg))
    usleep(stop[].delay_us)
    store_stop_flag(stop[].flag_addr, True)
    return _null_ptr()


def _fork_front_that_stops(base: String, stop_after_us: Int) raises -> Int:
    """Fork the front server; it starts a graceful stop after
    ``stop_after_us``. Returns its port; the child exits once it drained."""
    var config = ServerConfig(shutdown_timeout_ms=10_000)
    var srv = HttpServer.bind(SocketAddr.localhost(0), config^)
    var port = Int(srv.local_addr().port)
    var pid = fork()
    if pid == 0:
        try:
            var flag = Int(Pointer[Bool, _](to=srv._stopping))
            var stop = Pool[_StopLater].alloc_move(
                _StopLater(flag, stop_after_us)
            )
            var t = ThreadHandle.spawn_os[_stop_later](
                _OpaquePtr(unsafe_from_address=stop)
            )
            t.detach()
            srv.serve(_front(base))
        except:
            pass
        exit()
    usleep(150_000)
    return port


def _get(url: String) raises -> Response:
    var client = HttpClient(timeout_ms=5_000).with_read_timeout(5_000)
    return client.get(url)


def _get_h2(url: String) raises -> Response:
    """Speak HTTP/2 from the first byte, so only an h2 server answers."""
    var client = HttpClient(timeout_ms=5_000).with_read_timeout(5_000)
    client = client^.with_h2c(prior_knowledge=True)
    return client.get(url)


def _send_raw(url_port: Int, path: String) raises -> TcpStream:
    """Send a request and leave the reply unread."""
    var conn = TcpStream.connect(SocketAddr.localhost(UInt16(url_port)))
    var req = String("GET ", path, " HTTP/1.1\r\nHost: x\r\n\r\n")
    conn.write_all(Span(req.as_bytes()))
    return conn^


def _read_all(mut conn: TcpStream) raises -> String:
    """Read until the server closes the connection."""
    var got = List[UInt8]()
    var buf = List[UInt8](capacity=4096)
    buf.resize(4096, 0)
    while True:
        var n = conn.read(buf.unsafe_ptr(), 4096)
        if n <= 0:
            break
        got.extend(Span(buf)[:n])
    return String(unsafe_from_utf8=Span(got))


def _port(url: String) raises -> Int:
    var colon = url.rfind(":")
    return Int(String(url[byte = colon + 1 :]))


# ── Tests ───────────────────────────────────────────────────────────────────


def test_two_rounds_of_calls_on_the_loop() raises:
    var servers = _Servers()
    var body: String
    try:
        body = _get(servers.url + "/dash").text()
    finally:
        servers.stop()
    assert_equal(body, "A:/a?t=tok|B")


def test_the_worker_serves_while_a_request_waits_on_calls() raises:
    var servers = _Servers()
    var ping_ms: Int
    var slow: String
    var ping: String
    try:
        var parked = _send_raw(_port(servers.url), "/slow")
        usleep(100_000)
        var start = monotonic_now_ms()
        ping = _get(servers.url + "/ping").text()
        ping_ms = monotonic_now_ms() - start
        var buf = List[UInt8](capacity=4096)
        buf.resize(4096, 0)
        var n = parked.read(buf.unsafe_ptr(), 4096)
        slow = String(unsafe_from_utf8=Span(buf)[:n])
    finally:
        servers.stop()
    assert_equal(ping, "pong")
    assert_true(ping_ms < 300, String("ping took ", ping_ms, " ms"))
    assert_true(slow.endswith("slow"), slow)


def test_a_slow_call_gets_503_at_the_handler_deadline() raises:
    var servers = _Servers(ServerConfig(handler_timeout_ms=200))
    var status: Int
    try:
        status = _get(servers.url + "/slow").status
    finally:
        servers.stop()
    assert_equal(status, 503)


def test_a_client_that_leaves_does_not_hurt_the_worker() raises:
    var servers = _Servers()
    var after: String
    try:
        var parked = _send_raw(_port(servers.url), "/slow")
        usleep(50_000)
        parked.close()
        usleep(50_000)
        after = _get(servers.url + "/dash").text()
    finally:
        servers.stop()
    assert_equal(after, "A:/a?t=tok|B")


def test_two_rounds_of_calls_on_an_http2_stream() raises:
    var servers = _Servers()
    var body: String
    try:
        body = _get_h2(servers.url + "/dash").text()
    finally:
        servers.stop()
    assert_equal(body, "A:/a?t=tok|B")


def test_a_slow_call_on_an_http2_stream_gets_503_at_the_deadline() raises:
    var servers = _Servers(ServerConfig(handler_timeout_ms=200))
    var status: Int
    var after: String
    try:
        status = _get_h2(servers.url + "/slow").status
        after = _get_h2(servers.url + "/ping").text()
    finally:
        servers.stop()
    assert_equal(status, 503)
    assert_equal(after, "pong")


def test_a_stop_still_answers_a_request_waiting_on_calls() raises:
    var back = HttpServer.bind(SocketAddr.localhost(0))
    var base = String("http://127.0.0.1:", Int(back.local_addr().port))
    var backend = fork_server(back^, _backend())
    var reply: String
    try:
        # /slow parks for 600 ms; the stop comes 200 ms into it.
        var port = _fork_front_that_stops(base, 300_000)
        var parked = _send_raw(port, "/slow")
        reply = _read_all(parked)
    finally:
        kill_forked_server(backend)
    assert_true(reply.startswith("HTTP/1.1 200"), reply)
    assert_true(reply.endswith("slow"), reply)
    assert_true("connection: close" in reply.lower(), reply)


comptime _CA_CRT = "tests/certs/ca.crt"


def test_call_tls_is_set_on_on_loop() raises:
    var alpn = List[String]()
    alpn.append("http/1.1")
    var back = HttpServer.bind_tls(
        SocketAddr.localhost(0),
        "tests/certs/server.crt",
        "tests/certs/server.key",
        alpn=alpn^,
    )
    var url = String("https://localhost:", Int(back.local_addr().port), "/b")
    var backend = fork_server(back^, _backend())
    var r = Router()
    r.get("/trusted", OnLoop(_Fetch(url), tls=TlsConfig(ca_bundle=_CA_CRT)))
    r.get("/default", OnLoop(_Fetch(url)))
    var front = HttpServer.bind(SocketAddr.localhost(0))
    var base = String("http://127.0.0.1:", Int(front.local_addr().port))
    var front_pid = fork_server(front^, r^)
    var trusted: String
    var default: String
    try:
        trusted = _get(base + "/trusted").text()
        default = _get(base + "/default").text()
    finally:
        kill_forked_server(front_pid)
        kill_forked_server(backend)
    assert_equal(trusted, "B")
    assert_true(default.startswith("failed: "), default)
    assert_true("certificate" in default.lower(), default)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

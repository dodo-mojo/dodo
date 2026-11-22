"""``LoopClient`` on a reactor of its own: calls to a forked backend,
side by side, through redirects, gzip and failures (ADR-0006)."""

from std.testing import TestSuite, assert_equal, assert_true

from dodo.http import (
    CallError,
    CallReply,
    Calls,
    HttpServer,
    Request,
    Response,
    Router,
    ok,
)
from dodo.http.encoding import compress_gzip
from dodo.tls.config import TlsConfig
from dodo.net import IpAddr
from dodo.tcp import TcpStream
from dodo.utils import SIGKILL, exit, fork, kill, usleep, waitpid
from dodo.http._loop_calls.client import CallLimits, LoopClient
from dodo.http._loop_calls.task import CallTask, task_free, task_new, task_ptr
from dodo.net import SocketAddr
from dodo.runtime import Reactor
from dodo.runtime._libc_time import monotonic_now_ms
from dodo.runtime.event import Event
from dodo.tcp import TcpListener
from dodo.testing import fork_server, kill_forked_server


def _backend() raises -> Router:
    var r = Router()
    r.get("/a", _a)
    r.get("/hop", _hop)
    r.post("/echo", _echo)
    r.get("/gz", _gz)
    return r^


def _gz(req: Request) raises -> Response:
    var body = compress_gzip(Span(String("unzipped text").as_bytes()))
    var resp = Response(status=200, body=body^)
    resp.headers.set("Content-Encoding", "gzip")
    return resp^


def _a(req: Request) raises -> Response:
    return ok("A:" + req.url)


def _hop(req: Request) raises -> Response:
    var resp = Response(status=302)
    resp.headers.set("Location", "/a")
    return resp^


def _echo(req: Request) raises -> Response:
    return ok(String(unsafe_from_utf8=Span(req.body)))


def _limits(conns: Int = 64) -> CallLimits:
    return CallLimits(conns, 16, 4_000, 0, 64)


def _round(
    mut client: LoopClient,
    mut reactor: Reactor,
    var calls: Calls,
    wait_ms: Int = 5_000,
) raises -> List[String]:
    """Run one round on ``client``. Each reply comes back as
    ``status:body`` or ``!kind:message``."""
    var task = task_new(CallTask(Request.test_get("/"), calls^, 0, 0))
    client.submit(task)
    var done = _spin(client, reactor, wait_ms, True)
    assert_true(done, "the round never finished")
    var out = List[String]()
    var tp = task_ptr(task)
    for i in range(len(tp[].slots)):
        ref reply = tp[].slots[i].value()
        if reply.failed():
            out.append(String("!", reply.error, ":", reply.message))
        else:
            out.append(String(reply.status, ":", reply.text()))
    task_free(task)
    return out^


def _spin(
    mut client: LoopClient,
    mut reactor: Reactor,
    wait_ms: Int,
    until_ready: Bool,
) raises -> Bool:
    """Drive the client the way the worker loop does, for ``wait_ms`` or
    until a task is ready. True when one was."""
    var events = List[Event]()
    var start = monotonic_now_ms()
    while monotonic_now_ms() - start < wait_ms:
        client.run(reactor)
        if until_ready and len(client.ready) > 0:
            _ = client.take_ready()
            return True
        _ = reactor.poll(client.next_timeout_ms(20), events)
        for i in range(len(events)):
            if events[i].is_wakeup():
                continue
            var fd = Int(events[i].token)
            if client.owns(fd):
                client.on_event(
                    fd,
                    events[i].is_readable(),
                    events[i].is_writable(),
                    reactor,
                )
    return False


def _run(mut client: LoopClient, var calls: Calls) raises -> List[String]:
    """One round on a reactor of its own, then close the client."""
    var reactor = Reactor()
    var out = _round(client, reactor, calls^)
    client.close(reactor)
    return out^


def _read_head(mut c: TcpStream) raises -> String:
    """Read until the end of a request head; empty when the peer closed."""
    var buf = List[UInt8](capacity=4096)
    buf.resize(4096, 0)
    var acc = String()
    while acc.find("\r\n\r\n") < 0:
        var n = c.read(buf.unsafe_ptr(), 4096)
        if n == 0:
            return ""
        acc += String(unsafe_from_utf8=Span(buf)[:n])
    return acc^


def _fork_script(var listener: TcpListener, proxy: Bool) raises -> Int:
    """Fork a scripted server. As a proxy it accepts one ``CONNECT`` and
    answers the tunneled request. Otherwise each connection gets one
    keep-alive reply, then is closed once the next request arrives: an
    idle connection the server dropped as it was reused."""
    var pid = fork()
    if pid != 0:
        listener.close()
        usleep(100_000)
        return pid
    try:
        while True:
            var c = listener.accept()
            if proxy:
                _ = _read_head(c)
                c.write_all(Span(String("HTTP/1.1 200 OK\r\n\r\n").as_bytes()))
            var head = _read_head(c)
            var ok_reply = String(
                "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"
            )
            if proxy:
                ok_reply = String(
                    "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nvia-proxy"
                )
            if head.byte_length() > 0:
                c.write_all(Span(ok_reply.as_bytes()))
            _ = _read_head(c)
            c.close()
    except:
        pass
    exit()
    return 0


def test_calls_run_side_by_side_and_reuse_connections() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var base = String("http://127.0.0.1:", Int(srv.local_addr().port))
    var pid = fork_server(srv^, _backend())
    var got: List[String]
    try:
        var client = LoopClient(_limits(1))
        var calls = Calls()
        _ = calls.get(base + "/a?x=1")
        _ = calls.get(base + "/a?x=2")
        _ = calls.post(base + "/echo", "hi")
        var reactor = Reactor()
        got = _round(client, reactor, calls^)
        assert_true(len(client.conns) <= 1)
        client.close(reactor)
    finally:
        kill_forked_server(pid)
    assert_equal(len(got), 3)
    assert_equal(got[0], "200:A:/a?x=1")
    assert_equal(got[1], "200:A:/a?x=2")
    assert_equal(got[2], "200:hi")


def test_a_redirect_is_followed() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var base = String("http://127.0.0.1:", Int(srv.local_addr().port))
    var pid = fork_server(srv^, _backend())
    var got: List[String]
    try:
        var client = LoopClient(_limits())
        var calls = Calls()
        _ = calls.get(base + "/hop")
        got = _run(client, calls^)
    finally:
        kill_forked_server(pid)
    assert_equal(got[0], "200:A:/a")


def test_failures_say_why() raises:
    var closed = TcpListener.bind(SocketAddr.localhost(0))
    var closed_url = String(
        "http://127.0.0.1:", Int(closed.local_addr().port), "/"
    )
    closed.close()
    var silent = TcpListener.bind(SocketAddr.localhost(0))
    var silent_url = String(
        "http://127.0.0.1:", Int(silent.local_addr().port), "/"
    )
    var client = LoopClient(_limits())
    var calls = Calls()
    _ = calls.get(closed_url)
    _ = calls.get(silent_url, 300)
    _ = calls.get("ftp://x/")
    _ = calls.get("http://no-such-host.invalid/")
    var got = _run(client, calls^)
    silent.close()
    assert_true(
        got[0].startswith(
            String(
                "!", CallError.CONNECT, ":NetworkError: all addresses failed"
            )
        ),
        got[0],
    )
    assert_true(
        got[1].startswith(String("!", CallError.TIMEOUT, ":Timeout")), got[1]
    )
    assert_true(got[2].startswith(String("!", CallError.BAD_URL, ":")), got[2])
    assert_true(got[3].startswith(String("!", CallError.CONNECT, ":")), got[3])


def test_https_with_a_trusted_ca_and_a_fallback_address() raises:
    var srv = HttpServer.bind_tls(
        SocketAddr(IpAddr.parse("127.0.0.1"), 0),
        "tests/certs/server.crt",
        "tests/certs/server.key",
    )
    var url = String("https://localhost:", Int(srv.local_addr().port), "/a")
    var pid = fork_server(srv^, _backend())
    var good: List[String]
    var bad: List[String]
    try:
        var client = LoopClient(_limits())
        var calls = Calls()
        calls.use_tls(TlsConfig(ca_bundle="tests/certs/ca.crt"))
        _ = calls.get(url)
        _ = calls.get(url + "?again")
        good = _run(client, calls^)
        var other = LoopClient(_limits())
        var untrusted = Calls()
        _ = untrusted.get(url)
        bad = _run(other, untrusted^)
    finally:
        kill_forked_server(pid)
    assert_equal(good[0], "200:A:/a")
    assert_equal(good[1], "200:A:/a?again")
    assert_true(bad[0].startswith(String("!", CallError.FAILED, ":")), bad[0])
    assert_true("ertificate" in bad[0], bad[0])


def test_a_gzip_body_comes_back_unzipped() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var base = String("http://127.0.0.1:", Int(srv.local_addr().port))
    var pid = fork_server(srv^, _backend())
    var got: List[String]
    try:
        var client = LoopClient(_limits())
        var calls = Calls()
        _ = calls.get(base + "/gz")
        got = _run(client, calls^)
    finally:
        kill_forked_server(pid)
    assert_equal(got[0], "200:unzipped text")


def test_a_proxy_tunnel_carries_the_call() raises:
    var listener = TcpListener.bind(SocketAddr.localhost(0))
    var proxy = String("http://127.0.0.1:", Int(listener.local_addr().port))
    var pid = _fork_script(listener^, True)
    var got: List[String]
    try:
        var client = LoopClient(_limits())
        client.proxies.http = proxy
        client.proxies.no_proxy = ""
        var calls = Calls()
        _ = calls.get("http://example.test/path")
        got = _run(client, calls^)
    finally:
        _ = kill(pid, SIGKILL)
        waitpid(pid)
    assert_equal(got[0], "200:via-proxy")


def test_a_stale_idle_connection_is_replayed_only_when_safe() raises:
    var listener = TcpListener.bind(SocketAddr.localhost(0))
    var url = String("http://127.0.0.1:", Int(listener.local_addr().port), "/")
    var pid = _fork_script(listener^, False)
    var first: List[String]
    var second: List[String]
    var post: List[String]
    try:
        var client = LoopClient(_limits())
        var reactor = Reactor()
        var calls = Calls()
        _ = calls.get(url)
        first = _round(client, reactor, calls^)
        var again = Calls()
        _ = again.get(url)
        second = _round(client, reactor, again^)
        var unsafe = Calls()
        _ = unsafe.post(url, "x")
        post = _round(client, reactor, unsafe^)
        client.close(reactor)
    finally:
        _ = kill(pid, SIGKILL)
        waitpid(pid)
    assert_equal(first[0], "200:ok")
    assert_equal(second[0], "200:ok")
    assert_true(post[0].startswith(String("!", CallError.FAILED, ":")), post[0])
    assert_true("no reply" in post[0], post[0])


def test_cancel_ends_the_calls_and_frees_the_task() raises:
    var silent = TcpListener.bind(SocketAddr.localhost(0))
    var url = String("http://127.0.0.1:", Int(silent.local_addr().port), "/")
    var client = LoopClient(_limits())
    var reactor = Reactor()
    var calls = Calls()
    _ = calls.get(url)
    _ = calls.get(url)
    var task = task_new(CallTask(Request.test_get("/"), calls^, 0, 0))
    client.submit(task)
    _ = _spin(client, reactor, 100, True)
    assert_equal(len(client.conns), 2)
    client.cancel(task)
    client.cancel(task)
    client.run(reactor)
    assert_true(not client.busy())
    assert_equal(len(client.conns), 0)
    assert_equal(len(client.exchanges), 0)
    assert_equal(len(client.take_ready()), 0)
    client.close(reactor)
    silent.close()


def test_idle_connections_close_after_the_idle_timeout() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var base = String("http://127.0.0.1:", Int(srv.local_addr().port))
    var pid = fork_server(srv^, _backend())
    var kept: Int
    var left: Int
    try:
        var client = LoopClient(CallLimits(64, 16, 100, 0, 64))
        var reactor = Reactor()
        var calls = Calls()
        _ = calls.get(base + "/a")
        _ = calls.get(base + "/a")
        _ = _round(client, reactor, calls^)
        kept = len(client.conns)
        _ = _spin(client, reactor, 300, False)
        left = len(client.conns)
        client.close(reactor)
    finally:
        kill_forked_server(pid)
    assert_equal(kept, 2)
    assert_equal(left, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

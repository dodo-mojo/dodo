"""Lingering close after an early error response, on every server loop.

The server answers 431 before the request head is in. It must then read
and drop the rest instead of closing at once: closing with unread input
makes the kernel reset the connection, and the client never sees the
431. Each test forks a server, sends a head far over the limit and reads
until the server closes.
"""

from std.testing import assert_true, TestSuite

from dodo.http import (
    FnHandler,
    HttpServer,
    Request,
    Response,
    ServerConfig,
    WithCancel,
    ok,
)
from dodo.http._reactor.keepalive_scan import (
    LINGER_READ_TIMEOUT_MS,
    LINGER_TOTAL_MS,
    _monotonic_ms,
)
from dodo.http._server_reactor_impl import run_reactor_loop_shared
from dodo.net import SocketAddr
from dodo.tcp import TcpStream
from dodo.tls import TlsConfig, TlsStream
from dodo.utils import SIGKILL, exit, fork, kill, usleep, waitpid


comptime _SERVER_CRT = "tests/certs/server.crt"
comptime _SERVER_KEY = "tests/certs/server.key"
comptime _CA_CRT = "tests/certs/ca.crt"

comptime _HEAD_START = "GET / HTTP/1.1\r\nHost: x\r\n"
"""A request head the client never finishes."""

comptime _FILL_LINES = 1000


def _hello(req: Request) raises -> Response:
    return ok("hi")


def _fill_line() -> List[UInt8]:
    """One 8 KB header line. _FILL_LINES of them are far over the limit, and more than loopback
    socket buffers hold, so a reset reaches the sender."""
    var line = "X-Fill: " + "a" * 8000 + "\r\n"
    var out = List[UInt8](capacity=line.byte_length())
    for c in line.as_bytes():
        out.append(c)
    return out^


def _spawn(loop: String) raises -> Tuple[Int, UInt16]:
    """Fork a server on ``loop``: ``unified`` (``serve``), ``cancel``
    (``serve_cancellable``), ``h1`` (the HTTP/1.1-only loop) or ``tls``
    (``serve`` over HTTPS). Returns (pid, port)."""
    var srv: HttpServer
    if loop == "tls":
        var alpn = List[String]()
        alpn.append("http/1.1")
        srv = HttpServer.bind_tls(
            SocketAddr.localhost(0), _SERVER_CRT, _SERVER_KEY, alpn^
        )
    else:
        srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var pid = fork()
    if pid == 0:
        try:
            if loop == "cancel":
                srv.serve_cancellable(WithCancel(FnHandler(_hello)))
            elif loop == "h1":
                srv._listener._socket.set_nonblocking(True)
                var h = FnHandler(_hello)
                run_reactor_loop_shared(
                    Int(srv._listener._socket.fd),
                    srv.config,
                    h,
                    srv._stopping,
                )
            else:
                srv.serve(_hello)
        except:
            pass
        exit()
    usleep(250000)
    return (Int(pid), port)


def _stop(pid: Int):
    _ = kill(pid, SIGKILL)
    waitpid(pid)


def _append(mut got: String, buf: List[UInt8], n: Int):
    for i in range(n):
        got += chr(Int(buf[i]))


def _oversized_head_cleartext(port: UInt16) raises -> Tuple[String, Bool]:
    var s = TcpStream.connect(SocketAddr.localhost(port))
    s.set_recv_timeout(10_000)
    s.write_all(_HEAD_START.as_bytes())
    var line = _fill_line()
    var sent_all = True
    try:
        for _ in range(_FILL_LINES):
            s.write_all(Span[UInt8, _](line))
    except:
        # The server closed with input unread and the kernel reset the
        # connection. Linux then drops the 431 too; macOS keeps it.
        sent_all = False
    var got = String("")
    var buf = List[UInt8](length=65536, fill=0)
    try:
        while True:
            var n = s.read(buf.unsafe_ptr(), len(buf))
            if n <= 0:
                break
            _append(got, buf, n)
    except:
        pass
    s.close()
    return (got, sent_all)


def _oversized_head_tls(port: UInt16) raises -> Tuple[String, Bool]:
    var cfg = TlsConfig(ca_bundle=_CA_CRT)
    cfg.alpn = List[String]()
    cfg.alpn.append("http/1.1")
    var s = TlsStream.connect("localhost", port, cfg)
    s.set_recv_timeout(10_000)
    s.write_all(_HEAD_START.as_bytes())
    var line = _fill_line()
    var sent_all = True
    try:
        for _ in range(_FILL_LINES):
            s.write_all(Span[UInt8, _](line))
    except:
        sent_all = False
    var got = String("")
    var buf = List[UInt8](length=65536, fill=0)
    try:
        while True:
            var n = s.read(buf.unsafe_ptr(), len(buf))
            if n <= 0:
                break
            _append(got, buf, n)
    except:
        pass
    s.close()
    return (got, sent_all)


def _check_431(loop: String) raises:
    var srv = _spawn(loop)
    var result = (String(""), False)
    try:
        if loop == "tls":
            result = _oversized_head_tls(srv[1])
        else:
            result = _oversized_head_cleartext(srv[1])
    except:
        pass
    _stop(srv[0])
    var got = result[0]
    assert_true(
        got.startswith("HTTP/1.1 431"),
        loop + ": no 431 for an 8 MB head, got: " + got[byte=:64],
    )
    assert_true(result[1], loop + ": the upload was reset")


def test_unified_loop_lingers_after_431() raises:
    _check_431("unified")


def test_cancel_loop_lingers_after_431() raises:
    _check_431("cancel")


def test_h1_loop_lingers_after_431() raises:
    _check_431("h1")


def test_tls_lingers_after_431() raises:
    _check_431("tls")


# ── Lingering ends ─────────────────────────────────────────────────────────


def _send_431_head(port: UInt16) raises -> TcpStream:
    """Connect and send a head over the limit, all at once, so the 431
    comes back while the connection stays open."""
    var s = TcpStream.connect(SocketAddr.localhost(port))
    s.set_recv_timeout(10_000)
    s.write_all(_HEAD_START.as_bytes())
    var line = _fill_line()
    for _ in range(4):
        s.write_all(Span[UInt8, _](line))
    return s^


def _read_to_close(mut s: TcpStream) -> String:
    var got = String("")
    var buf = List[UInt8](length=65536, fill=0)
    try:
        while True:
            var n = s.read(buf.unsafe_ptr(), len(buf))
            if n <= 0:
                break
            _append(got, buf, n)
    except:
        pass
    return got


def _write_probe(mut s: TcpStream) -> Bool:
    """Send a byte twice. True when both writes go through, so the server
    has not fully closed: once it has, the first write draws a reset and
    the second fails."""
    var one = List[UInt8]()
    one.append(UInt8(ord("x")))
    try:
        s.write_all(Span[UInt8, _](one))
        usleep(100_000)
        s.write_all(Span[UInt8, _](one))
        return True
    except:
        return False


def test_linger_ends_when_the_client_goes_quiet() raises:
    var srv = _spawn("unified")
    var got = String("")
    var open_while_sending = False
    var open_after_quiet = True
    try:
        var s = _send_431_head(srv[1])
        # The half-close shows up as end of stream after the 431.
        got = _read_to_close(s)
        usleep(LINGER_READ_TIMEOUT_MS * 1000 // 2)
        open_while_sending = _write_probe(s)
        usleep((LINGER_READ_TIMEOUT_MS + 1000) * 1000)
        open_after_quiet = _write_probe(s)
        s.close()
    except:
        pass
    _stop(srv[0])
    assert_true(got.startswith("HTTP/1.1 431"), "no 431: " + got[byte=:64])
    assert_true(open_while_sending, "closed before the quiet timeout")
    assert_true(not open_after_quiet, "still open after the quiet timeout")


def _read_once(mut s: TcpStream) -> String:
    var got = String("")
    var buf = List[UInt8](length=65536, fill=0)
    try:
        var n = s.read(buf.unsafe_ptr(), len(buf))
        if n > 0:
            _append(got, buf, n)
    except:
        pass
    return got


def test_linger_ends_after_the_total_limit_while_the_client_sends() raises:
    var srv = _spawn("unified")
    var got = String("")
    var closed = False
    var waited = 0
    try:
        var s = _send_431_head(srv[1])
        var start = _monotonic_ms()
        # Read the 431 first: a reset later may drop unread input.
        got = _read_once(s)
        var line = _fill_line()
        # Keep sending, under the quiet timeout, past the total limit.
        # Once the server has closed, a write fails.
        try:
            while _monotonic_ms() - start < LINGER_TOTAL_MS + 4000:
                s.write_all(Span[UInt8, _](line))
                usleep(300_000)
        except:
            closed = True
        waited = _monotonic_ms() - start
        s.close()
    except:
        pass
    _stop(srv[0])
    assert_true(got.startswith("HTTP/1.1 431"), "no 431: " + got[byte=:64])
    assert_true(closed, "still open after " + String(waited) + " ms")
    assert_true(
        waited >= LINGER_TOTAL_MS - 500,
        "closed before the total limit: " + String(waited) + " ms",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

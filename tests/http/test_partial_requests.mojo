"""Requests that arrive in pieces, or pipelined, on the default loop.

A request split across several reads must be answered without stalling
or spinning the loop while it waits for the rest, and pipelined requests
(whole, split, or chunked) must each get their response. Each scenario
runs against its own forked server, so one wedged server cannot hide
behind the next, and a 2 s receive timeout turns a hung server into a
failed assertion instead of a hung test.
"""

from std.ffi import c_int, c_size_t, c_uint
from std.memory import stack_allocation
from std.testing import assert_equal, assert_true, TestSuite

from dodo.utils import SIGKILL, exit, fork, kill, usleep, waitpid
from dodo.http import ServerConfig, FnHandlerCT, HttpServer, Response, ok
from dodo.http.request import Request
from dodo.net import SocketAddr
from dodo.net._libc import (
    AF_INET,
    MSG_NOSIGNAL,
    SOCK_STREAM,
    SOL_SOCKET,
    SO_RCVTIMEO,
    TIMEVAL_SIZE,
    _close,
    _connect,
    _fill_sockaddr_in,
    _recv,
    _send,
    _setsockopt,
    _socket,
    _strerror,
    get_errno,
)


comptime _OK: String = "HTTP/1.1 200"
comptime _SCN_SPLIT_BODY: Int = 0
comptime _SCN_LARGE_BODY: Int = 1
comptime _SCN_OTHER_CONN: Int = 2
comptime _SCN_PIPELINED: Int = 3
comptime _SCN_PIPELINED_THEN_SPLIT: Int = 4
comptime _SCN_PIPELINED_CHUNKED: Int = 5
comptime _SCN_LARGE_RESPONSE: Int = 6
comptime _BIG: Int = 32 * 1024 * 1024


def _connect_loopback(port: UInt16) raises -> c_int:
    """Connect to ``127.0.0.1:port`` with a 2 s receive timeout armed.

    Returns ``-1`` if every attempt was refused (the forked server never
    accepted); the caller treats that as a skip.
    """
    var sa = stack_allocation[16, UInt8]()
    for i in range(16):
        sa.unsafe_offset(i).unsafe_write(UInt8(0))
    var ip = stack_allocation[4, UInt8]()
    ip.unsafe_offset(0).unsafe_write(UInt8(127))
    ip.unsafe_offset(1).unsafe_write(UInt8(0))
    ip.unsafe_offset(2).unsafe_write(UInt8(0))
    ip.unsafe_offset(3).unsafe_write(UInt8(1))
    _fill_sockaddr_in(sa, port, ip)
    for _ in range(100):
        var c = _socket(AF_INET, SOCK_STREAM, c_int(0))
        if c < c_int(0):
            raise Error(
                "client socket() failed: " + _strerror(get_errno().value)
            )
        if _connect(c, sa, c_uint(16)) >= c_int(0):
            var tv = stack_allocation[16, UInt8]()
            for i in range(16):
                tv.unsafe_offset(i).unsafe_write(UInt8(0))
            tv.unsafe_offset(0).unsafe_write(UInt8(2))
            _ = _setsockopt(c, SOL_SOCKET, SO_RCVTIMEO, tv, TIMEVAL_SIZE)
            return c
        _ = _close(c)
        usleep(20000)
    return c_int(-1)


def _send_all(fd: c_int, data: String) raises:
    var bytes = data.as_bytes()
    var sent = 0
    while sent < len(bytes):
        var n = Int(
            _send(
                fd,
                bytes.unsafe_ptr().unsafe_offset(sent),
                c_size_t(len(bytes) - sent),
                c_int(MSG_NOSIGNAL),
            )
        )
        if n <= 0:
            raise Error("send() failed after " + String(sent) + " bytes")
        sent += n


def _count(hay: String, needle: String) -> Int:
    var n = 0
    var at = hay.find(needle)
    while at >= 0:
        n += 1
        at = hay.find(needle, at + 1)
    return n


def _await_responses(fd: c_int, want: Int) -> Int:
    """Read until ``want`` 200 responses were seen, or EOF / the 2 s
    receive timeout. Returns how many were seen."""
    var buf = stack_allocation[4096, UInt8]()
    var got = String()
    while _count(got, _OK) < want:
        var n = Int(_recv(fd, buf, c_size_t(4096), c_int(0)))
        if n <= 0:
            break
        for i in range(n):
            got += chr(Int(buf[unsafe_offset=i]))
    return _count(got, _OK)


def _get(path: String) -> String:
    return "GET " + path + " HTTP/1.1\r\nHost: x\r\n\r\n"


def _post_headers(length: Int) -> String:
    return (
        "POST / HTTP/1.1\r\nHost: x\r\nContent-Length: "
        + String(length)
        + "\r\n\r\n"
    )


def _handler(req: Request) raises -> Response:
    if req.url == "/big":
        return Response(200, body=List[UInt8](length=_BIG, fill=97))
    return ok("ok")


def _read_all(fd: c_int, want: Int) -> Int:
    """Bytes received until ``want`` arrived, EOF or the receive timeout."""
    var buf = stack_allocation[65536, UInt8]()
    var got = 0
    while got < want:
        var n = Int(_recv(fd, buf, c_size_t(65536), c_int(0)))
        if n <= 0:
            break
        got += n
    return got


comptime _Handler = FnHandlerCT[_handler]


def _scenario(port: UInt16, which: Int) raises -> String:
    """Run one scenario; returns an empty string on success, else why not."""
    var fd = _connect_loopback(port)
    if Int(fd) < 0:
        return "no connection"
    var err = String()
    try:
        if which == _SCN_SPLIT_BODY:
            # Headers now, body 200 ms later: two receive completions.
            _send_all(fd, _post_headers(5))
            usleep(200000)
            _send_all(fd, "hello")
            if _await_responses(fd, 1) != 1:
                err = "no response to a request split across two writes"
        elif which == _SCN_LARGE_BODY:
            # Larger than one 8192-byte provided buffer, so the request
            # needs several completions.
            var body = String()
            for _ in range(20000):
                body += "a"
            _send_all(fd, _post_headers(20000) + body)
            if _await_responses(fd, 1) != 1:
                err = "no response to a 20000-byte body"
        elif which == _SCN_OTHER_CONN:
            # A request waiting for its body must not hold up other
            # connections.
            _send_all(fd, _post_headers(5))
            usleep(100000)
            var other = _connect_loopback(port)
            if Int(other) < 0:
                err = "second connection refused"
            else:
                _send_all(other, _get("/"))
                if _await_responses(other, 1) != 1:
                    err = "a pending partial request stalled another connection"
                _ = _close(other)
            if err.byte_length() == 0:
                _send_all(fd, "hello")
                if _await_responses(fd, 1) != 1:
                    err = "partial request was not answered once it completed"
        elif which == _SCN_PIPELINED:
            # Five whole requests in one write: all five answered.
            var burst = String()
            for _ in range(5):
                burst += _get("/")
            _send_all(fd, burst)
            var seen = _await_responses(fd, 5)
            if seen != 5:
                err = "pipelined burst answered " + String(seen) + " of 5"
        elif which == _SCN_PIPELINED_THEN_SPLIT:
            # One whole request followed by the first part of a second.
            _send_all(fd, _get("/") + _post_headers(5) + "he")
            usleep(150000)
            _send_all(fd, "llo")
            var seen = _await_responses(fd, 2)
            if seen != 2:
                err = "pipelined + split answered " + String(seen) + " of 2"
        elif which == _SCN_PIPELINED_CHUNKED:
            # A complete chunked request queued behind another request must
            # still be served (its body length is unknown up front).
            _send_all(
                fd,
                _get("/")
                + "POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked"
                "\r\n\r\n5\r\nhello\r\n0\r\n\r\n",
            )
            var seen = _await_responses(fd, 2)
            if seen != 2:
                err = "pipelined chunked answered " + String(seen) + " of 2"
        elif which == _SCN_LARGE_RESPONSE:
            # More than the socket takes in one send: the rest must follow
            # once the client reads, not be dropped.
            # Not reading for a while fills the socket buffers.
            _send_all(fd, _get("/big"))
            usleep(300000)
            var got = _read_all(fd, _BIG)
            if got < _BIG:
                err = "32 MiB response cut at " + String(got) + " bytes"
        else:
            err = "unknown scenario"
    except e:
        err = String(e)
    _ = _close(fd)
    return err


def _run(which: Int) raises:
    """Fork a server and run one scenario against it."""
    var srv = HttpServer.bind(SocketAddr.localhost(0), ServerConfig())
    var port = UInt16(srv.local_addr().port)
    assert_true(Int(port) > 0, "server must bind to a positive port")

    var pid = fork()
    if pid == 0:
        try:
            var h = _Handler()
            srv.serve(h^)
        except:
            pass
        exit()
    usleep(120000)

    var err: String
    try:
        err = _scenario(port, which)
    except e:
        err = String(e)

    _ = kill(pid, SIGKILL)
    waitpid(pid)
    assert_equal(err, "")


def test_split_body() raises:
    _run(_SCN_SPLIT_BODY)


def test_large_body() raises:
    _run(_SCN_LARGE_BODY)


def test_partial_request_does_not_stall_other_connections() raises:
    _run(_SCN_OTHER_CONN)


def test_large_response() raises:
    _run(_SCN_LARGE_RESPONSE)


def test_pipelined_burst() raises:
    _run(_SCN_PIPELINED)


def test_pipelined_then_split() raises:
    _run(_SCN_PIPELINED_THEN_SPLIT)


def test_pipelined_chunked() raises:
    _run(_SCN_PIPELINED_CHUNKED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

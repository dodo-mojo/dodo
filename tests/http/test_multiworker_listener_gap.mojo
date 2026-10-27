"""Multi-worker serving never leaves the port without a listener.

``HttpServer.bind`` opens the listener; ``serve(num_workers=N)`` starts
N workers with one ``SO_REUSEPORT`` listener each. The bound listener
is handed to worker 0, so a client that connects between ``bind`` and
``serve`` (its connection waits in the backlog) is still answered, and
no new connect is refused while the workers start.

Each test connects and sends its request before the server child even
starts serving, so the case is deterministic: no sleep decides it.
"""

from std.os import setenv
from std.testing import TestSuite, assert_equal, assert_true

from dodo.http import HttpServer, Request, Response, ok
from dodo.http.streaming_server import StreamConn, StreamHandler
from dodo.net import SocketAddr
from dodo.tcp import TcpStream
from dodo.utils import SIGKILL, exit, fork, kill, waitpid


comptime EARLY_REQUEST = "GET /early HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
comptime READ_TIMEOUT_MS = 5000


def _hello(req: Request) raises -> Response:
    return ok("hello " + req.url)


struct _Greet(Copyable, StreamHandler):
    """Sends one line to every new connection, then closes it."""

    def __init__(out self):
        pass

    def on_open(mut self, mut conn: StreamConn) raises:
        conn.send("HELLO\n".as_bytes())
        conn.request_close()

    def on_writable(mut self, mut conn: StreamConn) raises:
        pass

    def on_close(mut self, mut conn: StreamConn) raises:
        pass


def _connect_early(port: UInt16, request: String) raises -> TcpStream:
    """Connect before the server serves. The kernel completes the
    handshake from the backlog, so this returns at once."""
    var stream = TcpStream.connect(SocketAddr.localhost(port))
    stream.set_recv_timeout(READ_TIMEOUT_MS)
    if request.byte_length() > 0:
        stream.write_all(request.as_bytes())
    return stream^


def _read_until_close(mut stream: TcpStream) -> String:
    """Everything the server sent until it closed. A reset or a timeout
    ends the read early; the caller's assertion then fails on what
    arrived (usually nothing)."""
    var got = List[UInt8]()
    var chunk = List[UInt8](capacity=4096)
    chunk.resize(4096, 0)
    while True:
        var n: Int
        try:
            n = stream.read(chunk.unsafe_ptr(), 4096)
        except:
            break
        if n == 0:
            break
        for i in range(n):
            got.append(chunk[i])
    return String(unsafe_from_utf8=Span[UInt8, _](got))


def _stop(pid: Int):
    _ = kill(pid, SIGKILL)
    _ = waitpid(pid)


def test_request_queued_before_multiworker_serve_is_answered() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var early = _connect_early(port, EARLY_REQUEST)

    var pid = fork()
    if pid == 0:
        try:
            srv.serve(_hello, num_workers=2, pin_cores=False)
        except:
            pass
        exit()

    var reply = _read_until_close(early)
    _stop(pid)
    assert_true(reply.startswith("HTTP/1.1 200"), "no reply: " + reply)
    assert_true(reply.endswith("hello /early"), "wrong body: " + reply)


def test_request_queued_before_shared_listener_serve_is_answered() raises:
    """``DODO_REUSEPORT_WORKERS=0``: every worker shares the one bound
    listener, so the queued connection is still accepted."""
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var early = _connect_early(port, EARLY_REQUEST)

    var pid = fork()
    if pid == 0:
        _ = setenv("DODO_REUSEPORT_WORKERS", "0")
        try:
            srv.serve(_hello, num_workers=2, pin_cores=False)
        except:
            pass
        exit()

    var reply = _read_until_close(early)
    _stop(pid)
    assert_true(reply.startswith("HTTP/1.1 200"), "no reply: " + reply)
    assert_true(reply.endswith("hello /early"), "wrong body: " + reply)


def test_request_queued_on_an_extra_address_is_answered() raises:
    """A multi-address server hands every bound listener to worker 0,
    not just the primary."""
    var addrs = List[SocketAddr]()
    addrs.append(SocketAddr.localhost(0))
    addrs.append(SocketAddr.localhost(0))
    var srv = HttpServer.bind(addrs^)
    var primary_port = UInt16(srv.local_addrs()[0].port)
    var extra_port = UInt16(srv.local_addrs()[1].port)
    var on_primary = _connect_early(primary_port, EARLY_REQUEST)
    var on_extra = _connect_early(extra_port, EARLY_REQUEST)

    var pid = fork()
    if pid == 0:
        try:
            srv.serve(_hello, num_workers=2, pin_cores=False)
        except:
            pass
        exit()

    var primary_reply = _read_until_close(on_primary)
    var extra_reply = _read_until_close(on_extra)
    _stop(pid)
    assert_true(
        primary_reply.endswith("hello /early"), "primary: " + primary_reply
    )
    assert_true(extra_reply.endswith("hello /early"), "extra: " + extra_reply)


def test_connection_queued_before_multiworker_streaming_is_served() raises:
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var early = _connect_early(port, "")

    var pid = fork()
    if pid == 0:
        try:
            srv.serve_streaming(_Greet(), num_workers=2, pin_cores=False)
        except:
            pass
        exit()

    var reply = _read_until_close(early)
    _stop(pid)
    assert_equal(reply, "HELLO\n")


def test_binding_a_port_in_use_still_raises() raises:
    """The bound listener carries ``SO_REUSEPORT`` so workers can join
    it. A second server on the same port must still fail to bind rather
    than silently share the port."""
    var first = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(first.local_addr().port)
    var message = String("")
    try:
        var second = HttpServer.bind(SocketAddr.localhost(port))
        second.close()
    except e:
        message = String(e)
    first.close()
    assert_true(message.startswith("AddressInUse"), "got: " + message)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

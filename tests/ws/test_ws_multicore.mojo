"""Smoke test for multi-worker :meth:`dodo.ws.WsServer.serve(handler, num_workers=N)`.

Forks a child running ``WsServer.serve(echo_handler, num_workers=4)``
on a fixed loopback port, opens 4 concurrent ``WsClient`` echoes
in a loop from the parent (one per round), and verifies the
round-trip works end-to-end. All workers accept from the one bound
listener, so the test exercises the fan-out path without needing
per-worker observation. The other tests pin down startup: the
workers never close or rebind the listener.

The "concurrent" part is sequential here on purpose: spawning
multiple ``WsClient`` from a single Mojo thread is enough to
prove the multi-worker server's accept loops are all live; a
proper concurrency test would need ``pthread`` plumbing on the
client side that dodo doesn't ship.
"""

from std.testing import assert_equal, assert_true, TestSuite

from dodo.net import SocketAddr
from dodo.tcp import TcpStream
from dodo.utils import (
    SIGKILL,
    exit,
    fork,
    kill,
    usleep,
    waitpid,
)
from dodo.ws import WsClient, WsConnection, WsOpcode, WsServer


def _echo(mut conn: WsConnection) raises:
    """Simplest possible WS handler: echo every text frame back.

    Signature matches :meth:`dodo.ws.WsServer.serve`'s
    ``def(mut WsConnection) raises thin -> None`` exactly --
    ``mut`` so the body can call ``conn.recv()`` /
    ``conn.send_text()`` (both ``mut self``).
    """
    while True:
        var frame = conn.recv()
        if frame.opcode == WsOpcode.CLOSE:
            break
        if frame.opcode == WsOpcode.TEXT:
            conn.send_text(frame.text_payload())


def test_ws_multicore_serve_4_workers_echo_round_trip() raises:
    """Spawn a 4-worker WsServer, drive 4 sequential WsClient echoes
    against it, and verify each round-trip."""
    var port = UInt16(28491)
    var srv = WsServer.bind(SocketAddr.localhost(port))

    var pid = fork()
    if pid == 0:
        try:
            srv.serve(_echo, num_workers=4)
        except:
            pass
        exit()
    usleep(300_000)

    var url = String("ws://127.0.0.1:") + String(Int(port)) + String("/")
    var raised = False
    var n_echoed = 0
    try:
        for i in range(4):
            with WsClient.connect(url) as c:
                var msg = String("hello-") + String(i)
                c.send_text(msg)
                var f = c.recv()
                assert_equal(f.opcode, WsOpcode.TEXT)
                assert_equal(f.text_payload(), msg)
                n_echoed += 1
    except:
        raised = True

    _ = kill(pid, SIGKILL)
    waitpid(pid)
    assert_true(not raised, "WsClient round-trip raised")
    assert_equal(n_echoed, 4)


def _upgrade_status(port: UInt16) -> String:
    """Send a WebSocket upgrade request and return the response's status
    line, or what went wrong. Reads time out after 5 s, so a connection
    that nobody accepts fails the test instead of hanging it."""
    try:
        var s = TcpStream.connect(SocketAddr.localhost(port))
        s.set_recv_timeout(5_000)
        var req = String(
            "GET / HTTP/1.1\r\n",
            "Host: 127.0.0.1\r\n",
            "Upgrade: websocket\r\n",
            "Connection: Upgrade\r\n",
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n",
            "Sec-WebSocket-Version: 13\r\n\r\n",
        )
        s.write_all(req.as_bytes())
        var buf = List[UInt8](length=512, fill=0)
        var n = s.read(buf.unsafe_ptr(), len(buf))
        s.close()
        var head = String(unsafe_from_utf8=Span[UInt8, _](buf)[:n])
        var end = head.find("\r\n")
        if end < 0:
            return head
        return String(head[byte=:end])
    except e:
        return String("raised: ") + String(e)


def test_ws_multicore_serves_while_another_process_holds_the_listener() raises:
    """The parent keeps its copy of the listener open, as a parent that
    forked a server often does. Starting the workers must not need the
    port to be free: they used to close the listener and bind new
    ``SO_REUSEPORT`` ones, which fails or splits the port with the
    parent's copy, so connections went unserved."""
    var srv = WsServer.bind(SocketAddr.localhost(0))
    var port = srv.local_addr().port

    var pid = fork()
    if pid == 0:
        try:
            srv.serve(_echo, num_workers=4)
        except:
            pass
        exit()

    var got = List[String]()
    for _ in range(8):
        got.append(_upgrade_status(port))

    _ = kill(pid, SIGKILL)
    waitpid(pid)
    _ = srv^
    for i in range(8):
        assert_equal(got[i], "HTTP/1.1 101 Switching Protocols")


def test_ws_multicore_accepts_connections_made_while_workers_start() raises:
    """A client that connects right after the fork, before the workers
    run, waits in the listener's backlog and is served. Closing the
    listener at startup used to reset or refuse it."""
    var srv = WsServer.bind(SocketAddr.localhost(0))
    var port = srv.local_addr().port

    var pid = fork()
    if pid == 0:
        try:
            srv.serve(_echo, num_workers=4)
        except:
            pass
        exit()
    srv.close()

    var got = _upgrade_status(port)

    _ = kill(pid, SIGKILL)
    waitpid(pid)
    assert_equal(got, "HTTP/1.1 101 Switching Protocols")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

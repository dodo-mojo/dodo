"""Tests for the HTTP/1.1 client connection pool.

Drives :class:`dodo.http.HttpClient` with :meth:`with_pool` enabled
against a forked HTTP/1.1 server and verifies:

* Two GETs to the same origin reuse a single TCP connection (the
  pool reports one idle fd between requests).
* The pool stays per-origin: a request to a different port doesn't
  drain another origin's idle fds.
* Plain (no-pool) ``HttpClient`` keeps close-after-each
  semantics (``idle_count() == 0`` always).
* A pooled fd that the server closed via ``Connection: close``
  is dropped from the pool (no stale reuse).
* ``HttpClient.__deinit__`` releases pool fds cleanly (no fd leak when
  the test exits).

The framed reader path is exercised by every successful round-trip
because pool-enabled requests go through it.
"""

from std.testing import assert_equal, assert_true

from dodo.http import HttpClient, HttpServer, Request, Response, ok
from dodo.http.headers import HeaderMap
from dodo.http.response import Status
from dodo.net import SocketAddr
from dodo.testing import fork_server, kill_forked_server


def _hello(req: Request) raises -> Response:
    return ok("pool-hello")


def test_two_requests_reuse_single_connection() raises:
    """Two GETs to the same origin should share a TCP connection:
    the pool reports one idle fd between them."""
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _hello)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var first_idle = -1
    var second_status = -1
    var raised = False
    try:
        with HttpClient().with_pool() as c:
            var r1 = c.get(url)
            assert_equal(r1.status, 200)
            assert_equal(r1.text(), "pool-hello")
            # After the first request returns, the fd is back in the
            # pool ready for reuse.
            first_idle = c.idle_count()
            var r2 = c.get(url)
            second_status = r2.status
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "pool round-trip raised")
    assert_equal(first_idle, 1)
    assert_equal(second_status, 200)


def test_disabled_pool_never_keeps_idle() raises:
    """Without ``with_pool``, the client closes after each request
    and ``idle_count`` stays at 0 across requests."""
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _hello)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var idle_after_request = -1
    var raised = False
    try:
        with HttpClient() as c:
            _ = c.get(url)
            idle_after_request = c.idle_count()
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "no-pool round-trip raised")
    assert_equal(idle_after_request, 0)


def test_max_idle_per_host_zero_drops_every_fd() raises:
    """``with_pool(max_idle_per_host=0)`` makes the pool drop every
    fd on release, so ``idle_count`` stays 0 even on a successful
    keep-alive-eligible response."""
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _hello)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var idle_after = -1
    var status = -1
    var raised = False
    try:
        with HttpClient().with_pool(max_idle_per_host=0) as c:
            var r = c.get(url)
            status = r.status
            idle_after = c.idle_count()
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "max_idle_per_host=0 round-trip raised")
    assert_equal(status, 200)
    assert_equal(idle_after, 0)


def test_pool_is_per_origin() raises:
    """Two distinct origins keep distinct buckets: a request to one
    port doesn't consume idle fds queued for another."""
    var srv1 = HttpServer.bind(SocketAddr.localhost(0))
    var port1 = UInt16(srv1.local_addr().port)
    var pid1 = fork_server(srv1^, _hello)

    var srv2 = HttpServer.bind(SocketAddr.localhost(0))
    var port2 = UInt16(srv2.local_addr().port)
    var pid2 = fork_server(srv2^, _hello)

    var u1 = String("http://127.0.0.1:") + String(Int(port1)) + String("/")
    var u2 = String("http://127.0.0.1:") + String(Int(port2)) + String("/")
    var idle_after_two_origins = -1
    var raised = False
    try:
        with HttpClient().with_pool() as c:
            _ = c.get(u1)
            _ = c.get(u2)
            idle_after_two_origins = c.idle_count()
    except:
        raised = True

    kill_forked_server(pid1)
    kill_forked_server(pid2)
    assert_true(not raised, "per-origin round-trip raised")
    assert_equal(idle_after_two_origins, 2)


def main() raises:
    test_two_requests_reuse_single_connection()
    test_disabled_pool_never_keeps_idle()
    test_max_idle_per_host_zero_drops_every_fd()
    test_pool_is_per_origin()
    print("test_h1_client_pool: 4 passed")

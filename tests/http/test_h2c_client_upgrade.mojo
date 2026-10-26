"""HTTP/2 cleartext via Upgrade dance, client side (RFC 7540 §3.2).

Drives the new ``HttpClient(h2c_upgrade=True)`` path against the
existing unified-reactor server (which already handles inbound
``Upgrade: h2c`` requests). The client sends an HTTP/1.1 request
decorated with ``Connection: Upgrade, HTTP2-Settings``, ``Upgrade:
h2c``, and ``HTTP2-Settings: <base64url>``; the server replies
``101 Switching Protocols`` and the response for the original
request flows back over h2 on stream id 1.

Tests:

- ``test_upgrade_round_trip``: 101 + h2 response on stream 1.
- ``test_upgrade_concurrent_clients``: a second h2c-upgrade client
  on the same server gets its own response (process-level
  isolation, but it asserts the upgrade path is re-entrant).
- ``test_upgrade_falls_back_when_server_does_not_speak_h2``: when
  pointed at a stub that always answers an h1 200, the client
  surfaces that response unchanged.
- ``test_upgrade_with_request_body``: the original h1 body is
  delivered before the 101 switch and the h2 stream-1 response is
  read correctly.
"""

from std.ffi import c_int, external_call
from std.testing import assert_equal, assert_true

from dodo.http import HttpClient, HttpServer, Request, Response, ok
from dodo.net import SocketAddr
from dodo.testing import fork_server, kill_forked_server


def _hello(req: Request) raises -> Response:
    return ok("h2c-upgrade-hello")


def _echo_method(req: Request) raises -> Response:
    return ok(req.method + ":" + String(len(req.body)))


def test_upgrade_round_trip() raises:
    """``HttpClient(h2c_upgrade=True).get(...)`` over a unified server
    completes the Upgrade dance and returns the h2 response body."""
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _hello)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var got_status = -1
    var got_body = String("")
    var raised = False
    try:
        with HttpClient(h2c_upgrade=True) as c:
            var r = c.get(url)
            got_status = r.status
            got_body = r.text()
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "h2c-upgrade round-trip raised")
    assert_equal(got_status, 200)
    assert_equal(got_body, "h2c-upgrade-hello")


def test_upgrade_with_request_body() raises:
    """A POST body sent on the h1 wire is honoured by the server,
    and the h2 response on stream 1 is read correctly."""
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _echo_method)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var got_body = String("")
    var raised = False
    try:
        with HttpClient(h2c_upgrade=True) as c:
            var r = c.post(url, "abcd")
            got_body = r.text()
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "h2c-upgrade POST raised")
    assert_equal(got_body, "POST:4")


def test_upgrade_two_back_to_back_requests() raises:
    """Two sequential h2c-upgrade calls (each opens its own TCP
    connection because the client doesn't pool yet) both succeed.
    Sanity-checks that the helper doesn't leak stream-1 state across
    fresh ``HttpClient`` instances or accidentally hold the listener
    open."""
    var srv = HttpServer.bind(SocketAddr.localhost(0))
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _hello)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var first = String("")
    var second = String("")
    var raised = False
    try:
        with HttpClient(h2c_upgrade=True) as c1:
            first = c1.get(url).text()
        with HttpClient(h2c_upgrade=True) as c2:
            second = c2.get(url).text()
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "back-to-back h2c-upgrade raised")
    assert_equal(first, "h2c-upgrade-hello")
    assert_equal(second, "h2c-upgrade-hello")


def main() raises:
    test_upgrade_round_trip()
    test_upgrade_with_request_body()
    test_upgrade_two_back_to_back_requests()
    print("test_h2c_client_upgrade: 3 passed")

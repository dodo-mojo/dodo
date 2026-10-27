"""Regression: h2c-via-Upgrade client must not double-count the
response body when the server's reply lands in a single recv blob.

The bug (Span-lifetime tightening): the client read loop in
:func:`dodo.http.client._h2c_upgrade_request_via_stream` fed each
recv chunk into the in-process HTTP/2 decoder via
``Span[UInt8, _](buf[:n])``. ``buf[:n]`` allocates a temporary
``List`` whose backing storage was destroyed before
``h2_conn.feed`` returned under Mojo's stricter destructor
scheduling, so the heap could re-publish the slot to the same
``read`` call's next iteration -- doubling the response body the
next time the loop appended into ``buf``. Fixed by feeding via
``Span[UInt8, _](unsafe_ptr=buf.unsafe_ptr(), length=n)`` so the
lifetime is the named ``buf``, which lives across the loop.

This regression fixture pins the fix:

* :func:`test_post_body_not_doubled` -- a POST with a 12-byte
  request body should round-trip a 28-byte response (``POST:12``
  echoed). Asserts both the value and the length so a future
  doubling regression hits a clearer error than ``"POST:12POST:12"
  != "POST:12"``.
* :func:`test_get_response_length_invariant` -- a GET on a handler
  that returns a body whose length is a power-of-two byte string.
  Doubling would yield a 2x-length response, so a strict length
  assertion is the simplest single-bit regression guard.
"""

from std.testing import assert_equal, assert_true

from dodo.http import (
    HttpClient,
    HttpServer,
    Request,
    Response,
    ServerConfig,
    ok,
)
from dodo.net import SocketAddr
from dodo.testing import fork_server, kill_forked_server


def _h2c_config() -> ServerConfig:
    """The server only honours Upgrade: h2c when the config allows it."""
    var config = ServerConfig()
    config.h2.allow_h2c_upgrade = True
    return config^


def _hello_64(req: Request) raises -> Response:
    """Return a 64-byte body. Power-of-two byte length so a
    doubling regression yields a 128-byte body, easily caught by
    a length-equality assertion."""
    return ok(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    )


def _echo_method(req: Request) raises -> Response:
    return ok(req.method + ":" + String(len(req.body)))


def test_post_body_not_doubled() raises:
    """POST with a 12-byte body should round-trip ``POST:12``,
    NOT ``POST:12POST:12``. Pre-fix this was a flaky failure
    because the Span over the slice temporary read freed storage
    on the second loop iteration."""
    var srv = HttpServer.bind(SocketAddr.localhost(0), _h2c_config())
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _echo_method)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var got_body = String("")
    var raised = False
    try:
        with HttpClient(h2c_upgrade=True) as c:
            var r = c.post(url, "abcdefghijkl")
            got_body = r.text()
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "h2c-upgrade POST raised")
    assert_equal(got_body, "POST:12")
    assert_equal(
        got_body.byte_length(),
        "POST:12".byte_length(),
        (
            "h2c response body length must equal expected; doubling"
            " regression would yield twice this length"
        ),
    )


def test_get_response_length_invariant() raises:
    """GET against a handler that returns a 64-byte body. Strict
    length-equality assertion catches a body-doubling regression
    in one bit -- a future regression that quietly returns a
    128-byte body fails this without needing to look at content."""
    var srv = HttpServer.bind(SocketAddr.localhost(0), _h2c_config())
    var port = UInt16(srv.local_addr().port)
    var pid = fork_server(srv^, _hello_64)

    var url = String("http://127.0.0.1:") + String(Int(port)) + String("/")
    var got_body = String("")
    var raised = False
    try:
        with HttpClient(h2c_upgrade=True) as c:
            var r = c.get(url)
            got_body = r.text()
    except:
        raised = True

    kill_forked_server(pid)
    assert_true(not raised, "h2c-upgrade GET raised")
    assert_equal(got_body.byte_length(), 64, "body length must be 64 bytes")
    assert_true(
        got_body.startswith("0123456789abcdef"),
        "body content must start with the handler's prefix",
    )


def main() raises:
    test_post_body_not_doubled()
    test_get_response_length_invariant()
    print("test_h2c_client_double_body: 2 passed")

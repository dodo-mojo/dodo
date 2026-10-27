"""The request parser refuses what RFC 9110/9112 don't allow, with the
right status (audit findings F3, F4, F10, and HTTP/0.9 and
Transfer-Encoding on HTTP/1.0)."""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_raises,
    assert_true,
)

from dodo.http.server import _parse_http_request_bytes
from dodo.http._server.parse import parse_error_status
from dodo.http.proto.chunked import (
    CHUNKED_INCOMPLETE,
    CHUNKED_MALFORMED,
    scan_chunked_resume,
)


def _parse(raw: String) raises:
    var data = raw.as_bytes()
    _ = _parse_http_request_bytes(Span[UInt8, _](data))


def _status_of(raw: String) -> Int:
    """The status the server answers ``raw`` with, or 0 if it parses."""
    try:
        _parse(raw)
    except e:
        return parse_error_status(String(e))
    return 0


# ── Host (F3) ────────────────────────────────────────────────────────────────


def test_http11_without_host_is_400() raises:
    assert_equal(_status_of("GET / HTTP/1.1\r\n\r\n"), 400)
    with assert_raises(contains="missing Host"):
        _parse("GET / HTTP/1.1\r\nX-A: 1\r\n\r\n")


def test_http10_without_host_is_served() raises:
    assert_equal(_status_of("GET / HTTP/1.0\r\n\r\n"), 0)


def test_host_present_is_served() raises:
    assert_equal(_status_of("GET / HTTP/1.1\r\nHost: x\r\n\r\n"), 0)


# ── Version ──────────────────────────────────────────────────────────────────


def test_http09_request_line_is_400() raises:
    assert_equal(_status_of("GET /\r\nHost: x\r\n\r\n"), 400)
    with assert_raises(contains="missing HTTP version"):
        _parse("GET /\r\nHost: x\r\n\r\n")


def test_higher_minor_version_is_served_as_http11() raises:
    """RFC 9110 sec 2.5: treat HTTP/1.9 as the highest 1.x we speak."""
    assert_equal(_status_of("GET / HTTP/1.9\r\nHost: x\r\n\r\n"), 0)


def test_other_major_versions_are_505() raises:
    assert_equal(_status_of("GET / HTTP/2.0\r\nHost: x\r\n\r\n"), 505)
    assert_equal(_status_of("GET / HTTP/0.9\r\nHost: x\r\n\r\n"), 505)
    assert_equal(_status_of("GET / HTTP/3.0\r\nHost: x\r\n\r\n"), 505)


def test_malformed_version_is_400() raises:
    assert_equal(_status_of("GET / HTTP/1\r\nHost: x\r\n\r\n"), 400)
    assert_equal(_status_of("GET / http/1.1\r\nHost: x\r\n\r\n"), 400)


# ── Request target (F4) ──────────────────────────────────────────────────────


def test_connect_is_501() raises:
    assert_equal(
        _status_of("CONNECT example.com:443 HTTP/1.1\r\nHost: x\r\n\r\n"), 501
    )


def test_asterisk_only_for_options() raises:
    assert_equal(_status_of("OPTIONS * HTTP/1.1\r\nHost: x\r\n\r\n"), 0)
    assert_equal(_status_of("GET * HTTP/1.1\r\nHost: x\r\n\r\n"), 400)


def test_target_must_be_origin_or_absolute_form() raises:
    assert_equal(_status_of("GET foo HTTP/1.1\r\nHost: x\r\n\r\n"), 400)
    assert_equal(
        _status_of("GET http://example.com/a HTTP/1.1\r\nHost: x\r\n\r\n"), 0
    )
    assert_equal(
        _status_of("GET HTTPS://example.com/a HTTP/1.1\r\nHost: x\r\n\r\n"), 0
    )


# ── Expect (F4) ──────────────────────────────────────────────────────────────


def test_unknown_expectation_is_417() raises:
    assert_equal(
        _status_of("GET / HTTP/1.1\r\nHost: x\r\nExpect: banana\r\n\r\n"), 417
    )


def test_100_continue_is_accepted_in_any_case() raises:
    assert_equal(
        _status_of("GET / HTTP/1.1\r\nHost: x\r\nExpect: 100-Continue\r\n\r\n"),
        0,
    )


def test_expect_is_ignored_for_http10() raises:
    assert_equal(_status_of("GET / HTTP/1.0\r\nExpect: banana\r\n\r\n"), 0)


# ── Transfer-Encoding on HTTP/1.0 ────────────────────────────────────────────


def test_transfer_encoding_in_http10_is_400() raises:
    var raw = (
        "POST / HTTP/1.0\r\nTransfer-Encoding: chunked\r\n\r\n"
        "5\r\nhello\r\n0\r\n\r\n"
    )
    assert_equal(_status_of(raw), 400)
    with assert_raises(contains="HTTP/1.0"):
        _parse(raw)


# ── Limits map to their own status (F10) ─────────────────────────────────────


def test_limit_errors_map_to_their_status() raises:
    assert_equal(parse_error_status("request headers exceed limit of 8"), 431)
    assert_equal(parse_error_status("request URI exceeds limit of 8"), 414)
    assert_equal(parse_error_status("request body exceeds limit of 8"), 413)
    assert_equal(parse_error_status("anything else"), 400)


def test_long_header_line_is_431() raises:
    var raw = "GET / HTTP/1.1\r\nHost: x\r\nX-A: " + "a" * 9000 + "\r\n\r\n"
    assert_equal(_status_of(raw), 431)


def test_long_uri_is_414() raises:
    var raw = "GET /" + "a" * 9000 + " HTTP/1.1\r\nHost: x\r\n\r\n"
    assert_equal(_status_of(raw), 414)


# ── Bare LF in a chunked body (F5) ───────────────────────────────────────────


def _chunked_scan(body: String) -> Int:
    var data = List[UInt8](body.as_bytes())
    var cursor = 0
    var decoded = 0
    return scan_chunked_resume(
        Span[UInt8, _](data), cursor, decoded, 1024 * 1024
    )


def test_chunk_size_line_with_bare_lf_is_malformed() raises:
    """A bare LF can't end a chunk-size line, so the body is refused
    now instead of waiting for a CRLF that never comes."""
    assert_equal(_chunked_scan("5\nhello\n0\n\n"), CHUNKED_MALFORMED)


def test_trailer_line_with_bare_lf_is_malformed() raises:
    assert_equal(
        _chunked_scan("5\r\nhello\r\n0\r\nX-T: 1\n"), CHUNKED_MALFORMED
    )


def test_partial_chunked_body_is_incomplete() raises:
    assert_equal(_chunked_scan("5\r\nhel"), CHUNKED_INCOMPLETE)
    assert_equal(_chunked_scan("5"), CHUNKED_INCOMPLETE)
    assert_true(_chunked_scan("5\r\nhello\r\n0\r\n\r\n") > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

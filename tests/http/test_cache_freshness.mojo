"""Unit tests for RFC 9111 freshness math and ``Vary`` parsing.

With the parsed :class:`CacheControl` carried on :class:`CacheEntry`, the
middleware composing on top can ask :func:`is_fresh` whether a
stored response can be reused without touching the origin. The
sister :func:`parse_vary_header` peels apart ``Vary`` into the
field-name list used for secondary-key derivation.

Cases cover the freshness model end-to-end:
- baseline ``max-age`` accept inside the lifetime window;
- ``max-age`` reject just past the window;
- ``s-maxage`` honoured when ``max-age`` is absent;
- ``no-cache`` / ``no-store`` / ``must-revalidate`` response
  directives all force revalidation;
- request-side ``Cache-Control: no-cache`` forces revalidation;
- request-side ``max-age=0`` forces revalidation;
- request-side ``max-age=N`` tightens the freshness bound;
- absent freshness directives → not fresh (RFC 9111 §4.2.2,
  heuristic freshness is opt-in for the middleware and intentionally
  not turned on by default in this commit);
- ``date_ms`` preferred over ``inserted_at_ms`` for age math when
  the response carried a ``Date`` header at insertion time;
- ``parse_vary_header`` peels the comma-separated list correctly
  (case-insensitive, OWS-trimmed, ``*`` surfaced).
"""

from std.collections import List, Optional
from std.testing import assert_equal, assert_false, assert_true

from dodo.http import HeaderMap
from dodo.http.cache import (
    CacheControl,
    is_fresh,
    parse_cache_control,
    parse_vary_header,
)


def _empty_headers() -> HeaderMap:
    return HeaderMap()


def _req_with(cache_control: String) raises -> HeaderMap:
    var h = HeaderMap()
    h.set(String("Cache-Control"), cache_control)
    return h^


def test_is_fresh_within_max_age() raises:
    var cc = parse_cache_control(String("max-age=60, public"))
    var inserted = Int64(1_000_000)
    # 30s after insertion -> within 60s lifetime.
    var now_ms = UInt64(1_030_000)
    assert_true(
        is_fresh(cc, inserted, Optional[Int64](), _empty_headers(), now_ms)
    )


def test_is_fresh_just_past_max_age() raises:
    var cc = parse_cache_control(String("max-age=60, public"))
    var inserted = Int64(1_000_000)
    # 61s after insertion -> outside the 60s lifetime.
    var now_ms = UInt64(1_061_000)
    assert_false(
        is_fresh(cc, inserted, Optional[Int64](), _empty_headers(), now_ms)
    )


def test_is_fresh_s_maxage_fallback_when_max_age_absent() raises:
    var cc = parse_cache_control(String("s-maxage=120, public"))
    var inserted = Int64(0)
    assert_true(
        is_fresh(
            cc, inserted, Optional[Int64](), _empty_headers(), UInt64(60_000)
        )
    )


def test_is_fresh_no_cache_response_directive_blocks() raises:
    var cc = parse_cache_control(String("no-cache, max-age=3600"))
    assert_false(
        is_fresh(cc, Int64(0), Optional[Int64](), _empty_headers(), UInt64(0))
    )


def test_is_fresh_no_store_response_directive_blocks() raises:
    var cc = parse_cache_control(String("no-store"))
    assert_false(
        is_fresh(cc, Int64(0), Optional[Int64](), _empty_headers(), UInt64(0))
    )


def test_is_fresh_must_revalidate_blocks() raises:
    var cc = parse_cache_control(String("max-age=60, must-revalidate"))
    assert_false(
        is_fresh(
            cc, Int64(0), Optional[Int64](), _empty_headers(), UInt64(10_000)
        )
    )


def test_is_fresh_request_no_cache_blocks() raises:
    var cc = parse_cache_control(String("max-age=3600"))
    var req = _req_with(String("no-cache"))
    assert_false(is_fresh(cc, Int64(0), Optional[Int64](), req, UInt64(0)))


def test_is_fresh_request_max_age_zero_blocks() raises:
    var cc = parse_cache_control(String("max-age=3600"))
    var req = _req_with(String("max-age=0"))
    assert_false(is_fresh(cc, Int64(0), Optional[Int64](), req, UInt64(0)))


def test_is_fresh_request_max_age_tighter_than_response() raises:
    var cc = parse_cache_control(String("max-age=600"))
    var req = _req_with(String("max-age=30"))
    var now_ms = UInt64(60_000)  # 60s old
    assert_false(is_fresh(cc, Int64(0), Optional[Int64](), req, now_ms))


def test_is_fresh_no_freshness_directives_is_not_fresh() raises:
    """RFC 9111 §4.2.2 allows heuristic freshness, but dodo's
    middleware intentionally requires an explicit
    ``Cache-Control: max-age`` / ``s-maxage`` to start with —
    less foot-gun, no surprise reuse of responses that the
    origin server did not opt-in for."""
    var cc = parse_cache_control(String("public"))
    assert_false(
        is_fresh(cc, Int64(0), Optional[Int64](), _empty_headers(), UInt64(0))
    )


def test_is_fresh_uses_date_when_present() raises:
    """Age math prefers the response ``Date`` header (RFC 9110
    §6.6.1) over the local insertion timestamp; when both are
    present and skew, ``Date`` wins."""
    var cc = parse_cache_control(String("max-age=60"))
    var inserted = Int64(0)
    var date = Optional[Int64](Int64(50_000))  # response says ts=50s
    # now=100s -> age=50s from Date, which is < 60s -> fresh.
    assert_true(is_fresh(cc, inserted, date, _empty_headers(), UInt64(100_000)))
    # now=120s -> age=70s from Date, which is > 60s -> stale.
    assert_false(
        is_fresh(cc, inserted, date, _empty_headers(), UInt64(120_000))
    )


def test_parse_vary_header_basic() raises:
    var fields = parse_vary_header(String("Accept, Accept-Language"))
    assert_equal(len(fields), 2)
    assert_equal(fields[0], String("accept"))
    assert_equal(fields[1], String("accept-language"))


def test_parse_vary_header_ows_trimmed_and_case_insensitive() raises:
    var fields = parse_vary_header(
        String("  Accept-Language ,  AUTHORIZATION ")
    )
    assert_equal(len(fields), 2)
    assert_equal(fields[0], String("accept-language"))
    assert_equal(fields[1], String("authorization"))


def test_parse_vary_header_star_surfaced() raises:
    """``Vary: *`` (RFC 9110 §12.5.5) signals that the response
    varies on aspects the cache cannot see. The middleware must
    refuse to reuse such entries; we surface ``*`` in the parsed
    list so the caller can short-circuit."""
    var fields = parse_vary_header(String("*"))
    assert_equal(len(fields), 1)
    assert_equal(fields[0], String("*"))


def test_parse_vary_header_empty_is_empty() raises:
    var fields = parse_vary_header(String(""))
    assert_equal(len(fields), 0)


def main() raises:
    test_is_fresh_within_max_age()
    test_is_fresh_just_past_max_age()
    test_is_fresh_s_maxage_fallback_when_max_age_absent()
    test_is_fresh_no_cache_response_directive_blocks()
    test_is_fresh_no_store_response_directive_blocks()
    test_is_fresh_must_revalidate_blocks()
    test_is_fresh_request_no_cache_blocks()
    test_is_fresh_request_max_age_zero_blocks()
    test_is_fresh_request_max_age_tighter_than_response()
    test_is_fresh_no_freshness_directives_is_not_fresh()
    test_is_fresh_uses_date_when_present()
    test_parse_vary_header_basic()
    test_parse_vary_header_ows_trimmed_and_case_insensitive()
    test_parse_vary_header_star_surfaced()
    test_parse_vary_header_empty_is_empty()
    print("test_cache_freshness: OK")

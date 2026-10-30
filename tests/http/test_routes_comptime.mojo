"""Tests for ``dodo.http.routes``: ``ComptimeRoute`` + ``ComptimeRouter``.

Covers the comptime-compiled dispatch path with feature-parity against
the runtime ``Router`` in [`test_router.mojo`](./test_router.mojo):

- Literal, parameter (``{name}``), and catch-all (``{*rest}``) segments.
- Method dispatch (``GET`` / ``POST`` / ``PUT`` / ``DELETE``).
- 404 on unknown paths.
- 405 with synthesised ``Allow:`` header on wrong method.
- Query-string stripping before match.
"""

from std.testing import (
    assert_true,
    assert_equal,
    TestSuite,
)

from dodo.http import (
    ComptimeRoute,
    ComptimeRouter,
    Request,
    Response,
    Status,
    Method,
    ok,
)
from dodo.http._route_path import parse_route_path


def _home(req: Request) raises -> Response:
    return ok("home")


def _list_users(req: Request) raises -> Response:
    return ok("list")


def _create_user(req: Request) raises -> Response:
    return ok("created")


def _get_user(req: Request) raises -> Response:
    return ok("user=" + req.param("id"))


def _get_files(req: Request) raises -> Response:
    return ok("files=" + req.param("rest"))


def _delete_user(req: Request) raises -> Response:
    return ok("deleted=" + req.param("id"))


comptime _BASE_ROUTES: List[ComptimeRoute] = [
    ComptimeRoute(Method.GET, "/", _home),
    ComptimeRoute(Method.GET, "/users", _list_users),
    ComptimeRoute(Method.POST, "/users", _create_user),
    ComptimeRoute(Method.GET, "/users/{id}", _get_user),
    ComptimeRoute(Method.DELETE, "/users/{id}", _delete_user),
    ComptimeRoute(Method.GET, "/files/{*rest}", _get_files),
]


def _router() raises -> ComptimeRouter[_BASE_ROUTES]:
    """Build a fresh router wired to all six comptime-bound handlers."""
    return ComptimeRouter[_BASE_ROUTES]()


# ── Literal matches ─────────────────────────────────────────────────────────


def _trailer(req: Request) raises -> Response:
    return ok("trailer:" + req.trailers.get("x-sum"))


comptime _TRAILER_ROUTES: List[ComptimeRoute] = [
    ComptimeRoute(Method.POST, "/upload", _trailer),
]


def test_handler_sees_the_whole_request() raises:
    """The matched handler gets the request as sent, trailers included."""
    var r = ComptimeRouter[_TRAILER_ROUTES]()
    var req = Request(method=Method.POST, url="/upload")
    req.trailers.append("x-sum", "42")
    assert_equal(r.serve(req).text(), "trailer:42")


def test_literal_root() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "home")


def test_literal_users() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/users"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "list")


def test_literal_trailing_slash_matches() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/users/"))
    # Trailing slash produces the same set of non-empty segments.
    assert_equal(resp.status, Status.OK)


# ── Parameter match ─────────────────────────────────────────────────────────


def test_param_extraction() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/users/42"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "user=42")


def test_param_long_value() raises:
    var r = _router()
    var resp = r.serve(
        Request(method=Method.GET, url="/users/aa-bb-cc-dd-ee-ff")
    )
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "user=aa-bb-cc-dd-ee-ff")


# ── Wildcard match ──────────────────────────────────────────────────────────


def test_wildcard_single() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/files/one"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "files=one")


def test_wildcard_deep() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/files/a/b/c.txt"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "files=a/b/c.txt")


# ── Method dispatch + 405 ───────────────────────────────────────────────────


def test_post_users() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.POST, url="/users"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "created")


def test_delete_user() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.DELETE, url="/users/7"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "deleted=7")


def test_method_not_allowed_on_users() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.PUT, url="/users"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)
    var allow = resp.headers.get("Allow")
    # Allow must list both GET and POST (order is route-declaration order).
    assert_true("GET" in allow)
    assert_true("POST" in allow)


def test_method_not_allowed_on_users_id() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.PATCH, url="/users/5"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)
    var allow = resp.headers.get("Allow")
    assert_true("GET" in allow)
    assert_true("DELETE" in allow)


# ── 404 on unknown path ─────────────────────────────────────────────────────


def test_unknown_path_returns_404() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/unknown"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_partial_prefix_returns_404() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/user"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_deeper_path_returns_404() raises:
    var r = _router()
    # ``/users/{id}`` has exactly two segments; three segments are
    # handled only by ``/files/*``, not by the users namespace.
    var resp = r.serve(Request(method=Method.GET, url="/users/1/posts"))
    assert_equal(resp.status, Status.NOT_FOUND)


# ── Query string is stripped before match ───────────────────────────────────


def test_query_stripped_before_match() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/users/9?expand=1"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "user=9")


# ── Parity with runtime Router on the match primitive ──────────────────────


def test_comptime_matches_runtime_route_shape() raises:
    """Sanity-check: the comptime table recognises routes in registration
    order, so handler 0 is always ``/``.
    """
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/"))
    assert_equal(resp.text(), "home")


# ── Catch-all and path errors are found at compile time ─────────────────────


comptime _CATCH_ALL_NOT_LAST = parse_route_path("/files/{*rest}/meta")
comptime _OLD_PARAM = parse_route_path("/users/:id")
comptime _OLD_WILDCARD = parse_route_path("/files/*")
comptime _PARTIAL_PARAM = parse_route_path("/a{b}")
comptime _VALID = parse_route_path("/users/{id}/files/{*rest}")
comptime _VALID_SEGMENT_COUNT = len(_VALID.segs)


def test_comptime_parse_reports_catch_all_not_last() raises:
    assert_equal(
        _CATCH_ALL_NOT_LAST.error,
        "catch-all '{*rest}' must be the last segment in a route",
    )


def test_comptime_parse_reports_old_param_syntax() raises:
    assert_equal(
        _OLD_PARAM.error,
        "route segment ':id' uses the old syntax; write '{id}'",
    )


def test_comptime_parse_reports_old_wildcard_syntax() raises:
    assert_equal(
        _OLD_WILDCARD.error,
        "route segment '*' uses the old syntax; write '{*rest}'",
    )


def test_comptime_parse_reports_partial_param() raises:
    assert_equal(
        _PARTIAL_PARAM.error,
        "route segment 'a{b}' must be one whole '{name}' param",
    )


def test_comptime_parse_accepts_valid_path() raises:
    assert_equal(_VALID.error, "")
    assert_equal(_VALID_SEGMENT_COUNT, 4)


def test_catch_all_capture_uses_its_name() raises:
    var r = _router()
    var resp = r.serve(Request(method=Method.GET, url="/files/a/b/c"))
    assert_equal(resp.text(), "files=a/b/c")


# ── Entry ──────────────────────────────────────────────────────────────────


def main() raises:
    print("=" * 60)
    print("test_routes_comptime.mojo — ComptimeRouter")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

"""Tests for ``dodo.http.Router``.

Covers:

- Literal path matching (exact, leading/trailing slashes).
- Parameter segments (``{name}``) and their appearance in ``req.params``.
- Catch-all tail (``{*rest}``) capturing multi-segment remainders.
- Method dispatch (GET / POST / PUT / PATCH / DELETE / HEAD).
- 404 for unknown paths.
- 405 Method Not Allowed with an ``Allow:`` header listing supported
  methods.
- ``mount(prefix, sub)`` for nesting.
- Query-string stripping (``"/users?x=1"`` still routes to ``/users``).
"""

from std.testing import (
    assert_true,
    assert_false,
    assert_equal,
    assert_raises,
    TestSuite,
)

from dodo.http import (
    Router,
    Request,
    Response,
    ResponseImpl,
    Status,
    Method,
    ok,
)
from dodo.http.handler import Handler


@fieldwise_init
struct _DupHandler(Copyable, Handler):
    def serve(self, req: Request) raises -> Response:
        return ok("dup")


# ── Handler functions used across tests ─────────────────────────────────────


def h_home(req: Request) raises -> Response:
    return ok("home")


def h_list_users(req: Request) raises -> Response:
    return ok("list")


def h_create_user(req: Request) raises -> Response:
    return ok("created")


def h_get_user(req: Request) raises -> Response:
    return ok("user:" + req.param("id"))


def h_get_post(req: Request) raises -> Response:
    return ok("user=" + req.param("uid") + " post=" + req.param("pid"))


def h_files(req: Request) raises -> Response:
    return ok("files:" + req.param("rest"))


def h_path(req: Request) raises -> Response:
    return ok("path:" + req.param("path"))


def h_user_rest(req: Request) raises -> Response:
    return ok(req.param("id") + "|" + req.param("rest"))


def h_has_star(req: Request) raises -> Response:
    if req.has_param("*"):
        return ok("has star")
    return ok("no star")


def h_delete_user(req: Request) raises -> Response:
    return ok("deleted")


def h_admin(req: Request) raises -> Response:
    return ok("admin:" + req.url)


def h_trailer(req: Request) raises -> Response:
    return ok("trailer:" + req.trailers.get("x-sum"))


# ── Literal paths ───────────────────────────────────────────────────────────


def h_trailer_param(req: Request) raises -> Response:
    return ok(req.param("id") + ":" + req.trailers.get("x-sum"))


def test_param_route_sees_the_whole_request() raises:
    """A route that adds params still hands over the trailers."""
    var r = Router()
    r.post("/upload/{id}", h_trailer_param)
    var req = Request(method=Method.POST, url="/upload/7")
    req.trailers.append("x-sum", "42")
    assert_equal(r.serve(req).text(), "7:42")


def test_literal_route_sees_the_whole_request() raises:
    """A handler behind a literal route gets the request as sent,
    trailers included; rebuilding it for dispatch dropped them."""
    var r = Router()
    r.post("/upload", h_trailer)
    var req = Request(method=Method.POST, url="/upload")
    req.trailers.append("x-sum", "42")
    assert_equal(r.serve(req).text(), "trailer:42")


def test_literal_root() raises:
    """Literal ``/`` matches exactly the root."""
    var r = Router()
    r.get("/", h_home)
    var resp = r.serve(Request(method=Method.GET, url="/"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "home")


def test_literal_multi_segment() raises:
    """Literal ``/users`` matches exactly."""
    var r = Router()
    r.get("/users", h_list_users)
    var resp = r.serve(Request(method=Method.GET, url="/users"))
    assert_equal(resp.text(), "list")


def test_literal_not_matched_returns_404() raises:
    """A different literal path returns 404."""
    var r = Router()
    r.get("/users", h_list_users)
    var resp = r.serve(Request(method=Method.GET, url="/other"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_trailing_slash_ignored_on_request() raises:
    """Trailing slash on request URL still matches the literal route."""
    var r = Router()
    r.get("/users", h_list_users)
    var resp = r.serve(Request(method=Method.GET, url="/users/"))
    assert_equal(resp.text(), "list")


def test_trailing_slash_ignored_on_route() raises:
    """Trailing slash on route pattern still matches a plain URL."""
    var r = Router()
    r.get("/users/", h_list_users)
    var resp = r.serve(Request(method=Method.GET, url="/users"))
    assert_equal(resp.text(), "list")


# ── Parameter segments ──────────────────────────────────────────────────────


def test_param_single() raises:
    """``:id`` captures a segment into req.params."""
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/42"))
    assert_equal(resp.text(), "user:42")


def test_param_multiple() raises:
    """Multiple params in one pattern get captured separately."""
    var r = Router()
    r.get("/users/{uid}/posts/{pid}", h_get_post)
    var resp = r.serve(Request(method=Method.GET, url="/users/3/posts/7"))
    assert_equal(resp.text(), "user=3 post=7")


def test_param_does_not_match_too_short() raises:
    """A pattern with a parameter does not match shorter paths."""
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_param_does_not_match_too_long() raises:
    """A pattern with a parameter does not match longer paths."""
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/42/extra"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_param_named_value() raises:
    """Captured param is the exact text of the segment."""
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/abc-DEF-123"))
    assert_equal(resp.text(), "user:abc-DEF-123")


# ── Catch-all tail ───────────────────────────────────────────────────────────


def test_catch_all_one_segment() raises:
    """``{*rest}`` captures a single remaining segment."""
    var r = Router()
    r.get("/files/{*rest}", h_files)
    var resp = r.serve(Request(method=Method.GET, url="/files/hello.txt"))
    assert_equal(resp.text(), "files:hello.txt")


def test_catch_all_many_segments() raises:
    """``{*rest}`` captures multiple remaining segments joined by ``/``."""
    var r = Router()
    r.get("/files/{*rest}", h_files)
    var resp = r.serve(
        Request(method=Method.GET, url="/files/deep/nested/file.txt")
    )
    assert_equal(resp.text(), "files:deep/nested/file.txt")


def test_catch_all_zero_segments_does_not_match() raises:
    """A catch-all needs at least one remaining segment."""
    var r = Router()
    r.get("/files/{*rest}", h_files)
    var resp = r.serve(Request(method=Method.GET, url="/files"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_catch_all_uses_its_own_name() raises:
    """The capture lands under the name written in the braces."""
    var r = Router()
    r.get("/static/{*path}", h_path)
    var resp = r.serve(Request(method=Method.GET, url="/static/css/site.css"))
    assert_equal(resp.text(), "path:css/site.css")


def test_catch_all_after_param() raises:
    """A param and a catch-all can share a pattern."""
    var r = Router()
    r.get("/users/{id}/{*rest}", h_user_rest)
    var resp = r.serve(Request(method=Method.GET, url="/users/7/a/b"))
    assert_equal(resp.text(), "7|a/b")


def test_catch_all_has_no_star_key() raises:
    """A catch-all captures under its own name, never ``"*"``."""
    var r = Router()
    r.get("/files/{*rest}", h_has_star)
    var resp = r.serve(Request(method=Method.GET, url="/files/a"))
    assert_equal(resp.text(), "no star")


# ── Malformed paths are rejected at registration ────────────────────────────


def _registration_error(path: String) -> String:
    """The error ``Router.get`` raises for ``path``, or ``"no error"``."""
    var r = Router()
    try:
        r.get(path, h_home)
    except e:
        return String(e)
    return String("no error")


def test_path_must_start_with_slash() raises:
    assert_equal(
        _registration_error("users"),
        "route path 'users' must start with '/'",
    )


def test_empty_path_rejected() raises:
    assert_equal(
        _registration_error(""),
        "route path '' must start with '/'",
    )


def test_unclosed_brace_rejected() raises:
    assert_equal(
        _registration_error("/users/{id"),
        "unclosed '{' in route segment '{id'",
    )


def test_closing_brace_without_opening_rejected() raises:
    assert_equal(
        _registration_error("/users/id}"),
        "'}' without '{' in route segment 'id}'",
    )


def test_reversed_braces_rejected() raises:
    assert_equal(
        _registration_error("/users/}id{"),
        "'}' without '{' in route segment '}id{'",
    )


def test_empty_param_name_rejected() raises:
    assert_equal(
        _registration_error("/users/{}"),
        "empty param name in route segment '{}'",
    )


def test_nameless_catch_all_rejected() raises:
    assert_equal(
        _registration_error("/files/{*}"),
        "empty param name in route segment '{*}'",
    )


def test_name_starting_with_digit_rejected() raises:
    assert_equal(
        _registration_error("/users/{1id}"),
        (
            "invalid param name '1id' in route segment '{1id}'; use letters,"
            " digits and '_', and do not start with a digit"
        ),
    )


def test_name_with_dash_rejected() raises:
    assert_equal(
        _registration_error("/users/{user-id}"),
        (
            "invalid param name 'user-id' in route segment '{user-id}'; use"
            " letters, digits and '_', and do not start with a digit"
        ),
    )


def test_underscore_and_digit_names_accepted() raises:
    assert_equal(_registration_error("/users/{_user_2}"), "no error")


def test_duplicate_param_name_rejected() raises:
    assert_equal(
        _registration_error("/users/{id}/posts/{id}"),
        "duplicate param name 'id' in route path",
    )


def test_duplicate_name_across_param_and_catch_all_rejected() raises:
    assert_equal(
        _registration_error("/{id}/{*id}"),
        "duplicate param name 'id' in route path",
    )


def test_catch_all_not_last_rejected() raises:
    assert_equal(
        _registration_error("/files/{*rest}/extra"),
        "catch-all '{*rest}' must be the last segment in a route",
    )


def test_param_with_literal_prefix_rejected() raises:
    assert_equal(
        _registration_error("/a{b}"),
        "route segment 'a{b}' must be one whole '{name}' param",
    )


def test_param_with_literal_suffix_rejected() raises:
    assert_equal(
        _registration_error("/{b}c"),
        "route segment '{b}c' must be one whole '{name}' param",
    )


def test_two_params_in_one_segment_rejected() raises:
    assert_equal(
        _registration_error("/{a}{b}"),
        "route segment '{a}{b}' must be one whole '{name}' param",
    )


def test_old_param_syntax_rejected() raises:
    assert_equal(
        _registration_error("/users/:id"),
        "route segment ':id' uses the old syntax; write '{id}'",
    )


def test_old_wildcard_syntax_rejected() raises:
    assert_equal(
        _registration_error("/files/*"),
        "route segment '*' uses the old syntax; write '{*rest}'",
    )


def test_post_registration_validates_too() raises:
    var r = Router()
    with assert_raises(contains="uses the old syntax"):
        r.post("/users/:id", h_home)


def test_struct_handler_registration_validates_too() raises:
    var r = Router()
    with assert_raises(contains="uses the old syntax"):
        r.get[_IdEcho]("/users/:id", _IdEcho())


# ── OpenAPI templates ───────────────────────────────────────────────────────


def test_openapi_template_keeps_params() raises:
    var r = Router()
    r.get("/users/{uid}/posts/{pid}", h_get_post)
    assert_equal(r.route_openapi_template(0), "/users/{uid}/posts/{pid}")


def test_openapi_template_names_catch_all() raises:
    var r = Router()
    r.get("/files/{*rest}", h_files)
    assert_equal(r.route_openapi_template(0), "/files/{rest}")


def test_openapi_template_root() raises:
    var r = Router()
    r.get("/", h_home)
    assert_equal(r.route_openapi_template(0), "/")


def test_route_path_params_lists_param_and_catch_all() raises:
    var r = Router()
    r.get("/users/{id}/{*rest}", h_user_rest)
    var names = r.route_path_params(0)
    assert_equal(len(names), 2)
    assert_equal(names[0], "id")
    assert_equal(names[1], "rest")


# ── Method dispatch ─────────────────────────────────────────────────────────


def test_method_get_and_post_on_same_path() raises:
    """GET and POST on the same path dispatch to different handlers."""
    var r = Router()
    r.get("/users", h_list_users)
    r.post("/users", h_create_user)
    var get_resp = r.serve(Request(method=Method.GET, url="/users"))
    var post_resp = r.serve(Request(method=Method.POST, url="/users"))
    assert_equal(get_resp.text(), "list")
    assert_equal(post_resp.text(), "created")


def test_method_wrong_on_known_path_returns_405() raises:
    """Wrong method on a known path returns 405."""
    var r = Router()
    r.get("/users", h_list_users)
    var resp = r.serve(Request(method=Method.POST, url="/users"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)


def test_method_not_allowed_includes_allow_header() raises:
    """405 responses list supported methods in an ``Allow:`` header."""
    var r = Router()
    r.get("/users", h_list_users)
    r.delete("/users", h_delete_user)
    var resp = r.serve(Request(method=Method.POST, url="/users"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)
    var allow = resp.headers.get("Allow")
    assert_true(allow.find("GET") >= 0)
    assert_true(allow.find("DELETE") >= 0)


def test_method_all_six() raises:
    """All six major HTTP methods each get their own route."""
    var r = Router()
    r.get("/x", h_home)
    r.post("/x", h_home)
    r.put("/x", h_home)
    r.patch("/x", h_home)
    r.delete("/x", h_home)
    r.head("/x", h_home)
    assert_equal(r.serve(Request(method=Method.GET, url="/x")).status, 200)
    assert_equal(r.serve(Request(method=Method.POST, url="/x")).status, 200)
    assert_equal(r.serve(Request(method=Method.PUT, url="/x")).status, 200)
    assert_equal(r.serve(Request(method=Method.PATCH, url="/x")).status, 200)
    assert_equal(r.serve(Request(method=Method.DELETE, url="/x")).status, 200)
    assert_equal(r.serve(Request(method=Method.HEAD, url="/x")).status, 200)


# ── 404 for unknown paths ───────────────────────────────────────────────────


def test_404_empty_router() raises:
    """A router with no routes returns 404 for any request."""
    var r = Router()
    var resp = r.serve(Request(method=Method.GET, url="/anywhere"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_404_unknown_path() raises:
    """A path that matches no registered route returns 404."""
    var r = Router()
    r.get("/users", h_list_users)
    var resp = r.serve(Request(method=Method.GET, url="/admin"))
    assert_equal(resp.status, Status.NOT_FOUND)


# ── Query string handling ───────────────────────────────────────────────────


def test_query_string_stripped() raises:
    """Routing ignores the ``?query=...`` portion of the URL."""
    var r = Router()
    r.get("/search", h_home)
    var resp = r.serve(
        Request(method=Method.GET, url="/search?q=mojo&limit=10")
    )
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "home")


def test_query_string_with_param() raises:
    """Query-string stripping does not interfere with path params."""
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/5?format=json"))
    assert_equal(resp.text(), "user:5")


@fieldwise_init
struct _RouterWrapper[Inner: Handler](Handler):
    """Tiny test wrapper proving ``Router`` satisfies ``Handler``."""

    comptime BodyType = Self.Inner.BodyType
    var inner: Self.Inner

    def serve(self, req: Request) raises -> ResponseImpl[Self.BodyType]:
        return self.inner.serve(req)


# ── Router is a Handler ─────────────────────────────────────────────────────


def test_router_is_handler() raises:
    """Router can be wrapped by a struct that takes a Handler."""
    var r = Router()
    r.get("/", h_home)
    var wrapped = _RouterWrapper(r^)
    var resp = wrapped.serve(Request(method=Method.GET, url="/"))
    assert_equal(resp.text(), "home")


# ── Router accepts Handler structs ─────────────

# Tiny stateful Handler used by the struct-handler tests below.
# The Router's `get[H]` / `post[H]` / etc. heap-allocate `H`,
# capture monomorphised serve / destroy thunks, and free in
# Router.__deinit__. Each test exercises a different facet of the
# new dispatch path.


@fieldwise_init
struct _StatefulGreeter(Copyable, Handler):
    """Handler with state that shows the boxed value survives
    registration + dispatch."""

    var greeting: String

    def serve(self, req: Request) raises -> Response:
        return ok(self.greeting + ":" + req.url)


def test_router_get_accepts_handler_struct() raises:
    """``Router.get[H]`` accepts an ``H: Handler`` struct."""
    var r = Router()
    r.get[_StatefulGreeter]("/hi", _StatefulGreeter("hello"))
    var resp = r.serve(Request(method=Method.GET, url="/hi"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "hello:/hi")


def test_router_post_accepts_handler_struct() raises:
    var r = Router()
    r.post[_StatefulGreeter]("/echo", _StatefulGreeter("posted"))
    var resp = r.serve(Request(method=Method.POST, url="/echo"))
    assert_equal(resp.text(), "posted:/echo")


def test_router_put_patch_delete_head_accept_handler_structs() raises:
    """All six method overloads accept ``H: Handler`` structs."""
    var r = Router()
    r.put[_StatefulGreeter]("/x", _StatefulGreeter("PUT"))
    r.patch[_StatefulGreeter]("/x", _StatefulGreeter("PATCH"))
    r.delete[_StatefulGreeter]("/x", _StatefulGreeter("DEL"))
    r.head[_StatefulGreeter]("/x", _StatefulGreeter("HEAD"))
    assert_equal(r.serve(Request(method=Method.PUT, url="/x")).text(), "PUT:/x")
    assert_equal(
        r.serve(Request(method=Method.PATCH, url="/x")).text(),
        "PATCH:/x",
    )
    assert_equal(
        r.serve(Request(method=Method.DELETE, url="/x")).text(),
        "DEL:/x",
    )
    assert_equal(
        r.serve(Request(method=Method.HEAD, url="/x")).text(),
        "HEAD:/x",
    )


def test_router_mixes_def_and_struct_handlers() raises:
    """Same Router holds a ``def(Request) -> Response`` and an
    ``H: Handler`` struct on parallel paths; dispatch picks the
    right kind per route."""
    var r = Router()
    r.get("/fn", h_home)
    r.get[_StatefulGreeter]("/struct", _StatefulGreeter("S"))
    var fn_resp = r.serve(Request(method=Method.GET, url="/fn"))
    var struct_resp = r.serve(Request(method=Method.GET, url="/struct"))
    assert_equal(fn_resp.text(), "home")
    assert_equal(struct_resp.text(), "S:/struct")


def test_router_404_with_struct_handler_present() raises:
    """An unknown path still returns 404 even when struct handlers
    are registered."""
    var r = Router()
    r.get[_StatefulGreeter]("/known", _StatefulGreeter("K"))
    var resp = r.serve(Request(method=Method.GET, url="/missing"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_router_405_with_struct_handler_present() raises:
    """405 Method Not Allowed still includes the Allow header when
    a struct handler is the registered method."""
    var r = Router()
    r.get[_StatefulGreeter]("/users", _StatefulGreeter("G"))
    var resp = r.serve(Request(method=Method.POST, url="/users"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)
    var allow = resp.headers.get("Allow")
    assert_true(allow.find("GET") >= 0)


struct _IdEcho(Copyable, Defaultable, Handler):
    """Stateless Handler used by
    ``test_router_struct_handler_path_param_capture``. Echoes the
    captured ``:id`` path param.
    """

    def __init__(out self):
        pass

    def serve(self, req: Request) raises -> Response:
        return ok("id=" + req.param("id"))


def test_router_struct_handler_path_param_capture() raises:
    """``:id``-style path params still populate ``req.params``
    when the route's handler is a struct."""
    var r = Router()
    r.get[_IdEcho]("/users/{id}", _IdEcho())
    var resp = r.serve(Request(method=Method.GET, url="/users/42"))
    assert_equal(resp.text(), "id=42")


def test_router_drops_struct_handlers_cleanly() raises:
    """Stress: register 100 struct handlers on a Router, then drop
    it. Each ``H`` must be freed via the matching destroy thunk;
    no leaks (validated by the test process not crashing on
    repeated runs).
    """
    for _ in range(5):
        var r = Router()
        for i in range(100):
            r.get[_StatefulGreeter](
                "/p" + String(i), _StatefulGreeter("g" + String(i))
            )
        # ``r`` drops here; Router.__deinit__ runs every destroy_thunk.


# ── OPTIONS / TRACE / CONNECT + fallback ────────────────────────────────────


def h_opts(req: Request) raises -> Response:
    return ok("opts")


def h_trace(req: Request) raises -> Response:
    return ok("trace")


def h_connect(req: Request) raises -> Response:
    return ok("connect")


def h_fb(req: Request) raises -> Response:
    return ok("fallback:" + req.url)


def test_router_options_registration() raises:
    var r = Router()
    r.options("/thing", h_opts)
    var resp = r.serve(Request(method=Method.OPTIONS, url="/thing"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "opts")


def test_router_trace_registration() raises:
    var r = Router()
    r.trace("/thing", h_trace)
    var resp = r.serve(Request(method=Method.TRACE, url="/thing"))
    assert_equal(resp.text(), "trace")


def test_router_connect_registration() raises:
    var r = Router()
    r.connect("/thing", h_connect)
    var resp = r.serve(Request(method=Method.CONNECT, url="/thing"))
    assert_equal(resp.text(), "connect")


def test_router_options_405_lists_allow() raises:
    """A path registered under OPTIONS still yields 405 + Allow for a
    different method."""
    var r = Router()
    r.options("/thing", h_opts)
    var resp = r.serve(Request(method=Method.GET, url="/thing"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)
    assert_true(resp.headers.get("Allow").find("OPTIONS") >= 0)


def test_router_custom_fallback() raises:
    """When set, the fallback replaces the default 404 body for an
    unmatched path (and returns 200 from the fallback here)."""
    var r = Router()
    r.get("/", h_home)
    r.fallback(h_fb)
    var resp = r.serve(Request(method=Method.GET, url="/nope"))
    assert_equal(resp.status, Status.OK)
    assert_equal(resp.text(), "fallback:/nope")


def test_router_fallback_not_used_on_405() raises:
    """A known path under another method returns 405, not the
    fallback (the fallback is a not-found hook only)."""
    var r = Router()
    r.get("/users", h_list_users)
    r.fallback(h_fb)
    var resp = r.serve(Request(method=Method.POST, url="/users"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)


def test_router_default_404_without_fallback() raises:
    var r = Router()
    r.get("/", h_home)
    var resp = r.serve(Request(method=Method.GET, url="/nope"))
    assert_equal(resp.status, Status.NOT_FOUND)


# ── Router audit fixes ──────────────────────────────────────────────────────


def test_404_body_does_not_echo_the_url() raises:
    var r = Router()
    r.get("/", h_home)
    var resp = r.serve(Request(method=Method.GET, url="/<script>?token=abc"))
    assert_equal(resp.status, Status.NOT_FOUND)
    assert_equal(resp.text(), "Not Found")


def test_duplicate_route_raises() raises:
    var r = Router()
    r.get("/users", h_list_users)
    with assert_raises(contains="duplicate route: GET /users"):
        r.get("/users", h_home)


def test_duplicate_route_ignores_trailing_slash() raises:
    var r = Router()
    r.get("/users", h_list_users)
    with assert_raises(contains="duplicate route"):
        r.get("/users/", h_home)


def test_duplicate_route_ignores_param_name() raises:
    var r = Router()
    r.get("/users/{id}", h_get_user)
    with assert_raises(contains="duplicate route: GET /users/{name}"):
        r.get("/users/{name}", h_home)


def test_duplicate_struct_route_raises() raises:
    var r = Router()
    r.get("/users", h_list_users)
    with assert_raises(contains="duplicate route"):
        r.get[_DupHandler]("/users", _DupHandler())


def test_same_path_other_method_is_not_a_duplicate() raises:
    var r = Router()
    r.get("/users", h_list_users)
    r.post("/users", h_create_user)
    assert_equal(r.route_count(), 2)


def test_param_and_catch_all_are_not_duplicates() raises:
    var r = Router()
    r.get("/files/{id}", h_get_user)
    r.get("/files/{*rest}", h_files)
    r.get("/files/latest", h_home)
    assert_equal(r.route_count(), 3)


def test_duplicate_mount_raises() raises:
    var r = Router()
    r.mount("/api", Router())
    with assert_raises(contains="duplicate mount: /api"):
        r.mount("/api/", Router())


def test_param_is_percent_decoded() raises:
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/a%20b+c"))
    assert_equal(resp.text(), "user:a b+c")


def test_param_is_decoded_only_once() raises:
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/a%2541"))
    assert_equal(resp.text(), "user:a%41")


def test_param_keeps_an_encoded_slash_in_one_segment() raises:
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/a%2Fb"))
    assert_equal(resp.text(), "user:a/b")


def test_catch_all_is_percent_decoded() raises:
    var r = Router()
    r.get("/files/{*rest}", h_files)
    var resp = r.serve(Request(method=Method.GET, url="/files/a%20b/c%21"))
    assert_equal(resp.text(), "files:a b/c!")


def test_literal_segment_is_matched_undecoded() raises:
    var r = Router()
    r.get("/users", h_list_users)
    var resp = r.serve(Request(method=Method.GET, url="/%75sers"))
    assert_equal(resp.status, Status.NOT_FOUND)


def test_bad_escape_in_param_is_400() raises:
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var truncated = r.serve(Request(method=Method.GET, url="/users/a%2"))
    assert_equal(truncated.status, Status.BAD_REQUEST)
    var not_hex = r.serve(Request(method=Method.GET, url="/users/a%zz"))
    assert_equal(not_hex.status, Status.BAD_REQUEST)


def test_invalid_utf8_in_param_is_400() raises:
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/%ff"))
    assert_equal(resp.status, Status.BAD_REQUEST)


def test_400_body_does_not_echo_the_param() raises:
    var r = Router()
    r.get("/users/{id}", h_get_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/%zz<b>"))
    assert_equal(resp.text(), "Bad percent escape in path")


def test_bad_escape_on_wrong_method_is_405() raises:
    var r = Router()
    r.post("/users/{id}", h_create_user)
    var resp = r.serve(Request(method=Method.GET, url="/users/%zz"))
    assert_equal(resp.status, Status.METHOD_NOT_ALLOWED)


# ── Entry point ─────────────────────────────────────────────────────────────


def main() raises:
    print("=" * 60)
    print("test_router.mojo — Router path matching + method dispatch")
    print("=" * 60)
    print()
    TestSuite.discover_tests[__functions_in_module()]().run()

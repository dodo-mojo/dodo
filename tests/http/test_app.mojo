"""``App``: typed handlers, shared state, problem responses, middleware."""

from std.collections import Optional
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false, assert_true, TestSuite

from dodo.http import Method, Request, Response, ok
from dodo.http.app import (
    App,
    JsonBody,
    NoState,
    PathParams,
    QueryParams,
    AppState,
)
from dodo.http.middleware import RequestId


@fieldwise_init
struct Db(AppState):
    """Movable only: if a request copied the state, this would not compile."""

    var name: String


@fieldwise_init
struct UserPath(PathParams):
    var org: String
    var id: Int


@fieldwise_init
struct IdPath(PathParams):
    var id: Int


@fieldwise_init
struct LimitQuery(QueryParams):
    var limit: Int


@fieldwise_init
struct NamePath(PathParams):
    var name: String


@fieldwise_init
struct RestPath(PathParams):
    var rest: String


@fieldwise_init
struct Paging(QueryParams):
    var limit: Int
    var ratio: Float64
    var verbose: Bool
    var tag: Optional[String]
    var page: Optional[Int]


@fieldwise_init
struct Search(QueryParams):
    var q: String


@fieldwise_init
struct NewUser(JsonBody):
    var name: String
    var score: Float64


@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String


@fieldwise_init
struct Address(Movable):
    var addr: Int


def _get(url: String) -> Request:
    return Request(method=Method.GET, url=url)


def _post(url: String, body: String) -> Request:
    return Request(
        method=Method.POST, url=url, body=List[UInt8](body.as_bytes())
    )


def _problem_body(status: Int, title: String, detail: String) -> String:
    return String(
        '{"type":"about:blank","title":"',
        title,
        '","status":',
        status,
        ',"detail":"',
        detail,
        '"}',
    )


def h_plain(req: Request) raises -> Response:
    return ok("plain")


def h_struct(req: Request) raises -> User:
    return User(1, "ada")


def h_path(req: Request, path: UserPath) raises -> User:
    return User(path.id, path.org)


def h_name(req: Request, path: NamePath) raises -> Response:
    return ok(path.name)


def h_rest(req: Request, path: RestPath) raises -> Response:
    return ok(path.rest)


def h_query(req: Request, q: Paging) raises -> Response:
    var tag = String("none")
    if q.tag:
        tag = q.tag.value()
    var page = -1
    if q.page:
        page = q.page.value()
    return ok(
        String(q.limit, " ", q.ratio, " ", q.verbose, " ", tag, " ", page)
    )


def h_search(req: Request, q: Search) raises -> Response:
    return ok(q.q)


def h_body(req: Request, body: NewUser) raises -> User:
    return User(Int(body.score), body.name)


def h_state(req: Request, db: Db) raises -> Response:
    return ok(db.name)


def h_address(req: Request, db: Db) raises -> Address:
    return Address(Int(Pointer(to=db)))


def h_two(req: Request, path: NamePath, db: Db) raises -> Response:
    return ok(String(path.name, "@", db.name))


def h_three(req: Request, path: NamePath, q: Search, db: Db) raises -> Response:
    return ok(String(path.name, " ", q.q, " ", db.name))


def h_four(
    req: Request, path: NamePath, q: Search, body: NewUser, db: Db
) raises -> Response:
    return ok(String(path.name, " ", q.q, " ", body.name, " ", db.name))


def h_id(req: Request, path: IdPath) raises -> Response:
    return ok(String(path.id))


def h_limit(req: Request, q: LimitQuery) raises -> Response:
    return ok(String(q.limit))


def h_boom(req: Request) raises -> Response:
    raise Error("secret detail")


def h_boom_struct(req: Request) raises -> User:
    raise Error("secret detail")


def test_plain_handler_returns_its_response() raises:
    var app = App()
    app.get["/"](h_plain)
    assert_equal(app.serve(_get("/")).text(), "plain")


def test_struct_return_is_200_json() raises:
    var app = App()
    app.get["/"](h_struct)
    var resp = app.serve(_get("/"))
    assert_equal(resp.status, 200)
    assert_equal(resp.headers.get("Content-Type"), "application/json")
    assert_equal(resp.text(), '{"id":1,"name":"ada"}')


def test_path_struct_filled_and_converted() raises:
    var app = App()
    app.get["/orgs/{org}/users/{id}"](h_path)
    assert_equal(
        app.serve(_get("/orgs/acme/users/7")).text(), '{"id":7,"name":"acme"}'
    )


def test_single_int_field_reaches_the_handler() raises:
    var app = App()
    app.get["/p/{id}"](h_id)
    app.get["/q"](h_limit)
    assert_equal(app.serve(_get("/p/7")).text(), "7")
    assert_equal(app.serve(_get("/q?limit=3")).text(), "3")


def test_bad_path_value_is_400_problem() raises:
    var app = App()
    app.get["/orgs/{org}/users/{id}"](h_path)
    var resp = app.serve(_get("/orgs/acme/users/x"))
    assert_equal(resp.status, 400)
    assert_equal(resp.headers.get("Content-Type"), "application/problem+json")
    assert_equal(
        resp.text(),
        _problem_body(400, "Bad Request", "field 'id': expected Int, got 'x'"),
    )


def test_path_param_is_percent_decoded() raises:
    var app = App()
    app.get["/n/{name}"](h_name)
    assert_equal(app.serve(_get("/n/a%20b+c")).text(), "a b+c")


def test_bad_percent_escape_is_400() raises:
    var app = App()
    app.get["/n/{name}"](h_name)
    assert_equal(app.serve(_get("/n/a%2")).status, 400)
    assert_equal(app.serve(_get("/n/a%zz")).status, 400)


def test_invalid_utf8_is_400() raises:
    var app = App()
    app.get["/n/{name}"](h_name)
    assert_equal(app.serve(_get("/n/%ff")).status, 400)


def test_catch_all_fills_its_field() raises:
    var app = App()
    app.get["/files/{*rest}"](h_rest)
    assert_equal(app.serve(_get("/files/a/b.txt")).text(), "a/b.txt")


def test_query_struct_required_and_optional() raises:
    var app = App()
    app.get["/"](h_query)
    var all = app.serve(_get("/?limit=5&ratio=0.5&verbose=true&tag=x&page=2"))
    assert_equal(all.text(), "5 0.5 True x 2")
    var some = app.serve(_get("/?limit=5&ratio=0.5&verbose=false"))
    assert_equal(some.text(), "5 0.5 False none -1")


def test_query_is_decoded() raises:
    var app = App()
    app.get["/"](h_search)
    assert_equal(app.serve(_get("/?q=a+b%21")).text(), "a b!")


def test_query_errors_name_the_field() raises:
    var app = App()
    app.get["/"](h_query)
    var missing = app.serve(_get("/?ratio=0.5&verbose=true"))
    assert_equal(missing.status, 400)
    assert_equal(
        missing.text(),
        _problem_body(400, "Bad Request", "missing field 'limit'"),
    )
    var bad = app.serve(_get("/?limit=5&ratio=0.5&verbose=maybe"))
    assert_equal(
        bad.text(),
        _problem_body(
            400, "Bad Request", "field 'verbose': expected Bool, got 'maybe'"
        ),
    )
    var bad_opt = app.serve(_get("/?limit=5&ratio=0.5&verbose=true&page=x"))
    assert_equal(
        bad_opt.text(),
        _problem_body(
            400, "Bad Request", "field 'page': expected Int, got 'x'"
        ),
    )


def test_failure_after_string_field_does_not_leak_or_crash() raises:
    var app = App()
    app.get["/orgs/{org}/users/{id}"](h_path)
    for _ in range(1000):
        assert_equal(app.serve(_get("/orgs/acme/users/x")).status, 400)


def test_json_body() raises:
    var app = App()
    app.post["/"](h_body)
    var resp = app.serve(_post("/", '{"name":"ada","score":3.0}'))
    assert_equal(resp.text(), '{"id":3,"name":"ada"}')


def test_bad_json_body_is_400() raises:
    var app = App()
    app.post["/"](h_body)
    assert_equal(app.serve(_post("/", "{not json")).status, 400)
    assert_equal(app.serve(_post("/", "")).status, 400)
    var missing = app.serve(_post("/", '{"name":"ada"}'))
    assert_equal(missing.status, 400)
    assert_true("score" in missing.text())


def test_state_is_shared_never_copied() raises:
    var app = App(state=Db("people"))
    app.get["/s"](h_state)
    app.get["/a"](h_address)
    assert_equal(app.serve(_get("/s")).text(), "people")
    var first = app.serve(_get("/a")).text()
    var copy = app.copy()
    assert_equal(copy.serve(_get("/a")).text(), first)


def test_many_arguments_in_any_order() raises:
    var app = App(state=Db("people"))
    app.get["/two/{name}"](h_two)
    app.get["/three/{name}"](h_three)
    app.post["/four/{name}"](h_four)
    assert_equal(app.serve(_get("/two/x")).text(), "x@people")
    assert_equal(app.serve(_get("/three/x?q=y")).text(), "x y people")
    assert_equal(
        app.serve(_post("/four/x?q=y", '{"name":"n","score":1.0}')).text(),
        "x y n people",
    )


def test_handler_error_is_500_and_hides_its_message() raises:
    var app = App()
    app.get["/r"](h_boom)
    app.get["/s"](h_boom_struct)
    var hidden = _problem_body(
        500, "Internal Server Error", "Internal Server Error"
    )
    assert_equal(app.serve(_get("/r")).text(), hidden)
    assert_equal(app.serve(_get("/s")).status, 500)


def test_handler_error_shows_in_dev_mode() raises:
    var app = App()
    app.get["/"](h_boom)
    var req = Request(method=Method.GET, url="/", expose_errors=True)
    assert_equal(
        app.serve(req).text(),
        _problem_body(500, "Internal Server Error", "secret detail"),
    )


def test_unknown_route_and_method() raises:
    var app = App()
    app.get["/"](h_plain)
    assert_equal(app.serve(_get("/nope")).status, 404)
    assert_equal(app.serve(_post("/", "")).status, 405)


def test_all_methods_register() raises:
    var app = App()
    app.post["/x"](h_plain)
    app.put["/x"](h_plain)
    app.patch["/x"](h_plain)
    app.delete["/x"](h_plain)
    app.route["/x"](Method.OPTIONS, h_plain)
    for method in [
        Method.POST,
        Method.PUT,
        Method.PATCH,
        Method.DELETE,
        Method.OPTIONS,
    ]:
        assert_equal(app.serve(Request(method=method, url="/x")).status, 200)


def test_stock_middleware_wraps_the_app() raises:
    var app = App(state=Db("people"))
    app.get["/"](h_state)
    var wrapped = RequestId(app^)
    var resp = wrapped.serve(_get("/"))
    assert_equal(resp.text(), "people")
    assert_true(resp.headers.contains("X-Request-Id"))


def test_mounted_group_shares_state_and_takes_middleware() raises:
    var app = App(state=Db("people"))
    app.get["/a"](h_address)
    var admin = app.group()
    admin.get["/a"](h_address)
    admin.get["/s"](h_state)
    app.mount("/admin", RequestId(admin^))

    assert_equal(
        app.serve(_get("/admin/a")).text(), app.serve(_get("/a")).text()
    )
    var resp = app.serve(_get("/admin/s"))
    assert_equal(resp.text(), "people")
    assert_true(resp.headers.contains("X-Request-Id"))
    assert_false(app.serve(_get("/a")).headers.contains("X-Request-Id"))
    assert_equal(app.serve(_get("/admin/nope")).status, 404)


def test_group_starts_with_no_routes() raises:
    var app = App()
    app.get["/"](h_plain)
    var sub = app.group()
    assert_equal(sub.serve(_get("/")).status, 404)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

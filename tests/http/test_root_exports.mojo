"""The `dodo` root exports what an app needs, enough to write one with it."""

from std.testing import assert_equal, TestSuite

from dodo import (
    App,
    AppState,
    JsonBody,
    PathParams,
    QueryParams,
    Request,
    Response,
    Status,
    bad_request,
    forbidden,
    internal_error,
    not_found,
    ok,
    ok_json,
    redirect,
    serve,
    unauthorized,
)


@fieldwise_init
struct Db(AppState):
    var name: String


@fieldwise_init
struct UserPath(PathParams):
    var id: Int


@fieldwise_init
struct Paging(QueryParams):
    var page: Int


@fieldwise_init
struct NewUser(JsonBody):
    var name: String


def home(req: Request) raises -> Response:
    return ok("home")


def get_user(req: Request, path: UserPath, db: Db) raises -> Response:
    return ok(String(db.name, ":", path.id))


def list_users(req: Request, paging: Paging) raises -> Response:
    return ok(String("page ", paging.page))


def add_user(req: Request, body: NewUser) raises -> Response:
    return ok_json(String('{"name":"', body.name, '"}'))


def _get(url: String) raises -> Request:
    return Request(method="GET", url=url)


def test_app_built_from_root_names() raises:
    var app = App(state=Db("people"))
    app.get["/"](home)
    app.get["/users/{id}"](get_user)
    app.get["/users"](list_users)
    app.post["/users"](add_user)

    assert_equal(app.serve(_get("/")).text(), "home")
    assert_equal(app.serve(_get("/users/7")).text(), "people:7")
    assert_equal(app.serve(_get("/users?page=2")).text(), "page 2")

    var post = Request(
        method="POST", url="/users", body=List[UInt8]('{"name":"a"}'.as_bytes())
    )
    assert_equal(app.serve(post).text(), '{"name":"a"}')


def test_response_helpers_from_root() raises:
    assert_equal(bad_request("x").status, Status.BAD_REQUEST)
    assert_equal(unauthorized("x").status, Status.UNAUTHORIZED)
    assert_equal(forbidden("x").status, Status.FORBIDDEN)
    assert_equal(not_found().status, Status.NOT_FOUND)
    assert_equal(internal_error("x").status, Status.INTERNAL_SERVER_ERROR)
    assert_equal(redirect("/x").status, Status.FOUND)


def _uses_serve() raises:
    # Never called: proves the free `serve` for wrapped apps is reachable.
    var app = App()
    app.get["/"](home)
    serve(app^, port=8080)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

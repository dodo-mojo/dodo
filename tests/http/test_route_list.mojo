"""The route list `dodo routes` prints: Router, App, mounts, wrappers."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from dodo.http import Method, Request, Response, Router, ok
from dodo.http.app import App, PathParams, routes_json
from dodo.http.handler import Handler, RouteInfo, join_route_path
from dodo.http.middleware import Logger, RequestId
from dodo.http.offload import Offload
from dodo.http.routes import ComptimeRoute, ComptimeRouter
from dodo.json import loads


def _home(req: Request) raises -> Response:
    return ok("home")


@fieldwise_init
struct _Echo(Copyable, Handler):
    def serve(self, req: Request) raises -> Response:
        return ok("echo")


@fieldwise_init
struct IdPath(PathParams):
    var id: Int


def _by_id(req: Request, path: IdPath) raises -> String:
    return String(path.id)


def _plain(req: Request) raises -> String:
    return "plain"


def _check(
    route: RouteInfo, method: String, path: String, blocking: Bool, kind: String
) raises:
    assert_equal(route.method, method)
    assert_equal(route.path, path)
    assert_equal(route.blocking, blocking)
    assert_equal(route.kind, kind)


def test_empty_router() raises:
    assert_equal(len(Router().route_list()), 0)


def test_router_routes_in_order() raises:
    var r = Router()
    r.get("/", _home)
    r.post("/users", _home)
    r.get("/users/{id}", _home)
    r.get("/files/{*rest}", _home)
    var routes = r.route_list()
    assert_equal(len(routes), 4)
    _check(routes[0], "GET", "/", False, "route")
    _check(routes[1], "POST", "/users", False, "route")
    _check(routes[2], "GET", "/users/{id}", False, "route")
    _check(routes[3], "GET", "/files/{*rest}", False, "route")


def test_trailing_slash_is_normalised() raises:
    var r = Router()
    r.get("/about/", _home)
    assert_equal(r.route_list()[0].path, "/about")


def test_struct_route_and_offload() raises:
    var r = Router()
    r.get("/echo", _Echo())
    r.get("/slow", Offload(_Echo()))
    var routes = r.route_list()
    _check(routes[0], "GET", "/echo", False, "route")
    _check(routes[1], "GET", "/slow", True, "route")


def test_fallback_is_listed_last() raises:
    var r = Router()
    r.fallback(_home)
    r.get("/", _home)
    var routes = r.route_list()
    assert_equal(len(routes), 2)
    _check(routes[1], "*", "/{*path}", False, "fallback")


def test_mount_prefixes_routes() raises:
    var sub = Router()
    sub.get("/", _home)
    sub.get("/users/{id}", _home)
    var r = Router()
    r.get("/", _home)
    r.mount("/api/v1", sub^)
    var routes = r.route_list()
    assert_equal(len(routes), 3)
    _check(routes[1], "GET", "/api/v1", False, "route")
    _check(routes[2], "GET", "/api/v1/users/{id}", False, "route")


def test_nested_mounts() raises:
    var inner = Router()
    inner.get("/x", _home)
    var middle = Router()
    middle.mount("/b", inner^)
    var outer = Router()
    outer.mount("/a", middle^)
    var routes = outer.route_list()
    assert_equal(len(routes), 1)
    assert_equal(routes[0].path, "/a/b/x")


def test_mount_through_middleware() raises:
    var sub = Router()
    sub.get("/stats", _home)
    var r = Router()
    r.mount("/admin", Logger(RequestId(sub^)))
    var routes = r.route_list()
    assert_equal(len(routes), 1)
    _check(routes[0], "GET", "/admin/stats", False, "route")


def test_mount_through_offload_marks_blocking() raises:
    var sub = Router()
    sub.get("/report", _home)
    var r = Router()
    r.mount("/jobs", Offload(sub^))
    _check(r.route_list()[0], "GET", "/jobs/report", True, "route")


def test_mounted_plain_handler_is_one_entry() raises:
    var r = Router()
    r.mount("/static", _Echo())
    var routes = r.route_list()
    assert_equal(len(routes), 1)
    _check(routes[0], "*", "/static/{*path}", False, "handler")


def test_mounted_sub_fallback_gets_prefix() raises:
    var sub = Router()
    sub.fallback(_home)
    var r = Router()
    r.mount("/docs", sub^)
    _check(r.route_list()[0], "*", "/docs/{*path}", False, "fallback")


def test_wrapper_forwards_router_list() raises:
    var r = Router()
    r.get("/", _home)
    var wrapped = Logger(r^)
    assert_equal(len(wrapped.route_list()), 1)


def test_app_routes_and_blocking() raises:
    var app = App()
    app.get["/"](_plain)
    app.get["/items/{id}"](_by_id, blocking=True)
    var admin = app.group()
    admin.get["/stats"](_plain)
    app.mount("/admin", RequestId(admin^))
    var routes = app.route_list()
    assert_equal(len(routes), 3)
    _check(routes[0], "GET", "/", False, "route")
    _check(routes[1], "GET", "/items/{id}", True, "route")
    _check(routes[2], "GET", "/admin/stats", False, "route")


comptime _TABLE: List[ComptimeRoute] = [
    ComptimeRoute(Method.GET, "/", _home),
    ComptimeRoute(Method.DELETE, "/users/{id}", _home),
]


def test_comptime_router() raises:
    var routes = ComptimeRouter[_TABLE]().route_list()
    assert_equal(len(routes), 2)
    _check(routes[1], "DELETE", "/users/{id}", False, "route")


def test_join_route_path() raises:
    assert_equal(join_route_path("", "/x"), "/x")
    assert_equal(join_route_path("/", "/x"), "/x")
    assert_equal(join_route_path("/api", "/"), "/api")
    assert_equal(join_route_path("/api", "/x"), "/api/x")


def test_routes_json() raises:
    var r = Router()
    r.get("/ü/{id}", _home)
    r.get("/slow", Offload(_Echo()))
    var text = routes_json(r.route_list())
    assert_false("\n" in text)
    var parsed = loads(text)
    var list = parsed["dodo_routes"]
    assert_equal(len(list), 2)
    assert_equal(list[0]["method"].as_string(), "GET")
    assert_equal(list[0]["path"].as_string(), "/ü/{id}")
    assert_false(list[0]["blocking"].as_bool())
    assert_true(list[1]["blocking"].as_bool())
    assert_equal(list[1]["kind"].as_string(), "route")


def test_routes_json_empty() raises:
    assert_equal(routes_json(List[RouteInfo]()), '{"dodo_routes":[]}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

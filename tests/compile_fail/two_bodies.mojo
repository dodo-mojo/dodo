# expect: route /x: two arguments are JsonBody (arguments 1 and 2)
from dodo.http import Request, Response, ok
from dodo.http.app import App, JsonBody, PathParams, QueryParams, AppState


@fieldwise_init
struct IdPath(PathParams):
    var id: Int


@fieldwise_init
struct Db(AppState):
    var name: String


@fieldwise_init
struct Other(AppState):
    var name: String


@fieldwise_init
struct Body(JsonBody):
    var name: String


@fieldwise_init
struct Plain(Movable):
    var name: String


def h(req: Request, a: Body, b: Body) raises -> Response:
    return ok("x")


def main() raises:
    var app = App()
    app.post["/x"](h)

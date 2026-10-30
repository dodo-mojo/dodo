# expect: duplicate route: GET /items/{name}
from dodo.http import ComptimeRoute, ComptimeRouter, Method, Request, Response, ok


def handler(req: Request) raises -> Response:
    return ok("x")


comptime ROUTES: List[ComptimeRoute] = [
    ComptimeRoute(Method.GET, "/items/{id}", handler),
    ComptimeRoute(Method.GET, "/items/{name}", handler),
]


def main() raises:
    var router = ComptimeRouter[ROUTES]()
    _ = router.serve(Request(method=Method.GET, url="/"))

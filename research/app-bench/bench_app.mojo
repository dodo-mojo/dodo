"""App used for the end-to-end run and load tests. Usage: bench_app PORT WORKERS"""

from std.sys import argv

from dodo import App, AppState, JsonBody, PathParams, QueryParams, Request, Response, ok
from std.collections import Optional


@fieldwise_init
struct Db(AppState):
    var name: String


@fieldwise_init
struct UserPath(PathParams):
    var id: Int


@fieldwise_init
struct TwoPath(PathParams):
    var org: String
    var id: Int


@fieldwise_init
struct Search(QueryParams):
    var q: String
    var limit: Optional[Int]


@fieldwise_init
struct NewUser(JsonBody):
    var name: String
    var age: Int


@fieldwise_init
struct User(Movable):
    var id: Int
    var db: String


@fieldwise_init
struct Echo(Movable):
    var name: String
    var age: Int


@fieldwise_init
struct Found(Movable):
    var q: String
    var limit: Int


def plain(req: Request) raises -> Response:
    return ok("hello")


def get_user(req: Request, path: UserPath, db: Db) raises -> User:
    return User(path.id, db.name)


def get_two(req: Request, path: TwoPath) raises -> Echo:
    return Echo(path.org, path.id)


def search(req: Request, query: Search) raises -> Found:
    var limit = 10
    if query.limit:
        limit = query.limit.value()
    return Found(query.q, limit)


def create(req: Request, body: NewUser) raises -> Echo:
    return Echo(body.name, body.age)


def boom(req: Request) raises -> Response:
    raise Error("secret detail")


def main() raises:
    var args = argv()
    var port = UInt16(Int(args[1]))
    var workers = Int(args[2])
    var app = App(state=Db("people"))
    app.get["/plain"](plain)
    app.get["/a/01"](plain)
    app.get["/a/02"](plain)
    app.get["/a/03"](plain)
    app.get["/a/04"](plain)
    app.get["/a/05"](plain)
    app.get["/a/06"](plain)
    app.get["/a/07"](plain)
    app.get["/a/08"](plain)
    app.get["/a/09"](plain)
    app.get["/a/10"](plain)
    app.get["/a/11"](plain)
    app.get["/a/12"](plain)
    app.get["/a/13"](plain)
    app.get["/a/14"](plain)
    app.get["/a/15"](plain)
    app.get["/a/16"](plain)
    app.get["/a/17"](plain)
    app.get["/a/18"](plain)
    app.get["/a/19"](plain)
    app.get["/last"](plain)
    app.get["/users/{id}"](get_user)
    app.get["/orgs/{org}/users/{id}"](get_two)
    app.get["/search"](search)
    app.post["/users"](create)
    app.get["/boom"](boom)
    app.serve(port=port, num_workers=workers)

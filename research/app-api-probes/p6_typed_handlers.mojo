"""P6: typed handlers on an App, end to end on fake requests.

Run: pixi run mojo -I . -I research/app-api-probes research/app-api-probes/p6_typed_handlers.mojo
"""

from p6_lib import *


@fieldwise_init
struct UserPath(PathParams):
    var org: String
    var id: Int


@fieldwise_init
struct OrgPath(PathParams):
    var org: String


@fieldwise_init
struct Paging(QueryParams):
    var limit: Int
    var verbose: Bool


@fieldwise_init
struct NewUser(JsonBody):
    var name: String
    var score: Float64


@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String
    var org: String


@fieldwise_init
struct AppState(State):
    var db_name: String
    var hits: Int


def get_user(req: Request, path: UserPath, state: AppState) raises -> User:
    return User(path.id, String("user-", path.id), path.org)


def list_users(req: Request, path: UserPath, q: Paging, state: AppState) raises -> Response:
    var body = String("db=", state.db_name, " org=", path.org, " limit=", q.limit, " verbose=", q.verbose)
    return text(body)


def create_user(req: Request, path: OrgPath, q: Paging, body: NewUser, state: AppState) raises -> User:
    return User(q.limit, body.name, path.org)


def health(req: Request) raises -> Response:
    return text("ok")


def main() raises:
    var app = App(state=AppState("people", 0))
    app.get["/orgs/{org}/users/{id}"](get_user)
    app.get["/orgs/{org}/users/{id}/all"](list_users)
    app.post["/orgs/{org}/users"](create_user)
    app.get["/health"](health)

    var requests = List[Request]()
    requests.append(Request("GET", "/health", "", ""))
    requests.append(Request("GET", "/orgs/acme/users/7", "", ""))
    requests.append(Request("GET", "/orgs/acme/users/7/all", "limit=5&verbose=true", ""))
    requests.append(Request("POST", "/orgs/acme/users", "limit=3&verbose=false", '{"name": "ada", "score": 1.5}'))
    requests.append(Request("GET", "/orgs/acme/users/x", "", ""))
    requests.append(Request("GET", "/orgs/acme/users/7/all", "limit=abc&verbose=true", ""))
    requests.append(Request("GET", "/orgs/acme/users/7/all", "verbose=true", ""))
    requests.append(Request("POST", "/orgs/acme/users", "limit=3&verbose=false", '{"name": "ada"}'))
    requests.append(Request("GET", "/nope", "", ""))
    for req in requests:
        var resp = app.dispatch(req.copy())
        print(req.method, req.path, req.query, "->", resp.status, resp.content_type, resp.body)

"""P6 failing case: two JsonBody arguments. Must not compile.

Run: pixi run mojo -I . -I research/app-api-probes research/app-api-probes/p6_fail_two_bodies.mojo
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
struct NewUser(JsonBody):
    var name: String


@fieldwise_init
struct Other(Movable):
    var x: Int


@fieldwise_init
struct AppState(State):
    var db_name: String


@fieldwise_init
struct OtherState(State):
    var n: Int


@fieldwise_init
struct Out(Movable):
    var id: Int

struct Second(JsonBody):
    var y: Int

    def __init__(out self, y: Int):
        self.y = y


def two(req: Request, a: NewUser, b: Second) raises -> Out:
    return Out(1)


def main():
    var app = App()
    app.post["/two"](two)

"""P6 failing case: handler wants state on an App without state. Must not compile.

Run: pixi run mojo -I . -I research/app-api-probes research/app-api-probes/p6_fail_no_state.mojo
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

def st(req: Request, s: AppState) raises -> Out:
    return Out(1)


def main():
    var app = App()
    app.get["/st"](st)

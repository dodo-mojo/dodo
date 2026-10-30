"""P7: two ways to attach middleware to an App, on the real dodo types.

Run: pixi run mojo -I . research/app-api-probes/p7_middleware.mojo

Form A wraps the whole app in the stock generic middleware: the App stays one
type and the wrappers are checked and dispatched statically.
Form B keeps a boxed chain inside the App: `app.use(m)` needs no new type, at
the cost of one indirect call per layer.
"""

from std.memory import ArcPointer, Layout
from std.memory.alloc import alloc
from std.time import perf_counter_ns

from dodo.http import Handler, Request, Response, Method, ok
from dodo.http.middleware import RequestId


struct App(Movable):
    """Stand-in for the App: one route, and state that must not be copied."""

    var hits_per_request: Int

    def __init__(out self):
        self.hits_per_request = 1

    def dispatch(self, req: Request) raises -> Response:
        return ok("hello")


@fieldwise_init
struct AppHandler(Copyable, Handler):
    """Form A: a cheap Copyable handle, because stock middleware wants Copyable."""

    var app: ArcPointer[App]

    def serve(self, req: Request) raises -> Response:
        return self.app[].dispatch(req)


# Form B: a middleware is a boxed struct plus a thin thunk.


trait Middleware(Movable):
    def handle(self, req: Request, next: Next) raises -> Response:
        ...


struct Next:
    """The rest of the chain: the next layer's index, then the app."""

    var chain: Pointer[Chain, MutUntrackedOrigin]
    var index: Int

    def __init__(out self, chain: Pointer[Chain, MutUntrackedOrigin], index: Int):
        self.chain = chain
        self.index = index

    def run(self, req: Request) raises -> Response:
        return self.chain[].run_from(self.index, req)


@fieldwise_init
struct Layer(Copyable):
    var box: Int
    var thunk: def(Int, Request, Next) raises thin -> Response


def layer_thunk[M: Middleware](box: Int, req: Request, next: Next) raises -> Response:
    var ptr = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=box).unsafe_bitcast[M]()
    return ptr[].handle(req, next)


struct Chain(Movable):
    var layers: List[Layer]
    var app: App

    def __init__(out self, var app: App):
        self.layers = List[Layer]()
        self.app = app^

    def use[M: Middleware](mut self, var middleware: M):
        var box = alloc(Layout[M](count=1)).unsafe_leak()
        box.unsafe_write(middleware^)
        self.layers.append(Layer(Int(box), layer_thunk[M]))

    def run_from(mut self, index: Int, req: Request) raises -> Response:
        if index == len(self.layers):
            return self.app.dispatch(req)
        var self_ptr = Pointer[Chain, MutUntrackedOrigin](unsafe_from_address=Int(Pointer(to=self)))
        var layer = self.layers[index].copy()
        return layer.thunk(layer.box, req, Next(self_ptr, index + 1))


@fieldwise_init
struct PassThrough(Middleware):
    var tag: Int

    def handle(self, req: Request, next: Next) raises -> Response:
        return next.run(req)


struct PassThroughWrap[Inner: Handler & Copyable](Copyable, Handler):
    """Form A's equivalent of PassThrough, for a fair timing."""

    var inner: Self.Inner

    def __init__(out self, var inner: Self.Inner):
        self.inner = inner^

    def serve(self, req: Request) raises -> Response:
        return self.inner.serve(req).lower()


def time_handler[H: Handler](handler: H, name: String, rounds: Int) raises:
    var req = Request(method=Method.GET, url="/")
    var start = perf_counter_ns()
    for _ in range(rounds):
        _ = handler.serve(req)
    print(name, Int(perf_counter_ns() - start) / rounds, "ns per request")


def main() raises:
    var rounds = 2000000
    var shared = ArcPointer(App())

    var bare = AppHandler(shared.copy())
    time_handler(bare, "bare app:           ", rounds)

    var wrapped = PassThroughWrap(PassThroughWrap(PassThroughWrap(AppHandler(shared.copy()))))
    time_handler(wrapped, "A, 3 wrappers:      ", rounds)

    var stock = RequestId(AppHandler(shared.copy()))
    var resp = stock.serve(Request(method=Method.GET, url="/"))
    print("A, stock RequestId around the app: status", resp.status)

    var chain = Chain(App())
    chain.use(PassThrough(1))
    chain.use(PassThrough(2))
    chain.use(PassThrough(3))
    var req = Request(method=Method.GET, url="/")
    var start = perf_counter_ns()
    for _ in range(rounds):
        _ = chain.run_from(0, req)
    print("B, 3 boxed layers:  ", Int(perf_counter_ns() - start) / rounds, "ns per request")

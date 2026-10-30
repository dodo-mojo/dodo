"""P2: one App.get that accepts handlers with different signatures.

Works: overloads on function types (A), a generic function-typed
parameter checked with comptime if (B), a registry that stores both
signatures in one List through a Handler trait (C), and the function
type of a handler compared at comptime (D).
"""


struct Request:
    var path: String

    def __init__(out self, path: String):
        self.path = path


struct Response:
    var body: String

    def __init__(out self, body: String):
        self.body = body


struct Model(Copyable):
    var name: String

    def __init__(out self, name: String):
        self.name = name


def hello(req: Request) raises -> Response:
    return Response(String("hello ", req.path))


def chat(req: Request, llm: Model) raises -> Response:
    return Response(String("chat with ", llm.name, " on ", req.path))


comptime PlainFn = def(Request) raises thin -> Response
comptime StateFn = def(Request, Model) raises thin -> Response


trait Handler(Movable):
    def serve(self, req: Request) raises -> Response:
        ...


struct PlainHandler(Handler):
    var f: PlainFn

    def __init__(out self, f: PlainFn):
        self.f = f

    def serve(self, req: Request) raises -> Response:
        return self.f(req)


struct StateHandler(Handler):
    var f: StateFn
    var state: Model

    def __init__(out self, f: StateFn, var state: Model):
        self.f = f
        self.state = state^

    def serve(self, req: Request) raises -> Response:
        return self.f(req, self.state)


struct App:
    var plain: List[PlainHandler]
    var stateful: List[StateHandler]

    def __init__(out self):
        self.plain = List[PlainHandler]()
        self.stateful = List[StateHandler]()

    # A: overloads, one per signature.
    def get(mut self, path: String, handler: PlainFn):
        self.plain.append(PlainHandler(handler))

    def get(mut self, path: String, handler: StateFn, var state: Model):
        self.stateful.append(StateHandler(handler, state^))


def main() raises:
    var all = List[Handler]()

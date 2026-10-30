"""P2: one App.get that accepts handlers with different signatures.

Works: overloads on function types (A) and one generic entry point that
compares the function type at comptime (B). Each signature lives in its
own typed List; a single List of mixed handlers needs the type erasure
dodo/http/router.mojo already does (see handlers_fail_trait_list.mojo).
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

    # B: one generic entry point; the function type is a type parameter.
    def get_any[F: ImplicitlyCopyable](mut self, path: String, handler: F):
        comptime if F == PlainFn:
            self.plain.append(PlainHandler(rebind[PlainFn](handler)))
        else:
            comptime assert False, "handler must be def(Request) raises -> Response"


def main() raises:
    var app = App()
    app.get("/hello", hello)
    app.get("/chat", chat, Model("m1"))
    app.get_any("/hello2", hello)
    print(app.plain[0].serve(Request("/x")).body)
    print(app.plain[1].serve(Request("/x")).body)
    print(app.stateful[0].serve(Request("/y")).body)

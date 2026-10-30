"""P2b: App.get deduces the state type from the handler's second argument."""


struct Request:
    var path: String

    def __init__(out self, path: String):
        self.path = path


struct Response:
    var body: String

    def __init__(out self, body: String):
        self.body = body


struct Model(Movable):
    var name: String

    def __init__(out self, name: String):
        self.name = name


struct Counter(Movable):
    var hits: Int

    def __init__(out self):
        self.hits = 0


def chat(req: Request, llm: Model) raises -> Response:
    return Response(String("chat with ", llm.name))


def count(req: Request, counter: Counter) raises -> Response:
    return Response(String("hits ", counter.hits))


struct App:
    var routes: Int

    def __init__(out self):
        self.routes = 0

    def get[S: Movable & Deinitable](
        mut self,
        path: String,
        handler: def(Request, S) raises thin -> Response,
        var state: S,
    ):
        comptime state_name = reflect[S].name()
        print("route", path, "state type", state_name)


def main() raises:
    var app = App()
    app.get("/chat", chat, Model("m1"))
    app.get("/count", count, Model("wrong"))

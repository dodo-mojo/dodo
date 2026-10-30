"""P3: route paths as compile-time parameters, parsed and checked at comptime.

`app.get["/hello/{name}"](hello)` parses the path while compiling. A
malformed path fails the build with the parser's own message. The param
names in the path are compared with the fields of the handler's params
struct, so a typo in either place fails the build too.
"""


struct Request:
    var path: String

    def __init__(out self, path: String):
        self.path = path


struct Response:
    var body: String

    def __init__(out self, body: String):
        self.body = body


@fieldwise_init
struct HelloParams:
    var name: String


def hello(req: Request, params: HelloParams) raises -> Response:
    return Response(String("hello ", params.name))


@fieldwise_init
struct ParsedPath(Copyable):
    var names: List[String]
    var error: String


def parse_path(path: String) -> ParsedPath:
    """Collect the `{name}` params of a route path, or describe what is wrong."""
    var names = List[String]()
    if path.byte_length() == 0:
        return ParsedPath(names^, String("route path is empty"))
    if path.as_bytes()[0] != UInt8(ord("/")):
        return ParsedPath(names^, String("route path must start with /"))

    var current = String("")
    var inside = False
    for byte in path.as_bytes():
        if byte == UInt8(ord("{")):
            if inside:
                return ParsedPath(names^, String("nested { in route path"))
            inside = True
            current = String("")
        elif byte == UInt8(ord("}")):
            if not inside:
                return ParsedPath(names^, String("} without { in route path"))
            if current.byte_length() == 0:
                return ParsedPath(names^, String("empty param name {} in route path"))
            for seen in names:
                if seen == current:
                    return ParsedPath(names^, String("duplicate param name in route path"))
            names.append(current)
            inside = False
        elif inside:
            current += chr(Int(byte))

    if inside:
        return ParsedPath(names^, String("unclosed { in route path"))
    return ParsedPath(names^, String(""))


def check_params_match[P: AnyType](path_names: List[String]) -> String:
    """Return an error text unless P has exactly one field per path param."""
    comptime field_count = reflect[P].field_count()
    comptime field_names = reflect[P].field_names()
    if len(path_names) != field_count:
        return String("path param count differs from handler params field count")
    for name in path_names:
        var found = False
        comptime for i in range(field_count):
            comptime field_name = field_names[i]
            if String(field_name) == name:
                found = True
        if not found:
            return String("path param has no matching field in the handler params struct")
    return String("")


struct App:
    var count: Int

    def __init__(out self):
        self.count = 0

    def get[path: String, P: AnyType](
        mut self, handler: def(Request, P) raises thin -> Response
    ):
        comptime parsed = parse_path(path)
        comptime assert parsed.error.byte_length() == 0, parsed.error
        comptime mismatch = check_params_match[P](parsed.names)
        comptime assert mismatch.byte_length() == 0, mismatch
        self.count += 1


def main():
    var app = App()
    app.get["/hello/{name}"](hello)
    print("registered", app.count)

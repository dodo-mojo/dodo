"""P6 library: typed handlers with stand-in Request and Response.

Shared by p6_typed_handlers.mojo and the p6_fail_*.mojo cases. Run those with
`pixi run mojo -I . -I research/app-api-probes research/app-api-probes/<file>.mojo`.
"""

from std.collections import Dict
from std.memory import Layout, MaybeUninit, Pointer
from std.memory.alloc import alloc


# ---------------------------------------------------------------------------
# Stand-in HTTP types
# ---------------------------------------------------------------------------


struct Request(Copyable):
    var method: String
    var path: String
    var query: String
    var body: String

    def __init__(out self, method: String, path: String, query: String, body: String):
        self.method = method
        self.path = path
        self.query = query
        self.body = body


struct Response(Copyable):
    var status: Int
    var content_type: String
    var body: String

    def __init__(out self, status: Int, content_type: String, body: String):
        self.status = status
        self.content_type = content_type
        self.body = body


def text(body: String) -> Response:
    return Response(200, "text/plain", body)


# ---------------------------------------------------------------------------
# Marker traits
# ---------------------------------------------------------------------------


trait PathParams(Movable):
    pass


trait QueryParams(Movable):
    pass


trait JsonBody(Movable):
    pass


trait State(Movable):
    pass


struct NoState(Movable):
    def __init__(out self):
        pass


# ---------------------------------------------------------------------------
# Text to value conversion
# ---------------------------------------------------------------------------


def parse_int(text: String, field: String) raises -> Int:
    try:
        return Int(text)
    except:
        raise Error("field '", field, "': expected Int, got '", text, "'")


def parse_float(text: String, field: String) raises -> Float64:
    try:
        return Float64(text)
    except:
        raise Error("field '", field, "': expected Float64, got '", text, "'")


def parse_bool(text: String, field: String) raises -> Bool:
    if text == "true":
        return True
    if text == "false":
        return False
    raise Error("field '", field, "': expected Bool, got '", text, "'")


def split_pairs(query: String) -> Dict[String, String]:
    """Turn `a=1&b=2` into a Dict."""
    var pairs = Dict[String, String]()
    if query.byte_length() == 0:
        return pairs^
    for pair in query.split("&"):
        var parts = String(pair).split("=")
        if len(parts) == 2:
            pairs[String(parts[0])] = String(parts[1])
    return pairs^


def json_flat_object(body: String) raises -> Dict[String, String]:
    """Stand-in JSON reader: one flat object of string, number and bool values."""
    var values = Dict[String, String]()
    var text = String(body.strip())
    if not text.startswith("{") or not text.endswith("}"):
        raise Error("body: expected a JSON object")
    var inner = String(text[byte = 1 : text.byte_length() - 1])
    if inner.byte_length() == 0:
        return values^
    for pair in inner.split(","):
        var parts = String(pair).split(":")
        if len(parts) != 2:
            raise Error("body: malformed JSON member '", String(pair), "'")
        var key = String(String(parts[0]).strip()).replace('"', "")
        var raw = String(String(parts[1]).strip())
        values[key] = raw.replace('"', "")
    return values^


# ---------------------------------------------------------------------------
# Reflection: fill a struct from a Dict, write a struct as JSON
# ---------------------------------------------------------------------------


def write_field[
    T: AnyType, po: MutOrigin
](ptr: Pointer[T, po], values: Dict[String, String], name: String) raises:
    """Convert one text value and write it into the field slot."""
    if name not in values:
        raise Error("missing field '", name, "'")
    var raw = values[name]
    comptime if T == String:
        ptr.unsafe_bitcast[String]().unsafe_write(raw)
    elif T == Int:
        ptr.unsafe_bitcast[Int]().unsafe_write(parse_int(raw, name))
    elif T == Bool:
        ptr.unsafe_bitcast[Bool]().unsafe_write(parse_bool(raw, name))
    elif T == Float64:
        ptr.unsafe_bitcast[Float64]().unsafe_write(parse_float(raw, name))
    else:
        comptime assert False, "unsupported field type " + reflect[T].name()


def destroy_written[T: AnyType](mut target: T, written: Int):
    """Drop the String fields already written when a later field failed."""
    comptime types = reflect[T].field_types()
    comptime for i in range(reflect[T].field_count()):
        comptime field_type = types[i]
        comptime if field_type == String:
            if i < written:
                ref field = reflect[T].field_ref[i](target)
                Pointer(to=field).unsafe_bitcast[String]().unsafe_deinit_pointee()


def fill_struct[T: Movable](values: Dict[String, String]) raises -> T:
    """Build a T from named text values. Fields are written once, in place."""
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()
    var slot = MaybeUninit[T]()
    ref target = slot.unsafe_assume_init()
    var written = 0
    comptime for i in range(count):
        comptime field_name = names[i]
        comptime field_type = types[i]
        ref field = reflect[T].field_ref[i](target)
        var ptr = Pointer(to=field).unsafe_bitcast[field_type]()
        try:
            write_field[field_type](ptr, values, String(field_name))
        except e:
            destroy_written[T](target, written)
            slot^.unsafe_forget()
            raise e^
        written += 1
    return slot^.unsafe_assume_init()


def write_json_value[T: AnyType](value: T) -> String:
    comptime if T == String:
        return String('"', rebind[String](value), '"')
    elif T == Int:
        return String(rebind[Int](value))
    elif T == Bool:
        return String(rebind[Bool](value))
    elif T == Float64:
        return String(rebind[Float64](value))
    elif reflect[T].is_struct():
        return struct_to_json[T](value)
    else:
        comptime assert False, "cannot serialize " + reflect[T].name()


def struct_to_json[T: AnyType](value: T) -> String:
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()
    var out = String("{")
    comptime for i in range(count):
        comptime if i > 0:
            out += ","
        comptime field_name = names[i]
        comptime field_type = types[i]
        ref field = reflect[T].field_ref[i](value)
        out += String('"', field_name, '":')
        out += write_json_value[field_type](rebind[field_type](field))
    out += "}"
    return out^


# ---------------------------------------------------------------------------
# Return type: Response passes through, anything else becomes JSON
# ---------------------------------------------------------------------------


def to_response[R: AnyType](value: R) -> Response:
    comptime if R == Response:
        return rebind[Response](value).copy()
    else:
        return Response(200, "application/json", struct_to_json[R](value))


# ---------------------------------------------------------------------------
# Compile-time route checks
# ---------------------------------------------------------------------------


comptime ROLE_PATH = 0
comptime ROLE_QUERY = 1
comptime ROLE_BODY = 2
comptime ROLE_STATE = 3
comptime ROLE_NONE = 4
comptime ROLE_UNUSED = 5


def role_of[A: AnyType]() -> Int:
    comptime if conforms_to(A, PathParams):
        return ROLE_PATH
    elif conforms_to(A, QueryParams):
        return ROLE_QUERY
    elif conforms_to(A, JsonBody):
        return ROLE_BODY
    elif conforms_to(A, State):
        return ROLE_STATE
    else:
        return ROLE_NONE


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


def has_field[P: AnyType](name: String) -> Bool:
    comptime count = reflect[P].field_count()
    comptime names = reflect[P].field_names()
    var found = False
    comptime for i in range(count):
        comptime field_name = names[i]
        if String(field_name) == name:
            found = True
    return found


def path_struct_error[P: AnyType](path: String, path_names: List[String]) -> String:
    """Name the first mismatch between the route's {params} and P's fields."""
    var prefix = String("route ", path, ": ")
    for name in path_names:
        if not has_field[P](name):
            return String(prefix, "path param {", name, "} has no field in ", reflect[P].name())
    comptime count = reflect[P].field_count()
    comptime names = reflect[P].field_names()
    comptime for i in range(count):
        comptime field_name = names[i]
        var matched = False
        for name in path_names:
            if name == String(field_name):
                matched = True
        if not matched:
            return String(prefix, "field '", field_name, "' of ", reflect[P].name(), " has no {", field_name, "} in the path")
    return String("")


def arg_error[A: AnyType, S: AnyType](path: String, role: Int) -> String:
    """Errors that depend on one argument and the App's state type."""
    var prefix = String("route ", path, ": ")
    if role == ROLE_NONE:
        return String(prefix, "argument type ", reflect[A].name(), " has none of PathParams, QueryParams, JsonBody, State")
    if role == ROLE_STATE:
        comptime if S == NoState:
            return String(prefix, "handler takes state ", reflect[A].name(), " but the App was created without state")
        elif A != S:
            return String(prefix, "state argument is ", reflect[A].name(), " but the App state is ", reflect[S].name())
    return String("")


def role_name(role: Int) -> String:
    if role == ROLE_PATH:
        return String("PathParams")
    if role == ROLE_QUERY:
        return String("QueryParams")
    if role == ROLE_BODY:
        return String("JsonBody")
    return String("State")


def duplicate_role_error(path: String, roles: List[Int]) -> String:
    for i in range(len(roles)):
        for j in range(i + 1, len(roles)):
            if roles[i] == roles[j] and roles[i] < ROLE_NONE:
                return String("route ", path, ": two arguments are ", role_name(roles[i]), " (arguments ", i + 1, " and ", j + 1, ")")
    return String("")


def path_check[A: AnyType](path: String, role: Int) -> String:
    """If A is the path struct, compare its fields with the path params."""
    if role != ROLE_PATH:
        return String("")
    var parsed = parse_path(path)
    return path_struct_error[A](path, parsed.names)


def no_path_struct_error(path: String, roles: List[Int]) -> String:
    """A path with {params} needs one PathParams argument."""
    var parsed = parse_path(path)
    if len(parsed.names) == 0:
        return String("")
    for role in roles:
        if role == ROLE_PATH:
            return String("")
    return String("route ", path, ": path has {", parsed.names[0], "} but the handler has no PathParams argument")


# ---------------------------------------------------------------------------
# Boxed handlers and thunks
# ---------------------------------------------------------------------------


def box_move[T: Movable](var value: T) -> Int:
    var p = alloc(Layout[T](count=1)).unsafe_leak()
    p.unsafe_write(value^)
    return Int(p)


def box_ptr[T: AnyType](addr: Int) -> Pointer[T, MutUntrackedOrigin]:
    return Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr).unsafe_bitcast[T]()


# ---------------------------------------------------------------------------
# Per-request context and argument holders
# ---------------------------------------------------------------------------


struct Ctx:
    var req: Request
    var path_values: Dict[String, String]
    var state_addr: Int

    def __init__(out self, var req: Request, var path_values: Dict[String, String], state_addr: Int):
        self.req = req^
        self.path_values = path_values^
        self.state_addr = state_addr


struct Arg[A: Movable & Deinitable]:
    """One handler argument: an owned value built per request, or a borrowed state."""

    var owned: Optional[Self.A]
    var shared_addr: Int

    def __init__(out self):
        self.owned = None
        self.shared_addr = 0

    def load[role: Int](mut self, ctx: Ctx) raises:
        comptime if role == ROLE_PATH:
            self.owned = fill_struct[Self.A](ctx.path_values)
        elif role == ROLE_QUERY:
            self.owned = fill_struct[Self.A](split_pairs(ctx.req.query))
        elif role == ROLE_BODY:
            self.owned = fill_struct[Self.A](json_flat_object(ctx.req.body))
        else:
            self.shared_addr = ctx.state_addr

    def ptr(mut self) -> Pointer[Self.A, MutUntrackedOrigin]:
        if self.owned:
            return Pointer(to=self.owned.unsafe_value()).unsafe_origin_cast[MutUntrackedOrigin]()
        return box_ptr[Self.A](self.shared_addr)
# ---------------------------------------------------------------------------
# Route checks shared by every arity
# ---------------------------------------------------------------------------


def check_path[path: String]():
    comptime parsed = parse_path(path)
    comptime assert parsed.error.byte_length() == 0, String("route ", path, ": ", parsed.error)


def check_arg[path: String, S: AnyType, A: AnyType]():
    comptime role = role_of[A]()
    comptime shape = arg_error[A, S](path, role)
    comptime assert shape.byte_length() == 0, shape
    comptime fields = path_check[A](path, role)
    comptime assert fields.byte_length() == 0, fields


def check_roles[path: String, roles: List[Int]]():
    comptime duplicate = duplicate_role_error(path, roles)
    comptime assert duplicate.byte_length() == 0, duplicate
    comptime missing = no_path_struct_error(path, roles)
    comptime assert missing.byte_length() == 0, missing


# ---------------------------------------------------------------------------
# One thunk per arity: build each argument, call the handler, make a Response
# ---------------------------------------------------------------------------


def thunk0[R: Movable & Deinitable](handler_addr: Int, ctx: Ctx) raises -> Response:
    ref handler = box_ptr[def(Request) raises thin -> R](handler_addr)[]
    var result = handler(ctx.req)
    return to_response[R](result)


def thunk1[R: Movable & Deinitable, A0: Movable & Deinitable](handler_addr: Int, ctx: Ctx) raises -> Response:
    var a0 = Arg[A0]()
    a0.load[role_of[A0]()](ctx)
    ref handler = box_ptr[def(Request, A0) raises thin -> R](handler_addr)[]
    var result = handler(ctx.req, a0.ptr()[])
    return to_response[R](result)


def thunk2[R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable](handler_addr: Int, ctx: Ctx) raises -> Response:
    var a0 = Arg[A0]()
    a0.load[role_of[A0]()](ctx)
    var a1 = Arg[A1]()
    a1.load[role_of[A1]()](ctx)
    ref handler = box_ptr[def(Request, A0, A1) raises thin -> R](handler_addr)[]
    var result = handler(ctx.req, a0.ptr()[], a1.ptr()[])
    return to_response[R](result)


def thunk3[R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable](handler_addr: Int, ctx: Ctx) raises -> Response:
    var a0 = Arg[A0]()
    a0.load[role_of[A0]()](ctx)
    var a1 = Arg[A1]()
    a1.load[role_of[A1]()](ctx)
    var a2 = Arg[A2]()
    a2.load[role_of[A2]()](ctx)
    ref handler = box_ptr[def(Request, A0, A1, A2) raises thin -> R](handler_addr)[]
    var result = handler(ctx.req, a0.ptr()[], a1.ptr()[], a2.ptr()[])
    return to_response[R](result)


def thunk4[R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable](handler_addr: Int, ctx: Ctx) raises -> Response:
    var a0 = Arg[A0]()
    a0.load[role_of[A0]()](ctx)
    var a1 = Arg[A1]()
    a1.load[role_of[A1]()](ctx)
    var a2 = Arg[A2]()
    a2.load[role_of[A2]()](ctx)
    var a3 = Arg[A3]()
    a3.load[role_of[A3]()](ctx)
    ref handler = box_ptr[def(Request, A0, A1, A2, A3) raises thin -> R](handler_addr)[]
    var result = handler(ctx.req, a0.ptr()[], a1.ptr()[], a2.ptr()[], a3.ptr()[])
    return to_response[R](result)


def thunk5[R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable](handler_addr: Int, ctx: Ctx) raises -> Response:
    var a0 = Arg[A0]()
    a0.load[role_of[A0]()](ctx)
    var a1 = Arg[A1]()
    a1.load[role_of[A1]()](ctx)
    var a2 = Arg[A2]()
    a2.load[role_of[A2]()](ctx)
    var a3 = Arg[A3]()
    a3.load[role_of[A3]()](ctx)
    var a4 = Arg[A4]()
    a4.load[role_of[A4]()](ctx)
    ref handler = box_ptr[def(Request, A0, A1, A2, A3, A4) raises thin -> R](handler_addr)[]
    var result = handler(ctx.req, a0.ptr()[], a1.ptr()[], a2.ptr()[], a3.ptr()[], a4.ptr()[])
    return to_response[R](result)


# ---------------------------------------------------------------------------
# Router pieces
# ---------------------------------------------------------------------------


def match_path(pattern: String, actual: String, mut values: Dict[String, String]) -> Bool:
    """Match `/orgs/{org}/users` against `/orgs/acme/users`, collecting params."""
    var pattern_parts = pattern.split("/")
    var actual_parts = actual.split("/")
    if len(pattern_parts) != len(actual_parts):
        return False
    for i in range(len(pattern_parts)):
        var want = String(pattern_parts[i])
        var got = String(actual_parts[i])
        if want.startswith("{") and want.endswith("}"):
            var name = String(want[byte = 1 : want.byte_length() - 1])
            values[name] = got
        elif want != got:
            return False
    return True


struct Route(Copyable):
    var method: String
    var pattern: String
    var handler_addr: Int
    var thunk: def(Int, Ctx) raises thin -> Response

    def __init__(out self, method: String, pattern: String, handler_addr: Int, thunk: def(Int, Ctx) raises thin -> Response):
        self.method = method
        self.pattern = pattern
        self.handler_addr = handler_addr
        self.thunk = thunk


struct App[S: Movable & Deinitable = NoState]:
    var state_addr: Int
    var routes: List[Route]

    def __init__(out self):
        comptime assert Self.S == NoState, "App() has no state: use App(state=...)"
        self.state_addr = box_move(NoState())
        self.routes = List[Route]()

    def __init__(out self, *, var state: Self.S):
        self.state_addr = box_move(state^)
        self.routes = List[Route]()

    def __deinit__(deinit self):
        for route in self.routes:
            Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=route.handler_addr).unsafe_free()
        var state = box_ptr[Self.S](self.state_addr)
        state.unsafe_deinit_pointee()
        state.unsafe_bitcast[UInt8]().unsafe_free()

    def add[F: Movable](mut self, method: String, pattern: String, var handler: F, thunk: def(Int, Ctx) raises thin -> Response):
        self.routes.append(Route(method, pattern, box_move(handler^), thunk))

    def dispatch(self, var req: Request) -> Response:
        for route in self.routes:
            if route.method != req.method:
                continue
            var values = Dict[String, String]()
            if not match_path(route.pattern, req.path, values):
                continue
            var ctx = Ctx(req^, values^, self.state_addr)
            try:
                return route.thunk(route.handler_addr, ctx)
            except e:
                return Response(400, "application/problem+json", String('{"detail":"', e, '"}'))
        return Response(404, "text/plain", "not found")

    def get[path: String, R: Movable & Deinitable](mut self, handler: def(Request) raises thin -> R):
        check_path[path]()
        comptime roles = List[Int]()
        check_roles[path, roles]()
        self.add("GET", path, handler, thunk0[R])

    def post[path: String, R: Movable & Deinitable](mut self, handler: def(Request) raises thin -> R):
        check_path[path]()
        comptime roles = List[Int]()
        check_roles[path, roles]()
        self.add("POST", path, handler, thunk0[R])

    def get[path: String, R: Movable & Deinitable, A0: Movable & Deinitable](mut self, handler: def(Request, A0) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        comptime roles: List[Int] = [role_of[A0]()]
        check_roles[path, roles]()
        self.add("GET", path, handler, thunk1[R, A0])

    def post[path: String, R: Movable & Deinitable, A0: Movable & Deinitable](mut self, handler: def(Request, A0) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        comptime roles: List[Int] = [role_of[A0]()]
        check_roles[path, roles]()
        self.add("POST", path, handler, thunk1[R, A0])

    def get[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable](mut self, handler: def(Request, A0, A1) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1]()]
        check_roles[path, roles]()
        self.add("GET", path, handler, thunk2[R, A0, A1])

    def post[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable](mut self, handler: def(Request, A0, A1) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1]()]
        check_roles[path, roles]()
        self.add("POST", path, handler, thunk2[R, A0, A1])

    def get[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable](mut self, handler: def(Request, A0, A1, A2) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        check_arg[path, Self.S, A2]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1](), role_of[A2]()]
        check_roles[path, roles]()
        self.add("GET", path, handler, thunk3[R, A0, A1, A2])

    def post[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable](mut self, handler: def(Request, A0, A1, A2) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        check_arg[path, Self.S, A2]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1](), role_of[A2]()]
        check_roles[path, roles]()
        self.add("POST", path, handler, thunk3[R, A0, A1, A2])

    def get[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        check_arg[path, Self.S, A2]()
        check_arg[path, Self.S, A3]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1](), role_of[A2](), role_of[A3]()]
        check_roles[path, roles]()
        self.add("GET", path, handler, thunk4[R, A0, A1, A2, A3])

    def post[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        check_arg[path, Self.S, A2]()
        check_arg[path, Self.S, A3]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1](), role_of[A2](), role_of[A3]()]
        check_roles[path, roles]()
        self.add("POST", path, handler, thunk4[R, A0, A1, A2, A3])

    def get[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable](mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        check_arg[path, Self.S, A2]()
        check_arg[path, Self.S, A3]()
        check_arg[path, Self.S, A4]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1](), role_of[A2](), role_of[A3](), role_of[A4]()]
        check_roles[path, roles]()
        self.add("GET", path, handler, thunk5[R, A0, A1, A2, A3, A4])

    def post[path: String, R: Movable & Deinitable, A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable](mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R):
        check_path[path]()
        check_arg[path, Self.S, A0]()
        check_arg[path, Self.S, A1]()
        check_arg[path, Self.S, A2]()
        check_arg[path, Self.S, A3]()
        check_arg[path, Self.S, A4]()
        comptime roles: List[Int] = [role_of[A0](), role_of[A1](), role_of[A2](), role_of[A3](), role_of[A4]()]
        check_roles[path, roles]()
        self.add("POST", path, handler, thunk5[R, A0, A1, A2, A3, A4])

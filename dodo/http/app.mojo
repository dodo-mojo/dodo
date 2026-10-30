"""The App: one front door for routes, typed handlers, state and serving.

```mojo
from dodo import App, AppState, PathParams, Request

@fieldwise_init
struct Db(AppState):
    var name: String

@fieldwise_init
struct UserPath(PathParams):
    var id: Int

@fieldwise_init
struct User(Movable):
    var id: Int
    var db: String

def get_user(req: Request, path: UserPath, db: Db) raises -> User:
    return User(path.id, db.name)

def main() raises:
    var app = App(state=Db("people"))
    app.get["/users/{id}"](get_user)
    app.serve(port=8080)
```

A handler takes `Request` plus up to five typed arguments, each recognized by
its marker trait, and returns a `Response` or a struct sent as 200 JSON. Route
and signature mistakes fail the build. See ADR-0008.
"""

from std.collections import Optional
from std.memory import ArcPointer, MaybeUninit, Pointer

from ..json.reflection import deserialize_json
from ..json.serialize import to_json_string
from ..net import IpAddr, SocketAddr
from ..runtime._thread import num_cpus
from ._route_path import SEG_LITERAL, parse_route_path
from ._server.responses import ok_json_of
from .handler import Handler
from .request import Method, Request
from .response import Response
from .router import Router
from .server import HttpServer
from .status_reason import status_reason


comptime _ArgType = Movable & Deinitable


trait PathParams(Deinitable, Movable):
    """A struct filled from the route's `{name}` params, field by field."""

    pass


trait QueryParams(Deinitable, Movable):
    """A struct filled from the query string. `Optional` fields may be absent.
    """

    pass


trait JsonBody(Deinitable, Movable):
    """A struct read from the JSON request body."""

    pass


trait AppState(Deinitable, Movable):
    """The app state: built once, then shared read-only by every worker."""

    pass


struct NoState(AppState):
    """The state of an `App` created without one."""

    def __init__(out self):
        pass


# Problem responses (RFC 9457)


def _problem(status: Int, detail: String) -> Response:
    var title = status_reason(status)
    var body = String(
        '{"type":"about:blank","title":',
        to_json_string(title),
        ',"status":',
        status,
        ',"detail":',
        to_json_string(detail),
        "}",
    )
    var resp = Response(
        status=status, reason=title, body=List[UInt8](body.as_bytes())
    )
    try:
        resp.headers.set("Content-Type", "application/problem+json")
    except:
        pass
    return resp^


def _handler_failed(req: Request, error: Error) -> Response:
    if req.expose_errors:
        return _problem(500, String(error))
    return _problem(500, "Internal Server Error")


# Text to value


def _hex_value(byte: UInt8) -> Int:
    """The value of one hex digit, or -1."""
    var c = Int(byte)
    if c >= ord("0") and c <= ord("9"):
        return c - ord("0")
    if c >= ord("a") and c <= ord("f"):
        return c - ord("a") + 10
    if c >= ord("A") and c <= ord("F"):
        return c - ord("A") + 10
    return -1


def _percent_decode(text: String, plus_is_space: Bool) raises -> String:
    var bytes = text.as_bytes()
    var decoded = List[UInt8](capacity=len(bytes))
    var i = 0
    while i < len(bytes):
        var byte = bytes[i]
        if byte == UInt8(ord("+")) and plus_is_space:
            decoded.append(UInt8(ord(" ")))
            i += 1
        elif byte == UInt8(ord("%")):
            if i + 2 >= len(bytes):
                raise Error("bad percent escape in '", text, "'")
            var high = _hex_value(bytes[i + 1])
            var low = _hex_value(bytes[i + 2])
            if high < 0 or low < 0:
                raise Error("bad percent escape in '", text, "'")
            decoded.append(UInt8(high * 16 + low))
            i += 3
        else:
            decoded.append(byte)
            i += 1
    return String(from_utf8=decoded)


def _parse_int(text: String, name: String) raises -> Int:
    try:
        return Int(text)
    except:
        raise Error("field '", name, "': expected Int, got '", text, "'")


def _parse_float(text: String, name: String) raises -> Float64:
    try:
        return Float64(text)
    except:
        raise Error("field '", name, "': expected Float64, got '", text, "'")


def _parse_bool(text: String, name: String) raises -> Bool:
    if text == "true":
        return True
    if text == "false":
        return False
    raise Error("field '", name, "': expected Bool, got '", text, "'")


def _text_of[
    from_path: Bool
](req: Request, name: String) raises -> Optional[String]:
    comptime if from_path:
        var value = req.param_opt(name)
        if not value:
            return None
        return _percent_decode(value.value(), plus_is_space=False)
    else:
        var value = req.query_param_opt(name)
        if not value:
            return None
        return _percent_decode(value.value(), plus_is_space=True)


def _write_field[
    F: AnyType, from_path: Bool, //
](ptr: Pointer[F, MutUntrackedOrigin], req: Request, name: String) raises:
    """Convert one text value and write it into its field."""
    var text = _text_of[from_path](req, name)
    comptime if F == Optional[String]:
        ptr.unsafe_bitcast[Optional[String]]().unsafe_write(text^)
        return
    elif F == Optional[Int]:
        var value = Optional[Int](None)
        if text:
            value = _parse_int(text.value(), name)
        ptr.unsafe_bitcast[Optional[Int]]().unsafe_write(value)
        return
    elif F == Optional[Float64]:
        var value = Optional[Float64](None)
        if text:
            value = _parse_float(text.value(), name)
        ptr.unsafe_bitcast[Optional[Float64]]().unsafe_write(value)
        return
    elif F == Optional[Bool]:
        var value = Optional[Bool](None)
        if text:
            value = _parse_bool(text.value(), name)
        ptr.unsafe_bitcast[Optional[Bool]]().unsafe_write(value)
        return
    else:
        if not text:
            raise Error("missing field '", name, "'")
        comptime if F == String:
            ptr.unsafe_bitcast[String]().unsafe_write(text.value())
        elif F == Int:
            ptr.unsafe_bitcast[Int]().unsafe_write(
                _parse_int(text.value(), name)
            )
        elif F == Float64:
            ptr.unsafe_bitcast[Float64]().unsafe_write(
                _parse_float(text.value(), name)
            )
        elif F == Bool:
            ptr.unsafe_bitcast[Bool]().unsafe_write(
                _parse_bool(text.value(), name)
            )
        else:
            comptime assert False, String(
                "field type ",
                reflect[F].name(),
                (
                    " is not supported in path or query params; use String,"
                    " Int, Float64, Bool or an Optional of them"
                ),
            )


def _destroy_written[T: AnyType](mut target: T, written: Int):
    """Drop the fields already written when a later field failed."""
    comptime types = reflect[T].field_types()
    comptime for i in range(reflect[T].field_count()):
        comptime F = types[i]
        comptime if F == String:
            if i < written:
                ref field = reflect[T].field_ref[i](target)
                Pointer(to=field).unsafe_bitcast[
                    String
                ]().unsafe_deinit_pointee()
        elif F == Optional[String]:
            if i < written:
                ref field = reflect[T].field_ref[i](target)
                Pointer(to=field).unsafe_bitcast[
                    Optional[String]
                ]().unsafe_deinit_pointee()


def _fill_struct[T: _ArgType, from_path: Bool](req: Request) raises -> T:
    """Build a T from named text values. Fields are written once, in place."""
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()
    var slot = MaybeUninit[T]()
    ref target = slot.unsafe_assume_init()
    var written = 0
    comptime for i in range(reflect[T].field_count()):
        comptime name = names[i]
        comptime F = types[i]
        ref field = reflect[T].field_ref[i](target)
        var ptr = (
            Pointer(to=field)
            .unsafe_bitcast[F]()
            .unsafe_origin_cast[MutUntrackedOrigin]()
        )
        try:
            _write_field[from_path=from_path](ptr, req, String(name))
        except e:
            _destroy_written[T](target, written)
            slot^.unsafe_forget()
            raise e^
        written += 1
    return slot^.unsafe_assume_init()


# Compile-time route checks


comptime _ROLE_PATH = 0
comptime _ROLE_QUERY = 1
comptime _ROLE_BODY = 2
comptime _ROLE_STATE = 3
comptime _ROLE_NONE = 4


def _role_of[A: AnyType]() -> Int:
    comptime if conforms_to(A, PathParams):
        return _ROLE_PATH
    elif conforms_to(A, QueryParams):
        return _ROLE_QUERY
    elif conforms_to(A, JsonBody):
        return _ROLE_BODY
    elif conforms_to(A, AppState):
        return _ROLE_STATE
    else:
        return _ROLE_NONE


def _role_name(role: Int) -> String:
    if role == _ROLE_PATH:
        return String("PathParams")
    if role == _ROLE_QUERY:
        return String("QueryParams")
    if role == _ROLE_BODY:
        return String("JsonBody")
    return String("AppState")


def _param_names(path: String) -> List[String]:
    var parsed = parse_route_path(path)
    var names = List[String]()
    for seg in parsed.segs:
        if seg.kind != SEG_LITERAL:
            names.append(seg.text)
    return names^


def _has_field[P: AnyType](name: String) -> Bool:
    comptime names = reflect[P].field_names()
    var found = False
    comptime for i in range(reflect[P].field_count()):
        comptime field = names[i]
        if String(field) == name:
            found = True
    return found


def _path_struct_error[P: AnyType](path: String) -> String:
    """The first mismatch between the route's params and P's fields, or empty.
    """
    var params = _param_names(path)
    for param in params:
        if not _has_field[P](param):
            return String(
                "route ",
                path,
                ": path param {",
                param,
                "} has no field in ",
                reflect[P].name(),
            )
    comptime names = reflect[P].field_names()
    comptime for i in range(reflect[P].field_count()):
        comptime field = names[i]
        var matched = False
        for param in params:
            if param == String(field):
                matched = True
        if not matched:
            return String(
                "route ",
                path,
                ": field '",
                field,
                "' of ",
                reflect[P].name(),
                " has no {",
                field,
                "} in the path",
            )
    return String("")


def _arg_error[path: String, S: AnyType, A: AnyType]() -> String:
    """A mistake in one handler argument, or empty."""
    comptime role = _role_of[A]()
    comptime if role == _ROLE_NONE:
        return String(
            "route ",
            path,
            ": argument type ",
            reflect[A].name(),
            " has none of PathParams, QueryParams, JsonBody, AppState",
        )
    elif role == _ROLE_PATH:
        return _path_struct_error[A](path)
    elif role == _ROLE_STATE:
        comptime if S == NoState:
            return String(
                "route ",
                path,
                ": handler takes state ",
                reflect[A].name(),
                " but the App was created without state",
            )
        elif A != S:
            return String(
                "route ",
                path,
                ": state argument is ",
                reflect[A].name(),
                " but the App state is ",
                reflect[S].name(),
            )
        else:
            return String("")
    else:
        return String("")


def _roles_error(path: String, roles: List[Int]) -> String:
    """Two arguments with one role, or params with no path struct, or empty."""
    for i in range(len(roles)):
        for j in range(i + 1, len(roles)):
            if roles[i] == roles[j]:
                return String(
                    "route ",
                    path,
                    ": two arguments are ",
                    _role_name(roles[i]),
                    " (arguments ",
                    i + 1,
                    " and ",
                    j + 1,
                    ")",
                )
    var params = _param_names(path)
    if len(params) == 0:
        return String("")
    for role in roles:
        if role == _ROLE_PATH:
            return String("")
    return String(
        "route ",
        path,
        ": path has {",
        params[0],
        "} but the handler has no PathParams argument",
    )


def _check_path[path: String]():
    comptime parsed = parse_route_path(path)
    comptime assert parsed.error.byte_length() == 0, String(
        "route ", path, ": ", parsed.error
    )


def _check_arg[path: String, S: AnyType, A: AnyType]():
    comptime error = _arg_error[path, S, A]()
    comptime assert error.byte_length() == 0, error


def _check_roles[path: String, roles: List[Int]]():
    comptime error = _roles_error(path, roles)
    comptime assert error.byte_length() == 0, error


# Per-request arguments


struct _Arg[A: _ArgType]:
    """One handler argument: built for this request, or the borrowed state."""

    var owned: Optional[Self.A]
    var state_addr: Int

    def __init__(out self):
        self.owned = None
        self.state_addr = 0

    def load[S: _ArgType](mut self, req: Request, state: ArcPointer[S]) raises:
        comptime role = _role_of[Self.A]()
        comptime if role == _ROLE_PATH:
            self.owned = _fill_struct[Self.A, True](req)
        elif role == _ROLE_QUERY:
            self.owned = _fill_struct[Self.A, False](req)
        elif role == _ROLE_BODY:
            self.owned = deserialize_json[Self.A](req.body)
        else:
            self.state_addr = Int(Pointer(to=state[]))

    def ptr(ref self) -> Pointer[Self.A, origin_of(self)]:
        """The tracked origin keeps this `_Arg` alive until the handler returns.
        """
        if self.owned:
            return Pointer(to=self.owned.unsafe_value()).unsafe_origin_cast[
                origin_of(self)
            ]()
        return Pointer[Self.A, origin_of(self)](
            unsafe_from_address=self.state_addr
        )


def _to_response[R: _ArgType](var value: R) raises -> Response:
    comptime if R == Response:
        return rebind_var[Response](value^)
    else:
        return ok_json_of(value)


# One route type per argument count


struct _Route0[S: _ArgType, R: _ArgType](Copyable, Handler):
    var handler: def(Request) raises thin -> Self.R
    var state: ArcPointer[Self.S]

    def __init__(
        out self,
        handler: def(Request) raises thin -> Self.R,
        state: ArcPointer[Self.S],
    ):
        self.handler = handler
        self.state = state

    def serve(self, req: Request) raises -> Response:
        try:
            return _to_response[Self.R](self.handler(req))
        except e:
            return _handler_failed(req, e)


struct _Route1[S: _ArgType, R: _ArgType, A0: _ArgType](Copyable, Handler):
    var handler: def(Request, Self.A0) raises thin -> Self.R
    var state: ArcPointer[Self.S]

    def __init__(
        out self,
        handler: def(Request, Self.A0) raises thin -> Self.R,
        state: ArcPointer[Self.S],
    ):
        self.handler = handler
        self.state = state

    def serve(self, req: Request) raises -> Response:
        var a0 = _Arg[Self.A0]()
        try:
            a0.load(req, self.state)
        except e:
            return _problem(400, String(e))
        try:
            return _to_response[Self.R](self.handler(req, a0.ptr()[]))
        except e:
            return _handler_failed(req, e)


struct _Route2[S: _ArgType, R: _ArgType, A0: _ArgType, A1: _ArgType](
    Copyable, Handler
):
    var handler: def(Request, Self.A0, Self.A1) raises thin -> Self.R
    var state: ArcPointer[Self.S]

    def __init__(
        out self,
        handler: def(Request, Self.A0, Self.A1) raises thin -> Self.R,
        state: ArcPointer[Self.S],
    ):
        self.handler = handler
        self.state = state

    def serve(self, req: Request) raises -> Response:
        var a0 = _Arg[Self.A0]()
        var a1 = _Arg[Self.A1]()
        try:
            a0.load(req, self.state)
            a1.load(req, self.state)
        except e:
            return _problem(400, String(e))
        try:
            return _to_response[Self.R](
                self.handler(req, a0.ptr()[], a1.ptr()[])
            )
        except e:
            return _handler_failed(req, e)


struct _Route3[
    S: _ArgType, R: _ArgType, A0: _ArgType, A1: _ArgType, A2: _ArgType
](Copyable, Handler):
    var handler: def(Request, Self.A0, Self.A1, Self.A2) raises thin -> Self.R
    var state: ArcPointer[Self.S]

    def __init__(
        out self,
        handler: def(Request, Self.A0, Self.A1, Self.A2) raises thin -> Self.R,
        state: ArcPointer[Self.S],
    ):
        self.handler = handler
        self.state = state

    def serve(self, req: Request) raises -> Response:
        var a0 = _Arg[Self.A0]()
        var a1 = _Arg[Self.A1]()
        var a2 = _Arg[Self.A2]()
        try:
            a0.load(req, self.state)
            a1.load(req, self.state)
            a2.load(req, self.state)
        except e:
            return _problem(400, String(e))
        try:
            return _to_response[Self.R](
                self.handler(req, a0.ptr()[], a1.ptr()[], a2.ptr()[])
            )
        except e:
            return _handler_failed(req, e)


struct _Route4[
    S: _ArgType,
    R: _ArgType,
    A0: _ArgType,
    A1: _ArgType,
    A2: _ArgType,
    A3: _ArgType,
](Copyable, Handler):
    var handler: def(
        Request, Self.A0, Self.A1, Self.A2, Self.A3
    ) raises thin -> Self.R
    var state: ArcPointer[Self.S]

    def __init__(
        out self,
        handler: def(
            Request, Self.A0, Self.A1, Self.A2, Self.A3
        ) raises thin -> Self.R,
        state: ArcPointer[Self.S],
    ):
        self.handler = handler
        self.state = state

    def serve(self, req: Request) raises -> Response:
        var a0 = _Arg[Self.A0]()
        var a1 = _Arg[Self.A1]()
        var a2 = _Arg[Self.A2]()
        var a3 = _Arg[Self.A3]()
        try:
            a0.load(req, self.state)
            a1.load(req, self.state)
            a2.load(req, self.state)
            a3.load(req, self.state)
        except e:
            return _problem(400, String(e))
        try:
            return _to_response[Self.R](
                self.handler(
                    req, a0.ptr()[], a1.ptr()[], a2.ptr()[], a3.ptr()[]
                )
            )
        except e:
            return _handler_failed(req, e)


struct _Route5[
    S: _ArgType,
    R: _ArgType,
    A0: _ArgType,
    A1: _ArgType,
    A2: _ArgType,
    A3: _ArgType,
    A4: _ArgType,
](Copyable, Handler):
    var handler: def(
        Request, Self.A0, Self.A1, Self.A2, Self.A3, Self.A4
    ) raises thin -> Self.R
    var state: ArcPointer[Self.S]

    def __init__(
        out self,
        handler: def(
            Request, Self.A0, Self.A1, Self.A2, Self.A3, Self.A4
        ) raises thin -> Self.R,
        state: ArcPointer[Self.S],
    ):
        self.handler = handler
        self.state = state

    def serve(self, req: Request) raises -> Response:
        var a0 = _Arg[Self.A0]()
        var a1 = _Arg[Self.A1]()
        var a2 = _Arg[Self.A2]()
        var a3 = _Arg[Self.A3]()
        var a4 = _Arg[Self.A4]()
        try:
            a0.load(req, self.state)
            a1.load(req, self.state)
            a2.load(req, self.state)
            a3.load(req, self.state)
            a4.load(req, self.state)
        except e:
            return _problem(400, String(e))
        try:
            return _to_response[Self.R](
                self.handler(
                    req,
                    a0.ptr()[],
                    a1.ptr()[],
                    a2.ptr()[],
                    a3.ptr()[],
                    a4.ptr()[],
                )
            )
        except e:
            return _handler_failed(req, e)


struct App[S: AppState = NoState](Copyable, Handler):
    """Routes, one shared state and the server.

    Copies share the routes and the state, so an `App` is cheap to hand to
    each worker. It is a `Handler`, so stock middleware can wrap it:
    `serve(Logger(app^), port=8080)`.
    """

    var _router: Router
    var _state: ArcPointer[Self.S]

    def __init__(out self):
        comptime assert (
            Self.S == NoState
        ), "App() has no state: use App(state=...)"
        self._router = Router()
        self._state = ArcPointer(rebind_var[Self.S](NoState()))

    def __init__(out self, *, var state: Self.S):
        self._router = Router()
        self._state = ArcPointer(state^)

    def group(self) -> Self:
        """A new `App` with no routes that shares this one's state.

        Mount it to give some routes their own middleware:
        `app.mount("/admin", RequireAuth(admin^))`.
        """
        var sub = self.copy()
        sub._router = Router()
        return sub^

    def mount[
        H: Handler & Copyable
    ](mut self, prefix: String, var sub: H) raises:
        """Serve `sub` under the literal path `prefix`, with the prefix stripped.
        """
        self._router.mount(prefix, sub^)

    def serve(self, req: Request) raises -> Response:
        return self._router.serve(req)

    def may_block(self) -> Bool:
        return self._router.may_block()

    def blocking(self, req: Request) raises -> Bool:
        return self._router.blocking(req)

    def serve(
        self,
        *,
        port: UInt16 = 8080,
        host: String = "127.0.0.1",
        num_workers: Int = 0,
    ) raises:
        """Listen and serve until stopped. `num_workers=0` uses every core."""
        _serve_on(self.copy(), port, host, num_workers)

    def route[
        path: String, R: _ArgType
    ](mut self, method: String, handler: def(Request) raises thin -> R) raises:
        _check_path[path]()
        comptime roles = List[Int]()
        _check_roles[path, roles]()
        self._router._add_struct(
            method, path, _Route0[Self.S, R](handler, self._state)
        )

    def route[
        path: String, R: _ArgType, A0: _ArgType
    ](
        mut self, method: String, handler: def(Request, A0) raises thin -> R
    ) raises:
        _check_path[path]()
        _check_arg[path, Self.S, A0]()
        comptime roles: List[Int] = [_role_of[A0]()]
        _check_roles[path, roles]()
        self._router._add_struct(
            method, path, _Route1[Self.S, R, A0](handler, self._state)
        )

    def route[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType
    ](
        mut self, method: String, handler: def(Request, A0, A1) raises thin -> R
    ) raises:
        _check_path[path]()
        _check_arg[path, Self.S, A0]()
        _check_arg[path, Self.S, A1]()
        comptime roles: List[Int] = [_role_of[A0](), _role_of[A1]()]
        _check_roles[path, roles]()
        self._router._add_struct(
            method, path, _Route2[Self.S, R, A0, A1](handler, self._state)
        )

    def route[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType, A2: _ArgType
    ](
        mut self,
        method: String,
        handler: def(Request, A0, A1, A2) raises thin -> R,
    ) raises:
        _check_path[path]()
        _check_arg[path, Self.S, A0]()
        _check_arg[path, Self.S, A1]()
        _check_arg[path, Self.S, A2]()
        comptime roles: List[Int] = [
            _role_of[A0](),
            _role_of[A1](),
            _role_of[A2](),
        ]
        _check_roles[path, roles]()
        self._router._add_struct(
            method, path, _Route3[Self.S, R, A0, A1, A2](handler, self._state)
        )

    def route[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
    ](
        mut self,
        method: String,
        handler: def(Request, A0, A1, A2, A3) raises thin -> R,
    ) raises:
        _check_path[path]()
        _check_arg[path, Self.S, A0]()
        _check_arg[path, Self.S, A1]()
        _check_arg[path, Self.S, A2]()
        _check_arg[path, Self.S, A3]()
        comptime roles: List[Int] = [
            _role_of[A0](),
            _role_of[A1](),
            _role_of[A2](),
            _role_of[A3](),
        ]
        _check_roles[path, roles]()
        self._router._add_struct(
            method,
            path,
            _Route4[Self.S, R, A0, A1, A2, A3](handler, self._state),
        )

    def route[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
        A4: _ArgType,
    ](
        mut self,
        method: String,
        handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R,
    ) raises:
        _check_path[path]()
        _check_arg[path, Self.S, A0]()
        _check_arg[path, Self.S, A1]()
        _check_arg[path, Self.S, A2]()
        _check_arg[path, Self.S, A3]()
        _check_arg[path, Self.S, A4]()
        comptime roles: List[Int] = [
            _role_of[A0](),
            _role_of[A1](),
            _role_of[A2](),
            _role_of[A3](),
            _role_of[A4](),
        ]
        _check_roles[path, roles]()
        self._router._add_struct(
            method,
            path,
            _Route5[Self.S, R, A0, A1, A2, A3, A4](handler, self._state),
        )

    def get[
        path: String, R: _ArgType
    ](mut self, handler: def(Request) raises thin -> R) raises:
        self.route[path](Method.GET, handler)

    def get[
        path: String, R: _ArgType, A0: _ArgType
    ](mut self, handler: def(Request, A0) raises thin -> R) raises:
        self.route[path](Method.GET, handler)

    def get[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType
    ](mut self, handler: def(Request, A0, A1) raises thin -> R) raises:
        self.route[path](Method.GET, handler)

    def get[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType, A2: _ArgType
    ](mut self, handler: def(Request, A0, A1, A2) raises thin -> R) raises:
        self.route[path](Method.GET, handler)

    def get[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
    ](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R) raises:
        self.route[path](Method.GET, handler)

    def get[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
        A4: _ArgType,
    ](
        mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R
    ) raises:
        self.route[path](Method.GET, handler)

    def post[
        path: String, R: _ArgType
    ](mut self, handler: def(Request) raises thin -> R) raises:
        self.route[path](Method.POST, handler)

    def post[
        path: String, R: _ArgType, A0: _ArgType
    ](mut self, handler: def(Request, A0) raises thin -> R) raises:
        self.route[path](Method.POST, handler)

    def post[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType
    ](mut self, handler: def(Request, A0, A1) raises thin -> R) raises:
        self.route[path](Method.POST, handler)

    def post[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType, A2: _ArgType
    ](mut self, handler: def(Request, A0, A1, A2) raises thin -> R) raises:
        self.route[path](Method.POST, handler)

    def post[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
    ](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R) raises:
        self.route[path](Method.POST, handler)

    def post[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
        A4: _ArgType,
    ](
        mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R
    ) raises:
        self.route[path](Method.POST, handler)

    def put[
        path: String, R: _ArgType
    ](mut self, handler: def(Request) raises thin -> R) raises:
        self.route[path](Method.PUT, handler)

    def put[
        path: String, R: _ArgType, A0: _ArgType
    ](mut self, handler: def(Request, A0) raises thin -> R) raises:
        self.route[path](Method.PUT, handler)

    def put[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType
    ](mut self, handler: def(Request, A0, A1) raises thin -> R) raises:
        self.route[path](Method.PUT, handler)

    def put[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType, A2: _ArgType
    ](mut self, handler: def(Request, A0, A1, A2) raises thin -> R) raises:
        self.route[path](Method.PUT, handler)

    def put[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
    ](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R) raises:
        self.route[path](Method.PUT, handler)

    def put[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
        A4: _ArgType,
    ](
        mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R
    ) raises:
        self.route[path](Method.PUT, handler)

    def patch[
        path: String, R: _ArgType
    ](mut self, handler: def(Request) raises thin -> R) raises:
        self.route[path](Method.PATCH, handler)

    def patch[
        path: String, R: _ArgType, A0: _ArgType
    ](mut self, handler: def(Request, A0) raises thin -> R) raises:
        self.route[path](Method.PATCH, handler)

    def patch[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType
    ](mut self, handler: def(Request, A0, A1) raises thin -> R) raises:
        self.route[path](Method.PATCH, handler)

    def patch[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType, A2: _ArgType
    ](mut self, handler: def(Request, A0, A1, A2) raises thin -> R) raises:
        self.route[path](Method.PATCH, handler)

    def patch[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
    ](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R) raises:
        self.route[path](Method.PATCH, handler)

    def patch[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
        A4: _ArgType,
    ](
        mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R
    ) raises:
        self.route[path](Method.PATCH, handler)

    def delete[
        path: String, R: _ArgType
    ](mut self, handler: def(Request) raises thin -> R) raises:
        self.route[path](Method.DELETE, handler)

    def delete[
        path: String, R: _ArgType, A0: _ArgType
    ](mut self, handler: def(Request, A0) raises thin -> R) raises:
        self.route[path](Method.DELETE, handler)

    def delete[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType
    ](mut self, handler: def(Request, A0, A1) raises thin -> R) raises:
        self.route[path](Method.DELETE, handler)

    def delete[
        path: String, R: _ArgType, A0: _ArgType, A1: _ArgType, A2: _ArgType
    ](mut self, handler: def(Request, A0, A1, A2) raises thin -> R) raises:
        self.route[path](Method.DELETE, handler)

    def delete[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
    ](mut self, handler: def(Request, A0, A1, A2, A3) raises thin -> R) raises:
        self.route[path](Method.DELETE, handler)

    def delete[
        path: String,
        R: _ArgType,
        A0: _ArgType,
        A1: _ArgType,
        A2: _ArgType,
        A3: _ArgType,
        A4: _ArgType,
    ](
        mut self, handler: def(Request, A0, A1, A2, A3, A4) raises thin -> R
    ) raises:
        self.route[path](Method.DELETE, handler)


def _serve_on[
    H: Handler & Copyable
](var handler: H, port: UInt16, host: String, num_workers: Int) raises:
    var workers = num_workers
    if workers <= 0:
        workers = num_cpus()
    var server = HttpServer.bind(SocketAddr(IpAddr.parse(host), port))
    server.serve(handler^, num_workers=workers)


def serve[
    H: Handler & Copyable
](
    var handler: H,
    *,
    port: UInt16 = 8080,
    host: String = "127.0.0.1",
    num_workers: Int = 0,
) raises:
    """Listen and serve any handler, such as an `App` wrapped in middleware."""
    _serve_on(handler^, port, host, num_workers)

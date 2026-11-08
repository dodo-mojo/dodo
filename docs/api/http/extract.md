# `dodo.http.extract`

Typed request extractors with reflective auto-injection.

Extractors turn a ``Request`` into a typed value. Each extractor is a
zero-runtime-allocation wrapper over the request: the compile-time
parameter ``name: StaticString`` names the path / query / header key,
and the concrete extractor (``PathInt`` / ``QueryStr`` / ...) decides
how the captured string is parsed into a concrete type. The
``.value`` accessor returns the primitive directly -- no
``.value.value`` chain.

## Primary surface

Value-constructor extractors usable from inside a handler body:

```mojo
from dodo.http import (
    Request, Response, ok, bad_request,
    PathInt, OptionalQueryInt, HeaderStr,
)

def get_user(req: Request) raises -> Response:
    var id = PathInt["id"].extract(req).value
    var page = OptionalQueryInt["page"].extract(req).value
    var auth = HeaderStr["Authorization"].extract(req).value
    return ok("user " + String(id))
```

## Auto-injection

For the axum-style "the handler's signature IS the extractor spec",
declare the extractor set as the fields of a ``Handler`` struct and
wrap it in ``Extracted[H]``:

```mojo
from dodo.http import (
    Extracted, Handler, Request, Response, ok,
    PathInt, OptionalQueryInt,
)

@fieldwise_init
struct GetUser(Copyable, Defaultable, Handler):
    var id: PathInt["id"]
    var page: OptionalQueryInt["page"]

    def __init__(out self):
        self.id = PathInt["id"]()
        self.page = OptionalQueryInt["page"]()

    def serve(self, req: Request) raises -> Response:
        return ok("user " + String(self.id.value))

# Register with any Router / HttpServer that accepts a ``Handler``:
# r.get("/users/{id}", Extracted[GetUser]())
```

``Extracted[H]`` is itself a ``Handler`` and reflects on ``H``'s field
list via ``reflect[H].field_count()`` + a `comptime assert
conforms_to(...)` per field:
per request, it default-constructs ``H``, walks each field with a
``comptime for`` loop, calls ``field.apply(req)`` through the
``Extractor`` trait, and invokes ``h.serve(req)``. No per-arity
wrapper types, no runtime dispatch — every field's type is known at
compile time and monomorphised through.

``H`` is just a regular ``Handler``; wrapping in ``Extracted[H]`` is
what gives it the field-population step. Passing ``H()`` directly to
a ``Router`` still compiles and calls ``serve(req)`` on default-
initialised fields — technically valid, almost never what you want,
so reach for ``Extracted[H]()`` whenever the struct has extractor
fields.

## Custom-type extraction

For types beyond ``Int`` / ``Float64`` / ``Bool`` / ``String``, write
a small extractor struct directly. The contract is simple: implement
the :trait:`Extractor` trait by populating a single ``value`` field
from the request, then add it to a handler struct or call
``extract(req)`` as a value constructor. The 20 concrete shipped
extractors (``PathInt`` ... ``OptionalHeaderBool``) are the canonical
templates::

```mojo
@fieldwise_init
struct PathUuid[name: StaticString](Copyable, Defaultable, Extractor):
    var value: Uuid

    def __init__(out self):
        self.value = Uuid()

    def apply(mut self, req: Request) raises:
        if not req.has_param(String(Self.name)):
            raise Error("missing path parameter: " + String(Self.name))
        self.value = Uuid.parse(req.param(String(Self.name)))
```

Custom types belong as their own ``Extractor`` struct directly --
the framework deliberately does not expose a parametric
``Path[T: ParamParser, name]`` shape, because in practice it
adds a ``.value.value`` chain at every call site without
carrying a parser implementation that could not just live in
the ``Extractor`` itself.

## Parse-failure handling

Each extractor's ``apply`` raises an ``Error`` if the request is
missing the parameter or the captured value fails to parse. The
``Extracted[H]`` adapter catches extractor errors and returns **400
Bad Request** with the error message in the body; the handler's
``serve`` is never called on a bad extraction.

## Structs

### `PathInt`

```mojo
struct PathInt[name: StringSpan[ImmStaticOrigin]]
```

Required path parameter named ``name``, parsed as ``Int``.

``apply`` raises if the route did not capture ``name`` or if the
captured bytes don't parse as a signed integer (optional leading
``-`` followed by ASCII digits).

Fields:

- `value` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `PathInt.__init__`

```mojo
def __init__(out self)
```

#### `PathInt.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `PathInt.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `PathStr`

```mojo
struct PathStr[name: StringSpan[ImmStaticOrigin]]
```

Required path parameter named ``name``, exposed as ``String``.

Fields:

- `value` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `PathStr.__init__`

```mojo
def __init__(out self)
```

#### `PathStr.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `PathStr.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `PathFloat`

```mojo
struct PathFloat[name: StringSpan[ImmStaticOrigin]]
```

Required path parameter named ``name``, parsed as ``Float64``.

Fields:

- `value` (`Float64`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `PathFloat.__init__`

```mojo
def __init__(out self)
```

#### `PathFloat.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `PathFloat.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `PathBool`

```mojo
struct PathBool[name: StringSpan[ImmStaticOrigin]]
```

Required path parameter named ``name``, parsed as ``Bool``.

Fields:

- `value` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `PathBool.__init__`

```mojo
def __init__(out self)
```

#### `PathBool.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `PathBool.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `QueryInt`

```mojo
struct QueryInt[name: StringSpan[ImmStaticOrigin]]
```

Required query-string parameter named ``name``, parsed as ``Int``.

Fields:

- `value` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `QueryInt.__init__`

```mojo
def __init__(out self)
```

#### `QueryInt.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `QueryInt.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `QueryStr`

```mojo
struct QueryStr[name: StringSpan[ImmStaticOrigin]]
```

Required query-string parameter named ``name``, exposed as ``String``.

Fields:

- `value` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `QueryStr.__init__`

```mojo
def __init__(out self)
```

#### `QueryStr.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `QueryStr.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `QueryFloat`

```mojo
struct QueryFloat[name: StringSpan[ImmStaticOrigin]]
```

Required query parameter named ``name``, parsed as ``Float64``.

Fields:

- `value` (`Float64`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `QueryFloat.__init__`

```mojo
def __init__(out self)
```

#### `QueryFloat.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `QueryFloat.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `QueryBool`

```mojo
struct QueryBool[name: StringSpan[ImmStaticOrigin]]
```

Required query parameter named ``name``, parsed as ``Bool``.

Fields:

- `value` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `QueryBool.__init__`

```mojo
def __init__(out self)
```

#### `QueryBool.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `QueryBool.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalQueryInt`

```mojo
struct OptionalQueryInt[name: StringSpan[ImmStaticOrigin]]
```

Optional query parameter as ``Optional[Int]``. ``value`` is ``None`` when absent.

Fields:

- `value` (`Optional[Int]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalQueryInt.__init__`

```mojo
def __init__(out self)
```

#### `OptionalQueryInt.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalQueryInt.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalQueryStr`

```mojo
struct OptionalQueryStr[name: StringSpan[ImmStaticOrigin]]
```

Optional query parameter as ``Optional[String]``.

Fields:

- `value` (`Optional[String]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalQueryStr.__init__`

```mojo
def __init__(out self)
```

#### `OptionalQueryStr.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalQueryStr.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalQueryFloat`

```mojo
struct OptionalQueryFloat[name: StringSpan[ImmStaticOrigin]]
```

Optional query parameter as ``Optional[Float64]``.

Fields:

- `value` (`Optional[Float64]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalQueryFloat.__init__`

```mojo
def __init__(out self)
```

#### `OptionalQueryFloat.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalQueryFloat.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalQueryBool`

```mojo
struct OptionalQueryBool[name: StringSpan[ImmStaticOrigin]]
```

Optional query parameter as ``Optional[Bool]``.

Fields:

- `value` (`Optional[Bool]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalQueryBool.__init__`

```mojo
def __init__(out self)
```

#### `OptionalQueryBool.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalQueryBool.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `HeaderInt`

```mojo
struct HeaderInt[name: StringSpan[ImmStaticOrigin]]
```

Required header named ``name``, parsed as ``Int``.

Fields:

- `value` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `HeaderInt.__init__`

```mojo
def __init__(out self)
```

#### `HeaderInt.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `HeaderInt.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `HeaderStr`

```mojo
struct HeaderStr[name: StringSpan[ImmStaticOrigin]]
```

Required header named ``name``, exposed as ``String``.

Fields:

- `value` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `HeaderStr.__init__`

```mojo
def __init__(out self)
```

#### `HeaderStr.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `HeaderStr.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `HeaderFloat`

```mojo
struct HeaderFloat[name: StringSpan[ImmStaticOrigin]]
```

Required header named ``name``, parsed as ``Float64``.

Fields:

- `value` (`Float64`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `HeaderFloat.__init__`

```mojo
def __init__(out self)
```

#### `HeaderFloat.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `HeaderFloat.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `HeaderBool`

```mojo
struct HeaderBool[name: StringSpan[ImmStaticOrigin]]
```

Required header named ``name``, parsed as ``Bool``.

Fields:

- `value` (`Bool`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `HeaderBool.__init__`

```mojo
def __init__(out self)
```

#### `HeaderBool.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `HeaderBool.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalHeaderInt`

```mojo
struct OptionalHeaderInt[name: StringSpan[ImmStaticOrigin]]
```

Optional header as ``Optional[Int]``.

Fields:

- `value` (`Optional[Int]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalHeaderInt.__init__`

```mojo
def __init__(out self)
```

#### `OptionalHeaderInt.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalHeaderInt.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalHeaderStr`

```mojo
struct OptionalHeaderStr[name: StringSpan[ImmStaticOrigin]]
```

Optional header as ``Optional[String]``.

Fields:

- `value` (`Optional[String]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalHeaderStr.__init__`

```mojo
def __init__(out self)
```

#### `OptionalHeaderStr.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalHeaderStr.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalHeaderFloat`

```mojo
struct OptionalHeaderFloat[name: StringSpan[ImmStaticOrigin]]
```

Optional header as ``Optional[Float64]``.

Fields:

- `value` (`Optional[Float64]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalHeaderFloat.__init__`

```mojo
def __init__(out self)
```

#### `OptionalHeaderFloat.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalHeaderFloat.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `OptionalHeaderBool`

```mojo
struct OptionalHeaderBool[name: StringSpan[ImmStaticOrigin]]
```

Optional header as ``Optional[Bool]``.

Fields:

- `value` (`Optional[Bool]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `OptionalHeaderBool.__init__`

```mojo
def __init__(out self)
```

#### `OptionalHeaderBool.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `OptionalHeaderBool.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `Peer`

```mojo
struct Peer
```

Kernel-reported peer ``SocketAddr`` of the connection.

The reactor captures ``TcpStream.peer_addr()`` at accept time and
threads it onto every ``Request`` for the connection. ``Peer.value``
surfaces it without parsing or any optionality — it always has a
value when the request came through ``HttpServer.serve``.

Note that this is the *kernel's* view of the peer. dodo does not
interpret ``X-Forwarded-For``, ``Forwarded:``, or PROXY-protocol
metadata for you. If you sit behind a reverse proxy and need the
upstream client IP, read the relevant header explicitly.

Example:
```mojo
from dodo.http import Peer

def who(req: Request) raises -> Response:
    var p = Peer.extract(req).value
    return ok(String(p.ip))
```

Fields:

- `value` (`SocketAddr`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `Peer.__init__`

```mojo
def __init__(out self)
```

#### `Peer.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `Peer.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `BodyBytes`

```mojo
struct BodyBytes
```

Extracts the raw request body as ``List[UInt8]``.

Always succeeds; the body is a byte copy so ownership is clean
across the handler invocation.

Fields:

- `value` (`List[UInt8]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `BodyBytes.__init__`

```mojo
def __init__(out self)
```

#### `BodyBytes.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `BodyBytes.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `BodyText`

```mojo
struct BodyText
```

Extracts the request body decoded as a UTF-8 ``String``.

Non-ASCII bytes are preserved verbatim by ``Request.text``; callers
who need strict UTF-8 validation should use ``BodyBytes`` and
validate themselves.

Fields:

- `value` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `BodyText.__init__`

```mojo
def __init__(out self)
```

#### `BodyText.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `BodyText.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `Cookies`

```mojo
struct Cookies
```

Extracts the request cookies as a ``CookieJar``.

Equivalent to ``req.cookies()`` but registerable as a field on a
``Handler`` struct via ``Extracted[H]`` for axum-style typed
handler signatures.

Fields:

- `value` (`CookieJar`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `Cookies.__init__`

```mojo
def __init__(out self)
```

#### `Cookies.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `Cookies.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `Form`

```mojo
struct Form
```

Extracts the request body as ``application/x-www-form-urlencoded``.

Raises if the request body is empty or contains a malformed
percent-escape. Use with ``Extracted[H]`` to map parse errors to
400.

Fields:

- `value` (`FormData`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `Form.__init__`

```mojo
def __init__(out self)
```

#### `Form.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `Form.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `Multipart`

```mojo
struct Multipart
```

Extracts the request body as ``multipart/form-data`` (RFC 7578).

Reads the boundary parameter from the request's ``Content-Type``
header and parses the body into a ``MultipartForm``. Raises on
missing or malformed multipart bodies.

Fields:

- `value` (`MultipartForm`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `Multipart.__init__`

```mojo
def __init__(out self)
```

#### `Multipart.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `Multipart.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `Json`

```mojo
struct Json
```

Extracts the request body as a parsed ``json.Value``.

``apply`` raises if the body is empty or not valid JSON; pair with
``Extracted[H]`` to have the server map the error to a 400.

Fields:

- `value` (`Value`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Extractor`, `Movable`

#### `Json.__init__`

```mojo
def __init__(out self)
```

#### `Json.apply`

```mojo
def apply(mut self, req: Request) raises
```

#### `Json.extract`

```mojo
def extract(req: Request) raises -> Self
```

### `Extracted`

```mojo
struct Extracted[H: Handler & Defaultable & Copyable]
```

Reflective auto-injection adapter: ``H``'s fields are its extractor set.

Per request: copy the prototype ``H``; for each field downcast the
reference to ``Extractor`` and call ``apply(req)`` (raises on
failure); then ``h.serve(req)``. Extractor failures map to **400
Bad Request**; ``serve`` exceptions propagate to the top-level 500.

``H`` is a regular ``Handler`` (the only extra bound is
``Defaultable``); the reflection step monomorphises per ``H``, the
direct analogue of axum's "parameter list declares the extractor
chain" without per-arity wrapper types.

Registration-time state: ``serve`` copies a stored *prototype* ``H``
per request rather than default-constructing a fresh one, so
pre-populated fields survive. Pair with :class:`State[T]` (a no-op
extractor carrying a registration value -- DB pool, config -- axum's
``State(db)``): set a prototype's ``State`` fields, then
``r.get(path, Extracted[H](proto^))``.

Fields:

- `prototype` (`H`): Registration-time handler prototype. Copied per request so ``State[T]`` (and any other pre-populated) fields survive; the reflective extractor walk overwrites the request-derived fields.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `Extracted.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, var prototype: H)
```

```mojo
def __init__(out self, *, copy: Self)
```

#### `Extracted.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

#### `Extracted.may_block`

```mojo
def may_block(self) -> Bool
```

#### `Extracted.blocking`

```mojo
def blocking(self, req: Request) raises -> Bool
```

# `dodo.testing.client`

In-process test client for ``Handler`` implementations.

``TestClient[H]`` is a thin synthesise-request-call-handler-
return-response helper. It exists for the same reason
FastAPI's ``TestClient`` does: handler-level tests want to
exercise the request/response shape without the friction of a
real socket, a real reactor, or a real port assignment.

Usage::

```mojo
var client = TestClient(MyHandler())
var resp = client.get("/users/42")
assert_equal(resp.status, 200)
```

The client supports the seven standard HTTP methods (GET, POST,
PUT, PATCH, DELETE, HEAD, OPTIONS); each accepts an optional
body and optional headers, and returns the captured
``Response``.

The client does not run any middleware *for* the caller -- the
``handler`` passed in must already be the fully-composed stack
the test wants to exercise. Compose your middleware once at
construction time, then run as many requests through it as the
test needs.

## Structs

### `TestClient`

```mojo
struct TestClient[H: Handler]
```

Wraps a ``Handler`` and exposes per-method synth helpers.

The handler is moved in at construction; subsequent calls
take a borrow. Two helper shapes are available per method:
a bare ``get(path)`` shape for cases where no body / no
custom headers are needed, and a ``request(method, path,
body, headers)`` shape for the full surface.

Fields:

- `handler` (`H`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `TestClient.__init__`

```mojo
def __init__(out self, var handler: H)
```

#### `TestClient.request`

```mojo
def request(self, method: String, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap()) raises -> Response
```

Synth a ``Request`` from the arguments and run it through ``self.handler``. The peer address is fixed to ``127.0.0.1:0`` and ``expose_errors`` is True so handler-level errors surface in the body (a test-mode affordance; production runs default to False).

#### `TestClient.get`

```mojo
def get(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `TestClient.head`

```mojo
def head(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `TestClient.options`

```mojo
def options(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `TestClient.post`

```mojo
def post(self, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `TestClient.put`

```mojo
def put(self, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `TestClient.patch`

```mojo
def patch(self, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `TestClient.delete`

```mojo
def delete(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

### `H2cTestClient`

```mojo
struct H2cTestClient[H: Handler]
```

In-process HTTP/2-cleartext (h2c) test client for a ``Handler``.

Where :class:`TestClient` calls ``handler.serve`` on a synthesized
:class:`Request` directly, :class:`H2cTestClient` drives the request
through the *real* HTTP/2 stack -- the byte-level
:class:`dodo.http2.Http2ClientConnection` and
:class:`dodo.http2.Http2Connection` exchange frames in memory (preface,
SETTINGS, HPACK-encoded HEADERS, DATA) so the h2 framing + HPACK
request-assembly + response-encoding path gets coverage with no TLS,
no socket, and no reactor. The handler runs server-side exactly as
the live reactor invokes it.

Usage::

```mojo
var client = H2cTestClient(MyHandler())
var resp = client.get("/users/42")
assert_equal(resp.status, 200)
```

The handler is moved in at construction; each request spins up a
fresh client + server driver pair so requests are independent (no
shared HPACK dynamic-table state across calls).

This does one request/response round per call over a fresh
connection pair -- no multiplexing or connection reuse across calls,
and request/response bodies must fit the default flow-control window
(no WINDOW_UPDATE-gated body pumping here). That is plenty to cover
the handler-facing h2 path; multi-stream / large-body coverage stays
with the live reactor e2e tests.

Fields:

- `handler` (`H`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `H2cTestClient.__init__`

```mojo
def __init__(out self, var handler: H)
```

#### `H2cTestClient.request`

```mojo
def request(self, method: String, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap(), authority: String = "testserver") raises -> Response
```

Drive one request through the in-process h2c client + server and return the :class:`Response` the handler produced.

Builds the request on a fresh client driver, pumps the framed
bytes into a fresh server driver, dispatches the assembled
:class:`Request` to ``self.handler``, frames the response back,
and decodes it on the client driver.

#### `H2cTestClient.get`

```mojo
def get(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `H2cTestClient.head`

```mojo
def head(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `H2cTestClient.options`

```mojo
def options(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `H2cTestClient.post`

```mojo
def post(self, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `H2cTestClient.put`

```mojo
def put(self, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `H2cTestClient.patch`

```mojo
def patch(self, path: String, var body: List[UInt8] = List(), var headers: HeaderMap = HeaderMap()) raises -> Response
```

#### `H2cTestClient.delete`

```mojo
def delete(self, path: String, var headers: HeaderMap = HeaderMap()) raises -> Response
```

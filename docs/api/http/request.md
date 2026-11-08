# `dodo.http.request`

HTTP request type.

## Structs

### `Method`

```mojo
struct Method
```

HTTP request method string constants (RFC 7231 §4).

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `GET = String("GET")`
- `POST = String("POST")`
- `PUT = String("PUT")`
- `PATCH = String("PATCH")`
- `DELETE = String("DELETE")`
- `HEAD = String("HEAD")`
- `OPTIONS = String("OPTIONS")`
- `CONNECT = String("CONNECT")`
- `TRACE = String("TRACE")`

### `Request`

```mojo
struct Request
```

An HTTP/1.1 request.

Fields:
    method: HTTP method string (use ``Method.*`` constants).
    url: Request target (path + query), e.g. ``"/items?page=1"``.
    headers: Request headers (owned ``HeaderMap``).
    body: Request body bytes (empty for GET/HEAD).
    version: HTTP version string (default ``"HTTP/1.1"``).
    peer: Kernel-reported peer address. Populated by
             the reactor at accept time from ``TcpStream.peer_addr()``.
             Direct ``Request`` constructions (tests, the client side)
             default to ``SocketAddr.localhost(0)`` so the field is
             always observable without having to special-case "did the
             reactor populate it." Note: this is the *kernel's* view
             of the peer; dodo does not interpret ``X-Forwarded-For``,
             ``Forwarded:``, or PROXY-protocol metadata.
    expose_errors: When ``True``, 4xx / 5xx responses generated from
             a raised ``Error`` may include the verbatim message in
             their body — useful in local dev. **Default ``False``**
             so production servers send a fixed status reason and
             log the message (with any user-controlled bytes) to
             stderr rather than echoing it back. Carried on the
             request because dodo is shared-nothing thread-per-core
             and the policy is set per-server (per-``ServerConfig``);
             the reactor copies ``ServerConfig.expose_error_messages``
             onto every parsed ``Request`` and ``_bad_request_from_error``
             reads it.

Path parameters extracted by ``Router`` live on a private field that
is lazily allocated on the first ``Router`` match. Handlers that
never go through a ``Router`` (the plaintext bench, pure static
handlers) therefore pay zero allocation cost per request. Access
params via ``req.params()`` or the convenience ``req.param(name)``
/ ``req.has_param(name)`` helpers.

This type is ``Movable`` (owns the header map and body) but not
``Copyable`` to avoid accidental deep copies.

Example:
```mojo
var req = Request(method=Method.POST, url="http://api.example.com/items")
req.headers.set("Content-Type", "application/json")
req.body = '{"name":"dodo"}'.as_bytes()
```

Fields:

- `method` (`String`)
- `url` (`String`)
- `headers` (`HeaderMap`)
- `body` (`List[UInt8]`)
- `trailers` (`HeaderMap`): Trailer fields sent after the body (RFC 9110 sec 6.5); fields that may not appear in a trailer are dropped.
- `version` (`String`)
- `peer` (`SocketAddr`): Kernel-reported peer ``SocketAddr``. See struct docstring.
- `expose_errors` (`Bool`): Whether 4xx / 5xx responses may echo raised ``Error`` messages. Default False; the reactor copies ``ServerConfig.expose_error_messages`` onto every parsed request. See struct docstring.
- `cancel` (`Cancel`): Set by the server when the request runs on the offload pool (``Offload``): it flips to ``TIMEOUT``, ``PEER_CLOSED`` or ``SHUTDOWN`` while the handler runs, so a long handler can poll ``req.cancel.cancelled()`` and stop early. Inline handlers, which nothing can interrupt, see ``Cancel.never()``.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Request.__init__`

```mojo
def __init__(out self, method: String, url: String, body: List[UInt8] = List(), version: String = "HTTP/1.1", peer: SocketAddr = SocketAddr(IpAddr(String("127.0.0.1"), False), UInt16(0)), expose_errors: Bool = False)
```

Create a new HTTP request.

Args:

- `method`: HTTP method string.
- `url`: Full URL or request target.
- `body`: Request body bytes; empty by default.
- `version`: HTTP version; ``"HTTP/1.1"`` by default.
- `peer`: Peer ``SocketAddr``; defaults to ``127.0.0.1:0`` for direct constructions. The reactor passes the kernel-reported peer captured at accept time.
- `expose_errors`: Whether handler / extractor error messages may flow into the response body. Default ``False`` (production-safe). The reactor copies this from ``ServerConfig.expose_error_messages``.

#### `Request.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `Request.test_get`

```mojo
def test_get(url: String) -> Self
```

Construct a GET request for cookbook examples and unit tests.

Equivalent to ``Request(method=Method.GET, url=url)`` but
spells the intent without re-stating the keyword arg trio.
Defaults: empty body, ``HTTP/1.1``, ``127.0.0.1:0`` peer,
``expose_errors=False``, no TLS info.

Args:

- `url`: Request target (path + optional query string).

Returns: A ready-to-route GET request.

#### `Request.test_post`

```mojo
def test_post(url: String, body: String, content_type: String = "application/octet-stream") raises -> Self
```

Construct a POST request with a string body.

Convenience factory for cookbook examples and unit tests
that want to drive an extractor / handler with a synthetic
body without writing the
``Request(method="POST", url=url, version="HTTP/1.1")`` +
per-byte ``body.append(...)`` loop the synthetic-request
shape used to require.

Args:

- `url`: Request target (path + optional query string).
- `body`: Body bytes as a UTF-8 ``String``. Empty string is fine.
- `content_type`: Value for the ``Content-Type`` header. Defaults to ``"application/octet-stream"``; pass ``"application/json"`` for JSON bodies and ``"application/x-www-form-urlencoded"`` for form bodies.

Returns: A ready-to-route POST request with the body bytes and a ``Content-Type`` header.

#### `Request.has_params`

```mojo
def has_params(self) -> Bool
```

Return True if a ``Router`` populated this request's path params.

#### `Request.params_mut`

```mojo
def params_mut(mut self) -> ref[self._params] Dict[String, String]
```

Lazily allocate and return a mutable reference to the path-params dict.

``Router`` calls this when it captures path parameters on a
matched route. Tests and examples can call it to construct a
``Request`` with synthetic path params without going through a
Router (e.g. when unit-testing a handler that reads
``req.param("id")``). The underlying ``Dict`` is allocated on
first call, so requests that never see a Router pay zero
allocation cost.

Production handlers should not call this — Router owns
param-population on the request path, and writing through this
accessor mid-request would be surprising. It's public only so
the test surface doesn't have to reach for an underscored
name.

#### `Request.param`

```mojo
def param(self, name: String) raises -> String
```

Return path param ``name``. Raises ``Error`` if missing.

Equivalent to ``req.params()[name]`` but does not allocate an
empty ``Dict`` when no params are present (raises immediately
instead).

#### `Request.has_param`

```mojo
def has_param(self, name: String) -> Bool
```

Return True if path param ``name`` is set (no allocation).

#### `Request.param_opt`

```mojo
def param_opt(self, name: String) raises -> Optional[String]
```

Return path param ``name`` as ``Optional[String]`` (``None`` on miss).

Uniform miss-behavior matrix -- every request-value source
(path param / query param / cookie) offers the same three
accessors:

- base (``param`` / ``query_param`` / ``cookie``): the
  domain-appropriate default. ``param`` **raises** because a
  missing path param is a routing/programming error, not client
  input; ``query_param`` / ``cookie`` return ``""`` because
  those are genuinely optional client input.
- ``*_opt`` -> ``Optional[String]``: ``None`` on absent,
  ``Optional("")`` on present-empty (distinguishes the two).
- ``*_or(name, default)`` -> ``String``: ``default`` on absent.

Pick ``*_opt`` for uniform absence handling regardless of source.

#### `Request.param_or`

```mojo
def param_or(self, name: String, default: String = "") raises -> String
```

Return path param ``name``, or ``default`` when absent.

The non-raising convenience form of ``param`` (see ``param_opt``
for the full uniform-accessor matrix).

#### `Request.query_param`

```mojo
def query_param(self, name: String) -> String
```

Return the first query-string value for ``name``, or ``""``.

Scans the URL's query string (the substring after ``?``, stopping
at ``#``) for ``name=value`` pairs separated by ``&``. Case-sensitive
key match. Does not percent-decode; callers should decode if they
expect encoded bytes. Allocation-free on requests that have no
query string (fast path checks for ``?`` in the URL first).

Args:

- `name`: Query parameter name.

Returns: The first value for ``name``, or an empty string if absent.

#### `Request.has_query_param`

```mojo
def has_query_param(self, name: String) -> Bool
```

Return True if query parameter ``name`` is present (even if empty).

Args:

- `name`: Query parameter name.

Returns: True if the key is present in the URL's query string.

#### `Request.query_param_opt`

```mojo
def query_param_opt(self, name: String) -> Optional[String]
```

Return query param ``name`` as ``Optional[String]`` (``None`` when the key is absent; ``Optional("")`` for a present-empty value).

Companion to ``param_opt`` / ``cookie_opt`` for uniform miss
semantics.

#### `Request.query_param_or`

```mojo
def query_param_or(self, name: String, default: String) -> String
```

Return query param ``name``, or ``default`` when the key is absent (unlike ``query_param``'s bare ``""``, which cannot tell absent from present-empty). Uniform with ``param_or`` / ``cookie_or``.

#### `Request.text`

```mojo
def text(self) -> String
```

Decode the request body as a UTF-8 string.

Invalid UTF-8 sequences are replaced with the Unicode
replacement character; the body comes from the client, so this
never raises on malformed input.

Returns: The body decoded as a ``String``. Empty string if body is empty.

#### `Request.json`

```mojo
def json(self) raises -> Value
```

Parse the request body as JSON.

Returns: A ``json.Value`` representing the parsed JSON document.

Raises: Error: If the body is not valid JSON.

#### `Request.content_length`

```mojo
def content_length(self) -> Int
```

Return the Content-Length header value, or 0 if absent or not a plain decimal of at most 18 digits.

#### `Request.cookies`

```mojo
def cookies(self) -> CookieJar
```

Parse the ``Cookie`` request header(s) into a ``CookieJar``.

Walks every ``Cookie`` header value (multiple headers are
legal under RFC 7230 paragraph 3.2.2) and feeds each to
``parse_cookie_header``. Returns an empty jar if no
``Cookie`` header is present.

#### `Request.cookie`

```mojo
def cookie(self, name: String) -> String
```

Return the value of cookie ``name`` from the ``Cookie`` header.

#### `Request.cookie_opt`

```mojo
def cookie_opt(self, name: String) -> Optional[String]
```

Return cookie ``name`` as ``Optional[String]`` (``None`` on miss).

Companion to ``param_opt`` / ``query_param_opt`` for uniform miss
semantics across path params, query params, and cookies.

#### `Request.cookie_or`

```mojo
def cookie_or(self, name: String, default: String) -> String
```

Return cookie ``name``, or ``default`` when absent. Uniform with ``param_or`` / ``query_param_or``.

#### `Request.has_cookie`

```mojo
def has_cookie(self, name: String) -> Bool
```

Return ``True`` if cookie ``name`` is set on this request.

#### `Request.connection_close`

```mojo
def connection_close(self) -> Bool
```

Return True if ``Connection: close`` is set.

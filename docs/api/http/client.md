# `dodo.http.client`

HTTP client: HTTP/1.1 and HTTP/2, over TCP or TLS.

- ``Content-Length``, chunked, and read-until-close response bodies
- Up to ``_max_redirects`` automatic 3xx redirects
- Automatic ``Host``, ``User-Agent``, ``Connection`` headers
- Optional ``Authorization`` header via the ``Auth`` trait

Module-level convenience functions (``get``, ``post``, ``put``,
``delete``, ``head``) create a one-shot ``HttpClient`` per call and are
suitable for quick scripts. For multiple requests, prefer instantiating
a shared ``HttpClient``.

``post`` and ``put`` accept a ``String`` body (sets
``Content-Type: application/json`` automatically), a ``json.Value``
body (serialised with ``dumps`` first), or a ``List[UInt8]`` body (sent
as raw bytes with no implicit ``Content-Type``).

Example:
    ```mojo
    from dodo.http import get, post, HttpClient, BasicAuth, BearerAuth, Status

    # One-shot GET
    var resp = get("https://httpbin.org/get")

    # One-shot POST JSON — String body sets Content-Type automatically
    var r2 = post("https://httpbin.org/post", '{"k": 1}')

    # Session with base URL and authentication
    with HttpClient("https://httpbin.org", BasicAuth("alice", "s3cr3t")) as c:
        var r = c.get("/basic-auth/alice/s3cr3t")
        r.raise_for_status()
        print(r.text())
    ```

## Aliases

### `DODO_VERSION`

```mojo
comptime DODO_VERSION = String("0.0.1")
```

The library version, as reported in the default ``User-Agent``.

Bump alongside ``pixi.toml`` at release.

### `DEFAULT_USER_AGENT`

```mojo
comptime DEFAULT_USER_AGENT = (String("dodo/") + StringSpan(DODO_VERSION))
```

Default ``User-Agent`` sent when the caller does not set one.

## Structs

### `PoolStats`

```mojo
struct PoolStats
```

A point-in-time view of an ``HttpClient``'s connection pools.

Fields:

- `h1_idle` (`Int`): Idle cleartext HTTP/1.1 connections.
- `tls_idle` (`Int`): Idle HTTPS HTTP/1.1 connections.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

### `HttpClient`

```mojo
struct HttpClient
```

A blocking HTTP client (HTTP/1.1 and HTTP/2).

Opens one connection per request by default; opt into keep-alive
reuse with :meth:`with_pool`. Follows
redirects per a configurable :meth:`with_redirect_policy`, optionally
auto-decompresses responses, retries transient failures via
:meth:`with_retry`, and keeps a session cookie jar via
:meth:`with_cookies`.

This type is ``Movable`` but not ``Copyable``. It supports the context
manager protocol (``__enter__``) for use with ``with``.

Constructors follow a natural ergonomic order:

- ``HttpClient()`` — defaults only
- ``HttpClient("https://api.example.com")`` — base URL positional
- ``HttpClient(BearerAuth("token"))`` — auth first
- ``HttpClient("https://api.example.com", BearerAuth("token"))`` — base URL + auth

Example:
```mojo
# Simple one-liner
var resp = HttpClient().get("https://httpbin.org/get")

# Session with base URL and auth — no repeated prefixes
with HttpClient("https://api.example.com", BearerAuth("tok")) as c:
    c.post("/items", '{"name": "dodo"}').raise_for_status()
    var items = c.get("/items").json()
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `HttpClient.__init__`

```mojo
def __init__(out self, base_url: String = "", max_redirects: Int = Int(10), timeout_ms: Int = Int(30000), user_agent: String = DEFAULT_USER_AGENT, prefer_h2c: Bool = False, h2c_upgrade: Bool = False, auto_decompress: Bool = True)
```

Initialise an ``HttpClient`` with secure defaults.

Args:

- `base_url`: Optional base URL prepended to relative paths.
- `max_redirects`: Maximum number of redirects to follow (default 10).
- `timeout_ms`: Connect timeout in milliseconds (default 30 s). Body reads stay unbounded unless :meth:`with_read_timeout` sets a read timeout.
- `user_agent`: Value for the ``User-Agent`` header.
- `prefer_h2c`: When ``True``, ``http://`` requests speak HTTP/2 over cleartext via prior knowledge. ``https://`` requests always negotiate via ALPN regardless.
- `h2c_upgrade`: When ``True``, ``http://`` requests issue an HTTP/1.1 ``Upgrade: h2c`` handshake (RFC 7540 §3.2) instead of using prior knowledge; the connection switches to HTTP/2 only if the server returns ``101 Switching Protocols``, otherwise it stays on HTTP/1.1.
- `auto_decompress`: When ``True`` (default), compressed response bodies are decoded transparently.

```mojo
def __init__(out self, tls: TlsConfig, base_url: String = "", max_redirects: Int = Int(10), timeout_ms: Int = Int(30000), user_agent: String = DEFAULT_USER_AGENT, prefer_h2c: Bool = False, h2c_upgrade: Bool = False, auto_decompress: Bool = True)
```

Initialise an ``HttpClient`` with custom TLS configuration.

```mojo
def __init__[A: Auth](out self, auth: A, base_url: String = "", max_redirects: Int = Int(10), timeout_ms: Int = Int(30000), user_agent: String = DEFAULT_USER_AGENT, prefer_h2c: Bool = False, h2c_upgrade: Bool = False, auto_decompress: Bool = True) raises
```

Initialise an ``HttpClient`` with authentication.

```mojo
def __init__[A: Auth](out self, base_url: String, auth: A, max_redirects: Int = Int(10), timeout_ms: Int = Int(30000), user_agent: String = DEFAULT_USER_AGENT, prefer_h2c: Bool = False, h2c_upgrade: Bool = False, auto_decompress: Bool = True) raises
```

Initialise an ``HttpClient`` with a base URL and authentication.

#### `HttpClient.__deinit__`

```mojo
def __deinit__(deinit self)
```

Free the pools and cookie jar owned by this client.

Idempotent on a moved-from client (``_pool._addr == 0``).
``HttpClient`` is :trait:`Movable` only, so each heap state is
freed exactly once.

#### `HttpClient.with_pool`

```mojo
def with_pool(var self, max_idle_per_host: Int = Int(8), max_idle_total: Int = Int(64), idle_timeout_ms: Int = Int(90000)) raises -> Self
```

Enable connection pooling on this client.

Returns the client (move-in / move-out so the call chains
with the regular ``HttpClient(...)`` constructor). Two pools
are enabled, both keyed on the origin: the cleartext HTTP/1.1
pool (``http://``, reuses idle fds) and the HTTPS HTTP/1.1 pool
(``https://``, reuses the whole established ``TlsStream`` so the
TLS handshake is skipped on keep-alive reuse). An ``h2``-
negotiated TLS connection is multiplexed on the h2 path and is
not pooled here.

Example:
```mojo
with HttpClient(base_url="https://api.example.com")
    .with_pool() as c:
    # Two GETs reuse the same TLS connection on idle reuse.
    _ = c.get("/users")
    _ = c.get("/items")
```

Args:

- `max_idle_per_host`: Per-origin idle cap. Default ``8``.
- `max_idle_total`: Total idle cap across origins (cleartext pool). Default ``64``. ``0`` disables the total cap.
- `idle_timeout_ms`: Max wallclock age for a pooled connection before lazy eviction. Default ``90_000`` ms.

Returns: ``self`` with pooling enabled.

#### `HttpClient.idle_count`

```mojo
def idle_count(self) -> Int
```

Return the total number of connections currently sitting idle across both keep-alive pools (cleartext HTTP/1.1 fds + HTTPS ``TlsStream`` connections). Returns 0 when pooling is disabled.

#### `HttpClient.tls_idle_count`

```mojo
def tls_idle_count(self) -> Int
```

Return the number of idle HTTPS (TLS HTTP/1.1) connections in the pool. Returns 0 when pooling is disabled.

#### `HttpClient.with_h2c`

```mojo
def with_h2c(var self, prior_knowledge: Bool = True, upgrade: Bool = False) -> Self
```

Choose how cleartext HTTP/2 is reached.

Args:

- `prior_knowledge`: Open with the HTTP/2 preface directly, no negotiation. Correct when you already know the origin speaks h2c.
- `upgrade`: Offer ``Upgrade: h2c`` on an HTTP/1.1 request and switch on a 101. Costs a round trip; works against an origin you have not probed. The streaming calls (:meth:`get_streaming` and friends) do not take this path -- they use prior knowledge when it is set and HTTP/1.1 otherwise.

Returns: The client, for chaining.

#### `HttpClient.pool_stats`

```mojo
def pool_stats(self) -> PoolStats
```

Idle-connection counts for the cleartext and TLS pools.

``idle_count()`` is ``h1_idle + tls_idle``.

Returns: A snapshot; the pools keep moving after it is taken.

#### `HttpClient.with_read_timeout`

```mojo
def with_read_timeout(var self, ms: Int) -> Self
```

Bound body reads, not just ``connect(2)`` (move-in / move-out so it chains off the constructor like :meth:`with_pool`).

``timeout_ms`` only ever reached ``connect``; once the
connection was up a read could block forever. That is what a
half-open connection looks like to the client -- the network
drops after the request goes out, the peer never learns it
should FIN, and ``recv`` waits for bytes that will never
arrive. ``ms`` sets ``SO_RCVTIMEO`` on the socket, so a read
that stalls that long raises ``Timeout`` instead.

The bound is per-read inactivity, not a deadline on the whole
response: a large body that keeps arriving never trips it, and
a stalled one trips it after ``ms`` of silence. The client has
no whole-request deadline.

Set it before the first request. The timeout rides on the
socket, so a connection keeps it for its whole lifetime.
Cleartext pooled fds are re-armed on checkout; pooled TLS
connections keep whatever was armed when they were dialled,
and lowering ``ms`` to ``0`` clears neither.

Example:
```mojo
with HttpClient().with_read_timeout(10_000) as c:
    _ = c.get("https://example.com/")
```

Args:

- `ms`: Read timeout in milliseconds. ``0`` (the default) disables it and restores the unbounded behaviour.

Returns: The client, for chaining.

#### `HttpClient.with_redirect_policy`

```mojo
def with_redirect_policy(var self, policy: RedirectPolicy) -> Self
```

Set the redirect-following policy (move-in / move-out so it chains off the constructor like :meth:`with_pool`).

The default (:meth:`RedirectPolicy.follow_all`) preserves the
legacy unconditional-follow behaviour. Swap in
:meth:`RedirectPolicy.same_origin_only` to refuse cross-origin
redirects (and never leak the Authorization header across
origins), or :meth:`RedirectPolicy.deny` to surface 3xx
responses to the caller unfollowed.

Example:
```mojo
var pol = RedirectPolicy.same_origin_only(max_redirects=5)
with HttpClient("https://api.example.com")
    .with_redirect_policy(pol) as c:
    _ = c.get("/protected")
```

#### `HttpClient.with_retry`

```mojo
def with_retry(var self, policy: RetryPolicy = RetryPolicy()) -> Self
```

Opt into request-level retries on transient failure (move-in / move-out, chains off the constructor).

Retries fire when a request raises (connection/I/O error) or
returns a ``>= 500`` status, up to ``policy.max_attempts``
total attempts. By default only idempotent methods (RFC 9110
sec 9.2.2) are retried; set ``policy.retry_only_idempotent =
False`` to retry any method. Backoff follows the same jittered
exponential schedule as the server-side
:class:`dodo.http.reliability.Retry` middleware.

Example:
```mojo
var pol = RetryPolicy()
pol.max_attempts = 4
pol.initial_backoff_ms = 50
with HttpClient().with_retry(pol) as c:
    _ = c.get("https://flaky.example.com/data")
```

#### `HttpClient.with_max_decompressed_bytes`

```mojo
def with_max_decompressed_bytes(var self, n: Int) -> Self
```

Set the decompressed-size ceiling for auto-decompressed response bodies (move-in / move-out, chains off the constructor).

Guards against a decompression bomb: a small compressed body that
inflates without bound. Defaults to 16 MiB; raise or lower it to
fit the largest legitimate response this client expects.

Example:
```mojo
with HttpClient().with_max_decompressed_bytes(64 * 1024 * 1024) as c:
    _ = c.get("https://example.com/big.json.gz")
```

#### `HttpClient.with_proxy`

```mojo
def with_proxy(var self, proxy_url: String) raises -> Self
```

Route every request through the HTTP proxy at ``proxy_url`` (move-in / move-out, chains off the constructor).

Establishes a ``CONNECT`` tunnel to the origin through the proxy
for both ``http://`` and ``https://`` (TLS then runs over the
tunnel). Overrides the ``HTTP_PROXY`` / ``HTTPS_PROXY`` env
policy; ``NO_PROXY`` is still honored. Pass ``""`` to clear.

Example:
```mojo
with HttpClient().with_proxy("http://127.0.0.1:8080") as c:
    var r = c.get("http://example.com/")
```

#### `HttpClient.with_cookies`

```mojo
def with_cookies(var self) raises -> Self
```

Enable a per-client cookie jar (move-in / move-out, chains off the constructor).

When enabled, the client captures ``Set-Cookie`` response
headers and replays the stored cookies as a ``Cookie`` request
header on subsequent requests -- the standard session-cookie
flow for a logged-in client. The jar is origin-agnostic (every
stored cookie is sent on every request from this client), which
matches the common single-origin ``HttpClient(base_url=...)``
session.

Example:
```mojo
with HttpClient("https://api.example.com")
    .with_cookies() as c:
    _ = c.post("/login", '{"u":"a","p":"b"}')  # stores session
    _ = c.get("/me")                            # replays cookie
```

#### `HttpClient.cookie_header`

```mojo
def cookie_header(self, url: String) raises -> String
```

The ``Cookie`` request header value the jar would send to ``url``, or ``""`` when cookies are disabled / none match. Useful for tests and introspection.

#### `HttpClient.send_chunked`

```mojo
def send_chunked[B: ChunkSource](self, method: String, url: String, mut source: B, content_type: String = "application/octet-stream", body_size: Int = Int(-1), cancel: Cancel = Cancel.never()) raises -> Response
```

Send a request whose body is streamed from a ``ChunkSource`` using ``Transfer-Encoding: chunked``, without materializing the full body in memory.

For large uploads (multi-MB / multi-GB) this keeps client memory
bounded to one chunk in flight: the source's ``next(cancel)`` is
pulled, framed as a chunked-transfer chunk, and written straight
to the socket. The body is never assembled into a single buffer.

This is an explicit bounded-memory path over HTTP/1.1 (cleartext
or TLS, ALPN forced to ``http/1.1``); it deliberately does not
go through connection pooling, redirects, retries, or h2
(all of which buffer or re-send the body). Use :meth:`post` /
:meth:`send` for those.

Args:

- `method`: HTTP method (e.g. ``"POST"`` / ``"PUT"``).
- `url`: Target URL (absolute or relative to ``base_url``).
- `source`: A ``ChunkSource`` yielding body chunks; pulled to exhaustion (``next`` returns ``None``).
- `content_type`: ``Content-Type`` header value. Defaults to ``application/octet-stream``.
- `body_size`: Total body length in bytes when known (sent as ``Content-Length``); negative selects chunked framing.
- `cancel`: Cancellation token checked while the body is pulled.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure.

#### `HttpClient.__enter__`

```mojo
def __enter__(var self) -> Self
```

Transfer ownership of ``self`` into the ``with`` block.

Returns: This ``HttpClient`` (moved).

#### `HttpClient.default`

```mojo
def default() -> Self
```

Return a client with secure defaults (TLS verification enabled).

Returns: An ``HttpClient`` with 30-second timeout and TLS verification.

#### `HttpClient.get`

```mojo
def get(self, url: String) raises -> Response
```

Perform a GET request.

Args:

- `url`: The URL to request (``http://``, ``https://``, or relative path when ``base_url`` is set).

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

#### `HttpClient.get_streaming`

```mojo
def get_streaming(self, url: String) raises -> HttpStreamResponse
```

Stream a GET response body without buffering it.

Works on ``http://`` and ``https://`` alike. The wire is chosen
the way :meth:`send` chooses it, with one exception: ALPN
settles h2 versus HTTP/1.1 on TLS, and cleartext uses HTTP/1.1
unless :meth:`with_h2c` asked for prior-knowledge h2c. The
``Upgrade: h2c`` handshake is the exception -- a streaming
response cannot be re-read if the origin declines the upgrade,
so this path stays on HTTP/1.1 rather than guessing.

The response head is parsed before this returns; the body is
pulled by :meth:`HttpStreamResponse.read_chunk`, so a
multi-gigabyte download costs one buffer rather than one
allocation the size of the body. The connection is exclusive to
this response and is not pooled.

Args:

- `url`: Absolute URL, or a path when the client has a base URL.

Returns: The response head plus an incremental body reader.

Raises: NetworkError: On a connect, TLS or read failure. Error: On an unparseable URL.

#### `HttpClient.post_streaming`

```mojo
def post_streaming(self, url: String, body: String) raises -> HttpStreamResponse
```

POST a JSON body and stream the response.

The shape server-sent events and JSON-lines APIs want: a small
request, then a response read incrementally for as long as the
server keeps writing.

Args:

- `url`: Absolute URL, or a path when the client has a base URL.
- `body`: Request body, sent as ``application/json``.

Returns: The response head plus an incremental body reader.

Raises: NetworkError: On a connect, TLS or read failure.

#### `HttpClient.send_streaming`

```mojo
def send_streaming(self, var req: Request) raises -> HttpStreamResponse
```

Send ``req`` and stream the response body.

The primitive the other two are written in terms of. Redirects,
retries and cookie handling apply only up to the point the head
is parsed; after that the body belongs to the caller and cannot
be replayed, so nothing re-sends it.

Args:

- `req`: The request (ownership transferred). Framing headers on it are ignored -- the writer owns framing.

Returns: The response head plus an incremental body reader.

Raises: NetworkError: On a connect, TLS or read failure. Error: On an unparseable URL or an unusable header.

#### `HttpClient.post`

```mojo
def post(self, url: String, body: String) raises -> Response
```

Perform a POST request with a JSON string body.

Sets ``Content-Type: application/json`` automatically. This is the
default for string bodies because virtually every HTTP API that accepts
a string payload expects JSON.

Example:
```mojo
var resp = client.post("https://httpbin.org/post", '{"key": "value"}')
resp.raise_for_status()
```

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: The JSON request body as a ``String``.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

```mojo
def post(self, url: String, body: Value) raises -> Response
```

Perform a POST request with a ``json.Value`` body.

Serialises ``body`` to JSON with ``dumps`` and sets
``Content-Type: application/json`` automatically.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: A ``json.Value`` to serialise and send.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

```mojo
def post(self, url: String, body: List[UInt8]) raises -> Response
```

Perform a POST request with a raw byte body.

No ``Content-Type`` header is set automatically; the caller is
responsible for setting it via a custom ``Request`` if required.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: The raw request body bytes.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

#### `HttpClient.put`

```mojo
def put(self, url: String, body: String) raises -> Response
```

Perform a PUT request with a JSON string body.

Sets ``Content-Type: application/json`` automatically.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: The JSON request body as a ``String``.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

```mojo
def put(self, url: String, body: Value) raises -> Response
```

Perform a PUT request with a ``json.Value`` body.

Serialises ``body`` to JSON with ``dumps`` and sets
``Content-Type: application/json`` automatically.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: A ``json.Value`` to serialise and send.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

```mojo
def put(self, url: String, body: List[UInt8]) raises -> Response
```

Perform a PUT request with a raw byte body.

No ``Content-Type`` header is set automatically.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: The raw request body bytes.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

#### `HttpClient.delete`

```mojo
def delete(self, url: String) raises -> Response
```

Perform a DELETE request.

Args:

- `url`: The target URL.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

#### `HttpClient.head`

```mojo
def head(self, url: String) raises -> Response
```

Perform a HEAD request.

Identical to ``GET`` but the server MUST NOT include a message body
in the response (RFC 7231 §4.3.2).

Args:

- `url`: The target URL.

Returns: The server's ``Response`` (empty body).

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

#### `HttpClient.patch`

```mojo
def patch(self, url: String, body: String) raises -> Response
```

Perform a PATCH request with a JSON string body.

Sets ``Content-Type: application/json`` automatically.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: The JSON request body as a ``String``.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

```mojo
def patch(self, url: String, body: Value) raises -> Response
```

Perform a PATCH request with a ``json.Value`` body.

Serialises ``body`` to JSON with ``dumps`` and sets
``Content-Type: application/json`` automatically.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: A ``json.Value`` to serialise and send.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

```mojo
def patch(self, url: String, body: List[UInt8]) raises -> Response
```

Perform a PATCH request with a raw byte body.

No ``Content-Type`` header is set automatically.

Args:

- `url`: The target URL (absolute or relative to ``base_url``).
- `body`: The raw request body bytes.

Returns: The server's ``Response``.

Raises: NetworkError: On connection or I/O failure. TooManyRedirects: If the redirect limit is exceeded.

#### `HttpClient.send`

```mojo
def send(self, req: Request) raises -> Response
```

Send an HTTP request and return the response.

Follows redirects per the configured :class:`RedirectPolicy`
(default: follow all, capped at ``max_redirects``), transparently
decodes a compressed body when ``auto_decompress`` is on, and
replays / captures cookies when the jar is enabled. When
:meth:`with_retry` opted in, the whole exchange is retried on a
transient failure per the :class:`RetryPolicy`.

Args:

- `req`: The request to send.

Returns: The final (possibly redirected) ``Response``.

Raises: NetworkError: On I/O failure. TooManyRedirects: If the redirect cap is exceeded. Error: On a cross-origin redirect refused by a ``same_origin_only`` policy.

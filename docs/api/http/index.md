# `dodo.http`

HTTP/1.1 client and server.

Built on `dodo.tcp` and `dodo.tls` — no external HTTP library. Supports
persistent connections, redirects, chunked transfer encoding, gzip/deflate
decompression, and injection-safe header handling.

## Public API

```mojo
from dodo.http import (
    HttpClient, HttpServer,
    Request, Response,
    HeaderMap, HeaderInjectionError,
    Url, UrlParseError,
    Method, Status, Encoding,
    HttpError, TooManyRedirects,
    BasicAuth, BearerAuth,
    get, post, put, delete, head,
)
```

- `HttpClient` — Send HTTP/HTTPS requests: `get`, `post`, `put`, etc.
- `HttpServer` — Accept and dispatch HTTP requests.
- `Request` — HTTP request (method, URL, headers, body).
- `Response` — HTTP response (status, headers, body, `text()`, `json()`).
- `HeaderMap` — Case-insensitive HTTP header collection.
- `HeaderInjectionError` — Raised on CR/LF characters in header names or values.
- `Url` — Parsed HTTP/HTTPS URL (scheme, host, port, path, query).
- `UrlParseError` — Raised on invalid URL syntax.
- `Method` — HTTP method string constants (`GET`, `POST`, …).
- `Status` — HTTP status code integer constants (`OK`, `NOT_FOUND`, …).
- `Encoding` — Content-Encoding token constants (`gzip`, `deflate`).
- `HttpError` — Raised by `Response.raise_for_status()` on non-2xx responses.
- `TooManyRedirects` — Raised when the redirect limit is exceeded.
- `BasicAuth` — HTTP Basic authentication (RFC 7617).
- `BearerAuth` — HTTP Bearer token authentication (RFC 6750).
- `Extractor` — Trait implemented by each extractor.
- `PathInt`, `PathStr`, `PathFloat`, `PathBool`,
  `QueryInt`, `QueryStr`, `QueryFloat`, `QueryBool`,
  `OptionalQueryInt`, `OptionalQueryStr`, `OptionalQueryFloat`, `OptionalQueryBool`,
  `HeaderInt`, `HeaderStr`, `HeaderFloat`, `HeaderBool`,
  `OptionalHeaderInt`, `OptionalHeaderStr`, `OptionalHeaderFloat`, `OptionalHeaderBool`
  — Concrete typed extractors for path params, query string, headers. Each
    exposes ``.value`` as the parsed primitive directly. Custom types are
    handled by writing your own ``Extractor`` struct.
- `Peer`
  — Extracts the kernel-reported peer ``SocketAddr`` populated by the
    reactor at accept time.
- `BodyBytes`, `BodyText`, `Json`, `Cookies`, `Form`, `Multipart`
  — Extractors that read the request body.
- `FormData`, `parse_form_urlencoded`, `urlencode`, `urldecode`
  — ``application/x-www-form-urlencoded`` parsing helpers.
- `MultipartPart`, `MultipartForm`, `parse_multipart_form_data`
  — ``multipart/form-data`` parser (RFC 7578).
- `Extracted`
  — Reflective auto-injection wrapper: put your extractor set on the
    fields of any ``Handler`` struct (plus ``Defaultable``) and wrap
    it in ``Extracted[H]`` to get a ``Handler`` that pulls each field
    from the request before calling the inner ``serve``.
- `ComptimeRoute`, `ComptimeRouter`
  — Comptime-compiled route table: segment parsing runs at compile
    time and the dispatch loop unrolls per route. Same 404 / 405
    contract as ``Router``, parametric over a comptime
    ``List[ComptimeRoute]``.
- `get`, `post`, `put`, `delete`, `head` — Module-level one-shot helpers.
  `post` and `put` accept a `String` (JSON auto-set), `json.Value`
  (auto-serialised), or `List[UInt8]` (raw bytes).

## Example

```mojo
from dodo.http import HttpClient, BasicAuth, BearerAuth, get, post

def main() raises:
    # One-shot GET
    var resp = get("https://httpbin.org/get")
    print(resp.status) # 200

    # One-shot POST — String body sets Content-Type: application/json automatically
    post("https://httpbin.org/post", '{"k": 1}').raise_for_status()

    # Session with base URL + auth — no repeated URL prefix
    with HttpClient("https://httpbin.org", BasicAuth("alice", "s3cr3t")) as c:
        var r = c.get("/basic-auth/alice/s3cr3t")
        r.raise_for_status()
        print(r.text())

    # Parse JSON response body (returns json.Value)
    var data = HttpClient().get("https://httpbin.org/json").json()
    print(data["slideshow"]["title"].string_value())
```

## Packages

- [`dodo.http.cache`](cache/index.md): ``dodo.http.cache`` — RFC 9111 HTTP cache primitives.
- [`dodo.http.ffi`](ffi/index.md)
- [`dodo.http.proto`](proto/index.md): ``dodo.http.proto`` -- pure-function HTTP wire codecs and parsers.
- [`dodo.http.wire`](wire/index.md): Wire-neutral types shared by HTTP/1.1 and HTTP/2.

## Modules

- [`dodo.http.alpn_dispatch`](alpn_dispatch.md): ALPN-driven wire dispatch.
- [`dodo.http.app`](app.md): The App: one front door for routes, typed handlers, state and serving.
- [`dodo.http.async_body`](async_body.md): Reactor-integrated external streaming source.
- [`dodo.http.auth`](auth.md): HTTP authentication helpers.
- [`dodo.http.auth_extract`](auth_extract.md): Server-side authentication extractors + CSRF helper.
- [`dodo.http.body`](body.md): Streaming response body primitives.
- [`dodo.http.cancel`](cancel.md): Cancel token plumbed from the reactor into request handlers.
- [`dodo.http.client`](client.md): HTTP client: HTTP/1.1 and HTTP/2, over TCP or TLS.
- [`dodo.http.client_pool`](client_pool.md): HTTP/1.1 client connection pool.
- [`dodo.http.conditional`](conditional.md): Conditional GET / PUT middleware (RFC 9110 §13).
- [`dodo.http.cookie`](cookie.md): HTTP cookie support (RFC 6265).
- [`dodo.http.cors`](cors.md): ``Cors[Inner]`` middleware (Cross-Origin Resource Sharing).
- [`dodo.http.encoding`](encoding.md): HTTP content-encoding helpers: gzip and deflate via zlib FFI.
- [`dodo.http.error`](error.md): HTTP-level error types.
- [`dodo.http.extract`](extract.md): Typed request extractors with reflective auto-injection.
- [`dodo.http.form`](form.md): ``application/x-www-form-urlencoded`` parsing (WHATWG URL Living Standard, §5.1).
- [`dodo.http.frontend`](frontend.md): HTTP frontends for the multicore :class:`dodo.runtime.Scheduler`.
- [`dodo.http.fs`](fs.md): ``FileServer`` — serve files from a directory with HEAD + Range support.
- [`dodo.http.handler`](handler.md): The ``Handler`` trait: dodo's request-to-response contract.
- [`dodo.http.header_phf`](header_phf.md): Comptime perfect-hash dispatch for ~70 standard HTTP header names.
- [`dodo.http.header_view`](header_view.md): Borrowed header storage.
- [`dodo.http.headers`](headers.md): HTTP header collection with case-insensitive key lookup.
- [`dodo.http.hpack_huffman`](hpack_huffman.md): HPACK Huffman codec — RFC 7541 Appendix B.
- [`dodo.http.hpack_huffman_simd`](hpack_huffman_simd.md): HPACK Huffman fast decoder.
- [`dodo.http.intern`](intern.md): Interned ``StaticString`` table for HTTP method names + common header values.
- [`dodo.http.metrics`](metrics.md): Prometheus-text-exposition metrics middleware.
- [`dodo.http.middleware`](middleware.md): Generic middleware library for .
- [`dodo.http.multipart`](multipart.md): ``multipart/form-data`` parsing (RFC 7578).
- [`dodo.http.multipart_builder`](multipart_builder.md): Client-side ``multipart/form-data`` request-body builder (RFC 7578).
- [`dodo.http.offload`](offload.md): ``Offload``: run a blocking handler on the offload pool (ADR-0004).
- [`dodo.http.proxy_protocol`](proxy_protocol.md): PROXY protocol v1 + v2 parser (HAProxy spec).
- [`dodo.http.redirect_policy`](redirect_policy.md): HTTP redirect policy: configurable cross-origin + auth gating.
- [`dodo.http.reliability`](reliability.md): Reliability middleware: ``Retry`` / ``PostHocDeadline`` / ``RateLimit`` / ``CircuitBreaker`` policies.
- [`dodo.http.request`](request.md): HTTP request type.
- [`dodo.http.request_builder`](request_builder.md): Fluent-ish per-request builder for the HTTP client.
- [`dodo.http.request_chunks`](request_chunks.md): Streaming-shape adapter for inbound request bodies.
- [`dodo.http.request_view`](request_view.md): Zero-copy HTTP request view.
- [`dodo.http.response`](response.md): HTTP response type.
- [`dodo.http.response_pool`](response_pool.md): Per-worker ``Response`` pool.
- [`dodo.http.response_stream`](response_stream.md): Streaming-response plumbing for the normal Handler path.
- [`dodo.http.router`](router.md): HTTP request router with method dispatch + path parameters.
- [`dodo.http.routes`](routes.md): Comptime-compiled route table and ``ComptimeRouter``.
- [`dodo.http.server`](server.md): HTTP server: HTTP/1.1 and HTTP/2, cleartext or TLS, on the reactor.
- [`dodo.http.session`](session.md): Signed cookies + typed sessions.
- [`dodo.http.simd_parsers`](simd_parsers.md): SIMD-friendly byte-scan primitives for the HTTP/1.1 parser hot path.
- [`dodo.http.sse`](sse.md): Server-Sent Events (W3C SSE / RFC 9110 ``text/event-stream``).
- [`dodo.http.status_reason`](status_reason.md): The standard reason phrase for each HTTP status code (RFC 9110 sec 15).
- [`dodo.http.streaming_response`](streaming_response.md): Streaming response with a parametric body type.
- [`dodo.http.streaming_serialize`](streaming_serialize.md): Streaming response serializer.
- [`dodo.http.streaming_server`](streaming_server.md): Typed streaming-handler surface.
- [`dodo.http.structured_logger`](structured_logger.md): Structured (JSON-shaped) request logger middleware.
- [`dodo.http.template`](template.md): Tiny tag-based template engine.
- [`dodo.http.url`](url.md): URL parser for HTTP/HTTPS URLs.

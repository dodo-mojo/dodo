# App layer audit

What the imported core already gives Phase 2 (`docs/design.md` section 9), measured against the API sketch in section 4.
Date: 2026-10-29. Code: `dev` at `6f81011`. Toolchain: Mojo 1.2.0.

## Summary

- **Most of the app layer exists.** Router, typed extractors, middleware, static files, CORS, caching, sessions, cookies, forms, multipart, SSE, templates, auth, metrics, rate limits and JSON with reflection are all there and tested.
- **The front door does not.** There is no `App`, no `state=`, no `{name}` routes, no `json(value)` response and no `req.json[T]()`. A hello server today needs `Router`, `HttpServer`, `SocketAddr` and a hand-set `Content-Type`.
- **Too many ways to write a handler.** A plain `def`, a struct that implements `Handler`, or an `Extracted[H]` struct whose fields are extractors. The sketch wants one: a plain function with typed arguments.
- **Mojo 1.2 can carry the sketch.** Probes show compile-time path checks, typed state taken from the handler's signature, and JSON Schema built at compile time. User decorators and capturing closures do not exist, so routes are registered in `main`.
- **The public surface is large.** `dodo` re-exports 126 names and `dodo.http` 217. "One obvious way" needs a small root API.

Probes: [research/app-api-probes](../research/app-api-probes) (each claim below that says "probe" was compiled and run).

## What exists

| Area | Today | Where |
|---|---|---|
| Routing | `Router` with `:name` params and a final `*` wildcard, a linear scan in registration order, 405 with `Allow`, trailing slashes ignored, literal-prefix `mount`, a `fallback` | `dodo/http/router.mojo` |
| Compile-time routing | `ComptimeRouter[routes]`, segments parsed at compile time, dispatch unrolled | `dodo/http/routes.mojo` |
| Handlers | `Handler` trait (`serve`, plus `may_block` and `blocking`); a plain `def(Request) raises -> Response` is wrapped in `FnHandler` | `dodo/http/handler.mojo` |
| Extractors | `PathInt["id"]`, `QueryStr`, `HeaderBool` and friends, `Json`, `JsonAs[T: FromJson]`, `Form`, `Multipart`, `Cookies`, `Peer`, `State[T]`, used as fields of a struct wrapped in `Extracted[H]`. An extractor error becomes a 400, `AuthError` a 401 | `dodo/http/extract.mojo`, `_extract_*.mojo` |
| Middleware | Generic wrappers around an inner `Handler`: `Logger`, `RequestId`, `Compress`, `CatchPanic`, `Cors`, `Cache`, `Metrics`, `StructuredLogger`, `Retry`, `RateLimit`, `CircuitBreaker` | `dodo/http/middleware.mojo` and others |
| Static files | `FileServer` with ranges | `dodo/http/fs.mojo` |
| JSON | `dodo.json`: `Value`, writer, simdjson parser, reflection serde (`serialize_json`, `deserialize_json`) | `dodo/json/` |
| Errors | `HttpError`, `dodo.errors` | `dodo/http/error.mojo`, `dodo/errors.mojo` |
| Server | `HttpServer.bind`, `bind_tls`, `serve` overloads, `serve_streaming`, `serve_cancellable` | `dodo/http/server.mojo` |

## What Mojo 1.2 allows (probes)

| Question | Answer |
|---|---|
| Route path as a compile-time parameter, checked while compiling | Works. `app.get["/hello/{name}"](hello)` fails the build on an unclosed brace, empty or duplicate name, or a missing leading `/`, with our own message |
| Path params checked against the handler | Works through a params struct: `def hello(req, p: HelloParams)`; a typo in either fails the build. Argument names cannot be read |
| Typed state | Works. `get[S](path, handler: def(Request, S) raises thin -> Response, var state: S)` takes `S` from the handler; a wrong state type is a compile error |
| Handlers of different shapes in one app | Works only as boxed thunks, the way `Router` already stores struct handlers. `List[Handler]` and capturing closures do not compile |
| Struct reflection | Works at compile time: field count, names, types. A full JSON Schema is a compile-time constant. An unsupported field type fails the build, naming the type but not the field |
| User decorators (`@route`) | Do not exist: `unsupported compiler decorator` |
| Wrong handler arity | Fails, but only with `no matching method in call to 'get'` |
| Typed handlers, 0 to 5 arguments | Work on a stand-in App. Marker traits identify each argument. Path typos, a wrong state type and duplicate roles fail the build with a message naming the route |
| Shared state | Boxed once and borrowed: Movable-only state compiles, and 8 threads saw one address with 0 mismatches |
| Middleware | Wrapping the whole app and a boxed `app.use(m)` chain both work. Three pass-through layers cost the same within noise. Stock middleware needs `Copyable`, so wrapping puts the app behind an `ArcPointer` handle |

## Gaps

### Build

1. **`App`**: one struct over `Router` and `HttpServer`: `get/post/...`, `mount`, middleware, `serve(port=)`. Paths are compile-time parameters and checked while compiling.
2. **Handler signatures**: a plain function taking `Request` plus optional typed parts (path params struct, query struct, JSON body struct, state), each found by its type at compile time and filled through reflection. This replaces `Extracted[H]` with extractor fields for app code.
3. **Responses**: `json(value)` (reflection, sets `Content-Type`), `text`, `html`, `redirect`, `status`.
4. **Request body**: `req.json[T]()` through reflection, so a user struct needs no hand-written `parse_json`.
5. **Errors**: problem+json responses with stable codes (`DODO-E0142`), cause, fix and docs link, as text or JSON. `dodo explain <code>`.
6. **Introspection**: `routes()` listing and an OpenAPI document built from the paths and the reflected structs.
7. **CLI**: `dodo new/dev/run/test/routes/doctor`, all with `--json`. `dev` keeps the listening socket open across rebuilds.
8. **Agent tooling**: `dodo docs pull/search` with version-pinned docs and a Mojo 1.x cheat sheet, `AGENTS.md`, `dodo mcp`.

### Change

1. **Route syntax**: `:name` today, `{name}` in the sketch and in OpenAPI.
2. **Root API**: cut `dodo`'s 126 re-exports to what an app needs; the rest stays under `dodo.http`, `dodo.ws` and so on.
3. **Two routers**: `Router` (runtime) and `ComptimeRouter` overlap. Keep one; the lookup structure (the design says radix tree, the code scans a list) is settled by measurement in the performance pass.

### Fix

Items 1 to 3 are fixed and tested: all three were confirmed by failing tests first. The router now decodes params, and literal segments stay undecoded. The rest were read from code, not yet run.

1. The 404 body echoes `req.url`, query string included (`router.mojo:757`, `_server/responses.mojo:156`). Reflecting request input is a bad default; return a fixed body.
2. Registering the same method and path twice is silently accepted, and the first wins (`router.mojo:503`). It should raise.
3. No percent-decoding was found on the router path, so `/users/a%20b` may give the param `a%20b`.
4. `dodo/http/_offload_pool.mojo` triggers deprecation warnings (positional `__getitem__`) in every build that imports `dodo.http`.
5. No tests for `HttpFrontend` or for the reflection serde (`serialize_json`, `deserialize_json`).
6. `docs/design.md` says the router is a radix tree; it is a list.

## Decisions (2026-10-29)

1. **Route syntax:** `{name}` params and a named `{*rest}` catch-all. The old `:name` and bare `*` are errors that show the new form.
2. **Handler model:** plain functions whose typed arguments (path params, query, JSON body, state) are found by type at compile time and filled through reflection. `Handler` and `Extracted` stay as the lower-level layer for middleware and special cases.
3. **Return type:** a handler returns a `Response` or any serializable struct. A struct becomes a 200 JSON response, and its type gives OpenAPI the response schema.
4. **State:** one user-defined state struct, given to `App` once and shared read-only by every worker. Handlers take it as a typed argument. Anything inside that changes (counters, caches) does its own locking.
5. **Middleware:** wrap the whole app in the stock generic wrappers, with `App` holding its shared handle internally. Middleware for some routes goes on a mounted `App`.

## End-to-end run and profile (2026-10-30)

`research/app-bench/` holds the app, the checks (`e2e.py`) and the load script (`load.sh`). Measured on one Apple Silicon Mac with 10 cores, with wrk on the same machine (2 threads, 32 connections), 2 server workers and 5 s per endpoint. Debug symbols were on. These numbers compare endpoints with each other; they are not a benchmark result for the framework.

| Endpoint | Requests/s | p50 | p99 |
|---|---:|---:|---:|
| Bare handler, no App | 227,819 | 111 us | 386 us |
| App, first route | 239,157 | 113 us | 255 us |
| App, literal route after 20 others | 224,950 | 119 us | 326 us |
| One path param, state, JSON response | 197,764 | 135 us | 399 us |
| Two path params | 197,733 | 139 us | 506 us |
| Query params | 220,483 | 126 us | 275 us |
| JSON body | 207,314 | 135 us | 298 us |
| 404 | 225,892 | 119 us | 322 us |

- **Bug found and fixed:** a client that pipelined two requests and then half-closed got only the first response. `_apply_keepalive_policy` closed on `peer_eof` even with a whole request still buffered.
- **Profile:** `sample` over 8 s on the path, query and body endpoints puts 68 to 72% of busy samples in `sendto` and `recvfrom`. The largest dodo symbol is `Router._match` at about 3%.
- **Decision:** no App-layer rewrite. A faster router lookup would gain about 3% at 25 routes, and the larger gain is in syscalls per request, which belongs to the performance pass on Linux.
- **Memory:** RSS stayed flat across sustained load on each endpoint, including 10 s of 400 responses. This is a growth check over seconds, not a leak checker.
- **Not covered:** Linux and epoll, TLS, HTTP/2 through App, and long soak runs.

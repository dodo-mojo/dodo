# ADR-0008: The App API

- Status: accepted
- Date: 2026-10-29

## Context

The imported core has most of an app layer (router, extractors, middleware, JSON with reflection), but no front door. A hello server needs `Router`, `HttpServer`, `SocketAddr` and a hand-set `Content-Type`, and there are three ways to write a handler. Phase 2 needs one obvious way that humans and agents get right the first time, with mistakes caught while compiling ([app-layer-audit.md](../app-layer-audit.md)).

Probes on Mojo 1.2.0 ([research/app-api-probes](../../research/app-api-probes)) show that route paths can be parsed and checked at compile time, that argument and return types can be recovered from a function's type, and that struct fields can be reflected at compile time. Mojo 1.2 has no user decorators and no capturing closures.

## Decision

1. **One `App`.** It owns the router, the state, middleware and the server: `App(state=...)`, `app.get[path](handler)` and the other methods, `app.mount`, `app.serve(port=)`.
2. **Route paths are compile-time parameters** with `{name}` params and a named `{*rest}` catch-all. A malformed path fails the build. The old `:name` and bare `*` are errors that show the new form.
3. **Handlers are plain functions** taking `Request` plus typed arguments, each recognized at compile time by a marker trait on its type (`PathParams`, `QueryParams`, `JsonBody`, `State`) and filled through reflection: a path params struct, a query struct, a JSON body struct, and the app state. The path's `{name}` params are checked against the path struct's fields while compiling. Up to about five typed arguments.
4. **A handler returns a `Response` or any serializable struct.** A struct becomes a 200 JSON response, and its type gives OpenAPI the response schema.
5. **One app state.** A user-defined struct, given to `App` once and shared read-only by every worker, so a model is loaded once. Handlers take it as a typed argument. Anything inside it that changes does its own locking.
6. **Errors are problem+json** (RFC 9457): a bad path, query or body is a 400 that names the field; an unhandled error is a 500 that hides its message unless dev mode is on.
7. **Lower layers stay.** `Router`, `Handler`, `Extracted` and the stock middleware remain under `dodo.http` for middleware authors and special cases. The `dodo` root exports only what an app needs.

## Consequences

- An app reads like FastAPI or axum, and route, signature and state mistakes fail the build.
- Every typed argument count needs its own overload, so the count is capped.
- Compile-time errors from a failed check arrive under a generic `function instantiation failed` line; our messages must name the route and the field to be useful.
- Code written against `:name` routes breaks with a message that says how to fix it.

## Open

- How middleware attaches to `App`. Probes show both forms work at about the same cost: wrapping the whole app in generic wrappers, which reuses the stock middleware, or a boxed `app.use(m)` chain.
- Whether `Router` and `ComptimeRouter` merge, and the lookup structure: settled with numbers in the performance pass.

## Alternatives considered

- Keep `Extracted` structs with extractor fields as the main style: works today, but more code per handler and no compile-time path check.
- Per-route `state=`: each worker copies its route's state, which is wrong for a model that must load once.
- Decorators (`@app.get("/x")`): not available in Mojo 1.2.

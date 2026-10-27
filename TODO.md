# TODO

## You (needs your account, payment or judgment)

- [ ] **Buy a domain** (later). Available at Porkbun on 2026-10-26:
  - `dodomojo.dev`: $8.75 first year, renews $12.87
  - `usedodo.dev`: $8.75 first year, renews $12.87
  - `dodomojo.com`: $11.08/year
  - `dodo.*` is taken or premium almost everywhere (`dodo.app` is listed at $79,999).
  - Optional: `dodo-mojo.github.io` is free with the org.
- [ ] **Claim social handles** (optional). Free on 2026-10-26: X `@dodo_mojo`, Bluesky `dodomojo.bsky.social`, YouTube `@dodo-mojo`. Taken: X `@dodomojo`, YouTube `@dodomojo`, Bluesky `dodo`.
- [ ] **Trademark search** for "dodo" in software (class 9/42) in your country, before 1.0.

## Claude (after the items above are unblocked)

- [ ] Performance pass: set up a bare-metal Linux benchmark box (cloud VM is fine); profile the HTTP/1.1 hot path (allocations, copies, syscalls per request); rewrite or remove what's slow; benchmark against other Mojo frameworks and the fastest Rust/Go servers.
- [ ] Clean imported code as we touch it: remove Flare's changelog-style and personal comments, restyle to our standards.
- [ ] Phase 0 spikes (see `docs/design.md` §9).
- [ ] Publish `0.0.1` and open the modular-community PR using `packaging/recipe.yaml`. This claims the `dodo` package name and needs a minimal working server.
- [ ] Enable GitHub Pages for docs at `dodo-mojo.github.io/dodo`.
- [ ] PyPI `dodo-mojo`: only if we ship a pip-installable CLI.
- [ ] Review, after the offload pool lands: is it worth folding `serve_cancellable`'s `Cancel` support and the streaming loop into the unified loop, so the remaining separate loops can be deleted? Weigh the code removed against the risk and the performance-pass numbers.
- [ ] Rebuild the live-server checks the import dropped (they needed upstream's benchmark and example servers): h2spec, the Autobahn WebSocket suite, curl/h2load interop, and ASan/TSan runs. Each needs a small test server under `tests/`. The audit probes (`research/flare-audit/probe.py`) belong there too.
- [ ] Lingering close (after an early error response) runs only on the unified loop for cleartext. The HTTP/1.1-only loops (`serve_cancellable`, io_uring) and TLS still close at once.
- [ ] `H1LeniencyConfig.allow_lf_only_line_endings` only reaches the parser: the reactor frames on CRLFCRLF, so a bare-LF head never completes. Support it in the reactor or drop the flag.
- [ ] The io_uring buffer-ring loop is never chosen with the default config (it needs every timeout off and `max_connections < 0`). Decide whether it should arm timers or be removed. It also sets `Request.peer` to a loopback placeholder.
- [ ] `RequestView` (zero-copy request) has no server loop since `serve_view` was removed. The performance pass decides whether the unified loop parses into it or it is deleted.
- [ ] Keep-alive idle timeout defaults to 500 ms; `docs/design.md` says 5 s. Settle it in the performance pass (short is cheaper under load, long saves reconnects).
- [ ] Dedupe the status reason-phrase tables: two copies (`_server/write.mojo`, `streaming_serialize.mojo`).
- [ ] Decide on `json` and `mozz` (git dependencies from the upstream author): keep, vendor, or replace.
- [ ] Model workers (ADR-0005, proposed): supervised child processes for models and kernels, shared-memory handoff, per-worker CPU/RAM/GPU limits as ratios or amounts of the box (container or machine), restarts, `/healthz` and `/readyz`. Accept the ADR first.
- [ ] Outgoing calls on the event loop (ADR-0006, proposed): an HTTP client on the worker's loop, so a handler starts several calls and parks until they answer. Accept the ADR first.
- [ ] Dedupe `_monotonic_ms`: four copies (`client_pool`, `tls_pool`, `keepalive_scan`, `runtime._libc_time`), and the client-pool ones allocate on every call.

## Developer experience and AI agents (Phase 2 and later)

Agents know little Mojo, and it changes fast, so these come first:

- [ ] `dodo docs`: pull agent-friendly Markdown docs for the exact versions in use into the project (`.dodo/docs/mojo-1.2/`, `.dodo/docs/dodo-0.1/`). `dodo docs pull` takes the versions from the project; `dodo docs pull mojo@1.2 dodo@0.1` asks for others. The generated AGENTS.md points agents there. `dodo docs search "<query>"` searches them, with `--json`.
- [ ] Mojo 1.x cheat sheet for agents in those docs: what changed (no `fn`, explicit `raises`, `comptime`, `std.` paths) with before and after examples.
- [ ] `dodo fix`: rewrite outdated Mojo syntax automatically, like `cargo fix`.
- [ ] Compiler error explainer: wrap `mojo build` and turn common errors into a plain cause and a fix, as text or JSON.
- [ ] Claude Code plugin with skills ("add a route", "profile this", "debug a 500"), next to `dodo mcp`.

Faster feedback:

- [ ] `dodo verify`: build, tests, lints and a benchmark comparison in one command, with one JSON verdict.
- [ ] `dodo why <request-id>`: every error response carries a request id; the command explains what happened to it (route, middleware, timings, error).
- [ ] Record and replay: capture real requests in dev and replay them as snapshot tests (`dodo record`).
- [ ] Hot reload that keeps models loaded: swap code on save while model workers (ADR-0005) keep their weights.

Convenience:

- [ ] Typed TypeScript and Python clients generated from the routes at compile time.
- [ ] Fake models and GPUs: deterministic stand-ins so tests and CI run without a GPU or API keys.
- [ ] Dev dashboard at `/_dodo` (dev only): routes, recent requests, traces, a "try it" box.
- [ ] Starters: `dodo new --template chat|rag|vision|agent`.
- [ ] One typed config file, overridden by environment variables, checked at startup; `dodo config --json` prints it.
- [ ] `dodo port fastapi`: turn a FastAPI app's routes into a dodo skeleton.

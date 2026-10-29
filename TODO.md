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
- [ ] Live-server checks: `tests/live/` runs h2spec and the Autobahn WebSocket suite against `tests/live/live_server.mojo`, with ASan/TSan through `LIVE_SANITIZE`. Still missing: curl/h2load interop, the audit probes (`research/flare-audit/probe.py`), and a CI job that runs them.
- [ ] `RequestView` (zero-copy request) has no server loop since `serve_view` was removed. The performance pass decides whether the unified loop parses into it or it is deleted.
- [ ] Keep-alive idle timeout defaults to 500 ms; `docs/design.md` says 5 s. Settle it in the performance pass (short is cheaper under load, long saves reconnects).
- [ ] Dedupe the status reason-phrase tables: two copies (`_server/write.mojo`, `streaming_serialize.mojo`).
- [ ] Decide on `json` and `mozz` (git dependencies from the upstream author): keep, vendor, or replace.
- [ ] Dedupe `_monotonic_ms`: four copies (`client_pool`, `tls_pool`, `keepalive_scan`, `runtime._libc_time`), and the client-pool ones allocate on every call.

# TODO

## You (needs your account, payment or judgment)

- [ ] **Create GitHub org `dodo-mojo`.** https://github.com/account/organizations/new, Free plan. GitHub has no API for this, and it means accepting GitHub's terms. Then tell Claude, who creates `dodo-mojo/dodo` and pushes.
- [ ] **Buy a domain** (later). Available at Porkbun on 2026-10-26:
  - `dodomojo.dev`: $8.75 first year, renews $12.87
  - `usedodo.dev`: $8.75 first year, renews $12.87
  - `dodomojo.com`: $11.08/year
  - `dodo.*` is taken or premium almost everywhere (`dodo.app` is listed at $79,999).
  - Optional: `dodo-mojo.github.io` is free with the org.
- [ ] **Claim social handles** (optional). Free on 2026-10-26: X `@dodo_mojo`, Bluesky `dodomojo.bsky.social`, YouTube `@dodo-mojo`. Taken: X `@dodomojo`, YouTube `@dodomojo`, Bluesky `dodo`.
- [ ] **Trademark search** for "dodo" in software (class 9/42) in your country, before 1.0.

## Claude (after the items above are unblocked)

- [ ] Create `dodo-mojo/dodo`, then the first commit and push (needs the org).
- [ ] Performance pass: set up a bare-metal Linux benchmark box (cloud VM is fine); profile the HTTP/1.1 hot path (allocations, copies, syscalls per request); rewrite or remove what's slow; benchmark against other Mojo frameworks and the fastest Rust/Go servers.
- [ ] Clean imported code as we touch it: remove Flare's changelog-style and personal comments, restyle to our standards.
- [ ] Phase 0 spikes (see `docs/design.md` §9).
- [ ] Publish `0.0.1` and open the modular-community PR using `packaging/recipe.yaml`. This claims the `dodo` package name and needs a minimal working server.
- [ ] Enable GitHub Pages for docs at `dodo-mojo.github.io/dodo`.
- [ ] PyPI `dodo-mojo`: only if we ship a pip-installable CLI.
- [ ] Fix audit findings F1–F10 from `docs/flare-audit.md` in the imported code.
- [ ] Rebuild the live-server checks the import dropped (they needed upstream's benchmark and example servers): h2spec, the Autobahn WebSocket suite, curl/h2load interop, and ASan/TSan runs. Each needs a small test server under `tests/`.
- [ ] `IoUringSqe` reads non-zero when its test shares a process with a real io_uring round trip (`tests/runtime/test_io_uring_sqe.mojo` runs standalone for now). Suspected use-after-free of the SQE buffer while the kernel still holds it.
- [ ] Decide on `json` and `mozz` (git dependencies from the upstream author): keep, vendor, or replace.
- [ ] Each pooled-connection test in `tests/http/test_h2_client_pool.mojo` and `test_client_pooled_framing.mojo` takes about 3 minutes (same before the import). Find what it waits on; it's most of the suite's run time.
- [ ] Dedupe `_monotonic_ms`: four copies (`client_pool`, `tls_pool`, `keepalive_scan`, `runtime._libc_time`), and the client-pool ones allocate on every call.

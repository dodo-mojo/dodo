# ADR-0003: Fork Flare as dodo's networking core

- Status: accepted
- Date: 2026-10-26

## Context

dodo planned to write its own networking core after Lightbug failed our audit. Flare (MIT, Mojo 1.2) already has HTTP/1.1, 2 and 3, TLS, WebSocket, SSE, a router and middleware on a thread-per-core reactor. It passed our audit ([flare-audit.md](../flare-audit.md)). One maintainer wrote about 97% of it.

## Decision

We hard-fork Flare v0.13.0 (commit `8fe83c5`) into dodo. From then on the code is dodo's own:

1. **One import commit, no history.** Flare's git history is not carried over. The import is a single commit in our format.
2. **Renamed to dodo.** `flare.*` becomes `dodo.*` (`flare.http` → `dodo.http`, and so on), including env vars, log prefixes and library names. Users and docs never see the name Flare.
3. **Our conventions only.** Code follows `docs/engineering-standards.md`, not Flare's style. Flare's changelog-style and personal comments (version notes, step numbers, audit IDs) are removed or rewritten as we touch each file.
4. **Only what dodo needs.** Anything off dodo's roadmap is cut at import; it can be restored from the snapshot if the roadmap changes.
   - **Kept:** the reactor and scheduler (`runtime`), sockets (`net`, `tcp`, `uds`, `io`), `dns`, `http` (server, router, middleware, extractors, SSE, client), `http2`, `ws`, `tls`, `crypto`, `utils`, `testing`. The HTTP client, DNS and TLS stay because `dodo.agent` calls remote model APIs over HTTPS. Unix sockets stay because proxy → app over a Unix socket is faster than TCP.
   - **Cut:** `quic`, `http3`, `qpack` and `udp` (about 22k lines; this also removes the Rust toolchain from the build), `grpc`, `openapi` (dodo generates OpenAPI from its own compile-time reflection), `prelude` (dodo has its own).
   - **Not imported:** docs, benchmarks, examples, agent and editor configs, and the Lean proofs (`formal/`, which need a Lean toolchain; revisit later).
5. **Fastest Mojo framework.** Speed is a release requirement, not a later goal:
   - The HTTP/1.1 hot path pays nothing for HTTP/2, TLS or WebSocket support it isn't using.
   - We profile before cutting. Allocations, copies and syscalls per request are measured, and anything slow on the hot path is rewritten or removed.
   - Benchmarks run on bare-metal Linux (WSL2's clock and network distort results), against every other Mojo HTTP framework and, as the real bar, the fastest Rust and Go servers on TechEmpower-style plaintext and JSON tests.
6. **No upstream tracking.** We fix things ourselves (audit findings F1–F10). We may still read Flare's later changes for security fixes and port them by hand.
7. **License notice stays.** MIT requires Flare's copyright and license text to ship with the code. It lives in `THIRD_PARTY_NOTICES.md` only, as it does for Lightbug. That is the one place the name appears.

## Consequences

- dodo owns about 85k lines of networking code on day one, after the cuts. Roadmap Phases 1–2 become renaming, cleanup and hardening, not writing a server.
- We carry all maintenance, with no upstream to share it. In exchange, nothing outside dodo can break or slow us.
- The audit findings become dodo bugs to fix in the import, not upstream PRs.

## Alternatives considered

- Depend on Flare as a pinned package: least work, but dodo would follow another project's conventions and pace, and depend on one maintainer.
- Our own core from scratch: months of work to reach where Flare is today.

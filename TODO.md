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
- [ ] **Docker Desktop WSL integration** (optional): turn it on for Ubuntu-24.04 so `pixi run tests-db` can start the test databases from WSL. Until then, start them from Windows (`docker compose -f tests/live/db/compose.yaml up -d --wait`) and run with `DODO_DB_NO_COMPOSE=1`.

## Claude (after the items above are unblocked)

- [ ] Performance pass: set up a bare-metal Linux benchmark box (cloud VM is fine); profile the HTTP/1.1 hot path (allocations, copies, syscalls per request); rewrite or remove what's slow; benchmark against other Mojo frameworks and the fastest Rust/Go servers.
- [ ] Clean imported code as we touch it: remove Flare's changelog-style and personal comments, restyle to our standards.
- [ ] Phase 0 spikes (see `docs/design.md` §9).
- [ ] Publish `0.0.1`: tag `v0.0.1` on `production`, then open the modular-community PR with `packaging/recipe.yaml` and `packaging/tests/` as `recipes/dodo/`. The recipe builds and passes its tests on macOS arm64 and Linux aarch64 (`packaging/build_local.sh`); Linux x86-64 is checked only by the channel's CI.
- [ ] Enable GitHub Pages for docs at `dodo-mojo.github.io/dodo`.
- [ ] PyPI `dodo-mojo`: only if we ship a pip-installable CLI.
- [ ] Review, after the offload pool lands: is it worth folding `serve_cancellable`'s `Cancel` support and the streaming loop into the unified loop, so the remaining separate loops can be deleted? Weigh the code removed against the risk and the performance-pass numbers.
- [ ] Live-server checks: `tests/live/` runs h2spec and the Autobahn WebSocket suite against `tests/live/live_server.mojo`, with ASan/TSan through `LIVE_SANITIZE`. Still missing: curl/h2load interop, the audit probes (`research/flare-audit/probe.py`), and a CI job that runs them.
- [ ] `RequestView` (zero-copy request) has no server loop since `serve_view` was removed. The performance pass decides whether the unified loop parses into it or it is deleted.
- [ ] Keep-alive idle timeout defaults to 500 ms; `docs/design.md` says 5 s. Settle it in the performance pass (short is cheaper under load, long saves reconnects).
- [ ] Model workers (ADR-0005): supervised child processes for models and kernels, shared-memory handoff, per-worker CPU/RAM/GPU limits as ratios or amounts of the box (container or machine), restarts, `/healthz` and `/readyz`.
- [ ] Outgoing calls on the event loop (ADR-0006): an HTTP client on the worker's loop, so a handler starts several calls and parks until they answer.
- [x] Database drivers (ADR-0009): PostgreSQL/CockroachDB, MySQL/MariaDB, SQLite, Redis/Valkey, MongoDB and ClickHouse in `dodo.db`, one shared pool, unit tests in `tests/db/`, Docker suites in `tests/live/db/` (`pixi run tests-db`).
- [x] `blocking=True` on App routes (ADR-0004, ADR-0009), so a typed handler that queries a database runs on the offload pool. Usage guide: `docs/databases.md`.
- [x] Database migrations (ADR-0010): `db.migrate(Migrations.from_dir("migrations"))` on `Postgres`, `MySql` and `Sqlite`; checksums, a `dodo_migrations` table, safe when several processes start at once. A `dodo migrate` CLI can wrap it later.
- [ ] PostgreSQL `LISTEN/NOTIFY` and `COPY` (ADR-0011): `PgListener` with `listen`, `wait` and reconnecting by itself, `db.notify`, `copy_in`/`copy_out` and their streaming forms, text and CSV formats.
- [ ] CI job for `pixi run tests-db`: the compose services on the Ubuntu runner, `DODO_DB_NO_COMPOSE=1` if they come up as job services.
- [ ] Fuzzers for the database parsers: PostgreSQL messages, MySQL packets and rows, RESP replies, BSON and OP_MSG, ClickHouse RowBinary.
- [ ] Database follow-ups when someone needs them: prepared-statement caches (PostgreSQL, MySQL, SQLite), ClickHouse bulk insert in RowBinary, MongoDB replica sets and `mongodb+srv://`, Redis pub/sub on a dedicated connection, typed dates.
- [x] App API (ADR-0008): `App`, compile-time `{name}` paths, typed-argument handlers, struct or `Response` returns, one shared app state, problem+json errors.
- [x] Shrink the `dodo` root to what an app needs (ADR-0008 point 8).
- [x] Router fixes from `docs/app-layer-audit.md`: fixed 404 body, duplicate routes and mounts raise, path params are percent-decoded once by the router.
- [x] Deprecation warnings from `dodo/http/_offload_pool.mojo` (positional `__getitem__`) in every build.
- [x] Tests for `HttpFrontend` and the reflection serde (`serialize_json`, `deserialize_json`).
- [ ] `HttpFrontend.run_worker` and `StreamFrontend.run_worker` swallow every error from the reactor loop with `except: pass`. Check whether a worker that fails this way goes unnoticed, and report it if so.
- [ ] `docs/design.md` calls the router a radix tree; it scans a list. Fix the text once the performance pass picks the lookup. `Router._match` is about 3% of busy samples at 25 routes (`docs/app-layer-audit.md`); recheck with hundreds of routes.

## `dodo` CLI (branch `feat/cli`, in progress)

Scope: `new`, `run`, `dev`, `test`, `routes`, `doctor`, `docs pull`. Every command has `--json`, stable exit codes and no prompts without a TTY. `dodo mcp` is the next PR.

Decisions (asked one at a time):

- [x] 1. Language of the CLI: Mojo, one binary in the conda package; docs pull uses dodo's own HTTP client
- [x] 2. Where the CLI lives in the repo: top-level `cli/` (built to `bin/dodo`), tests in `tests/cli/`; it imports dodo like any app
- [x] 3. Docs archive: `mojo-docs/<version>/` built from Modular's `mojo/v<version>` tag (MDX to plain Markdown, plus the stdlib API generated with `mojo doc`); dodo's docs in `docs/` (with `best-practices/` and generated `api/`), copied to `dodo-docs/<version>/` at each release (changed 2026-11-08: the v0.0.1 tag has no index, and short versions need a version list). Both are read from `dev`. Each folder has an llms.txt-shaped `index.md`, the only file list. The AGENTS.md from `dodo new` points to the pulled indexes instead of embedding one (changed 2026-11-11: an embedded copy goes stale).
- [x] 4. `dodo dev`: polls file times every 200 ms (0.2 ms for 253 files; folders relisted only when their time changes). It owns the listening socket and passes it as `DODO_LISTEN_FD`; all workers share it. It builds before stopping the old app, which drains in-flight requests on SIGTERM.
- [x] 5. `dodo routes`: `App` keeps a list of (method, path, blocking), mounts included; run with `DODO_ROUTES=json`, `app.serve` prints it and exits without binding. Has a timeout, since `main` runs up to `serve`.
- [x] 6. `dodo test`: every `tests/**/test_*.mojo` is a `TestSuite` program, built into its own binary in parallel (2.1 s each against the package), skipped when no `.mojo` changed; one report or `--json`. Exit 0 pass, 1 test failed, 2 build failed.

- [x] 7. Argument parser: our own small one (argmojo pins Mojo 1.2.x, so it would hold back upgrades).

Build order, each step tested end to end before the next:

- [x] Process spawning: posix_spawn, a waitpid that returns the exit status, passing Ctrl-C and SIGTERM on
- [x] CLI core: argument parsing, `--json` output, exit codes, TTY check
- [x] Docs archive: Mojo 1.2.0 split into topic files with an index, the Mojo 1.x cheat sheet, dodo's docs per release, the save-a-new-release tool, license check and credit
- [x] `dodo docs pull`: project versions, `--mojo`/`--dodo` and `mojo@1.2 dodo@0.1`, short versions, every error case, never delete docs on a failed pull
- [ ] First release that saves its docs (`tools/save_docs.py dodo --release`); until then the dodo half of `dodo docs pull` finds none, since dev still says 0.0.1
- [x] `dodo new`: pixi.toml (dodo from modular-community, pinned), main.mojo, app.mojo, tests/, AGENTS.md, CLAUDE.md (`@AGENTS.md`), .gitignore; only writes files; `git init` unless `--no-git` or inside a repository. No TODO.md, ADRs or commit hook: those are the dodo repo's own habits, not every app's (decided 2026-11-11).
- [x] `dodo run`, `dodo test`, `dodo routes`, `dodo doctor`
- [x] Planted-mistake check for the CLI (`pixi run check-mistakes`): 61 mistakes, all caught
- [x] `dodo dev`: change detection, restart, socket kept open across restarts
- [ ] Packaging: `mojo build` installs `$PREFIX/bin/dodo`, recipe tests cover it. Until then a project from `dodo new` has no `dodo` command (checked 2026-11-11 with `build/bin/dodo` on `PATH` and the local package).
- [ ] Profile every command (startup, docs pull, dev restart time) and fix the slow parts, with before/after numbers
- [x] Retire `tools/docs_pull.py`; update CLAUDE.md, design.md and README
- [ ] Planted mistakes for the library too (HTTP parser, router, scheduler, drivers), added as each area is next touched

## After v1

- [ ] Best practices guide in `docs/best-practices/`, examples built in CI; the rule in CONTRIBUTING.md, the PR template and CLAUDE.md. Written once the API it describes is stable.

## Mojo ecosystem (survey in `docs/ecosystem.md`, 2026-11-04)

Rule: learn from other packages and write our own; copy code only under a permissive license (never GPL or EUPL), with a credit in `THIRD_PARTY_NOTICES.md`. Most packages pin Mojo 1.0 or 1.1, so a dependency would hold back our upgrades.

- [x] CLI: read mtest's runner for edge cases (hung tests, crashes, stray child processes, cached builds) before finishing `dodo test`.
- [ ] Phase 3 AI: safetensors-mojo (weights), mbpe (tokens and budgets).
- [ ] Phase 3b agents: mojo-regex (scorers, guardrails), uuid (request, trace and run ids).
- [ ] Phase 3c vision: compare mosaic-mojo with our preprocessing kernels.
- [ ] Phase 4 profiling: professor's spans.
- [ ] Phase 5 gRPC: protomojo and grpc-mojo on our HTTP/2.
- [ ] Database drivers: morrow for typed dates. Auth middleware: mcrypto for password hashing and token signing.

## Developer experience and AI agents (Phase 2 and later)

Agents know little Mojo, and it changes fast, so these come first:

- [x] `pixi run docs-pull` (`tools/docs_pull.py`): pulls the Mojo docs for the toolchain in use (`.dodo/docs/mojo-1.2.0/`, from mojolang.org) and dodo's guides plus `mojo doc` API JSON (`.dodo/docs/dodo-0.0.1/`). Retired 2026-11-08: replaced by `dodo docs pull` and the archives in `mojo-docs/` and `docs/`.
- [ ] `dodo docs`: the CLI form of the above, with versions from the project and `dodo docs pull mojo@1.2 dodo@0.1` for others. mojolang.org serves only the latest release, so pulling an older Mojo needs another source. The generated AGENTS.md points agents there. `dodo docs search "<query>"` searches them, with `--json`.
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

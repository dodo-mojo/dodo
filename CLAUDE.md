# dodo

A Mojo web framework where HTTP, AI models (MAX), GPU kernels and agent harnesses run in one process. Built for humans and AI agents. Apache-2.0. GitHub: `dodo-mojo/dodo` (public). Work and PRs go to `dev` (the default branch); `production` is for releases.

**Status:** networking core imported (ADR-0003): HTTP/1.1, HTTP/2, TLS, WebSocket, client, reactor. It's our code now: dodo names, our conventions, no upstream history. The upstream name appears only in `THIRD_PARTY_NOTICES.md` (MIT requires it). Audit fixes F1–F10 done except F7 (offload pool, ADR-0004 proposed). Next: the performance pass.

## Read first

- `docs/design.md`: architecture, API sketch, roadmap. This is the source of truth for the plan.
- `docs/engineering-standards.md`: how we write code, tests, docs, commits. **Follow it.**
- `docs/adr/`: major decisions only. Read before changing anything they cover.
- `TODO.md`: open tasks, split into what the human does and what Claude does.

## Layout

| Path | What |
|---|---|
| `dodo/` | The library. `http`, `http2`, `ws`, `tls`, `tcp`, `uds`, `dns`, `net`, `runtime`, `crypto`, `io`, `testing`, `utils`. Native wrappers in `dodo/*/ffi/`. |
| `tests/` | One dir per package. `tests/tools/run_tests.sh` builds one binary per dir from `tests/_agg/` (generated). |
| `fuzz/` | mozz fuzzers, one per parser |
| `docs/` | Design, audits (`lightbug-audit.md`, `flare-audit.md`), naming, standards, ADRs |
| `research/` | Throwaway spikes and audit harnesses (probe servers, fuzzers). Not shipped. |
| `packaging/recipe.yaml` | Draft modular-community recipe for the `dodo` package |

## Toolchain

- Mojo has no Windows support. Build and run everything in **WSL Ubuntu-24.04**: `wsl -d Ubuntu-24.04 -- bash -l`.
- Mojo 1.2.0 and MAX/modular 26.7.0 via pixi (`~/.pixi/bin`). The repo is used from WSL as `/mnt/e/dodo`; `.pixi/config.toml` keeps the env off the Windows drive.
- `pixi run tests` runs everything (about 2,450 tests). After adding a test file: `pixi run tests-gen`. One file: `pixi run mojo -I . tests/http/test_x.mojo`. Use `AGG_JOBS=2` on 16 GB machines.
- Mojo 1.x: `def` only (`fn` is removed), and `raises` must be explicit. GPU code is under `max.gpu`.
- The GPU is an RTX 5070, verified working.
- Reference clones live in WSL under `~/src/`.
- WSL2's wall clock jumps 2–3 s when it resyncs. Time benchmarks with a monotonic clock, or rerun any `wrk` run with a p99 around 1–2 s.
- **Stale builds after Windows-side edits:** WSL can keep old memory-mapped pages of a file edited from Windows, and Mojo compiles that old code. Before building, run `wsl -d Ubuntu-24.04 -u root -- sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"`. Never trust a binary from a build whose exit status you didn't check.

## Rules that bite

- Commits: `type: one line`, with no em dashes, no body, and **no Claude co-author trailer**. Only commit when asked.
- Ask the human one decision at a time, with a recommendation.
- Simple, readable code over clever code. No dense one-liners.
- Goal: the fastest Mojo framework. Profile before optimizing; show before/after numbers on hot-path PRs; delete code nothing on the roadmap uses.
- Major decision → write an ADR. Anything smaller → `TODO.md`.
- Test every UI input and button against its edge cases in the built-in browser.
- In imported code, delete changelog-style or personal comments ("v0.11:", "C7:", "Step 2") whenever you touch a file. Never follow the original project's conventions.
- Update this file when layout, commands or decisions change. Keep it under about 60 lines; link, don't copy.

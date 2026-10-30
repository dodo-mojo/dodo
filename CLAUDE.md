# dodo

A Mojo web framework where HTTP, AI models (MAX), GPU kernels, computer vision and agent harnesses run in one process. Built for humans and AI agents. Apache-2.0. GitHub: `dodo-mojo/dodo` (public). Work and PRs go to `dev` (the default branch); `production` is for releases.

**Status:** networking core imported (ADR-0003): HTTP/1.1, HTTP/2, TLS, WebSocket, client, reactor. It's our code now: dodo names, our conventions, no upstream history. The upstream name appears only in `THIRD_PARTY_NOTICES.md` (MIT requires it). Audit fixes F1–F10 done; F7 is `Offload(handler)`, a pool for blocking handlers on every server loop; the pool keeps its own copy of the handler, sharing one that is not `Copyable` through `SharedHandler` (ADR-0004). io_uring is removed; Linux uses epoll, macOS kqueue (ADR-0007). Accepted, not built yet: model workers in supervised child processes with per-worker limits (ADR-0005) and outgoing calls on the event loop (ADR-0006). The App API is built (`dodo/http/app.mojo`, ADR-0008). Next: the rest of Phase 2, then the performance pass.

## Read first

- `docs/design.md`: architecture, API sketch, roadmap. This is the source of truth for the plan.
- `docs/engineering-standards.md`: how we write code, tests, docs, commits. **Follow it.**
- `docs/adr/`: major decisions only. Read before changing anything they cover.
- `TODO.md`: open tasks, split into what the human does and what Claude does.

## Layout

| Path | What |
|---|---|
| `dodo/` | The library. `http`, `http2`, `ws`, `tls`, `tcp`, `uds`, `dns`, `net`, `runtime`, `crypto`, `io`, `json` (vendored, see `THIRD_PARTY_NOTICES.md`), `testing`, `utils`. Native wrappers in `dodo/*/ffi/`. |
| `tests/` | One dir per package. `tests/compile_fail/` holds programs that must fail to build with the message in their first line. `tests/tools/run_tests.sh` builds one binary per dir from `tests/_agg/` (generated). |
| `fuzz/` | Fuzzers, one per parser, on the vendored harness in `fuzz/mozz/` |
| `docs/` | Design, audits (`lightbug-audit.md`, `flare-audit.md`, `app-layer-audit.md`), naming, standards, ADRs |
| `research/` | Throwaway spikes and audit harnesses (probe servers, fuzzers). Not shipped. |
| `packaging/recipe.yaml` | Draft modular-community recipe for the `dodo` package |
| `.github/` | CI (`pixi run tests` on Ubuntu and macOS, on every PR; both jobs are required to merge into `dev`), issue and PR templates, Dependabot for actions |
| `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` | Community files. README stays short: the vision and roadmap, no walls of text. |

## Toolchain

- Two dev machines. **macOS (Apple Silicon):** native, repo at `~/anubhav/dodo`, kqueue backend, FFI wrappers built with clang++. **Windows:** Mojo has no Windows support, so build in **WSL Ubuntu-24.04** (`wsl -d Ubuntu-24.04 -- bash -l`), repo at `/mnt/e/dodo`. Linux-only code (epoll, accept balancing) is only tested on WSL. macOS has no `-z nodelete`, so each wrapper library pins itself (`dodo/utils/ffi/pin_self.h`); never overwrite an installed `.so` in place (macOS SIGKILLs the next process that loads it).
- Mojo 1.2.0 and MAX/modular 26.7.0 via pixi (`~/.pixi/bin`). `.pixi/config.toml` keeps the env out of the repo (detached environments).
- `pixi run tests` runs everything (about 2,450 tests). After adding a test file: `pixi run tests-gen`. One file: `pixi run mojo -I . tests/http/test_x.mojo`. Use `AGG_JOBS=2` on 16 GB machines.
- Mojo 1.x: `def` only (`fn` is removed), and `raises` must be explicit. GPU code is under `max.gpu`.
- GPU work runs on the Windows machine's RTX 5070 (verified working). The Mac has no NVIDIA GPU.
- Reference clones live in WSL under `~/src/`.
- WSL2's wall clock jumps 2–3 s when it resyncs. Time benchmarks with a monotonic clock, or rerun any `wrk` run with a p99 around 1–2 s.
- **Stale builds after Windows-side edits:** WSL can keep old memory-mapped pages of a file edited from Windows, and Mojo compiles that old code. Before building, run `wsl -d Ubuntu-24.04 -u root -- sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"`. Never trust a binary from a build whose exit status you didn't check.

## Rules that bite

- Commits: `type: one line`, with no em dashes, no body, and **no Claude co-author trailer**. Only commit when asked.
- All doc changes from one session go in one `docs:` commit.
- Every feature or fix gets a branch from `dev` (`type/short-name`) and a PR into `dev`, as in `CONTRIBUTING.md`. Never delete branches, even after merge.
- Ask the human one decision at a time, with a recommendation.
- Offloaded blocking work (`Offload`, `block_in_pool`, `resolve_async`) uses `ThreadHandle.spawn_os`, never a pool task: joining a pool task from a reactor worker can run the task on that worker.
- Simple, readable code over clever code. No dense one-liners.
- Goal: a fast framework. Profile before optimizing; show before/after numbers on hot-path PRs; delete code nothing on the roadmap uses.
- Major decision → write an ADR. Anything smaller → `TODO.md`.
- Test every UI input and button against its edge cases in the built-in browser.
- In imported code, fix slow code and workarounds for old Mojo bugs as you find them (measure the claim first; Mojo 1.2.0 fixed many). Delete changelog-style or personal comments ("v0.11:", "C7:", "Step 2") whenever you touch a file. Never follow the original project's conventions.
- Update this file when layout, commands or decisions change. Keep it under about 60 lines; link, don't copy.

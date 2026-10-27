# Contributing to dodo

Thanks for helping. dodo is early (pre-0.1), so the most useful things right now are bug reports with a reproduction, fixes with a regression test, and benchmarks that show where we are slow.

Before you start, read [docs/engineering-standards.md](docs/engineering-standards.md). It is short, and every PR is reviewed against it.

## Ways to help

- **Report a bug.** Open an issue with the smallest code or request that reproduces it.
- **Report a security problem privately.** See [SECURITY.md](SECURITY.md). Never in a public issue.
- **Propose a feature.** Open an issue first and say what you want to build with it. Big changes need an ADR (see below), so talk before you code.
- **Send a fix.** Small fixes can go straight to a PR.

## Set up

dodo builds on Linux (x86_64, aarch64) and macOS (Apple Silicon). Mojo has no Windows support, so on Windows use WSL.

1. Install [pixi](https://pixi.sh).
2. Clone and run the tests:

   ```bash
   git clone https://github.com/dodo-mojo/dodo.git
   cd dodo
   pixi run tests
   ```

The first run installs Mojo and the native libraries, and builds the C/C++ wrappers in `dodo/*/ffi/`. A full test run compiles several large binaries, so it takes a while; on a 16 GB machine use `AGG_JOBS=2 pixi run tests`.

Useful commands:

| Command | What it does |
|---|---|
| `pixi run tests` | Build and run every test |
| `pixi run tests-gen` | Regenerate `tests/_agg/` after adding or removing a test file |
| `pixi run mojo -I . tests/http/test_x.mojo` | Run one test file |
| `pixi run format` | Format the code |
| `pixi run -e fuzz fuzz` | Run the fuzzers |
| `pixi run check-sans-io` | Check the protocol layers do no I/O |

## Making a change

1. Branch from `dev`, named `type/short-name` (for example `feat/vision-decoders`). `dev` is the default branch; `production` is for releases only. Branches are kept after merge, so the history of each feature stays visible.
2. Keep the change small and about one thing.
3. Add tests. Every bug fix comes with a test that fails without the fix.
4. Run `pixi run tests` and `pixi run format`.
5. If you changed the layout, a command, or a decision, update `CLAUDE.md` (the short map of the repo) and the matching page in `docs/`.
6. Open a PR against `dev` and fill in the template.

### Commits and PR titles

One line, `type: what changed`, lowercase after the colon, no trailing period, no em dashes, no body.

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`.

```text
fix: reject chunk sizes that overflow Int
perf: reuse the header buffer across keep-alive requests
```

The PR description carries the detail: what changed, why, how you tested it, and any follow-ups.

### Performance

dodo aims to be fast, so speed is reviewed like correctness. A PR that touches the request hot path shows before and after numbers, measured on bare-metal Linux (WSL2 and laptops on battery distort results). Say how you measured.

### Big decisions

Architecture, public API shape, new dependencies, licensing and protocol scope are decided in an ADR. Copy [docs/adr/0000-template.md](docs/adr/0000-template.md), open it as a PR, and wait for it to be accepted before building on it. Smaller follow-ups go in an issue or `TODO.md`.

## Using AI tools

You may use AI coding agents; dodo is built to work well with them (`CLAUDE.md` is the agent's map of the repo). You are still the author:

- Read and understand every line you submit, and run the tests yourself.
- Don't open issues, PRs or security reports that no human has checked.
- Don't add AI co-author trailers to commits.

## Platforms

Some code only runs on Linux (epoll, io_uring, accept balancing) and some only on macOS (kqueue). CI runs both. If you can only test on one, say so in the PR.

## License

dodo is Apache-2.0. By contributing, you agree that your contribution is licensed under the [Apache License 2.0](LICENSE), as described in section 5 of the license. Code copied from elsewhere must have a compatible license and be listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Conduct

Everyone in the project follows the [Code of Conduct](CODE_OF_CONDUCT.md).

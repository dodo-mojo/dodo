# The `dodo` command line

One binary, written in Mojo, in `cli/`. Build it with `pixi run cli-build` (to `build/bin/dodo`). It imports dodo like any app. Tests are in `tests/cli/`.

Every command takes `--json` (one JSON object on stdout) and `--help`. dodo never asks questions; everything is a flag. `dodo help COMMAND` prints a command's flags.

| Command | What it does |
|---|---|
| `dodo run [FILE] [-- ARGS...]` | Build the app (cached in `.dodo/build/`) and run it. Exits with the app's own code. |
| `dodo dev [FILE] [-- ARGS...]` | Run the app and restart it on every save, keeping the port open. `--port` (default 8000), `--host` (default 127.0.0.1). |
| `dodo test [PATH...]` | Build every `tests/**/test_*.mojo` in parallel and run each. `--only NAME`, `--jobs N`, `--timeout SECONDS`. |
| `dodo routes [FILE]` | List the app's routes. |
| `dodo doctor` | Check the toolchain, the project and the machine. |
| `dodo docs pull [mojo@V] [dodo@V]` | Download the Mojo and dodo docs into `.dodo/docs/`. `--mojo V`, `--dodo V`. |
| `dodo new NAME` | Make a project folder: `pixi.toml`, `main.mojo`, `app.mojo`, `tests/`, `AGENTS.md`, `CLAUDE.md`. `--no-git` skips `git init`. |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | done |
| 1 | ran and found a failure (a test, a check) |
| 2 | the project's code did not build |
| 64 | wrong command line |
| 69 | something outside dodo is missing (network, mojo, git) |
| 70 | a bug in dodo |
| 130 | `dodo dev` stopped by Ctrl-C |

## How `dodo new` works

- It only writes files; it never downloads. It prints the next steps: `pixi run dodo docs pull`, then `pixi run dodo dev`.
- `NAME` may be a path (`apps/shop`); its last part is the project's name: a letter, then letters, digits, `-` or `_`, at most 64 bytes. The folder above must exist.
- A path that is there and is not an empty folder is refused, a symlink included.
- The files go into a hidden `.NAME.new.PID` folder next to the target and are moved into place at the end, so a failure leaves nothing.
- It runs `git init` (no first commit), unless `--no-git` is given or the folder is inside a git repository already.
- `pixi.toml` gets `dodo` from the modular-community channel, pinned to this CLI's version. `DODO_PACKAGE_CHANNEL` swaps the channel, for a package built locally with `packaging/build_local.sh` (`file:///path/to/build/conda`).
- `AGENTS.md` tells an agent to read the docs in `.dodo/docs/` first; `CLAUDE.md` is the one line `@AGENTS.md`.

## How `dodo dev` works

- dodo binds the port and holds it for the whole session. Each app it starts gets the socket as `DODO_LISTEN_FD`, and `App.serve` serves on it instead of binding. A request sent during a restart waits in the socket's queue and the new app answers it.
- Every 200 ms dodo checks the project's `.mojo` files (`cli/watch.mojo`). Folders are listed again only when their own time changes, so adding, removing or renaming a file is seen without walking the tree each time.
- On a change it builds while the old app keeps serving. Only a good build replaces the app: the old one gets SIGTERM and drains, then the new one starts. A failed build prints the compiler's errors and leaves the old app serving.
- An app that exits by itself is reported and starts again on the next save.
- The app and each build run in their own process group, so Ctrl-C reaches only dodo. dodo stops the app the same way and exits with 130. A second Ctrl-C half a second or more later kills the app at once.
- With `--json`, each event is one line on stdout among the app's own output: `{"dodo_dev": {"event": "listening" | "building" | "build_failed" | "started" | "app_exited" | "stopped", ...}}`.

## How `dodo docs pull` works

- It pulls two sets of docs: Mojo's for the `mojo --version` on `PATH`, and dodo's for the version of this `dodo`. Name others with `mojo@1.2 dodo@0.1` or `--mojo`/`--dodo`. A short version means the newest saved one it names.
- Both come from dodo's `dev` branch on GitHub: `mojo-docs/<version>/` and `dodo-docs/<version>/`, each with an `index.md` that lists its files. They land in `.dodo/docs/mojo-<version>/` and `.dodo/docs/dodo-<version>/` of the project root.
- Files download into a hidden folder that takes the old docs' place only once all are in, so a pull that fails or is stopped keeps the docs you had. A failed half fails the command (exit 69) but keeps the half that worked.
- An index that links outside its folder is refused. A server error is tried three times. A server silent for 30 s fails the pull.
- `DODO_DOCS_URL` points the pull at another server (the tests use a local one); `DODO_DOCS_READ_TIMEOUT_MS` changes the 30 s.
- Saving: `tools/save_docs.py mojo VERSION` saves a Mojo release, and `tools/save_docs.py dodo --release` saves dodo's at each release.

## Graceful stop

On SIGTERM (or Ctrl-C) a server stops accepting and finishes what it has, so a restart resets no request (`dodo/http/_reactor/drain.mojo`):

- A request being read or answered gets its response, with `Connection: close`.
- A keep-alive connection between requests is closed at once.
- A connection that has sent nothing yet gets 500 ms to send its first request.
- HTTP/2 connections get GOAWAY and finish their open streams.
- Requests running on the offload pool finish; queued ones are answered 503.

The server ends when no connection is left, or after `ServerConfig.shutdown_timeout_ms` (5 s by default).

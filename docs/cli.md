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
| `dodo new`, `dodo docs pull` | Not built yet (`TODO.md`). |

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

## How `dodo dev` works

- dodo binds the port and holds it for the whole session. Each app it starts gets the socket as `DODO_LISTEN_FD`, and `App.serve` serves on it instead of binding. A request sent during a restart waits in the socket's queue and the new app answers it.
- Every 200 ms dodo checks the project's `.mojo` files (`cli/watch.mojo`). Folders are listed again only when their own time changes, so adding, removing or renaming a file is seen without walking the tree each time.
- On a change it builds while the old app keeps serving. Only a good build replaces the app: the old one gets SIGTERM and drains, then the new one starts. A failed build prints the compiler's errors and leaves the old app serving.
- An app that exits by itself is reported and starts again on the next save.
- The app and each build run in their own process group, so Ctrl-C reaches only dodo. dodo stops the app the same way and exits with 130. A second Ctrl-C half a second or more later kills the app at once.
- With `--json`, each event is one line on stdout among the app's own output: `{"dodo_dev": {"event": "listening" | "building" | "build_failed" | "started" | "app_exited" | "stopped", ...}}`.

## Graceful stop

On SIGTERM (or Ctrl-C) a server stops accepting and finishes what it has, so a restart resets no request (`dodo/http/_reactor/drain.mojo`):

- A request being read or answered gets its response, with `Connection: close`.
- A keep-alive connection between requests is closed at once.
- A connection that has sent nothing yet gets 500 ms to send its first request.
- HTTP/2 connections get GOAWAY and finish their open streams.
- Requests running on the offload pool finish; queued ones are answered 503.

The server ends when no connection is left, or after `ServerConfig.shutdown_timeout_ms` (5 s by default).

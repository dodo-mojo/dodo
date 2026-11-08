# Mojo ecosystem: what can help dodo

A survey of the 77 packages on the modular-community channel, done on 2026-11-04. It lists the ones that can help dodo now or in a later phase, and how we would use each one.

## How we use other packages

- **dodo's core depends only on the Mojo stdlib** (design.md §3). A package becomes a dependency only for an optional part, and only when it keeps up with Mojo releases.
- **Most packages lag behind Mojo.** Of the useful ones below, only argmojo, mist, mbpe and safetensors-mojo build with Mojo 1.2.0 today. The rest pin 1.0 or 1.1. A dependency that lags holds back every dodo upgrade.
- **Learning from code costs nothing.** We read how a package solved a problem, test the idea ourselves, and write our own version. Copying code needs a permissive license and a credit in `THIRD_PARTY_NOTICES.md`.
- **Avoid copyleft code.** msl (GPL-3.0), knap (EUPL-1.2) and parts of cvc5_mojo (LGPL) are not copied into dodo.

## Useful now (the CLI)

| Package | What it is | Mojo | License | How it helps |
|---|---|---|---|---|
| [mtest](https://github.com/mikeleppane/mtest) | A pytest-like runner over the stdlib `TestSuite`: finds test files, builds each one, runs it under supervision, merges the results | 1.1.0 | MIT | The same design as `dodo test`. It also spawns through a small C helper, as we plan to. Read for edge cases: process groups, hung tests, crashes, cached builds. |
| [argmojo](https://github.com/forfudan/argmojo) | A command-line argument parser: subcommands, help, shell completion | 1.2.0 | Apache-2.0 | A possible parser for the `dodo` CLI (open decision). |
| [mist](https://github.com/thatstoasty/mist) | Terminal colors and styles | 1.2.0 | MIT | Ideas for color output that turns off without a TTY. We need only a few codes. |
| [flare-routegen](https://github.com/joeressler/flare-routegen) | A CLI that ships as `$PREFIX/bin/flare-routegen` | 1.0.0 | MIT | A working example of a recipe that installs a Mojo binary. |

## Useful later

| Phase | Package | What it is | Mojo | License | How it could help |
|---|---|---|---|---|---|
| 3 AI | [safetensors-mojo](https://github.com/egor-fedorov/safetensors.mojo) | Reads safetensors weights with checked validation | 1.2.0 | Apache-2.0 | Loading weights for models that MAX does not cover |
| 3 AI | [mbpe](https://github.com/ratulb/mbpe) | Byte-pair tokenizer: train, encode, decode | 1.2.0 | MIT | Token counting and budgets in `dodo.agent` |
| 3b Harness | [mojo-regex](https://github.com/msaelices/mojo-regex) | Regular expressions | 1.0.0 | MIT | Regex scorers in `dodo eval`, guardrails |
| 3b Harness | [uuid](https://github.com/lczerniawski/uuid), [nanoid](https://github.com/cirello-py/nanoid) | ID generation | 1.0.0 / older | MIT / Apache-2.0 | Request ids for `dodo why`, trace and run ids |
| 3c Vision | [mosaic-mojo](https://github.com/christianbator/mosaic) | Image processing, active | 1.x | Apache-2.0 | Compare against our preprocessing kernels |
| 3c Vision | [mimage](https://github.com/fnands/mimage) | PNG decoding in Mojo | old (2025) | Apache-2.0 | Ideas only; it is no longer maintained |
| 4 Profiling | [professor](https://github.com/gsmyridis/professor) | Instrumentation profiler | 1.0.0 | MIT | Ideas for `dodo.prof` spans |
| 5 Edge | [protomojo](https://github.com/nsalerni/protomojo), [grpc-mojo](https://github.com/nsalerni/grpc-mojo) | Protocol Buffers and gRPC | 1.0.x | Apache-2.0 | gRPC on top of our HTTP/2 |
| App | [morrow](https://github.com/mojoto/morrow.mojo) | Dates and times, the most used (127 stars) | 1.1.0 | Apache-2.0 | Typed dates in the database drivers (a TODO item) |
| App | [mcrypto](https://github.com/aelxtpt/mcrypto) | Hashes, AEAD, KDFs, signatures | 1.0.x | MIT | Password hashing and token signing for auth middleware, next to OpenSSL |
| App | [mojo-dotenv](https://github.com/DataBooth/mojo-dotenv) | Loads `.env` files | 0.26.1 | Apache-2.0 | Ideas for the typed config file (a TODO item) |
| Deploy | [lambda_runtime](https://github.com/fourlexboehm/mojo-lambda-runtime) | AWS Lambda custom runtime | 1.0.0b1 | Apache-2.0 | A possible "deploy to Lambda" guide |
| Data | [duckdb-mojo](https://github.com/sbrunk/duckdb.mojo), [pyroquet](https://github.com/idlab-discover/pyroquet), [polars-mojo](https://github.com/ethqnol/polars-mojo) | In-process analytics, Parquet, DataFrames | 1.1.0 / 1.0.0 / 1.0.0 | MIT / Apache-2.0 / MIT | Best-practices entries for data apps; not dependencies |

## Already covered by dodo

lightbug_http, mojo-net, mojo-tls, mojo-http2, mojo-websockets, heat-url, emberjson and req overlap with dodo's own networking, JSON and client code (ADR-0003). They are worth checking only when a bug or a speed question comes up in the same area.

## Not relevant

Numerics, science and ML libraries (numojo, scijo, stamojo, linamo, mojoblas, apn_mojo, decimo, poly_mojo, cvc5_mojo, msl, infrared, kelvin, nabla, mojmelo, strata, mojolearn, projectodyssey, mojogp), graphics and windows (vulkan-mojo, wgpu-mojo, mojo-wayland, mojo-window, mojo_raylib, mojo-intel-gpu), and narrow tools (ish, symspell, hdf5-mojo, usd-mojo, mav, libclang_mojo, bridge, fp_mojo, mojo-snappy, mojo_csv, MojoINI, mojo-yaml, mojo_datetime, small_time, ExtraMojo, mojopt, mogo-tester, filelock-mojo, axisweave-mojo, mo_protobuf, crypto, emberserde, knap, mojo-libc).

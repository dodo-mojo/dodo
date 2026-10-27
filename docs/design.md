# dodo: design

Status: draft v0.1, 2026-10-26. The first user is the author. This document is the plan we build against; change it when reality disagrees.

## 1. What dodo is

A production web framework written in Mojo, where the HTTP server, AI model inference, GPU kernels, computer vision and agents run **in one process, in one language**. You get systems-level control with Python-like code, and it is built to be driven equally well by humans and AI coding agents.

### Principles

1. **Never crash on input.** No request bytes, client behavior or load pattern may take down the process. Every Lightbug finding (see [lightbug-audit.md](lightbug-audit.md)) becomes a permanent regression test.
2. **Fast by default, measurable always.** Profiling is built in from the start.
3. **AI, GPU and vision are first-class.** Serving a model, running a kernel or processing an image inside a request handler is a normal, documented path (§5, §5.2). So is building an agent harness: models, tools, prompts, evals and traces are native parts (§5.1).
4. **Agent-native.** Every action is a CLI command with JSON output, every doc page is plain Markdown, and dodo ships its own MCP server and AGENTS.md.
5. **Boring where it should be.** HTTP/1.1 done strictly and well before anything fancy. Strict RFC 9110/9112 behavior is the default.
6. **The author's daily experience is the test.** If something is annoying to use, it's a bug.

### Not in v0.x

HTTP/3, a built-in ORM, an HTML templating engine (prompt templates are in, see §5.1), Windows-native builds (Mojo doesn't support Windows; use WSL).

## 2. Verified platform facts (2026-10-26)

| Fact | How it was checked |
|---|---|
| Current stable: Mojo 1.2.0 with MAX/modular 26.7.0, installed with pixi | `pixi add mojo`, `pixi add modular` |
| 1.x removed `fn` (use `def`). `def` doesn't raise unless marked `raises`. `UnsafePointer` is deprecated in favor of `Pointer`. Pointer indexing uses `unsafe_offset=`. | compiler errors and warnings |
| GPU APIs live in the `max` package: `max.gpu`, `max.gpu.host.DeviceContext`. Kernels launch as capturing closures via `ctx.enqueue_function(kernel, grid_dim=, block_dim=)`. | a vector-add ran correctly on the RTX 5070 under WSL (`research/gpu-smoke/vadd.mojo`) |
| Available: `std.ffi.external_call`, `std.atomic.Atomic`, `std.python`, `std.benchmark`, `max.algorithm.parallelize`, `max.runtime.tracing.Trace`, `max.runtime.asyncrt.parallelism_level` | import probes |
| Not found at the paths we tried: an async `TaskGroup`. Async/await status in 1.2 is unknown, so the design doesn't depend on it. | import probes |
| Mojo targets: Linux x86_64/aarch64, macOS arm64 | Lightbug `pixi.toml`, Modular packages |

## 3. Architecture

```
 your app (routes, handlers, models, kernels)
 ───────────────────────────────────────────────────────────────
 dodo.app    App, Router (radix tree), Request/Response, extractors,
             middleware, JSON, static files, errors (problem+json)
 dodo.ai     model hosting via MAX, request batching, SSE token streams   ┐ optional:
 dodo.gpu    DeviceContext ownership per worker, buffer pools, helpers    │ depends on `max`
 dodo.vision image/video decode, GPU pre/postprocessing, vision models   ┘
 dodo.agent  model clients, tool + prompt templates, agent loop, MCP,
             evals, traces (remote-API models need no `max`)
 dodo.prof   spans, per-route histograms, /_dodo/metrics, perf/nsys hooks
 ───────────────────────────────────────────────────────────────
 dodo.http   HTTP/1.1 codec: strict incremental parser (byte spans),
             chunked in/out, keep-alive, pipelining, limits → correct 4xx
 dodo.io     event loop per core: epoll (Linux) / kqueue (macOS),
             non-blocking sockets, timers, back-pressure, offload pool
 dodo.sys    libc FFI: sockets, epoll/kqueue, errno (ported from Lightbug,
             per-target constants)
```

The networking layers start as an imported fork (ADR-0003), so their package names follow the import (`dodo.net`, `dodo.runtime`, `dodo.http`, `dodo.tls`, and so on) rather than this sketch. The core depends only on the Mojo stdlib. `dodo.ai`, `dodo.gpu` and `dodo.vision` depend on `max`, so a plain web service doesn't pull in about 1 GB of MAX.

### 3.1 Concurrency model: thread-per-core with offload

- N workers, one per core by default. Each has its own listening socket (`SO_REUSEPORT`, so the kernel load-balances), its own epoll/kqueue loop, and its own buffers. Workers share nothing on the hot path, so no locks.
- Each connection is a non-blocking state machine: `reading_head → reading_body → handling → writing → keep_alive_idle → …`. This keeps Lightbug's state names, but nothing blocks.
- Timeouts on every state: header read 10 s, body idle 30 s, keep-alive idle 5 s, write 30 s, all configurable. This fixes C3/C5.
- **The catch:** a slow synchronous handler stalls its core's other connections. Mitigations:
  - `app.blocking(...)` runs work on an offload thread pool and wakes the loop through an eventfd.
  - GPU work is enqueued on the worker's `DeviceContext` stream, and completion is polled from the loop, so the CPU never sits waiting on the GPU.
  - In dev mode `dodo.prof` flags handlers that hold a loop longer than a threshold.
- If Mojo gains stable async later, handlers can become `async def` without changing the I/O layer.
- **Phase 0 spike:** confirm thread creation (`parallelize` vs. pthreads via FFI) and epoll from Mojo 1.2.

### 3.2 Request lifecycle

1. The connection is readable. Bytes land in a per-connection buffer from a pool, with no allocation per read.
2. The incremental parser records **byte offsets**, not Strings. Validation (token chars, no CTL, UTF-8 where required, CR/LF/NUL) happens once, before anything becomes a `String`.
3. Limits are checked as early as possible, each with the correct status: 400, 413, 414, 431. A missing `Host` on 1.1 is a 400. Requests with both TE and CL are rejected. Duplicate or invalid CL is a 400. Obs-fold is a 400.
4. Route lookup in a radix tree. Path params and the query are parsed lazily.
5. Middleware chain → handler → `Response`.
6. Encode: header values are validated when set (CR/LF/NUL rejected, which fixes H1). The cached `Date` is reused. Output goes through `writev` with the status line, headers and body as separate iovecs, so there's no concatenation copy.
7. Back-pressure: if the socket buffer is full, keep the response and wait for writability. Streaming bodies (SSE, chunked) pull from a producer only when writable.
8. Keep-alive or close. Pipelined bytes already in the buffer are parsed next instead of being dropped (fixes M1).

### 3.3 Protocols

| Protocol | When | Why |
|---|---|---|
| HTTP/1.1 (strict) + chunked + keep-alive + pipelining | Phase 1 | It's the base everything else stands on, and what reverse proxies speak to backends. |
| Server-Sent Events | Phase 3 | LLM token streaming. Plain HTTP/1.1. |
| WebSockets | Phase 3 | Realtime apps and agents. Upgrades from 1.1. |
| TLS (OpenSSL/BoringSSL via FFI) | Phase 5 | Until then, run behind Caddy, nginx or a cloud load balancer. That's also standard practice in production. |
| HTTP/2 | Phase 5 | Needed for gRPC and direct browser connections without a proxy. Large attack surface (HPACK, flow control, Rapid Reset). |
| HTTP/3 / QUIC | Not planned | Proxies and CDNs handle it in front of the app. |

## 4. Developer API (sketch)

Syntax is illustrative and will be adjusted to what Mojo 1.2 allows.

```mojo
from dodo import App, Request, Response, json
from dodo.ai import Model, sse

@fieldwise_init
struct Greeting(Json):
    var message: String

def hello(req: Request) raises -> Response:
    var name = req.param("name")          # typed, validated extractor
    return json(Greeting(String("hi ", name)))

def chat(req: Request, llm: Model) raises -> Response:
    var prompt = req.json[ChatIn]().prompt
    return sse(llm.generate_stream(prompt))   # tokens streamed as they're produced

def main() raises:
    var app = App()
    app.get("/hello/{name}", hello)
    app.post("/chat", chat, state=Model.load("meta-llama/Llama-3.2-1B"))  # loaded once, on GPU
    app.serve(port=8000)
```

Design rules for the API:

- Handlers are plain functions, and dependencies (models, DB pools, config) are injected as typed state.
- Route and handler-signature mistakes become **compile-time errors** wherever Mojo's comptime makes it possible.
- One obvious way to do each thing. Agents and humans both benefit from fewer choices.
- Escape hatch: `std.python` interop for libraries that don't exist in Mojo yet (DB drivers, SDKs). It works, but stays off the hot path.

## 5. AI and GPU (`dodo.ai`, `dodo.gpu`)

- **Model hosting:** load MAX models once per process. Each worker submits to a shared **batching queue** that groups concurrent requests into GPU batches (configurable max batch size and max wait).
- **Streaming:** `sse(...)` and WebSocket streams take a token iterator, and back-pressure from slow clients never blocks the GPU.
- **Custom kernels:** `dodo.gpu` gives each worker a `DeviceContext` and pooled device buffers, so a handler can run a Mojo kernel on request data (embeddings, image ops, re-ranking) without leaving the process.
- **No CUDA C:** Mojo compiles kernels for NVIDIA (CUDA), AMD and Apple GPUs from the same source. Verified on the author's RTX 5070.
- **Graceful CPU fallback:** with no accelerator present (`has_accelerator()` is false), AI routes still run on CPU or return a clear 503 with a reason. Startup never crashes.

### 5.1 Agent harness kit (`dodo.agent`)

A harness is everything around the model: assembling prompts, calling models, running tools, managing context, enforcing limits, and recording what happened. dodo ships the parts as a native kit. You can build a harness from scratch, or take an existing one and build on it, without writing the plumbing yourself.

| Piece | What you get |
|---|---|
| **Model clients** | One `ChatModel` trait over local MAX models (in-process, on GPU) and remote APIs (Anthropic, OpenAI, and any OpenAI-compatible server such as vLLM or Ollama). Streaming, tool calls, structured output, token counting, retries with backoff, rate limits, prompt-caching hints. Switching models is a one-line change. |
| **Tool templates** | A Mojo struct is a tool. Its JSON Schema is generated at compile time from fields and docstrings, and arguments are validated and decoded into the struct before your code runs, the same way typed request extractors work. Built-in templates: HTTP fetch, sandboxed shell (allowlist, timeout), files under a root directory, SQL (via Python interop at first), web search, call a sub-agent, ask a human for approval. `dodo add tool <name>` scaffolds one with a test. |
| **Prompt templates** | `prompts/*.prompt` files with typed variables, conditionals, loops and includes. A missing or misspelled variable is a **compile error**. Untrusted content (user input, tool output, web pages) is wrapped in delimiters by default to reduce prompt injection. Sections can carry token budgets with a truncation policy. Templates render to each provider's message format, and every render records the template's version hash. |
| **Agent loop** | `Agent(model, tools, prompt)` with `run` and `stream`. Hooks at each step (`before_model`, `after_model`, `before_tool`, `after_tool`, `on_error`) for guardrails, approvals and logging. Stop conditions for max turns, token or cost budget, and deadline. Parallel tool calls. Cancellation follows the HTTP request, so a dropped client stops the run. |
| **Context and memory** | Conversation state, compaction and summarization strategies, scratch storage, and in-process retrieval (embedding kernels on `dodo.gpu` plus a vector index). |
| **Structured output** | Decode model output straight into Mojo structs, validated against the schema, with an automatic repair-and-retry when it fails. |
| **Serving** | Expose any agent as an HTTP endpoint with SSE streaming, as an OpenAI-compatible `/v1/chat/completions` API, or as an MCP server. Sessions persist across requests. |
| **MCP both ways** | An MCP client that turns any MCP server's tools into dodo tools, and an MCP server that publishes dodo tools to other agents. |
| **Tracing** | Every model call and tool call is a `dodo.prof` span: tokens in and out, cost, latency, cache hits, prompt version. `dodo trace show <run>` replays a run step by step. |
| **Evals** | `dodo eval` runs a dataset through an agent with scorers (exact, regex, schema, LLM-as-judge), compares against a saved baseline, and runs in CI. Recorded model responses act as fixtures, so agent tests run offline and give the same result every time. |
| **Safety defaults** | Tool sandboxing (allowed paths and hosts, timeouts), approval gates for side effects, and secrets kept out of prompts and logs. |

**Mojo and Python, briefly:**
- Mojo is not a subset or superset of Python. It is its own compiled, statically typed language with Python-like syntax. Python files don't compile as Mojo.
- Python libraries still work. Mojo embeds CPython in the same process: `Python.import_module("langgraph")` loads the real package, and values come back as dynamic `PythonObject`s.
- Calls go both ways: Mojo functions can be exposed to Python.
- Python code runs at Python speed under the GIL, so keep it off the HTTP hot path. Native `dodo.agent` is the default; Python harnesses are for reuse and gradual porting.

**Building on someone else's harness:**

- **Python frameworks behind a Mojo API** (`dodo.agent.py`). Users write only dodo's Mojo API; LangGraph, LangChain and the others run in embedded CPython underneath. We wrap their core ideas, not every function, because LangChain's surface is huge and changes often:
  1. **Typed wrappers for the core ideas:** graphs, state, nodes and edges, chat models, tools, retrievers, checkpointers. State is a Mojo struct, and nodes and tools are Mojo functions, converted at the boundary.
  2. **A generator for the long tail:** `dodo wrap <package>` reads a library's Python type hints and Pydantic models and generates typed Mojo stubs. Any LangChain integration (vector DBs, loaders, providers) becomes usable without hand-written code.
  3. **An escape hatch:** a typed `py.call` for anything not wrapped yet.
  4. **Same features for every adapter:** Python exceptions become dodo errors, Python steps appear in `dodo trace` next to Mojo steps, and each adapter is version-pinned and CI-tested against that library's releases.

  **Order:** LangGraph; then LangChain models, tools and retrievers; then PydanticAI, OpenAI Agents SDK and Claude Agent SDK; then LlamaIndex, CrewAI and DSPy.

  **Trade-offs to document for users:** wrapped code runs at Python speed; the GIL means Python work doesn't scale across workers; deployments need a Python environment, which pixi manages. Native `dodo.agent` stays the fast path, so the migration story is "start on LangGraph, move hot pieces to native".
- **Protocols:** MCP and the OpenAI-compatible API, both as client and as server, so dodo plugs into any harness that speaks them.
- **Agent file formats:** read `AGENTS.md` and skill folders (`SKILL.md`) as context and prompt sources.
- **Starters:** `dodo new agent --template chat-tools|rag|coding|supervisor` creates a working agent with tests, evals and a served endpoint.

**CLI**, all with `--json`:
- `dodo new agent` and `dodo add tool|prompt|agent`
- `dodo agent run <name> --input …`
- `dodo prompt render <name> --vars vars.json`, which shows the exact rendered prompt and its token count
- `dodo eval` and `dodo trace`

**Reuse candidates and spikes:**
- Flare's template engine and its JSON library, `ehsanmok/json`, which has schema and reflection modules.
- Phase 0 must confirm that Mojo 1.2's compile-time reflection can list struct fields for schema generation.

### 5.2 Computer vision (`dodo.vision`)

Images and video go from the request to a model and back inside one process. Frames stay in pooled buffers from decode to response, on the GPU when there is one.

| Piece | What you get |
|---|---|
| **Input** | Image uploads (raw body or multipart), video file uploads, and live frame streams over WebSocket. |
| **Decode** | JPEG: libjpeg-turbo on CPU, nvJPEG on NVIDIA GPUs. PNG: Wuffs (memory-safe, faster than libpng). WebP: libwebp. AVIF: libavif with dav1d. Video: hardware decoders first, so frames land in GPU memory: NVDEC on NVIDIA (through the MIT-licensed `nv-codec-headers`), VideoToolbox on macOS, VA-API on Intel and AMD. Software fallback with permissive licenses: dav1d (AV1), libvpx (VP9), OpenH264 (H.264). No FFmpeg. dodo's own MP4 and WebM demuxer, written in Mojo as a sans-I/O parser and fuzzed like the HTTP parser. All C libraries are wrapped like the existing `dodo/*/ffi/` libraries. |
| **Tensors** | Decoded frames land in pooled CPU or device buffers as tensors. Decode, preprocessing and the model share them without copies. |
| **Preprocessing** | Resize (nearest, linear, bicubic), pad and crop come from the MAX kernel library (`max/kernels/src/nn`), which runs on CPU and GPU. dodo writes what MAX lacks: YUV and BGR to RGB conversion, per-channel mean/std normalization (MAX's normalization kernels are layer and RMS norm), and one fused kernel that converts, resizes, letterboxes and normalizes a frame in a single pass over memory. |
| **Models** | Detection, classification, segmentation, OCR, embeddings and vision-language models through MAX. Frames from concurrent requests share the `dodo.ai` batching queue. |
| **Postprocessing** | Non-maximum suppression and ROI align from the MAX kernel library. dodo writes box decoding (it depends on the model's output format) and mask run-length encoding. |
| **Pipelines** | A `Pipeline` of stages (decode, preprocess, infer, postprocess). Each stage reports its time and device to `dodo.prof` (`dodo profile vision`). |
| **Output** | JSON results (boxes, labels, scores, masks), annotated images, and per-frame results streamed over SSE or WebSocket. Each stream has a fixed-size frame queue; when a client falls behind, the oldest frames are dropped. |
| **Agents** | Vision tools for `dodo.agent`: detect, OCR, and describe an image with a vision-language model. |
| **Safety** | Decoders check limits before allocating: max pixels, max frame size, max frames per stream, and a guard against decompression bombs. Every decoder is fuzzed. A corrupt image returns a 4xx. |
| **CPU fallback** | With no accelerator, vision routes run on CPU or return a clear 503 with a reason, like `dodo.ai`. |

**To confirm in Phase 0:** which vision model formats MAX loads and runs today; the decoders' speed on our own images (the choices above follow published benchmarks); the fused preprocessing kernel against a chain of MAX kernels; and each decoder's license and packaging on the conda channels we use. H.264 and HEVC are patented: hardware decoders are licensed by their vendors, and OpenH264 is covered only through Cisco's prebuilt binary, so confirm before 1.0.

## 6. Profiling and observability (`dodo.prof`)

| Layer | What you get | Command |
|---|---|---|
| Request | Per-phase timings (parse, route, handler, encode, write), a `Server-Timing` header in dev, slow-request log | always on in dev |
| Metrics | Per-route latency histograms, status counts, in-flight requests, loop lag, GPU queue depth. Prometheus format at `/_dodo/metrics`. | `dodo stats` (live TUI, `--json` too) |
| CPU | Sampling profile and flamegraph via `perf` (Linux) or `samply` | `dodo profile cpu --duration 30s` |
| GPU | Request spans (`max.runtime.tracing.Trace`) and kernel launches on one timeline in Nsight Systems | `dodo profile gpu` (wraps `nsys`) |
| Computer vision | Per-stage timings for image and video pipelines (decode, preprocess, inference, postprocess), frames per second, and where each stage ran (CPU or GPU) | `dodo profile vision` |
| Harness | Each agent step as a span: model calls, tool calls, tokens in and out, cost, latency, cache hits, prompt version (see §5.1 Tracing) | `dodo profile harness` |
| Memory | Allocations per request and pool hit rates (dev mode) | `dodo profile mem` |
| Load | Built-in load generator and benchmark reports compared against a saved baseline | `dodo bench` |

All profiling output is saved as files plus a JSON summary, so an agent can read the results and suggest fixes.

## 7. Built for humans and agents

| Piece | Details |
|---|---|
| `dodo` CLI | `new`, `dev` (rebuild and restart on save; the listening socket is kept open so no requests drop), `run`, `test`, `fuzz`, `bench`, `profile`, `routes`, `doctor` (checks toolchain, WSL, GPU, ports), `docs`. Every command supports `--json` and has stable exit codes. No interactive prompts without a TTY. |
| AGENTS.md | In the dodo repo and generated in every new project: layout, commands, conventions, how to test, what not to touch. |
| MCP server | `dodo mcp` exposes tools: `routes.list`, `request.send`, `test.run`, `logs.tail`, `profile.run`, `bench.run`, `docs.search`, `scaffold.add_route`. Agents get the same powers as the CLI, with structured results. |
| Docs | Every page is Markdown in the repo, published with `llms.txt` and `llms-full.txt`. Every code example is compiled in CI, so docs can't drift. |
| Errors | Stable codes (`DODO-E0142`), one-line cause, a suggested fix and a docs link, in both human and JSON form. |
| Introspection | `dodo routes --json`, generated OpenAPI spec, `dodo explain <error-code>` |
| Scaffolding | `dodo add route|model|middleware|test`. Output is deterministic, so agent edits are predictable and reviewable. |
| Standards built in | `dodo new` sets up a project the way dodo itself is run (see [engineering-standards.md](engineering-standards.md)):<br>• a short `CLAUDE.md`/`AGENTS.md` that `dodo doctor` flags when it falls behind the code (new routes, commands or ADRs not mentioned)<br>• `docs/` with `docs/adr/` and `dodo adr new "<title>"`<br>• `TODO.md`<br>• a commit-message check (`type: one line`, no em dashes, no AI co-author trailers) installed as a git hook<br>• readability lints (dense one-liners, nested conditional expressions)<br>• `dodo test ui`, which runs every form field and button against a built-in list of edge cases in a real browser |
| One question at a time | When dodo's MCP tools or agents need a human decision, they ask one question with a recommended answer. They don't send a batch. |

## 8. Testing strategy

- **Unit tests** for every module (port Lightbug's 116 first).
- **Conformance suite:** RFC 9110/9112 request matrix, including every probe in `research/lightbug-audit/probe.py` with the expected status.
- **Fuzzing:** a mutation fuzzer for the parser, chunked codec and URI (built with `-D ASSERT=all`). A fixed-time run on every PR and longer nightly runs. Crashing inputs go into the corpus.
- **Adversarial runtime tests:** slowloris, RST before accept, disconnect mid-body, 10k idle connections, oversize everything. The server must stay up and keep serving others.
- **Load and soak:** `wrk` at 1/50/1k connections and a 1-hour soak checking that RSS and FD counts stay flat. Results are tracked over time.
- **CI:** Linux x86_64 + macOS arm64. GPU tests run on a self-hosted runner (the author's RTX 5070 under WSL) until a cloud GPU runner exists.

## 9. Roadmap

| Phase | Goal | Done when |
|---|---|---|
| 0. Spikes | Settle the unknowns | Threads + epoll loop from Mojo 1.2; port `c/` FFI with per-target constants; measure compile/rebuild times; confirm `nsys` CLI inside WSL; compile-time struct reflection for tool schemas; Python interop: run a LangGraph graph (asyncio) inside a worker thread and pass it a Mojo function as a tool; run a vision model through MAX on a decoded image |
| 1. Core server | Import the forked networking core as dodo's own (ADR-0003; imported 2026-10-27: cut, renamed, restyled), fix audit findings F1–F10, add the offload pool, then a profiling pass on the hot path | All kept tests and fuzzers pass under the dodo names; no upstream name in code outside `THIRD_PARTY_NOTICES.md`; audit findings fixed and tested; benchmarked on bare-metal plaintext and JSON tests against other Mojo frameworks and the fastest Rust and Go servers, with zero allocations per plaintext request |
| 2. App + CLI + agents | Router, extractors, JSON, middleware, static files; `dodo new/dev/run/test/routes`; AGENTS.md; `dodo mcp` | The author builds a small real app with an AI agent using only the docs |
| 3. AI + GPU + streaming | `dodo.ai`, `dodo.gpu`, SSE, WebSockets | Example: LLM chat endpoint plus a custom-kernel endpoint in one file, benchmarked against FastAPI + vLLM |
| 3b. Harness kit | `dodo.agent`: model clients, tool and prompt templates, agent loop, MCP client and server, `dodo eval`, `dodo trace`, Python harness adapters | The author rebuilds one of their existing agents on dodo in a day, with evals passing in CI |
| 3c. Vision | `dodo.vision`: decoders, GPU preprocessing and postprocessing kernels, pipelines, frame streams over WebSocket | Example: object detection on uploaded images and on a live WebSocket video stream in one file, benchmarked against FastAPI + PyTorch + OpenCV |
| 4. Profiling | `dodo.prof`, `dodo profile cpu/gpu/vision/harness/mem`, `dodo bench` | One command produces a joint timeline of requests, CPU, GPU, vision stages and agent steps |
| 5. Edge | Native TLS, HTTP/2 | Passes h2spec; TLS tested with testssl.sh |
| 6. 1.0 | Stable API, docs site, package on the modular-community channel | Used in production by someone other than the author |

## 10. Related projects (found 2026-10-26)

The first landscape search only found Lightbug and m0. A closer look at the modular-community channel found more:

| Project | What | License | State |
|---|---|---|---|
| [ehsanmok/flare](https://github.com/ehsanmok/flare) | Full networking stack: HTTP/1.1, HTTP/2, HTTP/3/QUIC, TLS/mTLS, WebSocket, gRPC, router, typed extractors, middleware, SSE, Prometheus metrics, OpenAPI. Thread-per-core reactor (epoll/kqueue/io_uring). Claims 63 fuzz harnesses, Lean 4 proofs, and about 1.0× actix-web throughput. | MIT | 72★, 5 contributors, created 2026-02, last push 2026-10-23 |
| [nsalerni/mojo-net](https://github.com/nsalerni/mojo-net), mojo-tls, mojo-http2, grpc-mojo | Sockets plus readiness polling, TLS 1.2/1.3, HPACK/HTTP2, gRPC | Apache-2.0 | New (2026-08), small, active |
| [joeressler/heat-url](https://github.com/joeressler/heat-url) | URL parsing (WHATWG + RFC 3986, IDNA) | Apache-2.0 | 1.0.0 |
| [msaelices/mojo-websockets](https://github.com/msaelices/mojo-websockets) | WebSockets | MIT | Stale since 2025-06 |
| [magmalake/threads.mojo](https://github.com/magmalake/threads.mojo) | pthreads for Mojo, extracted from Flare | — | New |

**What this means:** Flare already covers much of `dodo.sys`, `dodo.io` and `dodo.http` (sections 3.1–3.3). None of these claims are verified yet. Like Lightbug, Flare must pass our probe, fuzz and load suites before we rely on it. Options:

1. **Build on Flare:** dodo becomes the layer above it: in-process AI/GPU, profiling, the agent-native CLI/MCP and DX. We contribute fixes upstream. This is fastest to ship and puts our effort where dodo is unique.
2. **Fork or vendor Flare's core:** same as 1, but with full control of the hot path. More maintenance.
3. **Build our own core** as originally planned, borrowing ideas and code. Slowest; only worth it if Flare fails our tests or its design blocks the AI/GPU goals.

**Audit result (2026-10-26):** Flare passed. It fixes every critical and high Lightbug finding, and survived probes, slow clients and fuzzing with no crash. Details are in [flare-audit.md](flare-audit.md).

**Decision:** hard fork. Flare's code is imported once, renamed to dodo, and maintained as our own, with no upstream tracking and none of its history or conventions ([ADR-0003](adr/0003-fork-flare-core.md)).

## 11. Decisions

### Made

| Decision | Choice | Date |
|---|---|---|
| Name | **dodo** | 2026-10-26 |
| License | **Apache-2.0** (patent grant; matches the Mojo stdlib). Lightbug's MIT code is credited in `THIRD_PARTY_NOTICES.md`. | 2026-10-26 |
| GitHub home | org **`dodo-mojo`**, main repo `dodo-mojo/dodo` | 2026-10-26 |
| Package names | Mojo/conda package `dodo` (modular-community channel), CLI binary `dodo`, PyPI `dodo-mojo` (only if we ship a pip-installable CLI) | 2026-10-26 |
| Networking core | **Hard fork of Flare v0.13.0**, renamed and owned by dodo ([ADR-0003](adr/0003-fork-flare-core.md)) | 2026-10-26 |

### Still open

1. **Concurrency:** confirm thread-per-core + offload (section 3.1) after the Phase 0 spike.
2. **Minimum platforms for 0.1:** Linux x86_64 only, or also macOS arm64 from day one.

# dodo

A Mojo web framework with AI, GPU kernels, computer vision and agents natively supported, all in one language.

They run in one process by default, with no glue services or serialization between them. When you need crash isolation or separate scaling, move AI or GPU work into a supervised worker process, call a hosted AI service, or run dodo as one service among many, without a rewrite.

> **Status: pre-alpha.** The networking core, the App API, the database drivers and the `dodo` command line work and are tested. Nothing is stable yet.

## What dodo will be

- **Fast.** Thread-per-core, zero allocations per plaintext request, and benchmarks for every hot-path change.
- **Never crashes on input.** Bad bytes, slow clients and heavy load return errors. Every parser is fuzzed.
- **Web.** Router, typed extractors, JSON, middleware, static files, SSE, WebSockets, HTTP/1.1, HTTP/2, TLS.
- **AI in the handler.** Serve MAX models with request batching and token streaming from the same process.
- **GPU in the handler.** Run Mojo kernels on request data (NVIDIA, AMD, Apple) without leaving the process.
- **Computer vision in the handler.** Decode images and video streams, preprocess on the GPU, run detection, OCR or vision-language models, and stream results back per frame.
- **Agents built in.** Model clients, typed tools, compile-checked prompt templates, an agent loop, MCP client and server, evals and traces.
- **Python when you need it.** Use LangGraph, LangChain and friends behind a typed Mojo API.
- **Profiling built in.** CPU, GPU, computer vision pipelines and agent harnesses, all on one timeline.
- **Agent-native.** Every CLI command has `--json`, docs are plain Markdown, and dodo ships its own MCP server.

## Roadmap

| Phase | Goal | State |
|---|---|---|
| 1 | Core server: HTTP/1.1, HTTP/2, TLS, WebSocket, reactor | In progress |
| 2 | App API, CLI, AGENTS.md, `dodo mcp` | In progress |
| 3 | AI, GPU, streaming | Planned |
| 3b | Agent harness kit | Planned |
| 3c | Computer vision | Planned |
| 4 | Profiling | Planned |
| 6 | 1.0: stable API, docs site, package | Planned |

Details: [docs/design.md](docs/design.md).

## Try it

Linux or macOS (Apple Silicon); on Windows use WSL. Needs [pixi](https://pixi.sh).

```bash
git clone https://github.com/dodo-mojo/dodo.git
cd dodo
pixi run tests
```

## Contributing

New here? Pick a [good first issue](https://github.com/dodo-mojo/dodo/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22), ask anything in [Discussions](https://github.com/dodo-mojo/dodo/discussions), and read [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: [SECURITY.md](SECURITY.md).

## License

[Apache-2.0](LICENSE). Third-party code: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

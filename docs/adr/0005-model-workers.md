# ADR-0005: Model workers in supervised child processes

- Status: accepted
- Date: 2026-10-27

## Context

dodo runs HTTP, models and GPU kernels in one process. That is its main advantage (no network hop, no serialization, shared batching, one deployment), but it shares one fate: a GPU out-of-memory error, a hung kernel or a segfault in model code takes the HTTP server down with it. The offload pool (ADR-0004) keeps slow work off the event loop; it does not contain crashes. A crash can only be contained safely at a process boundary.

Two more costs of one process: model weights reload on every deploy of the web code, and several apps on one machine each load their own copy of a model.

Production runs in containers (Docker, Kubernetes), whose CPU and memory limits apply to the whole app.

## Decision

1. **Model workers.** A handler, model or kernel can be marked isolated, the way `Offload(handler)` marks a blocking one. dodo runs it in a child process that the server starts, watches and restarts. It is the same Mojo code in the same app and the same deployment; there is no separate service to write.
2. **Handoff.** Large data (images, tensors, frames) goes through shared memory; only a small message crosses a Unix socket. On NVIDIA, GPU buffers are shared between processes with CUDA IPC handles. Where GPU sharing is not available (Apple, at first), the data is copied.
3. **Crash containment.** If a worker crashes, runs out of memory or misses its watchdog deadline (it is then killed), the request gets `503`, other requests carry on, and the worker restarts. Restarts back off if a worker keeps crashing.
4. **Limits per worker.**
   - CPU cores (pinning, `sched_setaffinity` on Linux), RAM, and GPU memory (a budget in dodo's device allocator, so going over returns an error instead of crashing).
   - Each limit is either a ratio (`memory = 0.6`) or an amount (`memory = "8GB"`), worked out against **the box**: the container's own limits when dodo runs in one (read from its cgroup at startup), otherwise the whole machine.
   - dodo refuses to start when the shares add up to more than the box has.
   - Enforcement: dodo watches each worker's usage and restarts one that goes over. When the cgroup is writable, it also sets kernel hard limits (`memory.max`, `cpu.max`). macOS gets soft limits only.
5. **Kubernetes** needs nothing separate: a pod is a container, read the same way. dodo adds health endpoints (`/healthz`, `/readyz`) and drains on `SIGTERM` (graceful shutdown already does).
6. **Later:** the same API can point a worker at another machine, so all-in-one, hybrid and distributed setups are a config choice, not a rewrite.

## Consequences

- A bad model or kernel no longer takes the web server down, and deploying web code no longer reloads weights.
- Several web workers, or several apps on one machine, can share one loaded model.
- Every isolated call pays a small handoff; fast calls on small data should stay in process.
- dodo now supervises processes: startup order, restarts, logs and metrics per worker.
- GPU buffer sharing differs per vendor; Apple copies at first.

## Alternatives considered

- Keep everything in one process: simplest and fastest, but one crash takes everything down.
- Leave isolation to separate services (Triton, vLLM, a sidecar container): works today, but it means a second codebase and API, serialization at the boundary, and no shared batching queue.
- Catch crashes in process (signal handlers): a process after a segfault or GPU fault is not safe to keep running.

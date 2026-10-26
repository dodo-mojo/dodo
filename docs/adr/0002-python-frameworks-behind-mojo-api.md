# ADR-0002: Wrap Python agent frameworks behind a Mojo API

- Status: accepted
- Date: 2026-10-26

## Context

Most agent tooling (LangGraph, LangChain, PydanticAI, the OpenAI and Claude agent SDKs) is in Python. Mojo is not a Python subset, but it embeds CPython in-process through `std.python`, and Mojo functions can be exposed to Python. Users want to write only Mojo.

## Decision

`dodo.agent.py` gives Python agent frameworks a Mojo API. It has three parts:

1. Typed wrappers for the core ideas: graph, state, nodes, edges, models, tools, retrievers, checkpointers.
2. A `dodo wrap <package>` generator that turns type hints into typed Mojo stubs for the long tail.
3. A typed `py.call` escape hatch.

We do not wrap every function by hand. Native `dodo.agent` remains the default and fast path. Details are in [design.md §5.1](../design.md).

## Consequences

- Users can adopt dodo without giving up their existing agent stack.
- Wrapped code runs at Python speed under the GIL. This is documented, and Python stays off the HTTP hot path.
- Each adapter is pinned and CI-tested against its library's releases.
- Phase 0 must verify `asyncio` inside a worker thread and Mojo callbacks into Python.

## Alternatives considered

- Wrapping every API by hand: LangChain's surface is too large and changes too often.
- Native only: cuts users off from the Python ecosystem.
- Raw `PythonObject` only: works, but loses types and gives a poor developer experience.

# `dodo.testing`

``dodo.testing`` — handler + middleware testing helpers.

This package ships the in-process testing surface that lets
handlers and middleware be exercised without a real reactor:

- :class:`TestClient[H]` — FastAPI-style client that
  synthesises a :class:`dodo.http.Request`, runs it through a
  handler ``H``, and returns the captured
  :class:`dodo.http.Response`. No socket, no reactor, no
  thread.

Existing test infrastructure (``dodo.testing.fork_server`` for
integration tests that need a real socket) continues to live in
its own module; ``TestClient`` complements it for the much
larger universe of pure handler-level tests.

## Modules

- [`dodo.testing.client`](client.md): In-process test client for ``Handler`` implementations.
- [`dodo.testing.fork_server`](fork_server.md): Fork-and-serve helpers for cookbook examples and integration tests.

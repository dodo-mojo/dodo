# Conformance fixtures

Wire-format corpora that the sans-I/O parsers (`dodo.http.proto`, `dodo.ws`) are checked against. The format is in [fixture-format.md](fixture-format.md).

| Dir | Spec | Driven by |
|---|---|---|
| `h1/` | RFC 9112, HTTP/1.1 wire grammar | `test_conformance_h1.mojo` |
| `ws/` | RFC 6455 and permessage-deflate | `test_conformance_ws.mojo` |

These test the parsers directly. Running third-party suites (h2spec, Autobahn) against a live dodo server is tracked in `TODO.md`.

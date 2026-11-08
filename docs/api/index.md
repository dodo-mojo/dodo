# `dodo`

The dodo web framework for Mojo.

HTTP/1.1 and HTTP/2 server and client, WebSocket (RFC 6455), TLS 1.2/1.3
(OpenSSL with ALPN), TCP, Unix sockets and DNS, on one reactor per worker
(epoll on Linux, kqueue on macOS).

```mojo
from dodo import App, Request, Response, ok

def hello(req: Request) raises -> Response:
    return ok("hello")

def main() raises:
    var app = App()
    app.get["/"](hello)
    app.serve(port=8080)
```

The root exports what an app needs. Everything else lives in its subpackage:

```
dodo.http     server, client, Router, extractors, middleware, SSE,
              sessions, cookies, static files, content encoding
dodo.http2    HTTP/2 frames, HPACK, h2c
dodo.ws       WebSocket client and server, permessage-deflate,
              WebSocket over HTTP/2 (RFC 8441)
dodo.tls      OpenSSL client and server, ALPN, SNI, cert reload
dodo.tcp      TcpStream, TcpListener
dodo.uds      UnixListener, UnixStream, FrameMux
dodo.dns      resolver, cache, async resolve
dodo.net      IpAddr, SocketAddr, RawSocket
dodo.runtime  reactor, timer wheel, scheduler, buffer pool
dodo.crypto   HMAC-SHA256, base64url, random
dodo.io       buffered readers and writers
dodo.errors   typed errors shared across packages
dodo.testing  TestClient, fork_server
dodo.utils    POSIX helpers the Mojo stdlib doesn't expose yet
```

## Packages

- [`dodo.crypto`](crypto/index.md): ``dodo.crypto`` — minimal cryptographic primitives over the OpenSSL FFI.
- [`dodo.db`](db/index.md): Database drivers, written in Mojo (ADR-0009).
- [`dodo.dns`](dns/index.md): DNS resolution via `getaddrinfo(3)`.
- [`dodo.http`](http/index.md): HTTP/1.1 client and server.
- [`dodo.http2`](http2/index.md): ``dodo.http2`` -- low-level HTTP/2 driver primitives (RFC 9113 + RFC 7541).
- [`dodo.io`](io/index.md): Buffered I/O utilities for dodo streams.
- [`dodo.json`](json/index.md): JSON for dodo: parse, build, serialise, and reflect structs.
- [`dodo.net`](net/index.md): Raw POSIX socket primitives — the foundation of the dodo networking stack.
- [`dodo.runtime`](runtime/index.md): ``dodo.runtime`` — event-loop primitives for the Stage 1 reactor.
- [`dodo.tcp`](tcp/index.md): Blocking TCP streams and listeners.
- [`dodo.testing`](testing/index.md): ``dodo.testing`` — handler + middleware testing helpers.
- [`dodo.tls`](tls/index.md): TLS/SSL layer — wraps `TcpStream` with OpenSSL encryption.
- [`dodo.uds`](uds/index.md): ``dodo.uds`` — Unix domain socket primitives.
- [`dodo.utils`](utils/index.md): Cross-cutting utility helpers that don't fit any other layer.
- [`dodo.ws`](ws/index.md): WebSocket client and server (RFC 6455).

## Modules

- [`dodo.errors`](errors.md): Cross-module typed-error vocabulary for dodo.

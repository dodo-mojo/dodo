"""dodo: a Mojo web framework.

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
"""

from .http.app import App, AppState, JsonBody, PathParams, QueryParams, serve
from .http.request import Request
from .http.response import Response, Status
from .http.server import (
    ok,
    ok_json,
    bad_request,
    unauthorized,
    forbidden,
    not_found,
    internal_error,
    redirect,
)

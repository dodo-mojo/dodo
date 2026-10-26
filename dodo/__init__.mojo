"""dodo: a Mojo web framework.

HTTP/1.1 and HTTP/2 server and client, WebSocket (RFC 6455), TLS 1.2/1.3
(OpenSSL with ALPN), TCP, Unix sockets and DNS, on one reactor per worker
(epoll, opt-in io_uring on Linux; kqueue on macOS).

```mojo
from dodo import HttpServer, Router, Request, Response, ok, SocketAddr

def hello(req: Request) raises -> Response:
    return ok("hello")

def main() raises:
    var r = Router()
    r.get("/", hello)
    var srv = HttpServer.bind(SocketAddr.localhost(8080))
    srv.serve(r^, num_workers=4)
```

The root re-exports the types most applications use. Everything else
lives in its subpackage:

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
dodo.testing  TestClient, fork_server
dodo.utils    POSIX helpers the Mojo stdlib doesn't expose yet
```
"""

# Errors
from .errors import HttpStatusError, IoError, ValidationError

# HTTP core types + builders. `WsUpgrade` and `Http2Config` are the types
# of `ServerConfig.ws` and `ServerConfig.h2`, so they're exported too.
from .http._server.config import WsUpgrade
from .http.proto.h2_config import Http2Config
from .http.server import (
    HttpServer,
    ServerConfig,
    ShutdownReport,
    ok,
    ok_json,
    bad_request,
    unauthorized,
    forbidden,
    not_found,
    internal_error,
    redirect,
)
from .http.client import HttpClient
from .http._client.shortcuts import get, post, put, patch, delete, head
from .http.request import Request, Method
from .http.response import Response, Status, stream_response
from .http.body import Body, ChunkSource
from .http.request_view import RequestView
from .http.url import Url, UrlParseError
from .http.headers import HeaderMap, HeaderInjectionError
from .http.cancel import Cancel
from .http.handler import (
    Handler,
    CancelHandler,
    ViewHandler,
    WithCancel,
    WithViewCancel,
    HandlerInfallible,
    WithRaises,
)
from .http.router import Router
from .http.routes import ComptimeRoute, ComptimeRouter
from .http.auth import Auth, BasicAuth, BearerAuth
from .http.error import HttpError, TooManyRedirects
from .http.static_response import precompute_response, StaticResponse
from .http.cookie import Cookie, CookieJar, parse_set_cookie_header

# Streaming server and reactor-integrated body sources
from .io import ByteReader, ByteWriter
from .http.streaming_server import StreamHandler, StreamConn
from .http.async_body import AsyncChunkSource, ChunkPoll, UpstreamChunkSource

# Extractors (concrete; custom types belong as their own Extractor struct)
from .http.extract import (
    Extractor,
    PathInt,
    PathStr,
    PathFloat,
    PathBool,
    OptionalPathInt,
    OptionalPathStr,
    OptionalPathFloat,
    OptionalPathBool,
    QueryInt,
    QueryStr,
    QueryFloat,
    QueryBool,
    OptionalQueryInt,
    OptionalQueryStr,
    OptionalQueryFloat,
    OptionalQueryBool,
    HeaderInt,
    HeaderStr,
    HeaderFloat,
    HeaderBool,
    OptionalHeaderInt,
    OptionalHeaderStr,
    OptionalHeaderFloat,
    OptionalHeaderBool,
    BodyBytes,
    BodyText,
    Json,
    FromJson,
    JsonAs,
    Cookies,
    Form,
    Multipart,
    Peer,
    Extracted,
)

# Middleware stack
from .http.middleware import (
    CatchPanic,
    Compress,
    Logger,
    RequestId,
)
from .http.cors import Cors, CorsConfig
from .http.cache import Cache, InMemoryCacheStore
from .http.fs import FileServer
from .http.reliability import Retry, RetryPolicy, PostHocDeadline

# Sessions
from .http.session import (
    Session,
    CookieSessionStore,
    InMemorySessionStore,
)

# TLS
from .tls.config import TlsConfig
from .tls.acceptor import TlsAcceptor, TlsServerConfig, TlsSniCert

# Networking
from .net.address import IpAddr, SocketAddr
from .tcp.stream import TcpStream
from .tcp.listener import TcpListener
from .uds.listener import UnixListener
from .uds.stream import UnixStream

# WebSocket (high-level only; frame codec lives in dodo.ws)
from .ws.client import WsClient, WsMessage
from .ws.server import WsServer, WsConnection

# Testing
from .testing import TestClient

# Runtime conveniences
from .runtime._thread import num_cpus
from .runtime.scheduler import default_worker_count

"""The server the live checks in ``tests/live/`` run against.

    live_server <mode> <port> [workers]

Modes:

- ``http``: cleartext HTTP/1.1 and HTTP/2 (prior knowledge and h2c).
- ``https``: TLS with ALPN ``h2`` and ``http/1.1``, using the test
  certificates in ``tests/certs/``.
- ``ws``: WebSocket echo, one thread per connection.
- ``ws-reactor``: WebSocket echo on the reactor.

Routes on the HTTP modes:

- ``/echo``: the request body back.
- ``/big``: a 1 MB body.
- ``/inject``: copies the query string into a response header, as a
  careless app would; the server must refuse a CR or LF in it.
- ``/inject2``: sets a header value with a CRLF in it.
- ``/raise``: the handler raises.
- anything else: a line describing what the server parsed, which the
  probes check.

Prints ``listening <port>`` once it accepts connections.
"""

from std.sys import argv

from dodo.http import (
    HttpServer,
    Request,
    Response,
    ServerConfig,
    WsUpgrade,
    ok,
)
from dodo.net import SocketAddr
from dodo.ws import WsConnection, WsMessage
from dodo.ws.server_reactor import WsReactorHandler, WsSession


comptime _SERVER_CRT = "tests/certs/server.crt"
comptime _SERVER_KEY = "tests/certs/server.key"


def _split_target(url: String) -> Tuple[String, String]:
    """The request target as (path, query)."""
    var q = url.find("?")
    if q < 0:
        return (url, String(""))
    return (String(url[byte=:q]), String(url[byte=q + 1 :]))


def _describe(req: Request) raises -> String:
    var path = _split_target(req.url)[0]
    var out = "method=" + req.method + " path=" + path
    out += " bodylen=" + String(len(req.body))
    var cl = req.headers.get("content-length")
    if cl != "":
        out += " cl=" + cl
    var te = req.headers.get("transfer-encoding")
    if te != "":
        out += " te=" + te
    out += " nh=" + String(req.headers.len())
    return out


def handle(req: Request) raises -> Response:
    var target = _split_target(req.url)
    var path = target[0]
    var query = target[1]
    if path == "/echo":
        return Response(status=200, reason="OK", body=req.body.copy())
    if path == "/big":
        var body = List[UInt8](length=1024 * 1024, fill=UInt8(ord("x")))
        return Response(status=200, reason="OK", body=body^)
    if path == "/inject":
        var r = ok("ok")
        r.headers.set("X-Echo", query)
        return r^
    if path == "/inject2":
        var r = ok("ok")
        r.headers.set("X-Echo", "a\r\nSet-Cookie: evil=1")
        return r^
    if path == "/raise":
        raise Error("boom")
    return ok(_describe(req))


def ws_echo(mut conn: WsConnection) raises -> None:
    """Echo each message whole, as Autobahn's fuzzing client expects."""
    while True:
        var msg: WsMessage
        try:
            msg = conn.recv_message()
        except:
            # A CLOSE (already answered) or a protocol error (already
            # failed with the right code) ends the connection.
            return
        if msg.is_text:
            conn.send_text(msg.as_text())
        else:
            conn.send_binary(msg.as_binary())


@fieldwise_init
struct WsEcho(Copyable, WsReactorHandler):
    """The reactor twin of :func:`ws_echo`."""

    def on_open(mut self, mut ws: WsSession) raises -> None:
        pass

    def on_message(
        mut self, mut ws: WsSession, var msg: WsMessage
    ) raises -> None:
        if msg.is_text:
            ws.send_text(msg.as_text())
        else:
            ws.send_binary(msg.as_binary())

    def on_close(mut self, mut ws: WsSession, code: Int) -> None:
        pass


def _bind(mode: String, port: Int) raises -> HttpServer:
    var addr = SocketAddr.localhost(UInt16(port))
    var config = ServerConfig()
    if mode == "ws":
        config.ws = WsUpgrade(ws_echo)
    elif mode == "ws-reactor":
        config.ws = WsUpgrade.on_reactor(WsEcho())
    if mode == "https":
        var alpn = List[String]()
        alpn.append("h2")
        alpn.append("http/1.1")
        return HttpServer.bind_tls(
            addr, _SERVER_CRT, _SERVER_KEY, alpn^, config^
        )
    return HttpServer.bind(addr, config^)


def main() raises:
    var args = argv()
    if len(args) < 3:
        print("usage: live_server <http|https|ws|ws-reactor> <port> [workers]")
        return
    var mode = String(args[1])
    var port = Int(String(args[2]))
    var workers = 1
    if len(args) > 3:
        workers = Int(String(args[3]))
    var srv = _bind(mode, port)
    print("listening", srv.local_addr().port, flush=True)
    srv.serve(handle, num_workers=workers)

# Flare equivalent of research/lightbug-audit/probe_server.mojo.
# Run: mojo -I ~/src/flare probe_server.mojo [num_workers]
from std.sys import argv
from flare.prelude import *


def handle(req: Request) raises -> Response:
    var u = req.url
    var path = u
    var query = String("")
    var q = u.find("?")
    if q >= 0:
        path = String(u[byte=:q])
        query = String(u[byte=q + 1 :])
    if path == "/inject":
        # Header value taken from the query string, as a careless app would do.
        var r = ok("ok")
        r.headers.set("X-Echo", query)
        return r^
    if path == "/inject2":
        var r = ok("ok")
        r.headers.set("X-Echo", "a\r\nSet-Cookie: evil=1")
        return r^
    if path == "/inject3":
        # The public "unchecked" setter: does the serializer re-check?
        var r = ok("ok")
        r.headers.set_unchecked("X-Echo", "x-echo", "a\r\nSet-Cookie: evil=1")
        return r^
    if path == "/raise":
        raise Error("boom")
    var out = "method=" + req.method + " path=" + path + " bodylen=" + String(len(req.body))
    var cl = req.headers.get("content-length")
    if cl != "":
        out += " cl=" + cl
    var te = req.headers.get("transfer-encoding")
    if te != "":
        out += " te=" + te
    for i in range(req.headers.len()):
        if req.headers.name_at(i) == "":
            out += " emptyname"
    out += " nh=" + String(req.headers.len())
    return ok(out)


def main() raises:
    var workers = 1
    var args = argv()
    if len(args) > 1:
        workers = Int(args[1])
    var srv = HttpServer.bind(SocketAddr.localhost(8099))
    if len(args) > 2:
        srv.config.max_keepalive_requests = Int(args[2])
    print("listening on 127.0.0.1:8099 workers=" + String(workers))
    srv.serve(handle, num_workers=workers)

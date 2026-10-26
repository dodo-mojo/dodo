from lightbug_http import OK, Header, HeaderKey, Headers, HTTPRequest, HTTPResponse, HTTPService, Server


@fieldwise_init
struct ProbeService(HTTPService):
    fn func(mut self, req: HTTPRequest) raises -> HTTPResponse:
        var p = req.uri.path
        if p == "/inject":
            # Header value taken from the query string, as a careless app would do
            var v = req.uri.query_string
            return HTTPResponse(
                "ok".as_bytes(),
                headers=Headers(Header("X-Echo", v)),
            )
        if p == "/inject2":
            return HTTPResponse(
                "ok".as_bytes(),
                headers=Headers(Header("X-Echo", "a\r\nSet-Cookie: evil=1")),
            )
        var out = String("method=", req.method, " path=", p, " bodylen=", len(req.body_raw))
        var cl = req.headers.get(HeaderKey.CONTENT_LENGTH)
        if cl:
            out += String(" cl=", cl.value())
        var te = req.headers.get(HeaderKey.TRANSFER_ENCODING)
        if te:
            out += String(" te=", te.value())
        var empty = req.headers.get("")
        if empty:
            out += String(" emptyname=", empty.value())
        return OK(out)


fn main() raises:
    var server = Server()
    var service = ProbeService()
    server.listen_and_serve("127.0.0.1:8099", service)

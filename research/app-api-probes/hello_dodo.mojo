"""P5: smallest working dodo server: GET /hello/:name answers a JSON body.

Run: hello_dodo [port]   (default 8000)
"""

from std.sys import argv

from dodo.http import HttpServer, Request, Response, Router, ok
from dodo.json import serialize_json
from dodo.net import SocketAddr


@fieldwise_init
struct Greeting:
    var message: String


def hello(req: Request) raises -> Response:
    var name = req.param("name")
    var greeting = Greeting(String("hi ", name))
    var response = ok(serialize_json(greeting))
    response.headers.set("Content-Type", "application/json")
    return response^


def main() raises:
    var port = UInt16(8000)
    var args = argv()
    if len(args) > 1:
        port = UInt16(Int(args[1]))

    var router = Router()
    router.get("/hello/:name", hello)

    var server = HttpServer.bind(SocketAddr.localhost(port))
    server.serve(router^)

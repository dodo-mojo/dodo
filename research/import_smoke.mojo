from dodo import HttpServer, HttpClient, Router, Request, Response, ok
from dodo.ws import WsClient
from dodo.tls import TlsConfig


def main() raises:
    var r = Router()
    print("dodo imports ok")

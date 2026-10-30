"""Baseline: a bare Handler with no router or App. Usage: bench_raw PORT WORKERS"""

from std.sys import argv

from dodo import Request, Response, ok, serve
from dodo.http import Handler


@fieldwise_init
struct Raw(Copyable, Handler):
    def serve(self, req: Request) raises -> Response:
        return ok("hello")


def main() raises:
    var args = argv()
    serve(Raw(), port=UInt16(Int(args[1])), num_workers=Int(args[2]))

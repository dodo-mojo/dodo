"""Host lookups for the loop client, run on the offload pool.

``getaddrinfo(3)`` blocks and has no async form, so each lookup is a job
on the offload pool (ADR-0004). The answer comes back through the
worker's wake fd, like any offload job, and the worker never waits.
"""

from std.collections import List, Optional

from dodo.dns import resolve
from dodo.http._offload_pool import (
    offload_job,
    offload_port_open,
    offload_submit,
)
from dodo.http.handler import Handler
from dodo.http.request import Request
from dodo.http.response import Response
from dodo.net import IpAddr


comptime _LOOKUP_FAILED = 502
"""The status a lookup job answers with when the host did not resolve."""


@fieldwise_init
struct _Lookup(Copyable, Handler):
    """Resolves the host named by the request's URL. The addresses come
    back one per line; a failure comes back as 502 with the message."""

    def serve(self, req: Request) raises -> Response:
        try:
            var addrs = resolve(req.url)
            var lines = String()
            for i in range(len(addrs)):
                if i > 0:
                    lines += "\n"
                lines += String(addrs[i])
            return Response(status=200, body=List[UInt8](lines.as_bytes()))
        except e:
            return Response(
                status=_LOOKUP_FAILED, body=List[UInt8](String(e).as_bytes())
            )


def lookup_port_open(wake_fd: Int, threads: Int, depth: Int) raises -> Int:
    """Open this worker's port for lookups. Close it with
    ``close_offload_port``."""
    return offload_port_open(_Lookup(), wake_fd, threads, depth)


def lookup_submit(port: Int, host: String) raises -> Int:
    """Queue a lookup of ``host``. Returns the job, or 0 when the pool is
    full."""
    return offload_submit(port, Request(method="GET", url=host), 0, 0)


struct LookupResult(Movable):
    """What one lookup came to: addresses, or why there are none."""

    var addrs: List[IpAddr]
    var error: String

    def __init__(out self, var addrs: List[IpAddr], error: String):
        self.addrs = addrs^
        self.error = error


def lookup_result(job: Int) -> LookupResult:
    """Read what lookup ``job`` came back with."""
    var jp = offload_job(job)
    if not jp[].resp:
        return LookupResult(List[IpAddr](), "DnsError: the lookup did not run")
    ref resp = jp[].resp.value()
    var text = String(unsafe_from_utf8=Span(resp.body))
    if resp.status != 200:
        return LookupResult(List[IpAddr](), text)
    var addrs = List[IpAddr]()
    for line in text.split("\n"):
        try:
            addrs.append(IpAddr.parse(String(line)))
        except:
            pass
    if len(addrs) == 0:
        return LookupResult(addrs^, "DnsError: no addresses")
    return LookupResult(addrs^, "")


def literal_address(host: String) -> Optional[IpAddr]:
    """``host`` as an address when it is one, so it needs no lookup."""
    try:
        return Optional[IpAddr](IpAddr.parse(host))
    except:
        return Optional[IpAddr]()

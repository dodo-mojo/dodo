"""What every HTTP/1.1 client exchange shares, blocking or on the loop:
the request head, the redirect hop, the proxy choice, the replay rule
and the unzipped final body.

``HttpClient`` and the loop client (``dodo.http._loop_calls``) both build
on these, so a call answers the same whichever one makes it.
"""

from std.collections import List
from std.os import getenv

from ..encoding import decode_content
from ..error import TooManyRedirects
from ..headers import HeaderMap
from ..redirect_policy import RedirectAction, RedirectMode, RedirectPolicy
from ..reliability import _is_idempotent_method
from ..request import Request
from ..response import Response
from ..url import Url


comptime ACCEPT_ENCODINGS = "gzip, deflate, br"
"""What a client that unzips bodies asks for."""


def resolve_url(base_url: String, url: String) -> String:
    """``url`` with ``base_url`` put in front when ``url`` is a path."""
    if base_url.byte_length() == 0:
        return url
    if url.startswith("http://") or url.startswith("https://"):
        return url
    return base_url + url


def same_origin(a: String, b: String) -> Bool:
    """Scheme, host and port all equal (RFC 6454). Unparseable means
    not the same."""
    try:
        var ua = Url.parse(a)
        var ub = Url.parse(b)
        if ua.scheme.lower() != ub.scheme.lower():
            return False
        if ua.host.lower() != ub.host.lower():
            return False
        return ua.port == ub.port
    except:
        return False


def is_idempotent(method: String) -> Bool:
    """Whether ``method`` is idempotent (RFC 9110 sec 9.2.2), so sending
    it twice has the effect of sending it once."""
    return _is_idempotent_method(method.upper())


def may_replay(method: String, write_failed: Bool, no_reply: Bool) -> Bool:
    """Whether a request that failed on a reused connection may be sent
    again on a fresh one (RFC 9112 sec 9.3.1).

    A failed write is the stale-connection signature before the request
    reached the server. A read that failed before any reply byte is the
    other (the peer closed an idle keep-alive), but the request may have
    been processed, so only an idempotent one is sent again. Once reply
    bytes have arrived, nothing is sent again.
    """
    if write_failed:
        return True
    return no_reply and is_idempotent(method)


struct ProxyEnv(Copyable):
    """The proxy settings from the environment, read once."""

    var no_proxy: String
    var http: String
    var https: String
    var all: String

    def __init__(out self):
        """Read ``NO_PROXY``, ``HTTP_PROXY``, ``HTTPS_PROXY`` and
        ``ALL_PROXY``; the lowercase names count too, as in curl."""
        self.no_proxy = getenv("NO_PROXY", getenv("no_proxy", ""))
        self.http = getenv("HTTP_PROXY", getenv("http_proxy", ""))
        self.https = getenv("HTTPS_PROXY", getenv("https_proxy", ""))
        self.all = getenv("ALL_PROXY", getenv("all_proxy", ""))

    def pick(self, u: Url, explicit: String = "") -> String:
        """The proxy URL to reach ``u`` through, or empty for a direct
        connection.

        ``NO_PROXY`` (host suffixes, or ``*`` for all) wins; then the
        ``explicit`` proxy; then ``HTTPS_PROXY`` or ``HTTP_PROXY`` by
        scheme; then ``ALL_PROXY``.
        """
        var host = u.host.lower()
        if self.no_proxy == "*":
            return ""
        if self.no_proxy.byte_length() > 0:
            for entry in self.no_proxy.split(","):
                var e = String(entry).strip().lower()
                if e.byte_length() == 0:
                    continue
                if host == e or host.endswith("." + e):
                    return ""
        if explicit.byte_length() > 0:
            return explicit
        if u.is_tls():
            if self.https.byte_length() > 0:
                return self.https
        elif self.http.byte_length() > 0:
            return self.http
        return self.all


def connect_request(host: String, port: UInt16) -> String:
    """The ``CONNECT`` request that opens a tunnel to ``host:port``
    through a proxy."""
    var target = host + ":" + String(Int(port))
    var req = String("CONNECT ") + target + " HTTP/1.1\r\n"
    req += "Host: " + target + "\r\n"
    req += "Proxy-Connection: keep-alive\r\n\r\n"
    return req^


def tunnel_status_ok(head: Span[UInt8, _]) -> Bool:
    """Whether a proxy's reply head to ``CONNECT`` has a 2xx status."""
    var line_end = 0
    while line_end < len(head) and head[line_end] != 13:
        line_end += 1
    var sp = 0
    while sp < line_end and head[sp] != 32:
        sp += 1
    if sp + 1 >= line_end:
        return False
    return head[sp + 1] == UInt8(ord("2"))


def request_head(
    method: String,
    u: Url,
    headers: HeaderMap,
    body_len: Int,
    auth_header: String,
    user_agent: String,
    keep_alive: Bool,
) -> String:
    """The HTTP/1.1 request line and headers, ending in the empty line.

    ``Host`` comes from ``u`` (RFC 9110 sec 7.2); a caller's ``Host`` is
    dropped. A caller's ``Authorization`` is dropped when ``auth_header``
    is set, as on the HTTP/2 paths.
    """
    var wire = method + " " + u.request_target() + " HTTP/1.1\r\n"
    var host = u.host
    var default_port = False
    if u.scheme == "http" and u.port == 80:
        default_port = True
    if u.scheme == "https" and u.port == 443:
        default_port = True
    if not default_port:
        host = host + ":" + String(Int(u.port))
    wire += "Host: " + host + "\r\n"
    wire += "User-Agent: " + user_agent + "\r\n"
    if keep_alive:
        wire += "Connection: keep-alive\r\n"
    else:
        wire += "Connection: close\r\n"
    wire += "Accept: */*\r\n"
    if auth_header.byte_length() > 0:
        wire += "Authorization: " + auth_header + "\r\n"
    for i in range(headers.len()):
        var name = headers._keys[i]
        var lower = name.lower()
        if lower == "host":
            continue
        if lower == "authorization" and auth_header.byte_length() > 0:
            continue
        wire += name + ": " + headers._values[i] + "\r\n"
    if body_len > 0:
        wire += "Content-Length: " + String(body_len) + "\r\n"
    wire += "\r\n"
    return wire^


struct RedirectHop(Movable):
    """Where one exchange is in its chain of redirects: what the next
    request sends, and how many hops it has taken."""

    var url: String
    """The URL the next request goes to."""
    var method: String
    var headers: HeaderMap
    var body: List[UInt8]
    var auth_header: String
    """The ``Authorization`` value for the next request; dropped when a
    redirect crosses origins and the policy does not forward it."""
    var hops: Int
    """How many redirects were followed so far."""
    var base_url: String
    """Put in front of a path before comparing origins."""

    def __init__(
        out self,
        req: Request,
        auth_header: String,
        unzip: Bool,
        base_url: String = "",
    ):
        self.url = req.url
        self.method = req.method
        self.headers = req.headers.copy()
        self.body = req.body.copy()
        self.auth_header = auth_header
        self.hops = 0
        self.base_url = base_url
        if unzip and not self.headers.contains("Accept-Encoding"):
            try:
                self.headers.set("Accept-Encoding", ACCEPT_ENCODINGS)
            except:
                pass

    def follow(mut self, resp: Response, policy: RedirectPolicy) raises -> Bool:
        """Whether ``resp`` is a redirect to follow. When it is, the hop
        now describes the next request. False means ``resp`` is the
        answer.

        Raises:
            Error: The policy refuses a cross-origin redirect.
            TooManyRedirects: The hop cap was reached.
        """
        if not resp.is_redirect():
            return False
        var location = resp.headers.get("Location")
        var decision = policy.decide(
            self.url, self.method, resp.status, location, self.hops
        )
        if decision.action == RedirectAction.FOLLOW:
            self._take(decision.next_url, decision.next_method)
            if decision.next_body_dropped:
                self.body = List[UInt8]()
                _ = self.headers.remove("Content-Type")
            if not decision.forward_authorization:
                self.auth_header = String("")
                _ = self.headers.remove("Authorization")
            return True
        if decision.action == RedirectAction.REJECT:
            raise Error(
                String("RedirectPolicy: cross-origin redirect to '")
                + location
                + String("' refused (same_origin_only)")
            )
        if location.byte_length() == 0:
            return False
        if policy.mode == RedirectMode.DENY:
            return False
        raise TooManyRedirects(self.url, self.hops)

    def _take(mut self, next_url: String, next_method: String):
        """Move to ``next_url``. Credentials the caller attached were
        meant for the origin they asked for, so ``Cookie`` and
        ``Proxy-Authorization`` stay behind when the origin changes."""
        var here = resolve_url(self.base_url, self.url)
        var there = resolve_url(self.base_url, next_url)
        if not same_origin(here, there):
            _ = self.headers.remove("Cookie")
            _ = self.headers.remove("Proxy-Authorization")
        self.url = next_url
        self.method = next_method
        self.hops += 1


def unzip_body(var resp: Response, max_bytes: Int) -> Response:
    """Decode a gzip, deflate or br body in place. Identity, stacked,
    unknown or corrupt bodies are left as they came."""
    var enc = resp.headers.get("Content-Encoding")
    if enc.byte_length() == 0:
        return resp^
    var name = String(enc.strip()).lower()
    if name == "identity" or name == "":
        return resp^
    if name.find(",") >= 0:
        return resp^
    try:
        var decoded = decode_content(Span[UInt8, _](resp.body), name, max_bytes)
        resp.body = decoded^
        _ = resp.headers.remove("Content-Encoding")
        resp.headers.set("Content-Length", String(len(resp.body)))
    except:
        pass
    return resp^

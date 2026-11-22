"""The pieces every HTTP/1.1 client exchange shares: the replay rule,
the proxy choice, the tunnel request and reply, and the request head."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from dodo.http import HeaderMap, Request, Response
from dodo.http.redirect_policy import RedirectPolicy
from dodo.http.url import Url
from dodo.http._client.exchange import (
    ProxyEnv,
    RedirectHop,
    connect_request,
    may_replay,
    request_head,
    tunnel_status_ok,
)


def _proxies() -> ProxyEnv:
    var env = ProxyEnv()
    env.no_proxy = ""
    env.http = "http://hp:1"
    env.https = "http://sp:2"
    env.all = "http://ap:3"
    return env^


def test_a_failed_write_is_always_replayed() raises:
    assert_true(may_replay("POST", True, False))
    assert_true(may_replay("GET", True, False))


def test_no_reply_replays_only_a_safe_method() raises:
    assert_true(may_replay("GET", False, True))
    assert_true(may_replay("put", False, True))
    assert_false(may_replay("POST", False, True))
    assert_false(may_replay("PATCH", False, True))


def test_a_started_reply_is_never_replayed() raises:
    assert_false(may_replay("GET", False, False))


def test_the_proxy_follows_the_scheme() raises:
    var env = _proxies()
    assert_equal(env.pick(Url.parse("http://x.com/")), "http://hp:1")
    assert_equal(env.pick(Url.parse("https://x.com/")), "http://sp:2")
    env.https = ""
    assert_equal(env.pick(Url.parse("https://x.com/")), "http://ap:3")


def test_an_explicit_proxy_wins_over_the_environment() raises:
    var env = _proxies()
    var got = env.pick(Url.parse("http://x.com/"), "http://mine:9")
    assert_equal(got, "http://mine:9")


def test_no_proxy_matches_hosts_and_their_subdomains() raises:
    var env = _proxies()
    env.no_proxy = " Internal.COM , ,localhost"
    assert_equal(env.pick(Url.parse("http://internal.com/")), "")
    assert_equal(env.pick(Url.parse("http://api.internal.com/")), "")
    assert_equal(env.pick(Url.parse("http://localhost:8080/")), "")
    # A suffix that is not a whole label does not match.
    assert_equal(env.pick(Url.parse("http://notinternal.com/")), "http://hp:1")
    env.no_proxy = "*"
    assert_equal(env.pick(Url.parse("http://x.com/"), "http://mine:9"), "")


def test_connect_names_the_target_twice() raises:
    var req = connect_request("example.com", 443)
    assert_true(req.startswith("CONNECT example.com:443 HTTP/1.1\r\n"), req)
    assert_true("\r\nHost: example.com:443\r\n" in req, req)
    assert_true(req.endswith("\r\n\r\n"), req)


def test_only_a_2xx_reply_opens_the_tunnel() raises:
    var ok = String("HTTP/1.1 200 Connection established\r\n\r\n")
    var denied = String("HTTP/1.1 407 Proxy Auth\r\n\r\n")
    var cut = String("HTTP/1.1\r\n\r\n")
    assert_true(tunnel_status_ok(ok.as_bytes()))
    assert_false(tunnel_status_ok(denied.as_bytes()))
    assert_false(tunnel_status_ok(cut.as_bytes()))
    assert_false(tunnel_status_ok(String("").as_bytes()))


def test_the_head_keeps_a_port_only_when_it_is_not_the_default() raises:
    var h = HeaderMap()
    var plain = request_head(
        "GET", Url.parse("http://a.com/x"), h, 0, "", "ua", True
    )
    var odd = request_head(
        "GET", Url.parse("https://a.com:8443/"), h, 0, "", "ua", True
    )
    assert_true("\r\nHost: a.com\r\n" in plain, plain)
    assert_true("\r\nHost: a.com:8443\r\n" in odd, odd)


def test_the_head_drops_the_callers_host_and_a_replaced_auth() raises:
    var h = HeaderMap()
    h.set("Host", "evil.com")
    h.set("Authorization", "Basic old")
    var head = request_head(
        "POST", Url.parse("http://a.com/"), h, 3, "Bearer new", "ua", False
    )
    assert_false("evil.com" in head, head)
    assert_false("Basic old" in head, head)
    assert_true("\r\nAuthorization: Bearer new\r\n" in head, head)
    assert_true("\r\nConnection: close\r\n" in head, head)
    assert_true("\r\nContent-Length: 3\r\n" in head, head)


def test_a_cross_origin_redirect_leaves_credentials_behind() raises:
    var req = Request(method="GET", url="http://a.com/start")
    req.headers.set("Cookie", "s=1")
    var hop = RedirectHop(req, "Bearer t", False)
    var resp = Response(status=302)
    resp.headers.set("Location", "http://b.com/next")
    assert_true(hop.follow(resp, RedirectPolicy.follow_all(10)))
    assert_equal(hop.url, "http://b.com/next")
    assert_equal(hop.hops, 1)
    assert_equal(hop.auth_header, "")
    assert_false(hop.headers.contains("Cookie"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

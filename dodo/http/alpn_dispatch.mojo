"""ALPN-driven wire dispatch.

After a TLS handshake the server picks the protocol driver from the
negotiated ALPN identifier. dodo serves three wire shapes:

* **HTTP/1.1**: ALPN ``"http/1.1"`` or no ALPN.
* **h2c**: HTTP/2 cleartext, via ``Upgrade: h2c`` on an h1 request
  (RFC 7540 §3.2) or the prior-knowledge preface.
* **HTTP/2**: ALPN ``"h2"`` over TLS (RFC 9113 §3.3).

These are pure decision functions, so tests can pin every ALPN to wire
mapping without a listener.

References:
- RFC 7301, TLS Application-Layer Protocol Negotiation.
- RFC 9113 §3.3, Protocol Identification for HTTP/2.
"""

from std.collections import List


struct WireProtocol:
    """Integer codepoints for the wires :class:`HttpServer` dispatches
    between."""

    comptime UNKNOWN: Int = 0
    """No ALPN match. The reactor closes the connection with a TLS
    no_application_protocol alert (RFC 7301 §3.2)."""

    comptime HTTP_1_1: Int = 1
    """HTTP/1.1: ALPN ``"http/1.1"`` or no ALPN advertised."""

    comptime H2C: Int = 2
    """HTTP/2 cleartext upgrade via h1's ``Upgrade: h2c`` header. Not
    negotiated through ALPN."""

    comptime HTTP_2: Int = 3
    """HTTP/2 over TLS: ALPN ``"h2"`` (RFC 9113 §3.3)."""


comptime ALPN_HTTP_1_1: String = "http/1.1"
"""RFC 7301 identifier for HTTP/1.1."""

comptime ALPN_HTTP_2: String = "h2"
"""RFC 9113 §3.3 identifier for HTTP/2 over TLS."""


def dispatch_alpn(alpn: String) -> Int:
    """Map a negotiated ALPN identifier to a :data:`WireProtocol`
    codepoint. Empty means HTTP/1.1 (ALPN wasn't advertised); anything
    unknown maps to UNKNOWN."""
    if alpn == "":
        return WireProtocol.HTTP_1_1
    if alpn == ALPN_HTTP_1_1:
        return WireProtocol.HTTP_1_1
    if alpn == ALPN_HTTP_2:
        return WireProtocol.HTTP_2
    return WireProtocol.UNKNOWN


def dispatch_h2c_upgrade(detected: Bool) -> Int:
    """Map the h1 parser's ``Upgrade: h2c`` detection to a wire
    codepoint. Used on the cleartext path (no TLS, no ALPN)."""
    if detected:
        return WireProtocol.H2C
    return WireProtocol.HTTP_1_1


def negotiate_alpn(
    client_advertised: List[String], server_supports: List[String]
) -> String:
    """Pick the highest-priority protocol both sides support
    (RFC 7301 §3.2).

    The server's order wins: the first entry of ``server_supports`` that
    appears anywhere in ``client_advertised``. Returns ``""`` when there
    is no overlap; the caller must then close the connection with the
    ``no_application_protocol`` alert.
    """
    for i in range(len(server_supports)):
        var s = server_supports[i]
        for j in range(len(client_advertised)):
            if client_advertised[j] == s:
                return s
    return String("")


def wire_protocol_name(protocol: Int) -> String:
    """A readable label for a :class:`WireProtocol` codepoint, for logs
    and metrics."""
    if protocol == WireProtocol.HTTP_1_1:
        return String("HTTP/1.1")
    if protocol == WireProtocol.H2C:
        return String("h2c")
    if protocol == WireProtocol.HTTP_2:
        return String("HTTP/2")
    return String("unknown")

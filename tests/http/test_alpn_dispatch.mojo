"""Unit tests for the ALPN dispatcher (``dodo.http.alpn_dispatch``)."""

from std.testing import assert_equal

from dodo.http.alpn_dispatch import (
    ALPN_HTTP_1_1,
    ALPN_HTTP_2,
    WireProtocol,
    dispatch_alpn,
    dispatch_h2c_upgrade,
    negotiate_alpn,
    wire_protocol_name,
)


def test_wire_protocol_codepoints() raises:
    """Codepoints are stable so logs carry a fixed integer."""
    assert_equal(WireProtocol.UNKNOWN, 0)
    assert_equal(WireProtocol.HTTP_1_1, 1)
    assert_equal(WireProtocol.H2C, 2)
    assert_equal(WireProtocol.HTTP_2, 3)


def test_dispatch_alpn_empty_falls_back_to_h1() raises:
    """Empty ALPN means the handshake didn't negotiate one; the server
    falls back to HTTP/1.1."""
    assert_equal(dispatch_alpn(String("")), WireProtocol.HTTP_1_1)


def test_dispatch_alpn_known_identifiers() raises:
    assert_equal(dispatch_alpn(ALPN_HTTP_1_1), WireProtocol.HTTP_1_1)
    assert_equal(dispatch_alpn(ALPN_HTTP_2), WireProtocol.HTTP_2)


def test_dispatch_alpn_unknown_identifier() raises:
    """An unknown identifier maps to UNKNOWN; the reactor closes the
    connection with the no_application_protocol alert (RFC 7301 §3.2)."""
    assert_equal(
        dispatch_alpn(String("h1.5-experimental")),
        WireProtocol.UNKNOWN,
    )


def test_dispatch_alpn_h3_is_unknown() raises:
    """dodo doesn't serve HTTP/3, so ``h3`` is an unknown identifier."""
    assert_equal(dispatch_alpn(String("h3")), WireProtocol.UNKNOWN)


def test_dispatch_alpn_is_case_sensitive() raises:
    """ALPN identifiers are case-sensitive (RFC 7301)."""
    assert_equal(dispatch_alpn(String("H2")), WireProtocol.UNKNOWN)
    assert_equal(dispatch_alpn(String("HTTP/1.1")), WireProtocol.UNKNOWN)


def test_dispatch_h2c_upgrade() raises:
    assert_equal(dispatch_h2c_upgrade(True), WireProtocol.H2C)
    assert_equal(dispatch_h2c_upgrade(False), WireProtocol.HTTP_1_1)


def test_negotiate_alpn_server_preference_wins() raises:
    """RFC 7301 §3.2: the server's order wins, so ``h2`` beats
    ``http/1.1`` even though the client listed it second."""
    var client = List[String]()
    client.append(ALPN_HTTP_1_1)
    client.append(ALPN_HTTP_2)
    var server = List[String]()
    server.append(ALPN_HTTP_2)
    server.append(ALPN_HTTP_1_1)
    var pick = negotiate_alpn(client, server)
    assert_equal(pick, ALPN_HTTP_2)


def test_negotiate_alpn_no_overlap_returns_empty() raises:
    var client = List[String]()
    client.append(String("h1.5-experimental"))
    var server = List[String]()
    server.append(ALPN_HTTP_2)
    server.append(ALPN_HTTP_1_1)
    var pick = negotiate_alpn(client, server)
    assert_equal(pick, String(""))


def test_negotiate_alpn_empty_inputs() raises:
    var client = List[String]()
    var server = List[String]()
    var pick = negotiate_alpn(client, server)
    assert_equal(pick, String(""))


def test_wire_protocol_name() raises:
    assert_equal(wire_protocol_name(WireProtocol.HTTP_1_1), String("HTTP/1.1"))
    assert_equal(wire_protocol_name(WireProtocol.H2C), String("h2c"))
    assert_equal(wire_protocol_name(WireProtocol.HTTP_2), String("HTTP/2"))
    assert_equal(wire_protocol_name(WireProtocol.UNKNOWN), String("unknown"))
    assert_equal(wire_protocol_name(9999), String("unknown"))


def main() raises:
    test_wire_protocol_codepoints()
    test_dispatch_alpn_empty_falls_back_to_h1()
    test_dispatch_alpn_known_identifiers()
    test_dispatch_alpn_unknown_identifier()
    test_dispatch_alpn_h3_is_unknown()
    test_dispatch_alpn_is_case_sensitive()
    test_dispatch_h2c_upgrade()
    test_negotiate_alpn_server_preference_wins()
    test_negotiate_alpn_no_overlap_returns_empty()
    test_negotiate_alpn_empty_inputs()
    test_wire_protocol_name()
    print("test_alpn_dispatch: 11 passed")

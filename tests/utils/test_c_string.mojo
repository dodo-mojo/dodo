"""Tests for dodo.utils.c_string."""

from std.ffi import OwnedDLHandle
from std.testing import TestSuite, assert_equal

from dodo.net import _find_dodo_lib
from dodo.tls import TlsConfig
from dodo.tls.stream import _build_ssl_ctx, _do_ssl_ctx_free
from dodo.utils.c_string import prepare_c_string


def _c_text(mut text: String) -> String:
    """What C reads from `text.as_c_string_span()`, up to 32 bytes."""
    prepare_c_string(text)
    _ = text.as_c_string_span()
    var p = text.unsafe_ptr()
    var seen = String("")
    for i in range(32):
        var byte = Int(p[unsafe_offset=i])
        if byte == 0:
            break
        seen += chr(byte)
    return seen^


def _from_default(text: String = "") -> String:
    var copy = text.copy()
    return _c_text(copy)


def test_empty_default_argument_is_empty_in_c() raises:
    assert_equal(_from_default(), "")


def test_empty_literal_is_empty_in_c() raises:
    var text = String("")
    assert_equal(_c_text(text), "")


def test_text_is_kept() raises:
    var text = String("/etc/ssl/cert.pem")
    assert_equal(_c_text(text), "/etc/ssl/cert.pem")


def test_default_tls_config_loads_the_default_ca_bundle() raises:
    """`TlsConfig()` has an empty `ca_bundle` from a default argument; it
    must reach OpenSSL as empty, not as another string from the pool."""
    var lib = OwnedDLHandle(_find_dodo_lib())
    var ctx = _build_ssl_ctx(lib, TlsConfig())
    _do_ssl_ctx_free(lib, ctx)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

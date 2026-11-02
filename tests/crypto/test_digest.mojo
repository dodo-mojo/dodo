"""Tests for dodo.crypto.digest against published test vectors."""

from std.testing import assert_equal

from dodo.crypto.digest import (
    hmac_sha256_of,
    md5,
    pbkdf2_hmac_sha256,
    sha1,
    sha256,
)


def hex(data: List[UInt8]) -> String:
    comptime digits = "0123456789abcdef"
    var out = String()
    for b in data:
        out += digits[byte=Int(b >> 4)]
        out += digits[byte=Int(b & 15)]
    return out^


def test_hashes() raises:
    var abc = "abc".as_bytes()
    assert_equal(
        hex(sha256(abc)),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )
    assert_equal(hex(sha1(abc)), "a9993e364706816aba3e25717850c26c9cd0d89d")
    assert_equal(hex(md5(abc)), "900150983cd24fb0d6963f7d28e17f72")
    var empty = List[UInt8]()
    assert_equal(
        hex(sha256(empty)),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )


def test_hmac_rfc4231() raises:
    # Test case 2.
    assert_equal(
        hex(
            hmac_sha256_of(
                "Jefe".as_bytes(), "what do ya want for nothing?".as_bytes()
            )
        ),
        "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
    )
    var no_key = List[UInt8]()
    var no_message = List[UInt8]()
    assert_equal(
        hex(hmac_sha256_of(no_key, no_message)),
        "b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad",
    )


def test_pbkdf2_rfc7914() raises:
    assert_equal(
        hex(pbkdf2_hmac_sha256("passwd".as_bytes(), "salt".as_bytes(), 1)),
        "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc",
    )


def main() raises:
    test_hashes()
    test_hmac_rfc4231()
    test_pbkdf2_rfc7914()
    print("test_digest: 3 passed")

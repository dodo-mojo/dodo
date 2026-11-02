"""Tests for dodo.crypto.rsa (RSA-OAEP, used by MySQL's password exchange
on a plain connection). Decryption happens on the server, so these check
the shape of the output and the failures."""

from std.testing import assert_equal, assert_true

from dodo.crypto.rsa import rsa_oaep_encrypt


comptime PUBLIC_KEY = """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvqp4Zd0BFfDAz5O1Edh1
OGKC3lhM1AEDDC7PgHz1T2yTqBmJxZHrcmh+ofQSIlwgGpNvTslEpS07SzQlPD3z
2K6NEYALEuNL2qG2kTuul24O6k6MDSCIOFClMwgSIuzpIfntiYPznBVoV0Ft+XK4
7ZRLw8gLQhXs9bI9P1F5IovdOMb51q2a/1jl13hgusA4GPfj+So1wqE6751Whlm2
vKCRzMAG0MywpLwy+A8ghUY2AcH32NpaHIvUqcmoZtYTRL9cSOgA1iae4rZLuh5f
/pUMEQe9buhxV2kmnRNTlPYNsSwRuyNUzzWWuNxFKWN42TIEDiZkdQLcNjDeuxZn
dwIDAQAB
-----END PUBLIC KEY-----
"""


def test_encrypts_to_key_size() raises:
    var a = rsa_oaep_encrypt(PUBLIC_KEY.as_bytes(), "secret".as_bytes())
    var b = rsa_oaep_encrypt(PUBLIC_KEY.as_bytes(), "secret".as_bytes())
    # 2048-bit key: 256 bytes out. OAEP pads with fresh randomness.
    assert_equal(len(a), 256)
    var same = True
    for i in range(256):
        if a[i] != b[i]:
            same = False
    assert_true(not same, "two encryptions of one message should differ")


def test_bad_key_and_long_message_fail() raises:
    var failed = False
    try:
        _ = rsa_oaep_encrypt("not a key".as_bytes(), "secret".as_bytes())
    except:
        failed = True
    assert_true(failed, "a bad PEM should fail")
    # OAEP with SHA-1 fits at most 256 - 42 = 214 bytes.
    var long = List[UInt8](length=215, fill=65)
    failed = False
    try:
        _ = rsa_oaep_encrypt(PUBLIC_KEY.as_bytes(), Span(long))
    except:
        failed = True
    assert_true(failed, "a message longer than the key allows should fail")


def main() raises:
    test_encrypts_to_key_size()
    test_bad_key_and_long_message_fail()
    print("test_rsa: 2 passed")

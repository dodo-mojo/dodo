"""Check dodo.crypto.digest against published test vectors."""

from dodo.crypto.digest import sha256, sha1, md5, hmac_sha256_of, pbkdf2_hmac_sha256


def hex(data: List[UInt8]) -> String:
    var digits = "0123456789abcdef"
    var out = String()
    for b in data:
        out += digits[byte = Int(b >> 4)]
        out += digits[byte = Int(b & 15)]
    return out


def check(name: String, got: String, want: String):
    if got == want:
        print("ok  ", name)
    else:
        print("FAIL", name, got, "!=", want)


def main() raises:
    var abc = "abc".as_bytes()
    check(
        "sha256",
        hex(sha256(abc)),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )
    check("sha1", hex(sha1(abc)), "a9993e364706816aba3e25717850c26c9cd0d89d")
    check("md5", hex(md5(abc)), "900150983cd24fb0d6963f7d28e17f72")
    # RFC 4231 test case 2
    check(
        "hmac",
        hex(hmac_sha256_of("Jefe".as_bytes(), "what do ya want for nothing?".as_bytes())),
        "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
    )
    # RFC 7914 section 11
    check(
        "pbkdf2",
        hex(pbkdf2_hmac_sha256("passwd".as_bytes(), "salt".as_bytes(), 1)),
        "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc",
    )
    var empty = List[UInt8]()
    check(
        "sha256 empty",
        hex(sha256(empty)),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    )

"""Hashes, HMAC and PBKDF2 from the OpenSSL that `dodo.tls` already loads.

The database drivers authenticate with these: SCRAM-SHA-256 (PostgreSQL,
MongoDB), MD5 (older PostgreSQL servers), SHA-1 and SHA-256 (MySQL).

```mojo
from dodo.crypto.digest import sha256, hmac_sha256_of, pbkdf2_hmac_sha256

var digest = sha256("abc".as_bytes())
var salted = pbkdf2_hmac_sha256(password, salt, iterations=4096)
```

Each call resolves the libcrypto symbol through `libdodo_tls.so`, which
links libcrypto. These run once per connection, not per query.
"""

from std.ffi import OwnedDLHandle, c_int

from ..utils.dylib import dl_sym, find_dodo_lib


comptime SHA1_LEN = 20
comptime SHA256_LEN = 32
comptime MD5_LEN = 16


def _evp_digest(
    imm lib: OwnedDLHandle, md_name: String, data: Span[UInt8, _], size: Int
) raises -> List[UInt8]:
    # The handle is borrowed so it stays mapped across lookup and call.
    var get_md = dl_sym[def() thin abi("C") -> Int](lib, md_name)
    var digest_fn = dl_sym[
        def(Int, Int, Int, Int, Int, Int) thin abi("C") -> c_int
    ](lib, "EVP_Digest")
    var out = List[UInt8](length=size, fill=0)
    var rc = digest_fn(
        Int(data.unsafe_ptr()),
        len(data),
        Int(out.unsafe_ptr()),
        0,
        get_md(),
        0,
    )
    if Int(rc) != 1:
        raise Error("dodo.crypto: EVP_Digest failed for ", md_name)
    return out^


def sha256(data: Span[UInt8, _]) raises -> List[UInt8]:
    """The 32-byte SHA-256 digest of `data`."""
    var lib = OwnedDLHandle(find_dodo_lib("tls"))
    return _evp_digest(lib, "EVP_sha256", data, SHA256_LEN)


def sha1(data: Span[UInt8, _]) raises -> List[UInt8]:
    """The 20-byte SHA-1 digest of `data`. Only for protocols that require it.
    """
    var lib = OwnedDLHandle(find_dodo_lib("tls"))
    return _evp_digest(lib, "EVP_sha1", data, SHA1_LEN)


def md5(data: Span[UInt8, _]) raises -> List[UInt8]:
    """The 16-byte MD5 digest of `data`. Only for protocols that require it."""
    var lib = OwnedDLHandle(find_dodo_lib("tls"))
    return _evp_digest(lib, "EVP_md5", data, MD5_LEN)


def _hmac(
    imm lib: OwnedDLHandle,
    key: Span[UInt8, _],
    msg: Span[UInt8, _],
) raises -> List[UInt8]:
    var get_md = dl_sym[def() thin abi("C") -> Int](lib, "EVP_sha256")
    var hmac_fn = dl_sym[
        def(Int, Int, Int, Int, Int, Int, Int) thin abi("C") -> Int
    ](lib, "HMAC")
    var out = List[UInt8](length=SHA256_LEN, fill=0)
    # Heap cells, not locals: C writes through an address Mojo can't see,
    # and a local's value could be assumed unchanged.
    var out_len = List[UInt32](length=1, fill=0)
    # HMAC rejects a null key pointer, and an empty Span may have one.
    var empty = List[UInt8](length=1, fill=0)
    var key_addr = Int(key.unsafe_ptr())
    if len(key) == 0:
        key_addr = Int(empty.unsafe_ptr())
    var msg_addr = Int(msg.unsafe_ptr())
    if len(msg) == 0:
        msg_addr = Int(empty.unsafe_ptr())
    var result = hmac_fn(
        get_md(),
        key_addr,
        len(key),
        msg_addr,
        len(msg),
        Int(out.unsafe_ptr()),
        Int(out_len.unsafe_ptr()),
    )
    # Mojo may free a value right after its last use, which for `empty`
    # is taking its address above; keep it alive through the call.
    _ = empty^
    if result == 0 or Int(out_len[0]) != SHA256_LEN:
        raise Error("dodo.crypto: HMAC-SHA256 failed")
    return out^


def hmac_sha256_of(
    key: Span[UInt8, _], msg: Span[UInt8, _]
) raises -> List[UInt8]:
    """HMAC-SHA256 of `msg` under `key`, over spans."""
    var lib = OwnedDLHandle(find_dodo_lib("tls"))
    return _hmac(lib, key, msg)


def _pbkdf2(
    imm lib: OwnedDLHandle,
    password: Span[UInt8, _],
    salt: Span[UInt8, _],
    iterations: Int,
) raises -> List[UInt8]:
    var get_md = dl_sym[def() thin abi("C") -> Int](lib, "EVP_sha256")
    var pbkdf2_fn = dl_sym[
        def(
            Int, c_int, Int, c_int, c_int, Int, c_int, Int
        ) thin abi("C") -> c_int
    ](lib, "PKCS5_PBKDF2_HMAC")
    var out = List[UInt8](length=SHA256_LEN, fill=0)
    var rc = pbkdf2_fn(
        Int(password.unsafe_ptr()),
        c_int(len(password)),
        Int(salt.unsafe_ptr()),
        c_int(len(salt)),
        c_int(iterations),
        get_md(),
        c_int(SHA256_LEN),
        Int(out.unsafe_ptr()),
    )
    if Int(rc) != 1:
        raise Error("dodo.crypto: PBKDF2-HMAC-SHA256 failed")
    return out^


def pbkdf2_hmac_sha256(
    password: Span[UInt8, _], salt: Span[UInt8, _], iterations: Int
) raises -> List[UInt8]:
    """PBKDF2 with HMAC-SHA256 and a 32-byte output (RFC 8018)."""
    if iterations < 1:
        raise Error("dodo.crypto: PBKDF2 needs at least one iteration")
    var lib = OwnedDLHandle(find_dodo_lib("tls"))
    return _pbkdf2(lib, password, salt, iterations)

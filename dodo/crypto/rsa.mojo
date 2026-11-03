"""RSA-OAEP encryption with a PEM public key.

Only MySQL needs this: `caching_sha2_password` sends the password encrypted
with the server's public key when the connection has no TLS.
"""

from std.ffi import OwnedDLHandle, c_int

from ..tls.stream import _c_err
from ..utils.dylib import dl_sym, find_dodo_lib


def _rsa_encrypt(
    imm lib: OwnedDLHandle, pem: Span[UInt8, _], data: Span[UInt8, _]
) raises -> List[UInt8]:
    var encrypt = dl_sym[
        def(Int, Int, Int, Int, Int, Int, Int) thin abi("C") -> c_int
    ](lib, "dodo_rsa_oaep_encrypt")
    # 1024 bytes covers keys up to 8192 bits.
    var out = List[UInt8](length=1024, fill=0)
    # A heap cell: C writes the length through an address Mojo can't see.
    var written = List[Int](length=1, fill=0)
    var rc = encrypt(
        Int(pem.unsafe_ptr()),
        len(pem),
        Int(data.unsafe_ptr()),
        len(data),
        Int(out.unsafe_ptr()),
        len(out),
        Int(written.unsafe_ptr()),
    )
    if Int(rc) != 0:
        raise Error("dodo.crypto: RSA-OAEP encryption failed: ", _c_err(lib))
    out.resize(written[0], 0)
    return out^


def rsa_oaep_encrypt(
    pem: Span[UInt8, _], data: Span[UInt8, _]
) raises -> List[UInt8]:
    """Encrypt `data` with the PEM public key `pem` (OAEP, SHA-1)."""
    var lib = OwnedDLHandle(find_dodo_lib("tls"))
    return _rsa_encrypt(lib, pem, data)

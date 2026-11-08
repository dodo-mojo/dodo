# `dodo.crypto.rsa`

RSA-OAEP encryption with a PEM public key.

Only MySQL needs this: `caching_sha2_password` sends the password encrypted
with the server's public key when the connection has no TLS.

## Functions

### `rsa_oaep_encrypt`

```mojo
def rsa_oaep_encrypt(pem: Span[UInt8], data: Span[UInt8]) raises -> List[UInt8]
```

Encrypt `data` with the PEM public key `pem` (OAEP, SHA-1).

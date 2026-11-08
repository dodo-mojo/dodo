# `dodo.crypto.digest`

Hashes, HMAC and PBKDF2 from the OpenSSL that `dodo.tls` already loads.

The database drivers authenticate with these: SCRAM-SHA-256 (PostgreSQL,
MongoDB), MD5 (older PostgreSQL servers), SHA-1 and SHA-256 (MySQL).

```mojo
from dodo.crypto.digest import sha256, hmac_sha256_of, pbkdf2_hmac_sha256

var digest = sha256("abc".as_bytes())
var salted = pbkdf2_hmac_sha256(password, salt, iterations=4096)
```

Each call resolves the libcrypto symbol through `libdodo_tls.so`, which
links libcrypto. These run once per connection, not per query.

## Aliases

### `SHA1_LEN`

```mojo
comptime SHA1_LEN = 20
```

### `SHA256_LEN`

```mojo
comptime SHA256_LEN = 32
```

### `MD5_LEN`

```mojo
comptime MD5_LEN = 16
```

## Functions

### `sha256`

```mojo
def sha256(data: Span[UInt8]) raises -> List[UInt8]
```

The 32-byte SHA-256 digest of `data`.

### `sha1`

```mojo
def sha1(data: Span[UInt8]) raises -> List[UInt8]
```

The 20-byte SHA-1 digest of `data`. Only for protocols that require it.

### `md5`

```mojo
def md5(data: Span[UInt8]) raises -> List[UInt8]
```

The 16-byte MD5 digest of `data`. Only for protocols that require it.

### `hmac_sha256_of`

```mojo
def hmac_sha256_of(key: Span[UInt8], msg: Span[UInt8]) raises -> List[UInt8]
```

HMAC-SHA256 of `msg` under `key`, over spans.

### `pbkdf2_hmac_sha256`

```mojo
def pbkdf2_hmac_sha256(password: Span[UInt8], salt: Span[UInt8], iterations: Int) raises -> List[UInt8]
```

PBKDF2 with HMAC-SHA256 and a 32-byte output (RFC 8018).

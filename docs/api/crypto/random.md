# `dodo.crypto.random`

``dodo.crypto.random`` -- bytes from the operating system's CSPRNG.

Every unpredictable byte dodo needs comes from here: WebSocket
masking keys and handshake nonces, session identifiers. Nothing
reads ``/dev/urandom`` directly or falls back to a clock-derived or
constant value when the open fails. Opening a
file fails under fd exhaustion, which a remote peer can cause, so
the fallback was reachable on demand.

This module calls ``getentropy(3)`` instead. It is in macOS libc and
in glibc since 2.25, needs no file descriptor, and blocks only until
the kernel pool is first seeded at boot. There is no fallback: if
the kernel cannot supply entropy the call raises, and the caller
fails closed.

## Public API

```mojo
from dodo.crypto.random import random_bytes, fill_random
```

* :func:`random_bytes(n) raises -> List[UInt8]` -- ``n`` fresh bytes.
* :func:`fill_random(mut buf) raises` -- overwrite every byte of an
  existing buffer.

## Functions

### `fill_random`

```mojo
def fill_random(mut buf: List[UInt8]) raises
```

Overwrite every byte of ``buf`` with CSPRNG output.

Args:

- `buf`: Buffer to fill. Its length is unchanged.

Raises: Error: If the kernel cannot supply entropy. There is no fallback source.

### `random_bytes`

```mojo
def random_bytes(n: Int) raises -> List[UInt8]
```

Return ``n`` bytes of CSPRNG output.

Args:

- `n`: Number of bytes. Zero returns an empty list.

Returns: A list of exactly ``n`` unpredictable bytes.

Raises: Error: If ``n`` is negative, or the kernel cannot supply entropy.

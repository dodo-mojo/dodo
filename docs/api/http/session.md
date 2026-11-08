# `dodo.http.session`

Signed cookies + typed sessions.

The ``SignedCookie`` primitive encodes a payload as
``base64url(payload) + "." + base64url(hmac_sha256(key, base64url(payload)))``
— the same shape JSON Web Signature uses, so the format is
familiar to anyone who has read RFC 7515. The MAC is computed
over the *base64url-encoded payload* (not the raw bytes) so the
verifier can split on ``.`` without first decoding.

``Session[T]`` wraps an arbitrary ``Copyable`` payload
and (de)serialises it through a user-supplied ``SessionCodec[T]``.
``SessionStore`` is the abstraction over storage; dodo ships:

- ``CookieSessionStore`` — payload travels in the signed cookie
  itself (stateless).
- ``InMemorySessionStore`` — payload kept server-side, the
  cookie carries only an opaque (caller-supplied) session id.
- ``BackedSessionStore[B: SessionBackend]`` — the id is a CSPRNG token
  (``new_session_id``), the value lives in a pluggable ``SessionBackend``
  with a TTL, and ``destroy`` revokes it. ``MemorySessionBackend`` is the
  reference backend; a shared/Redis/SQL backend implements the same four
  methods (``get`` / ``set`` / ``delete`` / ``sweep``).

Sessions expire server-side by default: every store takes a ``ttl_s``
(default :data:`DEFAULT_SESSION_TTL_S`, one day; ``0`` opts out). The
cookie stores read the wall clock themselves and also offer ``encode_at`` /
``load_at`` / ``insert_at`` forms that take the time as an argument, the
way ``BackedSessionStore`` takes ``now_s``.

The two cookie stores share the ``SessionStore`` read trait
(``cookie_name`` + ``load``) so handler code can be generic over them.
Keys are rotated by passing ``previous_keys``; valid signatures under any
of the supplied keys are accepted (with the *current* key used to sign
new cookies).

Loading a session is done via ``store.load(req)`` (a
``BackedSessionStore`` adds ``now_s`` for TTL). It is deliberately not a
config-free ``Extractor``: an extractor only receives the ``Request`` and
cannot hold the runtime signing key / backend, so the store instance is
the injection point.

## Threat model

- The signing key is the trust anchor; rotate at the cadence your
  org demands. Library-level enforcement: ``Session.new`` rejects
  keys shorter than 16 bytes.
- HMAC-SHA256 verification is constant-time (``CRYPTO_memcmp``);
  no early-exit timing leak.
- Forged cookies (any byte tampered) raise on ``decode``; callers
  should treat the raise as "treat user as anonymous".

## Aliases

### `DEFAULT_SESSION_TTL_S`

```mojo
comptime DEFAULT_SESSION_TTL_S = Int(86400)
```

Default server-side lifetime of a session, in seconds (one day).

Every store in this module expires its sessions server-side after this
long unless told otherwise, so a stolen session cookie cannot be replayed
for as long as the signing key lives (``docs/threat-model.md``). Pass
``ttl_s=0`` to a store to opt out of expiry, or another value to change
the lifetime.

### `MIN_SESSION_KEY_BYTES`

```mojo
comptime MIN_SESSION_KEY_BYTES = Int(16)
```

Shortest HMAC key a session store or signed cookie will use, for signing or for verifying. A shorter key -- above all an empty one, which is what an unset environment variable produces -- makes every cookie forgeable by anyone who knows the payload format.

## Structs

### `StringSessionCodec`

```mojo
struct StringSessionCodec
```

The default codec: payload is just a UTF-8 string.

Pair with ``dodo.json``-encoded text payloads (or any other
string serialisation) when richer types are needed without
writing a new codec.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`, `SessionCodec`

#### `StringSessionCodec.__init__`

```mojo
def __init__(out self)
```

#### `StringSessionCodec.encode`

```mojo
def encode(payload: String) raises -> List[UInt8]
```

#### `StringSessionCodec.decode`

```mojo
def decode(data: List[UInt8]) raises -> String
```

### `Session`

```mojo
struct Session
```

A typed session payload, carried in either a signed cookie or an in-memory store.

Construction: ``Session.empty()`` / ``Session(value)``.

Field ``value`` is a ``String`` to keep the public surface
simple; pair with ``dodo.json`` if you need to roundtrip a
structured payload (encode JSON in the handler, decode on the
way out).

Fields:

- `value` (`String`): Opaque session value (typically a JSON blob).
- `present` (`Bool`): ``True`` if the session was loaded from a valid cookie / store entry; ``False`` for anonymous requests.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `Session.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, value: String)
```

#### `Session.empty`

```mojo
def empty() -> Self
```

### `CookieSessionStore`

```mojo
struct CookieSessionStore
```

Stateless store: the entire session is encoded into the signed cookie. Suitable for small payloads (< 4 KiB).

Stores no server-side state; payload size is bounded by the
cookie size limit (RFC 6265 paragraph 6.1 recommends >= 4096
bytes per cookie).

The signed payload is ``"<expiry>|<value>"``, where ``<expiry>`` is
the absolute epoch second after which :meth:`load` refuses the cookie
(``0`` = never; only with ``ttl_s <= 0``). The expiry is covered by
the MAC, so a client cannot extend it, and a validly signed payload
without one -- such as a cookie issued before expiry existed -- is
refused: its holder is treated as anonymous and signs in again.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `SessionStore`

#### `CookieSessionStore.__init__`

```mojo
def __init__(out self, key: List[UInt8], cookie_name: String = "dodo_session", ttl_s: Int = Int(86400)) raises
```

Sign and verify with ``key``.

Args:

- `key`: HMAC key, at least ``MIN_SESSION_KEY_BYTES`` bytes.
- `cookie_name`: Name of the session cookie.
- `ttl_s`: Lifetime of a cookie in seconds, counted from :meth:`encode`. ``0`` (or negative) issues cookies that never expire.

Raises: Error: If ``key`` is shorter than ``MIN_SESSION_KEY_BYTES``. There is no default constructor: a store without a real key cannot be made.

#### `CookieSessionStore.add_previous_key`

```mojo
def add_previous_key(mut self, key: List[UInt8]) raises
```

Accept ``key`` as a valid signing key for inbound cookies.

Used during key rotation: set ``self._key`` to the new key,
keep the old key here so existing browsers' cookies still
verify until their natural expiry.

Raises: Error: If ``key`` is shorter than ``MIN_SESSION_KEY_BYTES``.

#### `CookieSessionStore.cookie_name`

```mojo
def cookie_name(self) -> String
```

#### `CookieSessionStore.load`

```mojo
def load(self, req: Request) -> Session
```

Look up the session cookie on ``req`` and return a Session.

Returns ``Session.empty()`` for any failure mode (cookie
missing, malformed, MAC fails, expired, no expiry). Never
raises -- handlers can treat the result as authoritative.

#### `CookieSessionStore.load_at`

```mojo
def load_at(self, req: Request, now_s: Int) -> Session
```

:meth:`load` with the current epoch second given by the caller.

A cookie whose expiry is ``<= now_s`` is refused.

#### `CookieSessionStore.encode`

```mojo
def encode(self, value: String) raises -> String
```

Return a signed-cookie value carrying ``value`` as payload, expiring ``ttl_s`` seconds from now.

#### `CookieSessionStore.encode_at`

```mojo
def encode_at(self, value: String, now_s: Int) raises -> String
```

:meth:`encode` with the current epoch second given by the caller.

### `InMemorySessionStore`

```mojo
struct InMemorySessionStore
```

Server-side session table keyed by signed session id.

Entries expire ``ttl_s`` seconds after they are inserted (default
:data:`DEFAULT_SESSION_TTL_S`; ``0`` = never). :meth:`load` refuses an
expired entry and :meth:`sweep` evicts them.

Concurrency note: the implementation is single-worker; for
multi-worker mode the store is per-worker (each worker keeps
its own table). A shared backend (Redis, DB) can implement the
same trait.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `SessionStore`

#### `InMemorySessionStore.__init__`

```mojo
def __init__(out self, key: List[UInt8], cookie_name: String = "dodo_session", ttl_s: Int = Int(86400)) raises
```

Sign and verify session ids with ``key``.

Args:

- `key`: HMAC key, at least ``MIN_SESSION_KEY_BYTES`` bytes.
- `cookie_name`: Name of the session cookie.
- `ttl_s`: Lifetime of an entry in seconds, counted from :meth:`insert`. ``0`` (or negative) = never expires.

Raises: Error: If ``key`` is shorter than ``MIN_SESSION_KEY_BYTES``.

#### `InMemorySessionStore.cookie_name`

```mojo
def cookie_name(self) -> String
```

#### `InMemorySessionStore.insert`

```mojo
def insert(mut self, id: String, value: String)
```

Replace any existing entry for ``id`` with ``value``; it expires ``ttl_s`` seconds from now.

#### `InMemorySessionStore.insert_at`

```mojo
def insert_at(mut self, id: String, value: String, now_s: Int)
```

:meth:`insert` with the current epoch second given by the caller. Replacing an entry restarts its lifetime.

#### `InMemorySessionStore.remove`

```mojo
def remove(mut self, id: String) -> Bool
```

Drop the entry for ``id``. Returns ``True`` if present.

#### `InMemorySessionStore.sweep`

```mojo
def sweep(mut self, now_s: Int) -> Int
```

Evict every entry expired at ``now_s``; return the count.

#### `InMemorySessionStore.encode_id`

```mojo
def encode_id(self, id: String) raises -> String
```

Wrap ``id`` in a signed cookie value.

#### `InMemorySessionStore.load`

```mojo
def load(self, req: Request) -> Session
```

Look up the session for ``req``; empty if the cookie is missing, forged, unknown or expired.

#### `InMemorySessionStore.load_at`

```mojo
def load_at(self, req: Request, now_s: Int) -> Session
```

:meth:`load` with the current epoch second given by the caller.

#### `InMemorySessionStore.__len__`

```mojo
def __len__(self) -> Int
```

### `MemorySessionBackend`

```mojo
struct MemorySessionBackend
```

Reference in-process :trait:`SessionBackend` with TTL expiry.

ponytail: linear-scan parallel lists (id / value / expiry). Fine for
the moderate per-worker session counts this backs; a shared/large
deployment swaps in a hashed or external backend behind the same
trait. Not thread-safe -- one instance per worker (the multi-worker
server copies the store per worker).

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`, `SessionBackend`

#### `MemorySessionBackend.__init__`

```mojo
def __init__(out self)
```

#### `MemorySessionBackend.get`

```mojo
def get(mut self, id: String, now_s: Int) raises -> Optional[String]
```

#### `MemorySessionBackend.set`

```mojo
def set(mut self, id: String, value: String, now_s: Int, ttl_s: Int) raises
```

#### `MemorySessionBackend.delete`

```mojo
def delete(mut self, id: String) raises -> Bool
```

#### `MemorySessionBackend.sweep`

```mojo
def sweep(mut self, now_s: Int) raises -> Int
```

#### `MemorySessionBackend.__len__`

```mojo
def __len__(self) -> Int
```

### `BackedSessionStore`

```mojo
struct BackedSessionStore[B: SessionBackend]
```

Server-side session store over a pluggable :trait:`SessionBackend`.

The cookie carries only a CSPRNG session id (signed, so a client
cannot forge one); the value lives in the backend with a TTL. This
is the store to reach for when sessions must expire, be revocable
(:meth:`destroy`), or share a backend across workers.

Its load / save / destroy surface is ``mut self`` + ``raises`` +
``now_s`` (the backend mutates on lazy expiry and needs the clock),
so -- unlike the two cookie stores -- it deliberately does not
implement the minimal :trait:`SessionStore` read trait.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `BackedSessionStore.__init__`

```mojo
def __init__(out self, var backend: B, key: List[UInt8], cookie_name: String = "dodo_session", ttl_s: Int = Int(86400)) raises
```

Sign session ids with ``key`` and keep values in ``backend``.

Args:

- `backend`: The storage backend (ownership transferred).
- `key`: HMAC key, at least ``MIN_SESSION_KEY_BYTES`` bytes.
- `cookie_name`: Name of the session cookie.
- `ttl_s`: Lifetime of a saved session in seconds (default :data:`DEFAULT_SESSION_TTL_S`). ``0`` (or negative) saves sessions that never expire.

Raises: Error: If ``key`` is shorter than ``MIN_SESSION_KEY_BYTES``.

#### `BackedSessionStore.cookie_name`

```mojo
def cookie_name(self) -> String
```

#### `BackedSessionStore.load`

```mojo
def load(mut self, req: Request, now_s: Int) raises -> Session
```

Load the session for ``req`` (empty if no valid cookie / the backend entry is gone or expired).

#### `BackedSessionStore.save`

```mojo
def save(mut self, value: String, now_s: Int) raises -> String
```

Store ``value`` under a fresh CSPRNG id and return the signed session-cookie value to set on the response.

#### `BackedSessionStore.destroy`

```mojo
def destroy(mut self, req: Request) raises -> Bool
```

Revoke the session referenced by ``req``'s cookie; return ``True`` if a backend entry was removed.

#### `BackedSessionStore.sweep`

```mojo
def sweep(mut self, now_s: Int) raises -> Int
```

Evict expired backend entries; return the count.

## Traits

### `SessionCodec`

```mojo
trait SessionCodec
```

Encode / decode a typed payload to/from raw bytes.

Implementations live alongside the user's payload type; the
bundled ``StringSessionCodec`` carries opaque strings which is
enough for the common "username + roles JSON blob" use case
when paired with ``dodo.json``.

Inherits from: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `SessionCodec.encode`

```mojo
def encode(payload: String) raises -> List[UInt8]
```

#### `SessionCodec.decode`

```mojo
def decode(data: List[UInt8]) raises -> String
```

### `SessionStore`

```mojo
trait SessionStore
```

The read surface every cookie-backed session store shares.

Lets handler code stay generic over the storage strategy
(:class:`CookieSessionStore` stateless, :class:`InMemorySessionStore`
server-side). Both never raise on load -- a missing / forged cookie
yields :meth:`Session.empty` so the handler treats the caller as
anonymous. The richer TTL / CSPRNG / destroy surface lives on
:class:`BackedSessionStore` (which layers a pluggable
:trait:`SessionBackend`).

Inherits from: `AnyType`, `Copyable`, `Movable`

#### `SessionStore.cookie_name`

```mojo
def cookie_name(self) -> String
```

#### `SessionStore.load`

```mojo
def load(self, req: Request) -> Session
```

### `SessionBackend`

```mojo
trait SessionBackend
```

Storage abstraction behind :class:`BackedSessionStore`.

A backend maps an opaque session id to its value with a TTL. The
reference :class:`MemorySessionBackend` is a per-process table; a
shared backend (Redis / SQL / a cross-worker shared-memory map)
implements the same four methods to survive restarts or fan out
across workers. Time is caller-supplied (``now_s``) so the surface
stays clock-free + deterministically testable.

Inherits from: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `SessionBackend.get`

```mojo
def get(mut self, id: String, now_s: Int) raises -> Optional[String]
```

Return the live value for ``id`` (``None`` if absent/expired). Expired entries are lazily dropped.

#### `SessionBackend.set`

```mojo
def set(mut self, id: String, value: String, now_s: Int, ttl_s: Int) raises
```

Upsert ``id`` -> ``value``, expiring at ``now_s + ttl_s`` (``ttl_s <= 0`` = never expires).

#### `SessionBackend.delete`

```mojo
def delete(mut self, id: String) raises -> Bool
```

Drop ``id``; return ``True`` if it was present.

#### `SessionBackend.sweep`

```mojo
def sweep(mut self, now_s: Int) raises -> Int
```

Evict all entries expired at ``now_s``; return the count.

## Functions

### `new_session_id`

```mojo
def new_session_id(n_bytes: Int = Int(32)) raises -> String
```

Return a fresh unguessable session id: ``n_bytes`` from the OS CSPRNG rendered as lowercase hex.

32 bytes (256 bits) is the default -- well above the 128-bit floor
for a session identifier that a signed cookie carries opaquely. The
CSPRNG read is the trust anchor: a guessable id lets an attacker
hijack a session, so this never falls back to a weak PRNG -- it
raises if the entropy source is unavailable (which should not happen
on Linux / macOS).

### `session_now_s`

```mojo
def session_now_s() -> Int
```

Monotonic seconds for TTL bookkeeping (relative expiry only).

### `signed_cookie_encode`

```mojo
def signed_cookie_encode(payload: List[UInt8], key: List[UInt8]) raises -> String
```

Encode ``payload`` into a ``"<b64>.<b64>"`` signed cookie value.

``key`` should be at least 16 bytes for security; the caller is
responsible for ensuring that (``Session.new`` enforces it).

Args:

- `payload`: Raw payload bytes.
- `key`: HMAC key.

Returns: ``"<base64url(payload)>.<base64url(mac)>"`` cookie value.

### `signed_cookie_decode`

```mojo
def signed_cookie_decode(cookie: String, key: List[UInt8]) raises -> List[UInt8]
```

Decode + verify a signed cookie under one key.

Returns the raw payload bytes if the MAC verifies. Raises ``Error``
on any of: malformed shape, invalid base64, MAC mismatch.

Args:

- `cookie`: Cookie value as produced by ``signed_cookie_encode``.
- `key`: HMAC key.

Returns: Decoded payload bytes.

Raises: Error: When the cookie is malformed or the MAC fails to verify under ``key``.

### `signed_cookie_decode_keys`

```mojo
def signed_cookie_decode_keys(cookie: String, keys: List[List[UInt8]]) raises -> List[UInt8]
```

Decode a signed cookie under any of ``keys`` (key rotation).

Tries each key in order; returns the payload as soon as one
verifies. Raises if none do.

Args:

- `cookie`: Cookie value.
- `keys`: Acceptable HMAC keys (current key first, previous keys after).

Returns: Decoded payload bytes.

Raises: Error: When no key successfully verifies the MAC.

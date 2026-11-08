# `dodo.http.auth`

HTTP authentication helpers.

Provides an ``Auth`` trait and two concrete implementations — ``BasicAuth``
(RFC 7617) and ``BearerAuth`` (RFC 6750) — that attach an ``Authorization``
header to a request's ``HeaderMap``.

Usage with ``HttpClient``::

```mojo
from dodo.http import HttpClient, BasicAuth, BearerAuth

var client = HttpClient(auth=BasicAuth("alice", "s3cr3t"))
var resp = client.get("https://httpbin.org/basic-auth/alice/s3cr3t")
```

Example:
    ```mojo
    from dodo.http.auth import BasicAuth, BearerAuth
    from dodo.http.headers import HeaderMap

    var h = HeaderMap()
    BasicAuth("alice", "s3cr3t").apply(h)
    print(h.get("Authorization")) # Basic YWxpY2U6czNjcjN0
    ```

## Structs

### `BasicAuth`

```mojo
struct BasicAuth
```

HTTP Basic authentication (RFC 7617).

Encodes ``username:password`` as base64 and sets the ``Authorization``
header to ``Basic <encoded>``.

Fields:
    username: The account username.
    password: The account password (transmitted in plaintext over TLS).

Example:
```mojo
var auth = BasicAuth("alice", "s3cr3t")
var client = HttpClient(auth=auth)
```

Fields:

- `username` (`String`)
- `password` (`String`)

Implemented traits: `AnyType`, `Auth`, `Copyable`, `Deinitable`, `Movable`

#### `BasicAuth.__init__`

```mojo
def __init__(out self, username: String, password: String)
```

Initialise ``BasicAuth`` with ``username`` and ``password``.

Args:

- `username`: The account username.
- `password`: The account password.

#### `BasicAuth.apply`

```mojo
def apply(self, mut headers: HeaderMap) raises
```

Set ``Authorization: Basic <credentials>`` on ``headers``.

The credential string ``username:password`` is UTF-8 encoded then
base64-encoded per RFC 7617.

Args:

- `headers`: The ``HeaderMap`` to modify in place.

### `BearerAuth`

```mojo
struct BearerAuth
```

HTTP Bearer token authentication (RFC 6750).

Sets ``Authorization: Bearer <token>``.

Fields:
    token: The bearer token string (e.g. a JWT).

Example:
```mojo
var auth = BearerAuth("eyJhbGciOi...")
var client = HttpClient(auth=auth)
```

Fields:

- `token` (`String`)

Implemented traits: `AnyType`, `Auth`, `Copyable`, `Deinitable`, `Movable`

#### `BearerAuth.__init__`

```mojo
def __init__(out self, token: String)
```

Initialise ``BearerAuth`` with ``token``.

Args:

- `token`: The bearer token (e.g. a JWT or opaque token).

#### `BearerAuth.apply`

```mojo
def apply(self, mut headers: HeaderMap) raises
```

Set ``Authorization: Bearer <token>`` on ``headers``.

Args:

- `headers`: The ``HeaderMap`` to modify in place.

## Traits

### `Auth`

```mojo
trait Auth
```

Authentication strategy that sets one or more request headers.

Implementors write their credentials into ``headers`` (typically the
``Authorization`` header) before the request is sent.

Example:
    ```mojo
    struct MyAuth(Auth):
        def apply(self, mut headers: HeaderMap) raises:
            headers.set("Authorization", "MyScheme token")
    ```

Inherits from: `AnyType`

#### `Auth.apply`

```mojo
def apply(self, mut headers: HeaderMap) raises
```

Apply authentication credentials to ``headers``.

Implementors must set the ``Authorization`` header (and any other
required headers) on ``headers``.

Args:

- `headers`: The request ``HeaderMap`` to modify in place.

Raises: HeaderInjectionError: If the generated header value contains CRLF characters.

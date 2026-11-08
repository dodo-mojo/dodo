# `dodo.http.cookie`

HTTP cookie support (RFC 6265).

Provides ``Cookie`` for individual cookies and ``CookieJar`` for managing
collections of cookies on both request and response sides.

Example:
    ```mojo
    from dodo.http.cookie import Cookie, CookieJar

    var jar = CookieJar()
    jar.set(Cookie("session", "abc123", secure=True, http_only=True))
    var header = jar.to_request_header() # "session=abc123"
    ```

## Structs

### `SameSite`

```mojo
struct SameSite
```

SameSite attribute values for cookies.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `NONE = String("None")`
- `LAX = String("Lax")`
- `STRICT = String("Strict")`

### `Cookie`

```mojo
struct Cookie
```

An HTTP cookie (RFC 6265).

Fields:
    name: Cookie name (must not be empty).
    value: Cookie value.
    domain: Domain attribute (empty = not set).
    path: Path attribute (empty = not set).
    max_age: Max-Age in seconds (-1 = not set, 0 = delete).
    secure: Secure flag (HTTPS only).
    http_only: HttpOnly flag (not accessible to JavaScript).
    same_site: SameSite attribute (empty = not set).

Fields:

- `name` (`String`)
- `value` (`String`)
- `domain` (`String`)
- `path` (`String`)
- `max_age` (`Int`)
- `secure` (`Bool`)
- `http_only` (`Bool`)
- `same_site` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Cookie.__init__`

```mojo
def __init__(out self, name: String, value: String, domain: String = "", path: String = "", max_age: Int = Int(-1), secure: Bool = False, http_only: Bool = False, same_site: String = "")
```

#### `Cookie.session`

```mojo
def session(name: String, value: String) -> Self
```

A cookie with the attributes a session cookie should have: ``Path=/``, ``Secure``, ``HttpOnly``, ``SameSite=Lax``.

The plain constructor leaves all three flags off, which is the
RFC 6265 default but the wrong one for anything that
authenticates a user.

#### `Cookie.to_set_cookie_header`

```mojo
def to_set_cookie_header(self) raises -> String
```

Serialise this cookie as a ``Set-Cookie`` header value.

Validates against RFC 6265 sec 4.1.1 first. ``;`` is the
attribute separator, so a value or path holding one used to
inject attributes of the sender's choosing -- ``value =
"x; Domain=.evil.com"`` widened the cookie's scope.
``SameSite=None`` implies ``Secure``, which browsers require.

Returns: The full ``Set-Cookie`` value string.

Raises: Error: On an empty or non-token name, a value outside cookie-octet, a ``Domain`` or ``Path`` with a control byte or ``;``, or an unknown ``SameSite``.

#### `Cookie.to_request_pair`

```mojo
def to_request_pair(self) -> String
```

Serialise as ``name=value`` for a ``Cookie`` request header.

### `CookieJar`

```mojo
struct CookieJar
```

A collection of cookies for request/response management.

Stores cookies by name. Supports serialisation to request ``Cookie``
header and response ``Set-Cookie`` headers.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `CookieJar.__init__`

```mojo
def __init__(out self)
```

#### `CookieJar.set`

```mojo
def set(mut self, var cookie: Cookie)
```

Add or replace a cookie by name.

Args:

- `cookie`: The cookie to set (ownership taken).

#### `CookieJar.get`

```mojo
def get(self, name: String) -> String
```

Return the value of a cookie by name, or ``""`` if absent.

Args:

- `name`: Cookie name.

Returns: Cookie value or empty string.

#### `CookieJar.remove`

```mojo
def remove(mut self, name: String) -> Bool
```

Remove a cookie by name.

Args:

- `name`: Cookie name to remove.

Returns: True if a cookie was removed.

#### `CookieJar.contains`

```mojo
def contains(self, name: String) -> Bool
```

Return True if a cookie with this name exists.

#### `CookieJar.len`

```mojo
def len(self) -> Int
```

Return the number of cookies.

#### `CookieJar.to_request_header`

```mojo
def to_request_header(self) -> String
```

Serialise all cookies as a ``Cookie`` request header value.

Returns: ``"name1=value1; name2=value2; ..."`` format string.

## Functions

### `parse_cookie_header`

```mojo
def parse_cookie_header(header: String) -> List[Cookie]
```

Parse a ``Cookie`` request header value into individual cookies.

Format: ``name1=value1; name2=value2; ...``

Args:

- `header`: The ``Cookie`` header value string.

Returns: A list of ``Cookie`` instances (name + value only).

### `parse_set_cookie_header`

```mojo
def parse_set_cookie_header(header: String) -> Cookie
```

Parse a ``Set-Cookie`` response header value.

Args:

- `header`: The ``Set-Cookie`` header value string.

Returns: A ``Cookie`` with all attributes populated.

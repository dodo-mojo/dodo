# `dodo.http.url`

URL parser for HTTP/HTTPS URLs.

Handles the subset of RFC 3986 URIs relevant to HTTP clients:

```mojo
scheme://[user:pass@]host[:port]/path[?query][#fragment]
```

Only ``http`` and ``https`` schemes are supported. Fragment is parsed
but ignored for request purposes (not sent to server per RFC 7230 §5.1).

Component boundaries follow RFC 3986 §3: the fragment starts at the
first ``#``, and the authority ends at the first ``/``, ``?`` or ``#``,
so ``http://evil.com?@good.com/`` has host ``evil.com`` and query
``@good.com/`` (an ``@`` in the query is never userinfo). Userinfo ends at the last
``@`` of the authority, so ``http://a@evil.com@good.com/`` has host
``good.com`` and no host ever contains ``@``.

Example:
    ```mojo
    var u = Url.parse("https://api.example.com:8443/v1/items?filter=active")
    print(u.host) # api.example.com
    print(u.port) # 8443
    print(u.path) # /v1/items
    print(u.query) # filter=active
    ```

## Structs

### `UrlParseError`

```mojo
struct UrlParseError
```

Raised when a URL string cannot be parsed.

Fields:

- `message` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `UrlParseError.__init__`

```mojo
def __init__(out self, message: String)
```

#### `UrlParseError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `Url`

```mojo
struct Url
```

A parsed HTTP/HTTPS URL.

Fields:
    scheme: ``"http"`` or ``"https"``.
    host: Hostname or IP, without brackets (IPv6 brackets stripped).
    port: Numeric port; defaults to 80 (http) or 443 (https).
    path: URL path including leading ``/``; ``"/"`` if absent.
    query: Query string without leading ``?``; ``""`` if absent.
    fragment: Fragment without leading ``#``; ``""`` if absent.

This type is ``Movable`` but not ``Copyable``.

Fields:

- `scheme` (`String`)
- `host` (`String`)
- `port` (`UInt16`)
- `path` (`String`)
- `query` (`String`)
- `fragment` (`String`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `Url.__init__`

```mojo
def __init__(out self, scheme: String, host: String, port: UInt16, path: String, query: String = "", fragment: String = "")
```

#### `Url.parse`

```mojo
def parse(raw: String) raises -> Self
```

Parse a URL string into a ``Url``.

Args:

- `raw`: Full URL string (``http://...`` or ``https://...``).

Returns: Parsed ``Url``.

Raises: UrlParseError: If the URL is missing a scheme, host, or uses an unsupported scheme.

#### `Url.request_target`

```mojo
def request_target(self) -> String
```

Return the request-target for the HTTP request line.

Returns: ``/path?query`` or ``/path`` if query is empty.

#### `Url.is_tls`

```mojo
def is_tls(self) -> Bool
```

Return True if the scheme is ``https``.

Returns: True for ``https``, False for ``http``.

# `dodo.http.request_builder`

Fluent-ish per-request builder for the HTTP client.

``HttpClient.get(url)`` / ``post(url, body)`` cover the common cases but
take nothing else -- no per-request headers, query parameters, or
content-type without hand-rolling a ``Request`` and calling
``client.send(req)``. ``RequestBuilder`` is the ergonomic middle ground:
accumulate method, URL, headers, query parameters, and a typed body,
then ``build()`` a ``Request`` to hand to ``client.send``.

    var b = RequestBuilder(Method.POST, "https://api.example.com/items")
    b.header("Authorization", "Bearer " + token)
    b.query("page", "2")
    b.json('{"name":"widget"}')
    var resp = client.send(b^.build())

Query values are percent-encoded (``dodo.http.form.urlencode``) and
appended to the URL, so callers pass raw values. The builder is
move-only (it owns a ``HeaderMap`` + body buffer); ``build`` consumes it.

## Structs

### `RequestBuilder`

```mojo
struct RequestBuilder
```

Accumulates a request; ``build()`` produces the ``Request``.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `RequestBuilder.__init__`

```mojo
def __init__(out self, method: String, url: String)
```

Start a builder for ``method`` ``url``.

#### `RequestBuilder.header`

```mojo
def header(mut self, name: String, value: String) raises
```

Add a request header (repeatable; appends, does not replace).

#### `RequestBuilder.query`

```mojo
def query(mut self, name: String, value: String)
```

Add a query parameter; ``name`` and ``value`` are percent-encoded and joined with ``&``.

#### `RequestBuilder.body`

```mojo
def body(mut self, var data: List[UInt8], content_type: String = "")
```

Set a raw byte body (optionally with a content type).

#### `RequestBuilder.text`

```mojo
def text(mut self, data: String, content_type: String = "text/plain")
```

Set a UTF-8 text body (default ``text/plain``).

#### `RequestBuilder.json`

```mojo
def json(mut self, data: String)
```

Set a JSON string body + ``Content-Type: application/json``.

#### `RequestBuilder.build`

```mojo
def build(var self) raises -> Request
```

Materialise the ``Request`` (consumes the builder).

Query parameters are appended to the URL (``?`` or ``&`` as
appropriate); accumulated headers are copied; ``Content-Type``
is set from the typed-body helpers when present.

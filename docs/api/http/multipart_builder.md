# `dodo.http.multipart_builder`

Client-side ``multipart/form-data`` request-body builder (RFC 7578).

The server side parses multipart bodies (``parse_multipart_form_data``
+ the ``Multipart`` extractor); this is the matching client half:
assemble text fields and file parts into a body plus the
``Content-Type: multipart/form-data; boundary=...`` header value, then
hand both to ``RequestBuilder.body`` / ``HttpClient.send``.

    var mp = MultipartFormBuilder()
    mp.field("title", "hello")
    mp.file("upload", "a.txt", "text/plain", data)
    var ct = mp.content_type()
    var b = RequestBuilder(Method.POST, url)
    b.body(mp.finish(), ct)
    var resp = client.send(b^.build())

## Structs

### `MultipartFormBuilder`

```mojo
struct MultipartFormBuilder
```

Accumulates multipart/form-data parts; ``finish()`` yields the body.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `MultipartFormBuilder.__init__`

```mojo
def __init__(out self)
```

Start a builder with a unique random boundary.

```mojo
def __init__(out self, boundary: String)
```

Start a builder with a caller-fixed boundary (deterministic for tests). The caller must ensure it does not occur in any part's payload.

#### `MultipartFormBuilder.field`

```mojo
def field(mut self, name: String, value: String)
```

Add a plain text form field.

#### `MultipartFormBuilder.file`

```mojo
def file(mut self, name: String, filename: String, content_type: String, var data: List[UInt8])
```

Add a file part (``content_type`` empty defaults to ``application/octet-stream``).

#### `MultipartFormBuilder.content_type`

```mojo
def content_type(self) -> String
```

The ``Content-Type`` header value carrying the boundary. Read this before calling :meth:`finish` (which consumes).

#### `MultipartFormBuilder.finish`

```mojo
def finish(mut self) -> List[UInt8]
```

Append the closing delimiter and return the body bytes. Leaves the builder empty (do not reuse after).

# `dodo.http.multipart`

``multipart/form-data`` parsing (RFC 7578).

Browsers emit ``multipart/form-data`` for forms with file inputs or a
non-default ``enctype``. The body is a sequence of parts separated
by a boundary string declared in the request's
``Content-Type: multipart/form-data; boundary=<token>`` header. Each
part has its own headers and body bytes; binary file uploads do not
need any encoding (text fields stay verbatim too).

Wire format:

```mojo
--boundary\r\n
Content-Disposition: form-data; name="<field>"; filename="<file>"\r\n
Content-Type: <mime>\r\n
\r\n
<bytes...>\r\n
--boundary\r\n
Content-Disposition: form-data; name="<text-field>"\r\n
\r\n
<text...>\r\n
--boundary--\r\n
```

This module ships:

- ``MultipartPart`` — one form part: name, optional filename, optional
  content type, body bytes, raw header map.
- ``MultipartForm`` — name → part(s) collection; supports lookup by
  name plus iteration in receive order.
- ``parse_multipart_form_data`` — bytes + ``Content-Type`` header →
  ``MultipartForm``. The ``Multipart`` extractor in
  ``dodo.http.extract`` is the typed wrapper.

The parser is buffered (the entire body is a ``List[UInt8]`` already
held by ``Request.body``); a streaming variant on top of
``ChunkSource`` is left for a future revision when uploads exceed
``ServerConfig.max_body_size``.

## Structs

### `MultipartPart`

```mojo
struct MultipartPart
```

A single part inside a ``multipart/form-data`` body.

Fields:
    name: ``name="..."`` from ``Content-Disposition``;
                  empty if absent (treated as malformed).
    filename: ``filename="..."`` if present (file uploads);
                  empty for plain text fields.
    content_type: ``Content-Type`` of this part if specified;
                  empty otherwise (defaults to
                  ``text/plain; charset=US-ASCII`` per RFC 7578
                  §4.4 if a consumer needs a non-empty fallback).
    body: The part's raw payload bytes (no trailing CRLF).
    headers: Every header line for this part as a parallel
                  ``List[String]`` pair.

Fields:

- `name` (`String`)
- `filename` (`String`)
- `content_type` (`String`)
- `body` (`List[UInt8]`)
- `header_keys` (`List[String]`)
- `header_values` (`List[String]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `MultipartPart.__init__`

```mojo
def __init__(out self)
```

#### `MultipartPart.text`

```mojo
def text(self) -> String
```

Decode the part body as a UTF-8 ``String``.

Invalid UTF-8 sequences are replaced with the Unicode
replacement character: part bodies are raw client-supplied bytes
(RFC 7578 §4.2), so this never raises on malformed input.

#### `MultipartPart.is_file`

```mojo
def is_file(self) -> Bool
```

Return True if this part represents a file upload (has ``filename``).

#### `MultipartPart.header`

```mojo
def header(self, key: String) -> String
```

Return part-level header ``key`` (case-insensitive), or ``""``.

### `MultipartForm`

```mojo
struct MultipartForm
```

All parts of a parsed ``multipart/form-data`` body in receive order.

Fields:

- `parts` (`List[MultipartPart]`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `MultipartForm.__init__`

```mojo
def __init__(out self)
```

#### `MultipartForm.len`

```mojo
def len(self) -> Int
```

Return the number of parts in this form.

#### `MultipartForm.get`

```mojo
def get(self, name: String) -> Optional[MultipartPart]
```

Return the first part whose ``Content-Disposition`` ``name`` matches.

#### `MultipartForm.get_all`

```mojo
def get_all(self, name: String) -> List[MultipartPart]
```

Return every part with ``Content-Disposition`` ``name == name``.

#### `MultipartForm.value`

```mojo
def value(self, name: String) -> String
```

Convenience: return the first text value for ``name`` or ``""``.

#### `MultipartForm.file`

```mojo
def file(self, name: String) -> Optional[MultipartPart]
```

Return the first file part whose ``name`` matches, or ``None``.

#### `MultipartForm.contains`

```mojo
def contains(self, name: String) -> Bool
```

Return True if any part with ``name`` exists.

## Functions

### `parse_multipart_form_data`

```mojo
def parse_multipart_form_data(body: List[UInt8], content_type: String) raises -> MultipartForm
```

Parse a buffered multipart/form-data body.

Args:

- `body`: The raw request body bytes.
- `content_type`: The request's ``Content-Type`` header value (must include ``boundary=<token>``).

Returns: A populated ``MultipartForm``.

Raises: Error: When the boundary parameter is missing, the body does not begin with the expected delimiter, or any part is truncated (no closing CRLF before the next boundary).

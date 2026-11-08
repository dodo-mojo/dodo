# `dodo.http.fs`

``FileServer`` — serve files from a directory with HEAD + Range support.

Reads files synchronously via libc ``open(2)`` / ``read(2)``;
suitable for sub-100 MB static directories. For larger trees, or
under concurrent load, wrap the handler in ``Offload``.

Features:

- ``GET`` and ``HEAD``.
- Single-range ``Range: bytes=<start>-<end>`` support, RFC 9110
  paragraph 14.2 / 14.4. Multi-range responses are out of scope —
  servers may reject them per spec.
- Path safety: rejects any URL whose normalised path escapes the
  base directory (``..`` components, absolute paths, NUL bytes).
- ``Content-Type`` from a small built-in extension table (covers
  the common web shapes: HTML/CSS/JS/JSON/PNG/JPG/SVG/WOFF/TXT).
- Sets ``Last-Modified`` from the file's mtime so caches /
  conditional GET (``If-Modified-Since``) work correctly.

The handler is a plain ``Handler`` so it composes with the rest of
dodo's middleware. Configure via ``FileServer.new(root)``.

## Structs

### `ByteRange`

```mojo
struct ByteRange
```

One ``Range: bytes=start-end`` request.

Fields are 0-indexed inclusive, matching RFC 9110 paragraph
14.1.2's wire format. Negative ``start`` (suffix range) is
resolved into an absolute ``[start, end]`` against the file
size by ``parse_range``.

Fields:

- `start` (`Int`)
- `end` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `ByteRange.__init__`

```mojo
def __init__(out self)
```

### `FileServer`

```mojo
struct FileServer
```

Serve files from ``root`` under the request URL path.

Construction:
    ```mojo
    var fs = FileServer.new("./public")
    var srv = HttpServer.bind(addr)
    srv.serve(fs^, num_workers=4)
    ```

Returns 404 for any path that escapes ``root``, doesn't exist,
or is not a regular file. ``HEAD`` returns the response with an
empty body. ``Range: bytes=...`` returns 206 with the requested
slice; other methods return 405.

Fields:

- `root` (`String`)
- `index_file` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Handler`, `Movable`

Aliases:

- `BodyType = InlineBody`: The ``Body`` impl this handler authors its response with.

#### `FileServer.__init__`

```mojo
def __init__(out self)
```

#### `FileServer.new`

```mojo
def new(root: String, index_file: String = "index.html") -> Self
```

#### `FileServer.serve`

```mojo
def serve(self, req: Request) raises -> Response
```

## Functions

### `parse_range`

```mojo
def parse_range(value: String, file_size: Int) raises -> Optional[ByteRange]
```

Parse a single-range ``Range`` header value.

Returns ``None`` if the header is missing/blank. Returns
``Some(ByteRange{start, end})`` on success. Raises ``Error`` on:

- Multi-range requests (``,``-separated).
- Out-of-range / negative-end / inverted ranges.
- Non-``bytes=`` units.

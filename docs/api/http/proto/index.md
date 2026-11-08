# `dodo.http.proto`

``dodo.http.proto`` -- pure-function HTTP wire codecs and parsers.

This package is the **sans-I/O** face of dodo's HTTP stack. Every
module re-exported here is a pure-function library over byte spans
and Mojo values: no sockets, no reactor, no TLS context, no
filesystem access, no syscalls beyond what the Mojo stdlib pulls in
for ``String`` / ``List[UInt8]`` allocation. The strict contract:

- No imports from ``dodo.runtime`` (reactor, scheduler, cancel,
  timers, handoff, pools, blocking helpers).
- No imports from ``dodo.io`` (``BufReader``).
- No imports from ``dodo.tcp`` / ``dodo.udp`` / ``dodo.uds``.
- No imports from ``dodo.tls`` (OpenSSL FFI).
- No imports from ``dodo.net`` (socket address resolution).

The contract is enforced statically by ``pixi run check-sans-io``
which scans every file registered in ``tests/tools/check_sans_io.sh``
for the forbidden import prefixes. Adding a file to the sans-I/O
list is a one-line change in that script.

## Why a separate namespace

The same parser modules feed multiple users: the reactor server,
the in-process ``TestClient``, fuzz harnesses, conformance test
runners, and downstream applications that want to embed dodo's
parsers without pulling in the reactor. Today they live under
``dodo.http.*`` next to reactor-coupled code; the layout buries
the boundary. ``dodo.http.proto`` is the explicit, lint-enforced
public face for the parser-only surface.

## What lives here

This package re-exports the canonical sans-I/O modules from their
existing locations under ``dodo.http.*`` and ``dodo.http2.*``;
imports continue to work via either path. New pure-function
parsers added in future work land here directly.

```mojo
from dodo.http.proto import (
    Cookie, CookieJar, parse_cookie_header,
    FormData, parse_form_urlencoded, urldecode, urlencode,
    MultipartForm, parse_multipart_form_data,
    Url, UrlParseError,
    HeaderMap, HeaderMapView,
    H2Frame, parse_h2_frame, encode_h2_frame,
    HpackEncoder, HpackDecoder,
    Http2Connection, H2Stream, H2StreamState,
)
```

The H1 message parser, multipart boundary scanner, URL
percent-decoder, cookie / Set-Cookie parser, HPACK encoder /
decoder, and HTTP/2 frame codec / connection state machine are
all sans-I/O. The reactor-bound dispatcher in
``dodo.http.server`` calls into this layer; downstream users
embedding dodo-as-parser can do the same.

## H1 leniency

The H1 parser accepts a handful of widely-deployed RFC 9110 /
RFC 9112 relaxations as opt-in flags. The ``H1LeniencyConfig``
carrier surfaces them; strict mode (the no-argument constructor)
is the default. Each flag wires to a specific parser branch in
:func:`dodo.http.server._parse_http_request_bytes`. The legacy
``_ExperimentalH1LeniencyConfig`` alias remains importable for
back-compat.

## Modules

- [`dodo.http.proto.ascii`](ascii.md): ``dodo.http.proto.ascii`` -- zero-validation ASCII helpers.
- [`dodo.http.proto.chunked`](chunked.md): Sans-I/O framing for ``Transfer-Encoding: chunked`` request bodies.
- [`dodo.http.proto.h1_leniency`](h1_leniency.md): Named opt-in flags for HTTP/1.1 parser leniency.
- [`dodo.http.proto.h2_config`](h2_config.md): HTTP/2 SETTINGS and per-connection limits.
- [`dodo.http.proto.h2c_upgrade`](h2c_upgrade.md): HTTP/1.1 -> HTTP/2 cleartext (h2c) upgrade detection (RFC 7540 §3.2).
- [`dodo.http.proto.huffman`](huffman.md): Canonical sans-I/O HPACK Huffman codec surface (``dodo.http.proto.huffman``) -- RFC 7541 §5.2 + Appendix B.
- [`dodo.http.proto.utf8`](utf8.md): Lossy UTF-8 decoding for caller-supplied byte bodies.

"""``dodo.http.proto`` -- pure-function HTTP wire codecs and parsers.

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
"""

# Cookies (RFC 6265) -- pure parsers / constructors / serialisers.
from dodo.http.cookie import (
    Cookie,
    CookieJar,
    SameSite,
    parse_cookie_header,
    parse_set_cookie_header,
)

# Forms / URL percent-decoding (RFC 3986 §2.1 + RFC 7578) --
# pure parsers / encoders over ``String`` / ``List[UInt8]``.
from dodo.http.form import (
    FormData,
    parse_form_urlencoded,
    urldecode,
    urlencode,
)

# Multipart bodies (RFC 7578) -- pure parser + value types.
from dodo.http.multipart import (
    MultipartForm,
    MultipartPart,
    parse_multipart_form_data,
)

# URL parsing (RFC 3986) -- pure value types + parser.
from dodo.http.url import Url, UrlParseError

# Header maps + zero-copy views (RFC 9110 §5).
from dodo.http.headers import HeaderInjectionError, HeaderMap
from dodo.http.header_view import HeaderMapView, parse_header_view

# Standard header perfect-hash lookup (RFC 7230 + RFC 9110 list).
from dodo.http.header_phf import (
    StandardHeader,
    is_standard_header,
    lookup_standard_header_bytes,
    lookup_standard_header_string,
    standard_header_count,
    standard_header_name,
)

# Method + common-value interning -- ``StaticString`` returns.
from dodo.http.intern import (
    MethodIntern,
    ValueIntern,
    intern_common_value,
    intern_common_value_string,
    intern_method_bytes,
    intern_method_string,
)

# SIMD-accelerated byte scanners + percent-decode.
from dodo.http.simd_parsers import (
    HttpParseError,
    simd_cookie_scan,
    simd_memmem,
    simd_percent_decode,
)

# HPACK Huffman codec (RFC 7541 §5.2 + Appendix B). Single
# canonical surface re-exported from ``dodo.http.proto.huffman``;
# scalar reference + 256-entry 8-bit fast-table dispatcher today,
# real PSHUFB/TBL kernel slot reserved on the same symbols once
# Mojo exposes the byte-shuffle intrinsics. Pure functions over
# byte spans (no I/O imports anywhere on the path).
from dodo.http.proto.huffman import (
    HuffmanError,
    SIMD_HUFFMAN_THRESHOLD_BYTES,
    huffman_decode,
    huffman_decode_dispatch,
    huffman_decode_simd,
    huffman_decoded_length,
    huffman_encode,
    huffman_encoded_length,
)

# HTTP/2 frame codec (RFC 9113 §4). Pure encode / decode over
# byte spans -- the reactor copies bytes in and out, the codec
# never touches a fd.
from dodo.http2.frame import (
    Frame as H2Frame,
    FrameFlags as H2FrameFlags,
    FrameHeader as H2FrameHeader,
    FrameType as H2FrameType,
    encode_frame as encode_h2_frame,
    parse_frame as parse_h2_frame,
)

# HPACK encoder + decoder (RFC 7541). Both keep dynamic-table
# state internally but expose pure ``encode`` / ``decode`` methods
# over byte spans.
from dodo.http2.hpack import (
    HpackDecoder,
    HpackEncoder,
    HpackHeader,
    StringPair as HpackStringPair,
    decode_integer as hpack_decode_integer,
    encode_integer as hpack_encode_integer,
)

# HTTP/2 connection + stream state machines (RFC 9113 §5).
# ``Http2Connection`` exposes ``handle_frame`` as the single
# per-frame entry point; no timers, no fd, no reactor.
from dodo.http2.state import (
    Connection as Http2Connection,
    Stream as H2Stream,
    StreamState as H2StreamState,
)

# HTTP/1.1 parser leniency configuration carrier. Strict by
# default; every relaxation is opt-in and named after the RFC
# 9112 section it relaxes. Wired into the H1 request parser
# via :attr:`dodo.http.server.ServerConfig.h1_leniency`. The
# ``_ExperimentalH1LeniencyConfig`` alias is preserved as a thin
# rebind for existing configuration code.
from dodo.http.proto.h1_leniency import (
    H1LeniencyConfig,
    _ExperimentalH1LeniencyConfig,
)

# Zero-validation ASCII -> String helper. Promoted from the
# reactor-coupled ``dodo.http.server`` to the sans-I/O parser
# layer because every consumer (H1 message parser, H2 wire codec,
# HPACK) is parser-shaped.
from dodo.http.proto.ascii import (
    ascii_lower,
    ascii_unchecked_string,
    ascii_eq_ignore_case,
)

# RFC 7540 §3.2 ``Upgrade: h2c`` detector. Pure predicate over a
# parsed ``HeaderMap`` -- no reactor / socket / TLS coupling.
# Both ``dodo.http2.server.detect_h2c_upgrade`` and the unified
# reactor's per-conn helper delegate to this canonical surface.
from dodo.http.proto.h2c_upgrade import detect_h2c_upgrade
from dodo.http.proto.h2_config import Http2Config

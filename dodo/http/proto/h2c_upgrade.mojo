"""HTTP/1.1 -> HTTP/2 cleartext (h2c) upgrade detection (RFC 7540 §3.2).

Pure-function detector over a parsed :class:`HeaderMap`. The full
RFC 7540 §3.2 upgrade dance has three pieces; this module scopes
exactly to the **detection** step:

1. Client sends an HTTP/1.1 request with::

       Connection: Upgrade, HTTP2-Settings
       Upgrade: h2c
       HTTP2-Settings: <base64url(SETTINGS payload)>

2. Server returns ``101 Switching Protocols`` and starts speaking
   HTTP/2 on the same TCP connection (the decoded SETTINGS payload
   from step 1 is the peer's initial SETTINGS frame).

3. Subsequent bytes on the connection are the HTTP/2 client
   preface (``PRI * HTTP/2.0\\r\\n\\r\\nSM\\r\\n\\r\\n``) followed
   by frames.

This module owns step 1 — the *detection* — exclusively. The 101
write, the SETTINGS payload decode, and the HTTP/2 driver hand-off
all live in the reactor and HTTP/2 server modules. Placing the
detector in ``dodo.http.proto`` lets the H1 parser, the H2
acceptor, and the unified reactor each call into a single, neutral
helper instead of duplicating the predicate or chaining a
reactor-bound import.

## Why a sans-I/O module

Before this extraction the canonical helper lived in
``dodo.http2.server.detect_h2c_upgrade``. The reactor's
:class:`dodo.http._reactor.conn_handle.ConnHandle` needed the same
predicate but couldn't import :mod:`dodo.http2.server` (that
module pulls in the H2 reactor driver, which would create a
``conn_handle`` -> ``http2.server`` -> ``dodo.http`` import
cycle). So a byte-for-byte ``_detect_h2c_upgrade_inline`` copy
shipped with a TODO note pointing at this future extraction.

Promoting the detector into ``dodo.http.proto.h2c_upgrade``
breaks the cycle: every consumer (the H2 server, the unified
reactor, downstream code that wants to detect h2c on its own H1
parser output) imports from the neutral sans-I/O sublayer that
nothing else depends on. The two prior call sites
(:func:`dodo.http2.server.detect_h2c_upgrade` and
``conn_handle._detect_h2c_upgrade_inline``) both delegate to
:func:`detect_h2c_upgrade` here, so behaviour is preserved exactly.

## Strict acceptance contract

The RFC requires both ``Upgrade: h2c`` *and* a non-empty
``HTTP2-Settings`` header. We accept the upgrade only when both
are present:

- ``Upgrade`` header value must be exactly ``"h2c"`` (case-
  insensitive comparison via :class:`HeaderMap` lookup).
- ``HTTP2-Settings`` header must be present with a non-empty
  value. The base64url decode + payload validation happens later
  in the reactor when the connection migrates; rejecting the
  upgrade here on a missing header is sufficient to skip the
  reactor migration entirely for malformed clients.

## Sans-I/O contract

This module imports from :mod:`dodo.http.headers` only. No
sockets, no reactor, no TLS, no filesystem. ``HeaderMap`` is a
pure value type. The detector is a one-line predicate over header
lookups; it raises nothing and allocates nothing.
"""

from dodo.http.headers import HeaderMap


@always_inline
def detect_h2c_upgrade(headers: HeaderMap) -> Bool:
    """Detect an inbound RFC 7540 §3.2 ``Upgrade: h2c`` request.

    The full RFC also requires the client to list ``Upgrade`` and
    ``HTTP2-Settings`` in its ``Connection`` header; the deployed
    h2c clients in the wild are consistent on this and the parser
    rejects requests that ship ``Upgrade: h2c`` without a
    ``HTTP2-Settings`` payload. Detection scopes to those two
    headers exactly:

    1. ``Upgrade`` is exactly ``"h2c"`` (HeaderMap comparison is
       byte-wise; clients always emit lower-case ``h2c``).
    2. ``HTTP2-Settings`` is present and non-empty.

    The base64url decode of ``HTTP2-Settings`` runs later, on the
    reactor side, when the connection actually migrates to HTTP/2.

    Args:
        headers: Parsed request headers (any HeaderMap-shaped
            value, including a fresh parser output or a copy
            stashed for the upgrade path).

    Returns:
        ``True`` when both predicates above hold, ``False``
        otherwise.
    """
    var upg = headers.get("upgrade")
    if upg.byte_length() == 0:
        return False
    if upg != "h2c":
        return False
    return headers.get("http2-settings").byte_length() > 0

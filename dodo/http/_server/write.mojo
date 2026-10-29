"""HTTP/1.1 response serialization extracted from ``dodo.http.server``.

``_write_response_buffered`` (one-buffer-one-write serializer), the
allocation-free ``itoa`` / byte-append primitives it relies on, the
status-reason table, and the legacy stream writer. ``dodo.http.server``
re-exports every name here (including the ``_ascii_lower`` alias the
reactor imports from ``dodo.http.server``).
"""

from std.memory import unsafe_memcpy

from ..response import Response
from ..status_reason import status_reason
from ..headers import _eq_icase
from ...tcp import TcpStream

# ``_ascii_lower`` lives in ``dodo.http.proto.ascii`` (canonical
# sans-I/O helper); aliased here under the original private name and
# re-exported from ``dodo.http.server`` so every existing call site --
# the reactor and the tests -- keeps working.
from ..proto.ascii import ascii_lower as _ascii_lower


def _write_response_buffered(
    mut stream: TcpStream, resp: Response, keep_alive: Bool
) raises:
    """Serialise ``resp`` into a single buffer and write it in one call.

    Args:
        stream: Open ``TcpStream`` for the client connection.
        resp: The response to send.
        keep_alive: If True, sends ``Connection: keep-alive``; otherwise ``close``.

    Raises:
        NetworkError: On I/O failure.
    """
    var reason = resp.reason
    if reason.byte_length() == 0:
        reason = status_reason(resp.status)

    var body_len = len(resp.body)

    var estimated = 64 + body_len
    for i in range(resp.headers.len()):
        estimated += (
            resp.headers._keys[i].byte_length()
            + resp.headers._values[i].byte_length()
            + 4
        )
    var wire = List[UInt8](capacity=estimated)

    _append_str(wire, "HTTP/1.1 ")
    _append_str(wire, String(resp.status))
    _append_str(wire, " ")
    _append_str(wire, reason)
    _append_str(wire, "\r\n")

    for i in range(resp.headers.len()):
        var k = resp.headers._keys[i]
        var kl = _ascii_lower(k)
        if kl == "content-length" or kl == "connection":
            continue
        _append_str(wire, k)
        _append_str(wire, ": ")
        _append_str(wire, resp.headers._values[i])
        _append_str(wire, "\r\n")

    _append_str(wire, "Content-Length: ")
    _append_str(wire, String(body_len))
    _append_str(wire, "\r\n")

    if keep_alive:
        _append_str(wire, "Connection: keep-alive\r\n")
    else:
        _append_str(wire, "Connection: close\r\n")

    _append_str(wire, "\r\n")

    for i in range(body_len):
        wire.append(resp.body[i])

    stream.write_all(Span[UInt8, _](wire))


@always_inline
def _append_str(mut buf: List[UInt8], s: String):
    """Append all bytes of ``s`` to ``buf``.

    Bulk extend via resize + pointer copy. The naive per-byte
    ``buf.append(...)`` loop was called O(100) times per serialized
    response (status line + each header + body) which added measurable
    cost at 100K+ req/s.
    """
    var n = s.byte_length()
    if n == 0:
        return
    var old_len = len(buf)
    buf.resize(old_len + n, UInt8(0))
    unsafe_memcpy(
        dest=buf.unsafe_ptr().unsafe_offset(old_len),
        src=s.unsafe_ptr(),
        count=n,
    )


def _write_response(mut stream: TcpStream, resp: Response) raises:
    """Legacy response writer. Delegates to buffered version with Connection: close.
    """
    _write_response_buffered(stream, resp, keep_alive=False)


def frame_h1_stream_head_into(
    mut out: List[UInt8], resp: Response, keep_alive: Bool
):
    """Append the HTTP/1.1 head (status line + headers + blank line) of a
    *streaming* response to ``out``.

    This is the h1 member of the per-wire streaming-response head framers:
    the reusable framing adapter behind :meth:`StreamConn.send_response`
    and any HTTPS front that streams over :class:`TlsConnHandle` (the head
    bytes are transport-agnostic -- write them via ``send`` on plaintext or
    ``SSL_write`` on TLS). The sibling wires frame their heads through their
    own codecs: **h2** via HPACK (``encode_headers`` in the h2 server);
    those are frames on a multiplexed connection, not raw bytes, so they
    live with their drivers rather than here.

    Framing rules (streaming-specific, distinct from the buffered
    serialiser):

    - Any inbound ``Connection`` header is dropped; ``Connection`` is set
      solely from ``keep_alive``.
    - ``Content-Length`` is emitted from ``len(resp.body)`` **only** when
      the response declares neither ``Transfer-Encoding`` nor
      ``Content-Length`` -- a chunked / SSE front sets ``Transfer-Encoding``
      itself and streams the body via ``send``, so this must not force a
      length onto it.

    The fixed body (if any) is the caller's to append after the head.
    """
    var reason = resp.reason
    if reason.byte_length() == 0:
        reason = status_reason(resp.status)
    _append_str(out, "HTTP/1.1 ")
    _append_str(out, String(resp.status))
    _append_str(out, " ")
    _append_str(out, reason)
    _append_str(out, "\r\n")
    for i in range(resp.headers.len()):
        var k = resp.headers._keys[i]
        if _eq_icase(k, "connection"):
            continue
        _append_str(out, k)
        _append_str(out, ": ")
        _append_str(out, resp.headers._values[i])
        _append_str(out, "\r\n")
    if not resp.headers.contains(
        "transfer-encoding"
    ) and not resp.headers.contains("content-length"):
        _append_str(out, "Content-Length: ")
        _append_str(out, String(len(resp.body)))
        _append_str(out, "\r\n")
    if keep_alive:
        _append_str(out, "Connection: keep-alive\r\n")
    else:
        _append_str(out, "Connection: close\r\n")
    _append_str(out, "\r\n")

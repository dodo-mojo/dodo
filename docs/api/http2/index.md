# `dodo.http2`

``dodo.http2`` -- low-level HTTP/2 driver primitives (RFC 9113 + RFC 7541).

This package exposes the byte-level HTTP/2 machinery: frame
codec, HPACK encoder + decoder, stream + connection state
machines, the byte-level server driver
:class:`Http2Connection`, and the symmetric byte-level client
driver :class:`Http2ClientConnection`.

The **user-facing** HTTP/2 entry points live in
:mod:`dodo.http`: :meth:`dodo.http.HttpServer.serve`
auto-dispatches HTTP/1.1 vs HTTP/2 per accepted connection
(preface peek for cleartext, ALPN ``h2`` for TLS), and
:class:`dodo.http.HttpClient` advertises ALPN
``["h2", "http/1.1"]`` for ``https://`` URLs (and speaks
HTTP/2 cleartext via prior knowledge when constructed with
``prefer_h2c=True``). Application code should reach for those
unified types; the primitives below are re-exported for callers
who want to drive the protocol themselves.

Out of scope (per the design doc):

- HTTP/2 push (``PUSH_PROMISE``); we accept it on inbound
  connections from clients (rare) but never originate it.
- HTTP/2 priority; we accept the frames and ignore them. RFC
  9113 §5.3.2 already deprecates the priority signalling.
- gRPC; the framing is HTTP/2 + a subprotocol -- we expose
  enough primitives that a gRPC server can be layered on, but
  no ``Code`` / ``Status`` machinery here.

## Modules

- [`dodo.http2.client`](client.md): HTTP/2 client byte driver (RFC 9113).
- [`dodo.http2.frame`](frame.md): HTTP/2 frame codec (RFC 9113 §4).
- [`dodo.http2.hpack`](hpack.md): HPACK header compression (RFC 7541).
- [`dodo.http2.server`](server.md): HTTP/2 server glue (RFC 9113).
- [`dodo.http2.state`](state.md): HTTP/2 state machines (RFC 9113 §5).
- [`dodo.http2.stream_slab`](stream_slab.md): HTTP/2 per-connection stream slab.

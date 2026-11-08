# `dodo.http.proto.h2_config`

HTTP/2 SETTINGS and per-connection limits.

``Http2Config`` is pure configuration -- nine ``Int`` / ``Bool`` fields
and their RFC-mandated defaults, with no I/O and no dependency on the
HTTP/2 codec. It lives under :mod:`dodo.http.proto` rather than in
:mod:`dodo.http2` so that :class:`dodo.http.ServerConfig` can nest it
without ``dodo.http`` importing ``dodo.http2``, which the layering
lint forbids outside a short allowlist.

:mod:`dodo.http2` re-exports it, so ``from dodo.http2 import
Http2Config`` keeps working and remains the spelling to use when
configuring an :class:`~dodo.http2.Http2Connection` directly.

## Structs

### `Http2Config`

```mojo
struct Http2Config
```

Tunable HTTP/2 SETTINGS and limits for an :class:`Http2Connection`.

Protocol fields map to RFC 9113 §6.5.2 SETTINGS identifiers
(including the RFC 7541 HPACK header-table size). Defaults are the
production-shape numbers dodo's reactor wiring uses for both
the inline test driver in :mod:`tests.test_h2_server` and the
reactor-attached driver.

The ``allow_huffman_decode`` flag gates HPACK Huffman decoding
on the inbound HEADERS path. **Default ``True``, and it should
stay that way.** RFC 7541 sec 5.2 lets the *encoder* choose
whether a literal is Huffman-coded and signals it with the H bit;
a decoder does not get the same choice. curl, every browser, and
h2load Huffman-code by default, so a server that rejects H=1
cannot talk to them -- it answers the client's first HEADERS
frame by tearing down the connection.

Set it to ``False`` only to reproduce the raw-literal wire for a
specific peer.

The ``allow_huffman_encode`` flag is the emit-side twin and
legitimately defaults to ``False``: what a server *sends* is its
own choice, H=0 output is CRIME-class-side-channel-free by
construction, and every compliant client accepts it. Set it
``True`` to pick the shorter of raw vs Huffman per literal.

Example:

```mojo
from dodo.http2 import Http2Connection, Http2Config

var cfg = Http2Config(
    max_concurrent_streams=200,
    max_body_size=10 * 1024 * 1024,
    initial_window_size=131072,
    max_frame_size=32768,
    max_header_list_size=16384,
    header_table_size=8192,
    allow_huffman_decode=True,
    allow_huffman_encode=False,
    enable_connect_protocol=False,
)
var conn = Http2Connection.with_config(cfg)
```

Fields:
    max_concurrent_streams: SETTINGS_MAX_CONCURRENT_STREAMS
        (RFC 9113 §6.5.2). Bounds the per-connection live-stream
        count. ``0`` is not "unlimited": the server then refuses
        every new request stream with REFUSED_STREAM.
    max_body_size: Maximum buffered request bytes per stream, default
        10 MiB. Exceeding the limit resets the stream and frees its body.
        Zero permits only empty bodies; this is not a SETTINGS value.
    initial_window_size: SETTINGS_INITIAL_WINDOW_SIZE
        (RFC 9113 §6.5.2). Per-stream flow-control receive
        window the server advertises on inbound connections.
        Must be ``<= 2^31 - 1`` per RFC 9113 §6.9.2.
    max_frame_size: SETTINGS_MAX_FRAME_SIZE (RFC 9113 §6.5.2).
        Largest frame payload the server is willing to accept.
        Must be in ``[16384, 16777215]`` per RFC 9113 §6.5.2.
    max_header_list_size: SETTINGS_MAX_HEADER_LIST_SIZE
        (RFC 9113 §6.5.2). Header-list size cap (uncompressed,
        including 32-byte per-entry overhead).
    header_table_size: SETTINGS_HEADER_TABLE_SIZE (RFC 7541
        §4.2). HPACK dynamic-table size budget. It is advertised
        and caps the peer's table-size update; the decoder stays
        at the 4096 default until that update arrives.
    allow_huffman_decode: When ``True``, the HPACK decoder
        accepts H=1 literals (Huffman-encoded) via the RFC
        7541 Appendix B codec. Defaults to ``False`` --
        reject-by-default until soak data justifies flipping
        it on.
    allow_huffman_encode: When ``True``, the HPACK encoder
        picks the shorter of raw vs Huffman per emitted
        literal (size-only optimisation; H=1 frames remain
        CRIME-safe because the encoder dynamic table stays
        empty). Defaults to ``False`` -- H=0-only wire
        output until peers and soak data confirm interop.

Fields:

- `max_concurrent_streams` (`Int`)
- `max_body_size` (`Int`): Maximum buffered request bytes per stream (default 10 MiB).
- `initial_window_size` (`Int`)
- `max_frame_size` (`Int`)
- `max_header_list_size` (`Int`)
- `header_table_size` (`Int`)
- `allow_huffman_decode` (`Bool`)
- `allow_huffman_encode` (`Bool`)
- `enable_connect_protocol` (`Bool`)
- `allow_h2c_upgrade` (`Bool`): Honour ``Upgrade: h2c`` on cleartext HTTP/1.1 (RFC 7540 sec 3.2). Default ``False``: behind a proxy that forwards ``Upgrade``, a client could switch to HTTP/2 and get past the proxy's path rules (h2c smuggling). Prior-knowledge h2c (the client opens with the HTTP/2 preface) and h2 over TLS work either way.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `Http2Config.__init__`

```mojo
def __init__(out self)
```

Default to the production-shape SETTINGS pinned in the design doc: 100 concurrent streams, 64 KiB-1 initial window, 16 KiB max frame, 8 KiB max header list, 4 KiB HPACK dynamic table, Huffman decode **on** and encode off, Extended CONNECT disabled.

```mojo
def __init__(out self, max_concurrent_streams: Int, initial_window_size: Int, max_frame_size: Int, max_header_list_size: Int, header_table_size: Int, allow_huffman_decode: Bool, allow_huffman_encode: Bool, enable_connect_protocol: Bool, max_body_size: Int = Int(10485760), allow_h2c_upgrade: Bool = False)
```

Configure every field.

#### `Http2Config.validate`

```mojo
def validate(self) raises
```

Raise if any field violates the RFC 9113 / RFC 7541 bounds.

The reactor-side wiring calls this once at acceptor handoff
so a misconfigured server fails fast at boot rather than
emitting malformed SETTINGS frames mid-handshake.

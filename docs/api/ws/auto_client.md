# `dodo.ws.auto_client`

`dodo.ws.auto_client` -- ALPN-driven WebSocket client dispatcher.

WebSocket has two carrying wires:

* HTTP/1.1 ``Upgrade: websocket`` (RFC 6455) -- the original
  bootstrap. Always available.
* HTTP/2 Extended CONNECT (RFC 8441) -- the modern variant. The
  server MUST advertise ``SETTINGS_ENABLE_CONNECT_PROTOCOL = 1``
  for the client to use it.

The choice between the two is naturally ALPN-driven: when the
TLS handshake on a ``wss://`` URL negotiates ALPN ``"h2"`` and
the h2 SETTINGS frame includes ``ENABLE_CONNECT_PROTOCOL = 1``,
the client runs WS-over-h2; otherwise it falls back to the
HTTP/1.1 path.

Builds on the WS-over-h2 primitive
(:class:`dodo.ws.WsOverH2Stream` +
:func:`dodo.ws.bootstrap_ws_over_h2`). The pure decision logic
lives in :func:`decide_wire`; the 13-case test corpus in
:mod:`tests.ws.test_ws_autoclient` pins every observable outcome.

:meth:`WsAutoClient.connect` drives the TLS handshake, inspects
the negotiated ALPN, and routes to :class:`dodo.ws.WsClient`
(HTTP/1.1 Upgrade) or :class:`dodo.ws.WsOverH2Stream` (HTTP/2
Extended CONNECT). The caller queries :attr:`chosen_wire` after
:meth:`connect` returns to learn which path was taken; the
path-specific carrier is exposed via :meth:`take_h1_client` /
:meth:`take_h2_carrier`.

References:

- RFC 6455 "The WebSocket Protocol" -- HTTP/1.1 path.
- RFC 8441 "Bootstrapping WebSockets with HTTP/2" -- h2 path.
- RFC 7301 "ALPN" -- the wire-selection mechanism.

## Structs

### `WsWireChoice`

```mojo
struct WsWireChoice
```

Stable codepoints for the wire :class:`WsAutoClient` picks after the runtime negotiation completes. The reactor / call- site dispatches on these to pick the carrier driver.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

Aliases:

- `UNDETERMINED = Int(0)`: The dispatcher hasn't run :meth:`WsAutoClient.connect` yet. The initial carrier state.
- `HTTP_1_1 = Int(1)`: RFC 6455 over an HTTP/1.1 Upgrade stream. Used when: - the URL scheme is ``ws://`` (no TLS, no ALPN), OR - ``prefer_h2 = False``, OR - the TLS handshake negotiated ALPN ``http/1.1``, OR - the negotiated h2 connection didn't advertise ``ENABLE_CONNECT_PROTOCOL = 1`` (RFC 8441 §3).
- `HTTP_2 = Int(2)`: RFC 8441 Extended CONNECT over an HTTP/2 stream. Used when the URL scheme is ``wss://``, ``prefer_h2 = True``, the TLS handshake negotiated ALPN ``h2``, and the negotiated h2 connection's SETTINGS frame includes ``ENABLE_CONNECT_PROTOCOL = 1``.
- `FAILED = Int(3)`: The dispatcher attempted to connect but the underlying TCP / TLS / h2 handshake failed before reaching the application protocol decision. See :attr:`WsAutoClient.last_error` for the per-attempt reason.

### `WsAutoClientConfig`

```mojo
struct WsAutoClientConfig
```

Inputs to :class:`WsAutoClient`'s wire-selection.

The carrier holds the URL + the protocol preferences; the
dispatcher consults this carrier when running its decision
sequence.  The carrier is value-typed + copyable so call
sites can build a base config, clone it, and tweak per-call.

Fields:

- `url` (`String`): The target URL. ``ws://`` skips TLS + uses the HTTP/1.1 wire unconditionally; ``wss://`` runs TLS + consults :attr:`prefer_h2` and the ALPN outcome.
- `prefer_h2` (`Bool`): When True (default), the client advertises both ``h2`` and ``http/1.1`` in ALPN and runs WS-over-h2 if the server picks ``h2`` AND advertises ``ENABLE_CONNECT_PROTOCOL = 1``. When False the client advertises only ``http/1.1`` and skips the h2 path entirely.
- `subprotocols` (`List[String]`): RFC 6455 §1.9 / RFC 8441 §5.1 Sec-WebSocket-Protocol candidates. Empty list means "no subprotocol request", which is the protocol's default.
- `extensions` (`List[String]`): RFC 6455 §9.1 / RFC 8441 §5.1 Sec-WebSocket-Extensions candidates (e.g. ``"permessage-deflate; client_no_context_takeover"``). Empty list means "no extension request".
- `tls_config` (`TlsConfig`): Caller-supplied TLS configuration. The dispatcher rewrites :attr:`TlsConfig.alpn` based on :attr:`prefer_h2` but otherwise honours the verify-mode, CA-bundle, and mTLS inputs as-is.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `WsAutoClientConfig.__init__`

```mojo
def __init__(out self)
```

### `WsAutoClient`

```mojo
struct WsAutoClient
```

High-level WebSocket client that picks the carrying wire at runtime based on negotiated ALPN + h2 SETTINGS.

The carrier exposes the *decision*; the underlying I/O lives
in the existing :class:`dodo.ws.WsClient` (h1 path) and
:class:`dodo.ws.WsOverH2Stream` (h2 path).  The dispatcher
is the small piece on top that picks between them.

Call :meth:`connect` to drive the TLS handshake + ALPN
inspection + per-path bootstrap; query :attr:`chosen_wire`
+ :meth:`is_h2_path` afterwards to learn which carrier won.
The path-specific handle is accessible via
:meth:`take_h1_client` (HTTP/1.1) or :meth:`take_h2_carrier`
(HTTP/2).

Fields:

- `config` (`WsAutoClientConfig`): The inputs the dispatcher consults.
- `chosen_wire` (`Int`): Set by :meth:`connect` once the wire-selection completes. Starts at :data:`WsWireChoice.UNDETERMINED`.
- `last_error` (`String`): Per-connection-attempt failure reason. Empty until :attr:`chosen_wire` transitions to :data:`WsWireChoice.FAILED`.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WsAutoClient.__init__`

```mojo
def __init__(out self, var config: WsAutoClientConfig)
```

#### `WsAutoClient.url_scheme`

```mojo
def url_scheme(self) -> String
```

Return ``"ws"`` or ``"wss"`` -- the parsed scheme from ``config.url``.  Empty string when the URL doesn't start with one of those two schemes (caller-supplied bug).

#### `WsAutoClient.is_h1_path`

```mojo
def is_h1_path(self) -> Bool
```

``True`` after a successful connect picked HTTP/1.1. Pairs with :meth:`take_h1_client`.

#### `WsAutoClient.is_h2_path`

```mojo
def is_h2_path(self) -> Bool
```

``True`` after a successful connect picked HTTP/2 Extended CONNECT. Pairs with :meth:`take_h2_carrier`.

#### `WsAutoClient.take_h1_client`

```mojo
def take_h1_client(mut self) raises -> WsClient
```

Consume + return the HTTP/1.1 :class:`WsClient` the dispatcher opened. Must only be called after a successful connect that left :attr:`chosen_wire` at HTTP_1_1; raises otherwise. Idempotently transitions the dispatcher into a consumed state -- subsequent calls raise.

#### `WsAutoClient.take_h2_carrier`

```mojo
def take_h2_carrier(mut self) raises -> _WsAutoH2Carrier
```

Consume + return the h2 path carrier (TLS stream + h2 driver + WS-over-h2 adapter). Must only be called after a successful connect that left :attr:`chosen_wire` at HTTP_2; raises otherwise. Idempotently transitions the dispatcher into a consumed state.

#### `WsAutoClient.connect`

```mojo
def connect(mut self) raises
```

Run the runtime connection sequence.

The steps are:

1. Parse the URL scheme.
2. ``ws://``: open a cleartext :class:`WsClient` (no ALPN
   involved). Sets :attr:`chosen_wire` to HTTP_1_1.
3. ``wss://`` + ``prefer_h2 = False``: open a TLS
   :class:`WsClient` with ALPN ``["http/1.1"]``. Sets
   :attr:`chosen_wire` to HTTP_1_1.
4. ``wss://`` + ``prefer_h2 = True``: open a TLS handshake
   with ALPN ``["h2", "http/1.1"]``. Read
   :meth:`TlsStream.alpn_selected`:

   a. ``"h2"``: drive the h2 preface, wait for the peer's
      SETTINGS frame, gate on
      :meth:`Http2ClientConnection.peer_supports_extended_connect`,
      bootstrap_ws_over_h2 on a fresh stream id, await
      the server's :status = 200 response, and store the
      h2 carrier. Sets :attr:`chosen_wire` to HTTP_2.

   b. ``"http/1.1"`` or ``""`` (no ALPN extension): close
      the discovery TLS handshake + open a fresh TLS
      :class:`WsClient` advertising only ``http/1.1``.
      Sets :attr:`chosen_wire` to HTTP_1_1.

On any failure :attr:`chosen_wire` flips to FAILED,
:attr:`last_error` records the failing message, and the
exception is re-raised.

## Functions

### `decide_wire`

```mojo
def decide_wire(url_scheme: String, prefer_h2: Bool, negotiated_alpn: String, h2_advertises_connect_protocol: Bool) -> Int
```

The pure WS-wire decision the dispatcher executes after the TLS handshake completes.

Inputs:

- ``url_scheme`` -- ``"ws"`` (cleartext) or ``"wss"`` (TLS).
- ``prefer_h2`` -- whether the carrier advertised ALPN ``h2``
  alongside ``http/1.1``.
- ``negotiated_alpn`` -- the protocol the TLS handshake
  picked; empty when no ALPN was negotiated (cleartext or
  old TLS).
- ``h2_advertises_connect_protocol`` -- whether the h2 peer's
  SETTINGS frame advertised ``ENABLE_CONNECT_PROTOCOL = 1``
  per RFC 8441 §3.  Only meaningful when the negotiated ALPN
  is ``h2``.

The function is pure + testable without any I/O.  The runtime
dispatcher (:meth:`WsAutoClient.connect`) plumbs the real
values from the TLS + h2 layers into this call.

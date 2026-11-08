# `dodo.http.frontend`

HTTP frontends for the multicore :class:`dodo.runtime.Scheduler`.

A :trait:`dodo.runtime.Frontend` impl is the *only* coupling
point between the runtime's multicore lifecycle and a serving
protocol's accept-and-serve loop. This module ships every HTTP-
flavoured frontend dodo needs:

- :class:`HttpFrontend[H]` — the dynamic-handler frontend. Wraps
  a user :trait:`Handler` plus a :class:`ServerConfig` and an
  optional :class:`dodo.http2.Http2Config`. Selects between the
  HTTP/1.1-only loop and the unified HTTP/1.1 + HTTP/2 preface-peek
  loop based on its config.
- :class:`StreamFrontend[H]`: the :trait:`StreamHandler` frontend
  behind multi-worker ``serve_streaming``.

The runtime imports nothing from :mod:`dodo.http`; the frontends
here import the reactor entry points and serve as the inversion
boundary. See :mod:`dodo.runtime.frontend` for the
trait contract.

## Structs

### `HttpFrontend`

```mojo
struct HttpFrontend[H: Handler & Copyable]
```

Dynamic-handler HTTP frontend for the multicore scheduler.

Carries the per-worker HTTP state (handler, request config,
HTTP/2 settings, auto-protocol toggle) and dispatches into
one of two reactor entry points:

1. **Unified HTTP/1.1 + HTTP/2** (``auto_protocol``, TLS, or
   several addresses): :func:`run_unified_reactor_loop_shared`.
   Per-connection preface peek selects the protocol.
2. **HTTP/1.1 only** (otherwise):
   :func:`run_reactor_loop_shared`.

Every path runs a handler's ``Offload`` requests on the offload
pool.

The frontend is :class:`Copyable` so the scheduler can clone
it once per worker before pthread spawn; expensive shared
state inside the user handler should be wrapped behind an
:class:`Pointer` so per-worker copies stay cheap.

Fields:

- `handler` (`H`)
- `config` (`ServerConfig`)
- `h2_config` (`Http2Config`)
- `auto_protocol` (`Bool`)
- `tls_ctx_addr` (`Int`): Address of the server's shared ``SSL_CTX``, or 0 for cleartext.
- `ws_hooks` (`Optional[WsH2Hooks]`): The server's WebSocket-over-h2 sidecar; each worker serves a copy of it (:meth:`WsH2Hooks.clone`).

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Frontend`, `Movable`

#### `HttpFrontend.__init__`

```mojo
def __init__(out self, var handler: H, var config: ServerConfig, var h2_config: Http2Config = Http2Config(), auto_protocol: Bool = False, tls_ctx_addr: Int = Int(0), ws_hooks: Optional[WsH2Hooks] = None)
```

Build a frontend with the given handler + config combo.

Args:

- `handler`: User request handler; cloned per worker.
- `config`: Server configuration; cloned per worker.
- `h2_config`: HTTP/2 SETTINGS used by the unified path. Ignored when ``auto_protocol`` is ``False``.
- `auto_protocol`: When ``True``, every accepted connection auto-dispatches to the right per-conn state machine via the RFC 9113 §3.4 preface peek. When ``False`` (default), the worker speaks HTTP/1.1 exclusively.
- `tls_ctx_addr`: Address of the shared server ``SSL_CTX``; 0 (default) serves cleartext. When set, each accepted connection starts as a TLS handshake and its protocol is chosen by ALPN.
- `ws_hooks`: Optional WS-over-h2 sidecar handler (RFC 8441). ``None`` disables the WS carrier path.

#### `HttpFrontend.run_worker`

```mojo
def run_worker(mut self, listener_fd: Int, mut stopping: Bool, stats_addr: Int, extra_fds: List[Int] = List())
```

Pick the reactor entry point and run it until ``stopping`` flips.

### `StreamFrontend`

```mojo
struct StreamFrontend[H: StreamHandler & Copyable]
```

Typed-streaming frontend for the multicore scheduler.

The :trait:`StreamHandler` twin of :class:`HttpFrontend`: carries a
per-worker streaming handler + admission-control knobs and drives
:func:`run_stream_reactor_loop_shared` on each worker's listener fd.
Copied once per worker before pthread spawn (the ``H: Copyable``
bound); expensive shared state should sit behind an
:class:`Pointer` so the per-worker copy stays cheap.

Fields:

- `handler` (`H`)
- `max_in_flight` (`Int`)
- `retry_after_s` (`Int`)
- `config` (`ServerConfig`): Offload pool settings for ``StreamConn.offload``.

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Frontend`, `Movable`

#### `StreamFrontend.__init__`

```mojo
def __init__(out self, var handler: H, max_in_flight: Int = Int(0), retry_after_s: Int = Int(1), var config: ServerConfig = ServerConfig(Int(8192), Int(8192), Int(10485760), Int(8192), True, Int(1000), Int(500), Int(5000), Int(5000), False, Int(30000), Int(30000), Int(0), Int(1024), Int(60000), Int(10000), Int(240), False, H1LeniencyConfig(allow_mixed_case_method=False, allow_ows_around_colon=False, allow_obs_fold=False, allow_oversized_request_uri=False, allow_oversized_header_list=False, accept_empty_chunk_extensions=False, allow_multiple_content_length=False, allow_te_chunked_when_cl_present=False, accept_obs_text_in_field_value=False, accept_invalid_chunk_extension_chars=False, allow_leading_whitespace_before_request_line=False), Int(0), WsUpgrade(), Http2Config()))
```

#### `StreamFrontend.run_worker`

```mojo
def run_worker(mut self, listener_fd: Int, mut stopping: Bool, stats_addr: Int, extra_fds: List[Int] = List())
```

Drive the shared streaming reactor loop.

``extra_fds`` is refused rather than ignored: the streaming
reactor registers a single listener, so accepting the list
silently would leave an address the caller bound with nothing
listening on it. ``HttpServer.serve_streaming`` refuses
multi-address binds up front for the same reason.

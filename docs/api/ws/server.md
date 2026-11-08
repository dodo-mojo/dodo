# `dodo.ws.server`

WebSocket server: upgrades HTTP connections to WebSocket (RFC 6455).

Server-to-client frames MUST NOT be masked (RFC 6455 §5.3).
Client-to-server frames MUST be masked; ``WsConnection.recv`` un-masks
them automatically.

The upgrade handshake (§4.2):

```mojo
1. Accept TCP connection.
2. Read the HTTP GET request and locate ``Sec-WebSocket-Key``.
3. Compute ``Sec-WebSocket-Accept = base64(SHA-1(key + GUID))``.
4. Send ``101 Switching Protocols``.
5. Hand off to ``WsConnection``.
```

## Aliases

### `DEFAULT_MAX_OFFLOADED_WS`

```mojo
comptime DEFAULT_MAX_OFFLOADED_WS = Int(4096)
```

Detached WebSocket threads a process runs at once by default.

## Structs

### `WsConnection`

```mojo
struct WsConnection
```

An accepted WebSocket connection (server side).

Server-side frames MUST NOT be masked (RFC 6455 §5.3).
Client-side frames MUST be masked; ``recv`` unmasks them automatically.

This type is ``Movable`` but not ``Copyable``.

A CLOSE received by :meth:`recv` is answered here (RFC 6455 sec
5.5.1), and once a CLOSE has been sent, by that reply or by
:meth:`close`, every ``send_*`` raises: an endpoint MUST NOT send
data after its CLOSE.

Fields:
    _stream: The underlying TCP stream.
    _peer: The remote socket address.
    origin: The handshake ``Origin`` header (empty when absent).

Example:
```mojo
def on_connect(conn: WsConnection) raises:
    var frame = conn.recv()
    conn.send_text(frame.text_payload()) # echo back

var srv = WsServer.bind(SocketAddr.localhost(9001))
srv.serve(on_connect)
```

Fields:

- `origin` (`String`): The ``Origin`` header sent with the upgrade handshake, or empty when the client sent none.
- `max_frame_size` (`Int`): Largest frame payload :meth:`recv` accepts. A client frame that declares more is answered with CLOSE 1009 (MESSAGE_TOO_BIG) and :meth:`recv` raises, before any of the payload is buffered. Defaults to :data:`DEFAULT_MAX_FRAME_BYTES`; set it in the handler before the first ``recv`` to change it.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WsConnection.__init__`

```mojo
def __init__(out self, var stream: TcpStream, peer: SocketAddr, var origin: String = "")
```

```mojo
def __init__(out self, var stream: TcpStream, peer: SocketAddr, var prebuf: List[UInt8], var origin: String = "")
```

Construct a ``WsConnection`` seeded with already-buffered post-handshake bytes.

Used by the ``HttpServer`` WebSocket-upgrade seam to hand off
any frame bytes the HTTP reactor had already read past the
upgrade request. ``prebuf`` is consumed by the first
``recv``/``_recv_one`` before any socket read.

Args:

- `stream`: The upgraded connection, already in blocking mode.
- `peer`: Remote address, for :attr:`peer`.
- `prebuf`: Bytes the reactor read past the upgrade request.
- `origin`: The handshake's ``Origin``, for :attr:`origin`.

#### `WsConnection.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `WsConnection.send_text`

```mojo
def send_text(self, msg: String) raises
```

Send a UTF-8 text message to the client.

Server-to-client frames are NOT masked (RFC 6455 §5.3).

Args:

- `msg`: The UTF-8 string to send.

Raises: NetworkError: On I/O failure, or if a CLOSE was already sent.

#### `WsConnection.send_binary`

```mojo
def send_binary(self, data: List[UInt8]) raises
```

Send a binary message to the client.

Server-to-client frames are NOT masked (RFC 6455 §5.3).

Args:

- `data`: The raw binary payload.

Raises: NetworkError: On I/O failure, or if a CLOSE was already sent.

#### `WsConnection.send_frame`

```mojo
def send_frame(mut self, frame: WsFrame) raises
```

Send an already-constructed frame (server, no masking).

Sending a CLOSE frame marks the closing handshake as started, the
same as :meth:`close`; a second CLOSE is dropped.

Args:

- `frame`: Frame to send. The ``mask`` bit is always ``False``.

Raises: NetworkError: On I/O failure, or if a CLOSE was already sent.

#### `WsConnection.recv`

```mojo
def recv(mut self) raises -> WsFrame
```

Receive the next data frame from the client.

Automatically replies to PING frames with an unmasked PONG and
continues reading. Returns TEXT or BINARY frames. Client frames
are unmasked by ``WsFrame.decode_one`` automatically.

A CLOSE frame is answered before it is returned (RFC 6455 sec
5.5.1): with the received status code, with an empty CLOSE when
the body is empty, or with 1002 when the body is invalid (a
1-byte body, a code that may not be sent, a reason that is not
UTF-8). The reply is skipped if :meth:`close` already sent a
CLOSE. The frame is still returned, so a handler can leave its
loop; later ``send_*`` calls raise.

A frame that violates the protocol fails the connection after a
best-effort CLOSE: an unmasked client frame with 1002 (RFC 6455
sec 5.1), a final TEXT frame whose payload is not valid UTF-8
with 1007 (sec 8.1), an oversized frame with 1009. ``recv``
raises in each case and later ``send_*`` calls raise too.

Returns: The next complete data frame (TEXT, BINARY, or CLOSE).

Raises: WsProtocolError: If the client sends an unmasked frame, or a final TEXT frame that is not valid UTF-8. NetworkError: On I/O failure.

#### `WsConnection.recv_message`

```mojo
def recv_message(mut self) raises -> WsMessage
```

Receive the next complete message, reassembled.

A fragmented message (a TEXT or BINARY frame without FIN, then
CONTINUATION frames up to one with FIN, RFC 6455 sec 5.4) comes
back whole; :meth:`recv` returns its pieces one by one. PING is
answered and PONG skipped, between fragments too. A text message
is checked for UTF-8 as a whole, so a code point may be split
across fragments. The reassembled payload is bounded by
``max_frame_size``.

Raises: NetworkError: If the client sent CLOSE (already answered by :meth:`recv`), or on I/O failure. WsProtocolError: After failing the connection with 1002 for a CONTINUATION with no message to continue or a new data frame inside a fragmented one, 1007 for a text message that is not UTF-8, 1009 for a message over ``max_frame_size``.

#### `WsConnection.close`

```mojo
def close(mut self, code: UInt16 = UInt16(1000), reason: String = "") raises
```

Send a CLOSE frame, once.

Starts the closing handshake (RFC 6455 sec 7.1.2) and does not
wait for the peer's CLOSE: call :meth:`recv` to read it. A second
call, or a call after :meth:`recv` has already answered the
client's CLOSE, sends nothing. After this every ``send_*`` raises.

Args:

- `code`: Close status code (see ``WsCloseCode.*``).
- `reason`: Optional UTF-8 reason phrase (≤123 bytes).

#### `WsConnection.peer_addr`

```mojo
def peer_addr(self) -> SocketAddr
```

Return the remote socket address.

Returns: The client's ``SocketAddr``.

### `WsServer`

```mojo
struct WsServer
```

A WebSocket server that upgrades incoming HTTP connections.

Accepts TCP connections, performs the HTTP Upgrade handshake, and
calls ``handler`` once per established WebSocket connection.

This type is ``Movable`` but not ``Copyable``.

Fields:
    _listener: The bound TCP listener.

Example:
```mojo
def handle(conn: WsConnection) raises:
    while True:
        var frame = conn.recv()
        if frame.opcode == WsOpcode.CLOSE:
            break  # recv() has already sent the CLOSE reply
        conn.send_text(frame.text_payload())

var srv = WsServer.bind(SocketAddr.localhost(9001))
srv.serve(handle)
```

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `WsServer.__init__`

```mojo
def __init__(out self, var listener: TcpListener)
```

#### `WsServer.__deinit__`

```mojo
def __deinit__(deinit self)
```

#### `WsServer.bind`

```mojo
def bind(addr: SocketAddr) raises -> Self
```

Bind a WebSocket server on ``addr``.

Args:

- `addr`: Local address to accept connections on.

Returns: A ``WsServer`` ready to call ``serve()``.

Raises: AddressInUse: If the port is already bound. NetworkError: For any other OS error.

#### `WsServer.serve`

```mojo
def serve(self, handler: def(mut WsConnection) raises thin -> None) raises
```

Accept WebSocket connections in a single-threaded loop.

For each accepted TCP connection:

```mojo
1. Read the HTTP Upgrade request.
2. Compute ``Sec-WebSocket-Accept``.
3. Send ``101 Switching Protocols``.
4. Call ``handler(conn)``.
```

Upgrade errors for individual connections are silently
skipped; only fatal accept-loop errors propagate.
For the multi-worker variant (``num_workers >= 2``), see
:meth:`serve_multicore`.

Args:

- `handler`: Callback invoked once per successfully upgraded connection.

Raises: NetworkError: On fatal accept-loop errors.

```mojo
def serve(mut self, handler: def(mut WsConnection) raises thin -> None, num_workers: Int) raises
```

Accept WebSocket connections across ``num_workers`` threads.

``num_workers <= 1`` falls back to the single-threaded
:meth:`serve` shape (one worker on the current thread).
``num_workers >= 2`` spawns one thread per worker, and every
worker accepts from the bound listener itself. Nothing is
closed or bound again, so the port never goes without a
listener while the workers start, and connections already
in the backlog are served. Each worker runs its own
single-threaded accept loop, so the per-connection upgrade
and handler dispatch is unchanged.

Workers are joined before this method returns, which today
means it never returns: the workers run forever (no drain
machinery yet). Use ``Ctrl-C`` / ``kill`` to terminate.

Args:

- `handler`: Per-connection callback (same shape as the single-threaded variant). Function pointers are trivially copyable so the same value is shared across all workers without per-worker context packaging.
- `num_workers`: Worker count. ``<= 0`` is coerced to 1. Values > 256 are rejected.

Raises: Error: On ``pthread_create`` failure when ``num_workers >= 2``.

```mojo
def serve[H: WsHandler](mut self, var handler: H) raises
```

Accept WebSocket connections, dispatching each to a stateful :trait:`WsHandler` struct.

The struct-handler variant of :meth:`serve`: one ``handler``
instance serves every connection via ``mut self``, so it can
accumulate state (connection count, a shared room registry, etc.)
across connections. Single-threaded; a multi-worker struct-handler
path (per-worker handler copies over the SO_REUSEPORT listeners)
is a follow-up -- the ``def`` handler already has ``num_workers``.

Upgrade errors for individual connections are logged and skipped;
only fatal accept-loop errors propagate.

#### `WsServer.local_addr`

```mojo
def local_addr(self) -> SocketAddr
```

Return the local address the server is bound to.

Returns: The bound ``SocketAddr``.

#### `WsServer.close`

```mojo
def close(mut self)
```

Stop accepting connections. Idempotent.

## Traits

### `WsHandler`

```mojo
trait WsHandler
```

Stateful per-connection WebSocket handler.

The struct-handler counterpart to the ``def(mut WsConnection)``
callback: because :meth:`on_connection` takes ``mut self``, the
handler can carry state (a shared registry, a counter, config) that
persists across the connections one server instance serves. Mount via
:meth:`WsServer.serve` (the ``[H: WsHandler]`` overload).

The trait is protocol-agnostic -- it drives a :class:`WsConnection`,
which is the h1 carrier today; the same handler will run over the
WS-over-h2 carrier once that bridge lands (carrier abstraction).

Inherits from: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `WsHandler.on_connection`

```mojo
def on_connection(mut self, mut conn: WsConnection) raises
```

Run one established WebSocket connection to completion.

## Functions

### `ws_offload_try_acquire`

```mojo
def ws_offload_try_acquire(limit: Int) -> Bool
```

Claim one of ``limit`` detached WebSocket threads, process-wide. False when all are held: the upgrade is then refused rather than letting clients spawn threads until the process hits its limit.

### `ws_offload_release`

```mojo
def ws_offload_release()
```

Give back a thread claimed by ``ws_offload_try_acquire``.

### `ws_offloaded`

```mojo
def ws_offloaded() -> Int
```

Detached WebSocket threads currently running.

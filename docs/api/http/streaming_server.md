# `dodo.http.streaming_server`

Typed streaming-handler surface.

A custom multiplexing / streaming front -- the shape a streaming
proxy needs -- used to drop to the raw reactor and smuggle every live
object (the reactor, the streams, the buffers) as an ``Int`` address,
rebuilding it with ``Pointer(unsafe_from_address=...)``, plus
hand-rolled ``alloc`` per-slot tables and a free list. This module
removes that: the framework owns the connection lifecycle and the
reactor; the handler is a typed struct whose fields are its shared
state and which receives a framework-owned ``StreamConn`` per event.

Pieces:

- ``StreamHandler`` -- the lifecycle trait (``on_open`` / ``on_upstream``
  / ``on_writable`` / ``on_close``). Every method takes ``mut self``
  (the typed shared state, one instance shared across all connections)
  and a ``mut`` ref to the framework-owned ``StreamConn``. No raw
  token, no address-as-``Int``.
- ``StreamConn`` -- the framework-owned per-connection handle. Owns the
  client ``TcpStream``, a per-connection ``Cancel`` cell, a stable
  per-connection id, the close flag, and a single owned outbound write
  buffer (``send`` queues; ``flush_blocking`` / ``drain_nonblocking``
  empty it). No per-slot ``alloc`` table, no free list.
- ``run_stream_connection`` -- a blocking single-connection driver that
  walks one connection through the lifecycle. The reactor-integrated
  multi-connection entry point (``HttpServer.serve_streaming``, in
  ``_stream_reactor_impl``) builds on the same trait and the same
  ``StreamConn``; this driver is the testable single-connection core
  and is itself useful for one-connection UDS sidecars.

Typed-state model
-----------------

Mojo has neither parameterized traits nor associated types,
so a single ``StreamHandler`` cannot carry a per-handler "state type
S" or "per-connection type U" in its method signatures and still let
the method *body* read those typed fields. The model that is both
typed and usable:

- **Shared state** is the handler struct's own fields. The framework
  holds one handler instance and calls it (via ``mut self``) for every
  connection and every event, so the fields are shared, mutable, and
  fully typed -- this is the shared ``ServeState`` (e.g. a persistent
  ``FrameMux``) reached as a typed ref rather than an ``Int`` address.
- **Per-connection state** for the common single-upstream relay is
  framework-owned: ``conn.attach_upstream(source)`` moves an
  ``UpstreamChunkSource`` into the ``StreamConn``, the framework pumps
  it (``relay_upstream``), and teardown closes it. The relay front then
  has *no* per-connection container at all and touches no file
  descriptor or byte ``Span``.
- **Richer per-connection state** (fan-in, several upstreams, custom
  bookkeeping) is still keyed by ``conn.id()`` in a typed container the
  handler declares once (e.g. ``Dict[Int, MyConnState]``). The
  framework assigns the id and signals ``on_open`` / ``on_close`` so
  the handler inserts / removes its entry -- no ``alloc``, no manual
  free list, lifecycle framework-owned.

Together this removes the need for a hand-rolled context of ``Int``
addresses and the ``alloc[...](max_slots)`` slot tables + free stack a
raw-reactor front would otherwise carry.

Shared middleware with the request/response path
-------------------------------------------------

``serve`` (request/response ``Handler``) and ``serve_streaming``
(event-lifecycle ``StreamHandler``) are distinct entry points, but they
share one middleware stack through ``StreamConn.send_response``: build a
single ``Handler`` stack (e.g. ``Logger[RequestId[Router]]``), run it in
``on_open`` via ``stack.serve(req)``, and frame the resulting
``Response`` onto the connection with ``conn.send_response(resp)`` before
streaming the tail with ``conn.send``. This lets one process put a REST
control plane and a token-streaming endpoint behind the same
logging / request-id / routing stack. The request/response counterpart
is ``HttpServer.serve_cancellable(WithCancel(stack^))`` -- see that
method's docstring.

## Aliases

### `DEFAULT_HI_WATERMARK`

```mojo
comptime DEFAULT_HI_WATERMARK = Int(262144)
```

Default high watermark for the per-connection relay buffer. When unwritten outbound bytes reach this, the reactor drops read interest on the attached upstream fd so a slow client cannot force unbounded token buffering. This is a fixed 256 KiB ceiling -- one in-flight relay window; tune per-connection with ``set_watermarks`` if a front needs a deeper or shallower pipe.

### `DEFAULT_LO_WATERMARK`

```mojo
comptime DEFAULT_LO_WATERMARK = Int(65536)
```

Default low watermark. Once the relay buffer drains back to this, the reactor re-arms upstream read interest. The hi/lo gap is the hysteresis band that stops interest from thrashing on every chunk.

## Structs

### `StreamConn`

```mojo
struct StreamConn
```

Framework-owned per-connection handle.

Owns the accepted client stream and a per-connection cancel cell,
carries a stable per-connection id (for the handler to key its own
typed per-connection state), and the close flag the handler trips
when it is done with the connection. The ``client`` stream is owned
here (sole owner) and closed when the handle is dropped -- the same
ownership rule the reactor's ``ConnHandle`` follows.

For the common streaming-proxy shape it also owns one optional
``UpstreamChunkSource``: ``attach_upstream(source)`` moves the source
in, ``relay_upstream`` drains it, and teardown closes it -- so a
relay front carries no per-connection table and never names a file
descriptor or a byte ``Span``.

Fields:

- `client` (`TcpStream`): The accepted client connection. Sole owner; closed on drop.
- `out_buf` (`List[UInt8]`): Pending outbound bytes. ``send`` appends here; the blocking driver flushes with ``flush_blocking`` and the reactor drains incrementally with ``drain_nonblocking`` on writable edges. This is the single owned write buffer (no per-slot ``alloc`` table).
- `out_pos` (`Int`): Bytes of ``out_buf`` already written to the socket. The unwritten tail is ``out_buf[out_pos:]``; ``out_pos == len(out_buf)`` means fully drained.

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `StreamConn.__init__`

```mojo
def __init__(out self, var client: TcpStream, id: Int = Int(0)) raises
```

Adopt ``client`` into a fresh per-connection handle.

#### `StreamConn.id`

```mojo
def id(self) -> Int
```

Stable per-connection id (key for handler-owned per-conn state).

#### `StreamConn.fd`

```mojo
def fd(self) -> c_int
```

Underlying client fd. Fast accessor; does not check state.

#### `StreamConn.cancel`

```mojo
def cancel(mut self) -> Cancel
```

Return a ``Cancel`` handle bound to this connection's cell.

#### `StreamConn.flip_cancel`

```mojo
def flip_cancel(mut self, reason: Int)
```

Flip the connection's cancel cell (framework-internal).

#### `StreamConn.request_close`

```mojo
def request_close(mut self)
```

Ask the framework to close this connection after the current lifecycle step returns.

#### `StreamConn.is_closing`

```mojo
def is_closing(self) -> Bool
```

True once ``request_close`` has been called.

#### `StreamConn.offload`

```mojo
def offload[H: Handler & Copyable](mut self, handler: H, var req: Request) raises
```

Run ``handler.serve(req)`` on the offload pool instead of in this callback, which would stall every connection on the worker.

For a request the stack marks ``blocking`` (it reaches an
``Offload``): the front calls ``conn.offload(stack, req)`` and
returns. The job runs on its own copy of ``stack``; this
connection gets no ``on_writable`` edges meanwhile, and its
``StreamHandler.on_offload_done`` receives the response. A full
queue or ``handler_timeout_ms`` answers 503, a handler error its
mapped status. The job's ``req.cancel`` flips to ``PEER_CLOSED``
when the client leaves and to ``TIMEOUT`` at the deadline.

A connection may have several requests out at once (pipelined
requests, or a fan-out); they run side by side and
``on_offload_done`` gets their answers in the order they were
offloaded.

#### `StreamConn.offload_pending`

```mojo
def offload_pending(self) -> Bool
```

True while an offloaded request has not been answered.

#### `StreamConn.attach_upstream`

```mojo
def attach_upstream(mut self, var src: UpstreamChunkSource)
```

Attach an upstream source and let the framework run it.

This is the recommended, low-ceremony path: hand the connection
the source and the framework takes over -- it reads the fd to
watch internally (no descriptors in front code), owns the
source for the connection's lifetime (closing it on teardown),
and ``relay_upstream`` drains it. The front never keeps a
per-connection table, never names a file descriptor, and never
remembers to close anything.

```mojo
def on_open(mut self, mut conn: StreamConn) raises:
    conn.attach_upstream(UpstreamChunkSource.connect(self.backend))
```

```mojo
def attach_upstream(mut self, fd: Int)
```

Low-level: ask the reactor to watch a raw ``fd`` (a front-owned upstream socket / pipe / eventfd) for readability.

Prefer the ``attach_upstream(UpstreamChunkSource)`` overload --
it hides the descriptor and the lifetime. Use this only for an
upstream that is not an ``UpstreamChunkSource`` (a bare pipe, an
eventfd). The front then owns ``fd``'s lifetime: it opened the
upstream and must close it (typically by holding the stream in
its own per-connection state and dropping it in ``on_close``).
The framework only adds/removes ``fd`` from the event loop.

#### `StreamConn.detach_upstream`

```mojo
def detach_upstream(mut self)
```

Stop watching the attached upstream and drop any framework-owned source. The reactor unregisters the fd on the next reconcile.

#### `StreamConn.has_upstream`

```mojo
def has_upstream(self) -> Bool
```

True if an upstream fd is currently attached.

#### `StreamConn.has_attached_source`

```mojo
def has_attached_source(self) -> Bool
```

True if a framework-owned ``UpstreamChunkSource`` is attached (via the source-taking ``attach_upstream``).

#### `StreamConn.upstream`

```mojo
def upstream(mut self) -> ref[self._upstream._value] UpstreamChunkSource
```

The framework-owned upstream source, for fronts that want to poll it directly instead of using ``relay_upstream``.

Only valid when ``has_attached_source()``; call after attaching
via ``attach_upstream(UpstreamChunkSource)``.

#### `StreamConn.relay_upstream`

```mojo
def relay_upstream(mut self) raises
```

Drain the attached source into the client with backpressure.

The standard ``on_upstream`` body, shipped once so every relay
front does not re-derive it: pull ready chunks and ``send`` them
until the client write buffer hits the high watermark (so a
single readable edge cannot overshoot the bound -- the reactor
re-arms upstream interest when the client drains), request close
on EOF, and stop on pending (the reactor parks on the fd, no
spin). No-op if no source is attached.

```mojo
def on_upstream(mut self, mut conn: StreamConn) raises:
    conn.relay_upstream()
```

#### `StreamConn.upstream_fd`

```mojo
def upstream_fd(self) -> Int
```

The attached upstream fd, or ``-1`` if none.

#### `StreamConn.reg_upstream_fd`

```mojo
def reg_upstream_fd(self) -> Int
```

Framework-internal: the upstream fd currently registered with the reactor, or ``-1``.

#### `StreamConn.set_watermarks`

```mojo
def set_watermarks(mut self, hi: Int, lo: Int)
```

Tune the relay-buffer hi/lo watermarks for this connection.

``hi`` is the occupancy at which the reactor stops reading the
attached upstream; ``lo`` (< ``hi``) is where it resumes. Values
are clamped to a sane order (``lo`` forced below ``hi``) so a
front cannot wedge the gate shut. Call in ``on_open`` to size the
relay pipe before any bytes flow.

#### `StreamConn.hi_watermark`

```mojo
def hi_watermark(self) -> Int
```

The high watermark in bytes.

#### `StreamConn.lo_watermark`

```mojo
def lo_watermark(self) -> Int
```

The low watermark in bytes.

#### `StreamConn.write_buffer_full`

```mojo
def write_buffer_full(self) -> Bool
```

True once unwritten outbound bytes reach the high watermark.

A relay front should check this in its ``on_upstream`` drain loop
and stop pulling from the upstream when it returns True, so a
single readable edge cannot overshoot the bound before the
reactor's interest gate takes effect on the next reconcile.

#### `StreamConn.upstream_paused`

```mojo
def upstream_paused(self) -> Bool
```

True while upstream reads are gated off by backpressure.

#### `StreamConn.pause_count`

```mojo
def pause_count(self) -> Int
```

How many times upstream reads were paused (hi crossings).

#### `StreamConn.resume_count`

```mojo
def resume_count(self) -> Int
```

How many times upstream reads were resumed (lo crossings).

#### `StreamConn.apply_backpressure`

```mojo
def apply_backpressure(mut self) -> Bool
```

Recompute the upstream read gate from buffer occupancy with hi/lo hysteresis; update the paused flag and crossing counters.

Returns whether the attached upstream fd should currently be read
(``True`` = arm ``INTEREST_READ``; ``False`` = pause). Pauses on
crossing the high watermark, resumes on falling to the low one;
between the two it holds the prior state -- the band that stops
interest thrash. Framework-internal: the reactor calls this on
each reconcile.

#### `StreamConn.reg_upstream_interest`

```mojo
def reg_upstream_interest(self) -> Int
```

Framework-internal: upstream interest bits currently registered (``-1`` unknown).

#### `StreamConn.set_nonblocking`

```mojo
def set_nonblocking(mut self, enabled: Bool) raises
```

Toggle non-blocking mode on the client socket (reactor path sets this once at accept).

#### `StreamConn.send`

```mojo
def send(mut self, data: Span[UInt8])
```

Queue ``data`` for delivery to the client.

Buffered, not written immediately: the blocking driver flushes
        with ``flush_blocking`` after each lifecycle step; the reactor
        drains with ``drain_nonblocking`` on writable edges. Same call
        site in both modes, so a front never blocks the event loop.

        Token-burst coalescing: each ``send`` is an O(n) memcpy into
        the single contiguous ``out_buf`` -- it issues no syscall. When a
        front emits K ready chunks in one reactor tick (call ``send`` K
        times), the subsequent drain flushes all K in ONE ``send(2)``,
        removing the per-token syscall round-trip that dominates long-
output nTPOT. The gather is a memcpy into ``out_buf``,
not a zero-copy ``writev`` over the K chunk buffers; swap in
``writev_buf`` over a chunk vector only if that memcpy shows up in
a profile -- the syscall count (the nTPOT win) is already 1.

```mojo
def send(mut self, data: List[UInt8])
```

Queue an owned byte list for the client (no ``Span`` wrap).

Convenience over ``send(Span[UInt8, _])`` for the common case
where a front holds a ``List[UInt8]`` -- e.g. a chunk just taken
from a ``ChunkPoll``. Same coalescing semantics.

```mojo
def send(mut self, text: StringSpan)
```

Queue a UTF-8 string for the client (no byte juggling).

Convenience for text protocols (SSE, NDJSON, a status line):
``conn.send("data: " + line + "\n")``. Appends the string's
UTF-8 bytes with the same coalescing as ``send(Span[UInt8, _])``.

#### `StreamConn.send_response`

```mojo
def send_response(mut self, resp: ResponseImpl, keep_alive: Bool = False)
```

Queue a ``Handler``-produced ``Response`` as this stream's response head (and fixed body, if any).

This is the shared-middleware bridge between ``serve`` and
``serve_streaming``: build one ``Handler`` middleware stack
(e.g. ``Logger[RequestId[Router]]``), call ``stack.serve(req)``
inside ``on_open``, then ``conn.send_response(resp)`` -- the
streaming front gets the exact logging / request-id / routing
behaviour the request/response path has, and keeps
``conn.send(...)`` for the streamed tail (SSE tokens, relayed
chunks). Without this a streaming front had to hand-roll its
status line and headers as a raw string, bypassing the
middleware stack entirely.

``Content-Length`` is emitted from the body length unless the
response already declares ``Transfer-Encoding`` or
``Content-Length`` (chunked / SSE fronts set ``Transfer-Encoding``
and stream the body via ``send``). ``Connection`` is always set
from ``keep_alive`` (any inbound ``Connection`` header is
dropped). This is HTTP/1.x framing only -- a streaming front
speaks h1 to the client; h2/h3 response heads have their own
framing on those paths.

The head framing is the shared, transport-agnostic
``frame_h1_stream_head_into`` adapter (see
``dodo/http/_server/write.mojo``), so an HTTPS front streaming
over ``TlsConnHandle`` frames its head identically -- the bytes
just ride ``SSL_write`` instead of ``send``.

#### `StreamConn.pending_out`

```mojo
def pending_out(self) -> Int
```

Unwritten outbound bytes (``len(out_buf) - out_pos``).

#### `StreamConn.has_pending_out`

```mojo
def has_pending_out(self) -> Bool
```

True if there are unwritten outbound bytes.

#### `StreamConn.write_syscalls`

```mojo
def write_syscalls(self) -> Int
```

Number of ``send(2)`` calls issued so far by the drain path. A burst of K chunks queued via ``send`` flushes in one syscall, so this advances by ~1 per drain regardless of K.

#### `StreamConn.reset_write_syscalls`

```mojo
def reset_write_syscalls(mut self)
```

Reset the write-syscall counter (for microbenches).

#### `StreamConn.flush_blocking`

```mojo
def flush_blocking(mut self) raises
```

Write all pending outbound bytes, blocking. Used by the single-connection driver.

#### `StreamConn.drain_nonblocking`

```mojo
def drain_nonblocking(mut self) raises -> Bool
```

Write as much of the pending buffer as the socket accepts without blocking.

Returns ``True`` once the buffer is fully flushed, ``False`` if
the socket would block (EAGAIN) with bytes still pending -- the
caller then keeps ``INTEREST_WRITE`` armed and retries on the
next writable edge. Raises on a real socket error (EPIPE /
ECONNRESET) so the reactor closes the connection.

#### `StreamConn.recv`

```mojo
def recv(mut self, mut buf: List[UInt8], max_bytes: Int) raises -> Int
```

Append up to ``max_bytes`` bytes read from the client onto ``buf``. Returns the count read (0 on peer EOF).

#### `StreamConn.enable_inbound`

```mojo
def enable_inbound(mut self, enabled: Bool = True)
```

Opt into front-owned inbound body consumption.

Call in ``on_open`` for a front that reads a (possibly large)
request body itself via ``read_body``. While enabled the reactor
no longer drains-and-discards client bytes for FIN detection, so
the body bytes reach the front intact; the front pulls them in
bounded chunks (peak memory independent of body size) and detects
end-of-body when ``read_body`` returns ``eof``.

#### `StreamConn.inbound_enabled`

```mojo
def inbound_enabled(self) -> Bool
```

True if the front owns inbound body consumption.

#### `StreamConn.read_body`

```mojo
def read_body(mut self, max_bytes: Int = Int(65536)) raises -> ChunkPoll
```

Read up to ``max_bytes`` of the inbound request body, without blocking.

The result is a ``ChunkPoll`` (so inbound and outbound share
one tri-state shape):

- ``ready(bytes)`` -- a body chunk is available now;
- ``eof()`` -- the client finished the body (clean FIN);
- ``pending(fd)`` -- nothing buffered yet; the reactor will fire
  again on the next readable edge (no busy-poll).

A front loops on this in ``on_writable`` (the streaming reactor
keeps the connection live), processing each chunk and dropping it,
so peak memory is one chunk regardless of total body size up to
whatever ceiling the front enforces.

## Traits

### `StreamHandler`

```mojo
trait StreamHandler
```

Lifecycle callbacks for one logical stream.

The framework owns the reactor and the connection; the handler is a
typed struct whose fields are its shared state. Every callback takes
``mut self`` (that typed shared state) and a ``mut`` ref to the
framework-owned ``StreamConn``. There is no raw token and no
address-as-``Int`` anywhere in the front.

Inherits from: `AnyType`, `Deinitable`, `Movable`

#### `StreamHandler.on_open`

```mojo
def on_open(mut self, mut conn: StreamConn) raises
```

Called once when the connection is accepted. Parse the request, attach an upstream, begin the response.

The one required method: a front that implements nothing here
has no way to start a response.

#### `StreamHandler.on_upstream`

```mojo
def on_upstream(mut self, mut conn: StreamConn) raises
```

Called when the attached upstream is readable. For a source attached via ``conn.attach_upstream(UpstreamChunkSource)`` the whole body is ``conn.relay_upstream()`` (drain ready chunks to the client with backpressure, close on EOF). A front that attached a raw fd reads it itself and calls ``conn.send``.

Defaults to doing nothing: a front with no upstream attached
never sees this edge.

#### `StreamHandler.on_writable`

```mojo
def on_writable(mut self, mut conn: StreamConn) raises
```

Called on a writable edge. Emit the next chunk of the response; call ``conn.request_close()`` when the stream is complete.

Defaults to doing nothing, which is right for a pure relay: the
upstream edge drives the body and the framework handles
backpressure.

#### `StreamHandler.on_close`

```mojo
def on_close(mut self, mut conn: StreamConn) raises
```

Called once as the connection is torn down (front FIN, deadline, or ``request_close``). Release per-connection resources.

Defaults to doing nothing: a front whose state is all owned by
the framework has nothing to release.

#### `StreamHandler.on_offload_done`

```mojo
def on_offload_done(mut self, mut conn: StreamConn, var resp: ResponseImpl) raises
```

Called with the response to a request the front passed to ``conn.offload``: the handler's, its mapped error status, or 503 (queue full, ``handler_timeout_ms``). With several requests out it is called once per request, in the order they were offloaded.

Defaults to sending it and closing the connection, which suits
one request per connection; closing cancels any still out.

## Functions

### `run_stream_connection`

```mojo
def run_stream_connection[H: StreamHandler](mut handler: H, var client: TcpStream, id: Int = Int(0)) raises
```

Drive one accepted ``client`` connection through the handler lifecycle, blocking.

Calls ``on_open`` once, then ``on_writable`` repeatedly until the
front requests close (so a streaming front emits chunk-by-chunk),
then ``on_close`` exactly once. ``on_upstream`` is only driven by the
reactor path (``serve_streaming``); this blocking driver is the
single-connection core used by tests and one-shot sidecars.

The connection is closed when ``conn`` drops at function exit.

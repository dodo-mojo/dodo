"""``Offload`` over HTTP/1.1 and HTTP/2, cleartext and TLS, on the unified
loop.

Each test forks a server whose offloaded handler (``_Gate``) writes a
``started-<name>`` file, then waits until the test writes
``release-<name>`` or its request is cancelled, in which case it writes the
cancel reason to ``cancel-<name>``. The test reads and writes those files
to know where the handler is, so no outcome depends on a sleep: sleeps
only bound how long a test waits for something that must happen.
"""

from std.ffi import external_call
from std.os import remove
from std.collections import Dict
from std.os.path import exists
from std.sys.info import CompilationTarget
from std.testing import assert_equal, assert_false, assert_true, TestSuite

from dodo.http import (
    Cancel,
    CancelHandler,
    Handler,
    HttpServer,
    Logger,
    Offload,
    Request,
    Response,
    Router,
    StreamConn,
    StreamHandler,
    WithCancel,
    ok,
)
from dodo.http.streaming_server import run_stream_connection
from dodo.http.cancel import CancelReason
from dodo.http.server import ServerConfig
from dodo.http._server_reactor_impl import (
    run_reactor_loop_shared,
    run_uring_bufring_reactor_loop,
)
from dodo.http2 import (
    Frame,
    FrameFlags,
    FrameType,
    H2_PREFACE,
    HpackDecoder,
    HpackEncoder,
    HpackHeader,
    encode_frame,
    parse_frame,
)
from dodo.net import SocketAddr
from dodo.runtime import Pool
from dodo.runtime.uring_reactor import use_uring_backend
from dodo.runtime._thread import ThreadHandle, _OpaquePtr, _null_ptr
from dodo.runtime.scheduler_stats import store_stop_flag
from dodo.tcp import TcpListener, TcpStream
from dodo.tls import TlsConfig, TlsStream
from dodo.utils import SIGKILL, exit, fork, kill, usleep, waitpid


# ── Files the test and the forked server share ─────────────────────────────


def _prefix(test: String) -> String:
    var pid = Int(external_call["getpid", Int32]())
    return "/tmp/dodo-offload-" + String(pid) + "-" + test + "-"


def _touch(path: String, content: String = "") raises:
    """Create ``path`` holding ``content``. Written aside and renamed, so
    a reader that sees the file sees all of it."""
    var tmp = path + ".tmp"
    var dst = path
    with open(tmp, "w") as f:
        f.write(content)
    _ = external_call["rename", Int32](
        tmp.as_c_string_slice().unsafe_ptr(),
        dst.as_c_string_slice().unsafe_ptr(),
    )


def _read_file(path: String) raises -> String:
    with open(path, "r") as f:
        return f.read()


def _wait_file(path: String, timeout_ms: Int = 10_000) raises:
    var waited = 0
    while not exists(path):
        if waited >= timeout_ms:
            raise Error("timed out waiting for " + path)
        usleep(1000)
        waited += 1


def _cleanup(prefix: String, names: List[String]):
    for i in range(len(names)):
        for kind in ["started-", "release-", "cancel-", "finished-"]:
            try:
                remove(prefix + kind + names[i])
            except:
                pass
    for extra in ["stop", "exited", "quit", "bye"]:
        try:
            remove(prefix + extra)
        except:
            pass


# ── Server side ────────────────────────────────────────────────────────────


def _gate(
    prefix: String, name: String, cancel: Cancel, stubborn: Bool
) raises -> Response:
    """Announce ``name``, then wait for the test to release it. Unless
    ``stubborn``, stop early when ``cancel`` flips and record the
    reason."""
    _touch(prefix + "started-" + name)
    var waited = 0
    while not exists(prefix + "release-" + name):
        if not stubborn and cancel.cancelled():
            _touch(prefix + "cancel-" + name, String(cancel.reason()))
            return ok("cancelled " + name)
        if waited > 20_000:
            return ok("gave up " + name)
        usleep(1000)
        waited += 1
    _touch(prefix + "finished-" + name)
    return ok("done " + name)


struct _Gate(Copyable, Handler):
    """Waits at the gate, watching ``req.cancel``."""

    var prefix: String
    var stubborn: Bool

    def __init__(out self, prefix: String, stubborn: Bool = False):
        self.prefix = prefix
        self.stubborn = stubborn

    def serve(self, req: Request) raises -> Response:
        return _gate(self.prefix, req.param("name"), req.cancel, self.stubborn)


struct _CancelGate(CancelHandler, Copyable):
    """A ``CancelHandler`` that offloads ``/cancel/<name>`` itself and
    waits at the gate watching the ``cancel`` argument. Every other path
    goes to ``_router`` through ``WithCancel``."""

    var prefix: String
    var rest: WithCancel[Router]

    def __init__(out self, prefix: String) raises:
        self.prefix = prefix
        self.rest = WithCancel(_router(prefix))

    def serve(self, req: Request, cancel: Cancel) raises -> Response:
        if req.url.startswith("/cancel/"):
            var name = String(req.url[byte=8:])
            return _gate(self.prefix, name, cancel, False)
        return self.rest.serve(req, cancel)

    def may_block(self) -> Bool:
        return True

    def blocking(self, req: Request) raises -> Bool:
        if req.url.startswith("/cancel/"):
            return True
        return self.rest.blocking(req)


struct _Raiser(Copyable, Handler):
    def __init__(out self):
        pass

    def serve(self, req: Request) raises -> Response:
        raise Error("offloaded handler failed")


def _fast(req: Request) raises -> Response:
    return ok("fast")


def _router(prefix: String) raises -> Router:
    var r = Router()
    r.get("/fast", _fast)
    r.get("/slow/:name", Offload(_Gate(prefix)))
    r.get("/stubborn/:name", Offload(_Gate(prefix, stubborn=True)))
    r.get("/raise", Offload(_Raiser()))
    var api = Router()
    api.get("/slow/:name", Logger(Offload(_Gate(prefix))))
    r.mount("/api", api^)
    return r^


struct _MoveOnly(Handler):
    """A top-level handler that is not ``Copyable``; ``serve`` shares it
    with the pool through ``SharedHandler``."""

    var inner: Router

    def __init__(out self, var inner: Router):
        self.inner = inner^

    def serve(self, req: Request) raises -> Response:
        return self.inner.serve(req)

    def may_block(self) -> Bool:
        return self.inner.may_block()

    def blocking(self, req: Request) raises -> Bool:
        return self.inner.blocking(req)


struct _MoveOnlyCancel(CancelHandler):
    """``_CancelGate`` behind a ``CancelHandler`` that is not
    ``Copyable``."""

    var inner: _CancelGate

    def __init__(out self, var inner: _CancelGate):
        self.inner = inner^

    def serve(self, req: Request, cancel: Cancel) raises -> Response:
        return self.inner.serve(req, cancel)

    def may_block(self) -> Bool:
        return self.inner.may_block()

    def blocking(self, req: Request) raises -> Bool:
        return self.inner.blocking(req)


struct _StreamFront(Copyable, StreamHandler):
    """A streaming front over ``_router``: reads the request line, then
    hands a request the router marks ``blocking`` to ``conn.offload``
    and answers any other inline. ``on_offload_done`` sends the
    response and closes.

    ``/pair/<a>/<b>`` offloads ``/slow/<a>`` and ``/slow/<b>`` on the
    one connection and answers with both bodies, joined by a comma in
    the order ``on_offload_done`` saw them."""

    var stack: Router
    var pairs: Dict[Int, List[String]]
    """Bodies collected so far, by connection id, for ``/pair``."""

    def __init__(out self, prefix: String) raises:
        self.stack = _router(prefix)
        self.pairs = Dict[Int, List[String]]()

    def on_open(mut self, mut conn: StreamConn) raises:
        var target = _read_target(conn)
        if target.startswith("/pair/"):
            var names = target.split("/")
            conn.offload(self.stack, Request("GET", "/slow/" + names[2]))
            conn.offload(self.stack, Request("GET", "/slow/" + names[3]))
            self.pairs[conn.id()] = List[String]()
            return
        var req = Request("GET", target)
        if self.stack.blocking(req):
            conn.offload(self.stack, req^)
            return
        conn.send_response(self.stack.serve(req))
        conn.request_close()

    def on_offload_done(
        mut self, mut conn: StreamConn, var resp: Response
    ) raises:
        if conn.id() not in self.pairs:
            conn.send_response(resp)
            conn.request_close()
            return
        var part = String(resp.status)
        if resp.status == 200:
            part = resp.text()
        self.pairs[conn.id()].append(part)
        if len(self.pairs[conn.id()]) < 2:
            return
        var parts = self.pairs.pop(conn.id())
        conn.send_response(ok(parts[0] + "," + parts[1]))
        conn.request_close()


def _read_target(mut conn: StreamConn) raises -> String:
    """The request target, read blocking up to the end of the head."""
    conn.set_nonblocking(False)
    var buf = List[UInt8]()
    while True:
        if conn.recv(buf, 4096) == 0:
            break
        if "\r\n\r\n" in String(unsafe_from_utf8=Span[UInt8, _](buf)):
            break
    conn.set_nonblocking(True)
    var head = String(unsafe_from_utf8=Span[UInt8, _](buf))
    var line = head.split("\r\n")[0]
    return String(line.split(" ")[1])


struct _StopWatch(Movable):
    var flag_addr: Int
    var path: String

    def __init__(out self, flag_addr: Int, path: String):
        self.flag_addr = flag_addr
        self.path = path


def _stop_watch(arg: _OpaquePtr) -> _OpaquePtr:
    """Stop the server once the test writes its ``stop`` file."""
    var w = Pool[_StopWatch].get_ptr(Int(arg))
    while not exists(w[].path):
        usleep(1000)
    store_stop_flag(w[].flag_addr, True)
    return _null_ptr()


comptime _SERVER_CRT = "tests/certs/server.crt"
comptime _SERVER_KEY = "tests/certs/server.key"
comptime _CA_CRT = "tests/certs/ca.crt"


def _bind(var config: ServerConfig, tls: Bool) raises -> HttpServer:
    """A loopback server; with ``tls``, HTTPS offering h2 and http/1.1."""
    if not tls:
        return HttpServer.bind(SocketAddr.localhost(0), config^)
    var alpn = List[String]()
    alpn.append("h2")
    alpn.append("http/1.1")
    return HttpServer.bind_tls(
        SocketAddr.localhost(0), _SERVER_CRT, _SERVER_KEY, alpn^, config^
    )


def _spawn_server(
    prefix: String,
    var config: ServerConfig,
    tls: Bool = False,
    workers: Int = 1,
    loop: String = "unified",
) raises -> Tuple[Int, UInt16]:
    """Fork a server running ``_router`` on ``loop``: ``unified``
    (``serve``), ``moveonly`` (``serve`` with ``_MoveOnly`` around it),
    ``cancel`` (``serve_cancellable`` with ``_CancelGate`` in front),
    ``cancel-moveonly`` (that inside ``_MoveOnlyCancel``), ``stream``
    (``serve_streaming`` with ``_StreamFront``), ``h1`` (the
    HTTP/1.1-only loop) or ``bufring`` (the io_uring buffer ring).
    Returns (pid, port). With one worker, writing
    ``<prefix>stop`` stops it gracefully and it writes ``<prefix>exited``
    once ``serve`` returns. The process then stays up until the test
    writes ``<prefix>quit``, and writes ``<prefix>bye`` on its way out,
    so a test can see that the pool finished cleanly after ``serve``."""
    if loop == "bufring":
        # That loop arms no other timers and no connection cap.
        config.idle_timeout_ms = 0
        config.write_timeout_ms = 0
        config.read_body_timeout_ms = 0
        config.request_timeout_ms = 0
        config.header_timeout_ms = 0
        config.min_body_rate = 0
        config.max_connections = -1
    var srv = _bind(config^, tls)
    var port = UInt16(srv.local_addr().port)
    var pid = fork()
    if pid == 0:
        try:
            if workers > 1:
                srv.serve(_router(prefix), num_workers=workers)
                exit()
            var watch = Pool[_StopWatch].alloc_move(
                _StopWatch(
                    Int(Pointer[Bool, _](to=srv._stopping)), prefix + "stop"
                )
            )
            var t = ThreadHandle.spawn_os[_stop_watch](
                _OpaquePtr(unsafe_from_address=watch)
            )
            t.detach()
            if loop == "cancel":
                srv.serve_cancellable(_CancelGate(prefix))
            elif loop == "cancel-moveonly":
                srv.serve_cancellable(_MoveOnlyCancel(_CancelGate(prefix)))
            elif loop == "stream":
                srv.serve_streaming(_StreamFront(prefix))
            elif loop == "h1":
                srv._listener._socket.set_nonblocking(True)
                var h = _router(prefix)
                run_reactor_loop_shared(
                    Int(srv._listener._socket.fd),
                    srv.config,
                    h,
                    srv._stopping,
                )
            elif loop == "bufring":
                comptime if CompilationTarget.is_linux():
                    var h = _router(prefix)
                    run_uring_bufring_reactor_loop(
                        srv._listener, srv.config, h, srv._stopping
                    )
            elif loop == "moveonly":
                srv.serve(_MoveOnly(_router(prefix)))
            else:
                srv.serve(_router(prefix))
            _touch(prefix + "exited")
            _wait_file(prefix + "quit", 20_000)
            _touch(prefix + "bye")
        except:
            pass
        exit()
    return (pid, port)


def _stop_server(pid: Int):
    _ = kill(pid, SIGKILL)
    waitpid(pid)


# ── Client side ────────────────────────────────────────────────────────────


struct _Stream(Movable):
    """A client connection, cleartext or TLS."""

    var tcp: Optional[TcpStream]
    var tls: Optional[TlsStream]

    def __init__(out self, port: UInt16, tls: Bool, alpn: String) raises:
        self.tcp = None
        self.tls = None
        if tls:
            var cfg = TlsConfig(ca_bundle=_CA_CRT)
            cfg.alpn = List[String]()
            cfg.alpn.append(alpn)
            var s = TlsStream.connect("localhost", port, cfg)
            s.set_recv_timeout(10_000)
            self.tls = s^
        else:
            var s = TcpStream.connect(SocketAddr.localhost(port))
            s.set_recv_timeout(10_000)
            self.tcp = s^

    def write_all(mut self, data: Span[UInt8, _]) raises:
        if self.tls:
            self.tls.value().write_all(data)
        else:
            self.tcp.value().write_all(data)

    def read(mut self, mut buf: List[UInt8]) raises -> Int:
        if self.tls:
            return self.tls.value().read(buf.unsafe_ptr(), len(buf))
        return self.tcp.value().read(buf.unsafe_ptr(), len(buf))

    def close(mut self):
        if self.tls:
            self.tls.value().close()
        else:
            self.tcp.value().close()


struct _Conn(Movable):
    """A client connection that keeps bytes read past one response for
    the next."""

    var s: _Stream
    var pending: String

    def __init__(out self, port: UInt16, tls: Bool = False) raises:
        self.s = _Stream(port, tls, "http/1.1")
        self.pending = String("")

    def send(mut self, raw: String) raises:
        self.s.write_all(raw.as_bytes())

    def get(mut self, path: String) raises:
        self.send("GET " + path + " HTTP/1.1\r\nHost: x\r\n\r\n")

    def _response_len(self) raises -> Int:
        """Length of the first whole response in ``pending``, or -1."""
        var head_end = self.pending.find("\r\n\r\n")
        if head_end < 0:
            return -1
        var head = String(self.pending[byte=:head_end]).lower()
        var body = 0
        var at = head.find("content-length:")
        if at >= 0:
            var line_end = head.find("\r\n", at)
            if line_end < 0:
                line_end = head_end
            body = Int(String(head[byte = at + 15 : line_end]).strip())
        if self.pending.byte_length() < head_end + 4 + body:
            return -1
        return head_end + 4 + body

    def response(mut self) raises -> String:
        """The next whole response, or what arrived before the server
        closed."""
        var buf = List[UInt8](length=4096, fill=0)
        while self._response_len() < 0:
            var n = self.s.read(buf)
            if n <= 0:
                var partial = self.pending
                self.pending = String("")
                return partial
            self.pending += String(from_utf8_lossy=Span[UInt8, _](buf)[:n])
        var n = self._response_len()
        var out = String(self.pending[byte=:n])
        var rest = String(self.pending[byte=n:])
        self.pending = rest^
        return out

    def closed_by_server(mut self) -> Bool:
        """True once the server has closed the connection."""
        var buf = List[UInt8](length=64, fill=0)
        try:
            return self.s.read(buf) <= 0
        except:
            return True

    def close(mut self):
        self.s.close()


# ── HTTP/2 client side ─────────────────────────────────────────────────────


struct _H2(Movable):
    """An HTTP/2 client (prior-knowledge h2c, or h2 over TLS) that sends
    raw frames and records what comes back per stream."""

    var s: _Stream
    var scheme: String
    var enc: HpackEncoder
    var dec: HpackDecoder
    var inbuf: List[UInt8]
    var status: Dict[Int, String]
    var retry_after: Dict[Int, String]
    var body: Dict[Int, String]
    var ended: Dict[Int, Bool]
    var ping_acks: Int
    var goaway: Bool
    var closed: Bool

    def __init__(out self, port: UInt16, tls: Bool = False) raises:
        self.s = _Stream(port, tls, "h2")
        self.scheme = "https" if tls else "http"
        self.enc = HpackEncoder()
        self.dec = HpackDecoder()
        self.inbuf = List[UInt8]()
        self.status = Dict[Int, String]()
        self.retry_after = Dict[Int, String]()
        self.body = Dict[Int, String]()
        self.ended = Dict[Int, Bool]()
        self.ping_acks = 0
        self.goaway = False
        self.closed = False
        var hello = List[UInt8](String(H2_PREFACE).as_bytes())
        var settings = Frame()
        settings.header.type = FrameType.SETTINGS()
        hello.extend(Span[UInt8, _](encode_frame(settings)))
        self.s.write_all(Span[UInt8, _](hello))

    def headers(mut self, sid: Int, path: String) raises -> List[UInt8]:
        """A GET on stream ``sid`` as wire bytes."""
        var h = List[HpackHeader]()
        h.append(HpackHeader(":method", "GET"))
        h.append(HpackHeader(":scheme", self.scheme))
        h.append(HpackHeader(":path", path))
        h.append(HpackHeader(":authority", "x"))
        var f = Frame()
        f.header.type = FrameType.HEADERS()
        f.header.stream_id = sid
        f.header.flags = FrameFlags(
            FrameFlags.END_HEADERS() | FrameFlags.END_STREAM()
        )
        f.payload = self.enc.encode(Span[HpackHeader, _](h))
        return encode_frame(f)

    def get(mut self, sid: Int, path: String) raises:
        self.s.write_all(Span[UInt8, _](self.headers(sid, path)))

    def send(mut self, bytes: List[UInt8]) raises:
        self.s.write_all(Span[UInt8, _](bytes))

    def rst(mut self, sid: Int) raises:
        var f = Frame()
        f.header.type = FrameType.RST_STREAM()
        f.header.stream_id = sid
        f.payload = [UInt8(0), UInt8(0), UInt8(0), UInt8(8)]
        self.send(encode_frame(f))

    def ping(mut self) raises:
        var f = Frame()
        f.header.type = FrameType.PING()
        f.payload = List[UInt8](length=8, fill=7)
        self.send(encode_frame(f))

    def pump(mut self) raises:
        """Read once and handle every whole frame received."""
        var buf = List[UInt8](length=16384, fill=0)
        var n = 0
        try:
            n = self.s.read(buf)
        except:
            n = 0
        if n <= 0:
            self.closed = True
            return
        self.inbuf.extend(Span[UInt8, _](buf)[:n])
        while True:
            var parsed = parse_frame(Span[UInt8, _](self.inbuf))
            if not parsed:
                return
            var f = parsed.take()
            var used = 9 + f.header.length
            var rest = List[UInt8](Span[UInt8, _](self.inbuf)[used:])
            self.inbuf = rest^
            self._on_frame(f^)

    def _on_frame(mut self, var f: Frame) raises:
        var t = f.header.type.value
        var sid = f.header.stream_id
        if t == FrameType.SETTINGS().value:
            if not f.header.flags.has(FrameFlags.ACK()):
                var ack = Frame()
                ack.header.type = FrameType.SETTINGS()
                ack.header.flags = FrameFlags(FrameFlags.ACK())
                self.send(encode_frame(ack))
        elif t == FrameType.PING().value:
            if f.header.flags.has(FrameFlags.ACK()):
                self.ping_acks += 1
        elif t == FrameType.GOAWAY().value:
            self.goaway = True
        elif t == FrameType.HEADERS().value:
            var fields = self.dec.decode(Span[UInt8, _](f.payload))
            for i in range(len(fields)):
                if fields[i].name == ":status":
                    self.status[sid] = fields[i].value
                elif fields[i].name == "retry-after":
                    self.retry_after[sid] = fields[i].value
            if f.header.flags.has(FrameFlags.END_STREAM()):
                self.ended[sid] = True
        elif t == FrameType.DATA().value:
            var text = String(from_utf8_lossy=Span[UInt8, _](f.payload))
            if sid in self.body:
                self.body[sid] = self.body[sid] + text
            else:
                self.body[sid] = text
            if f.header.flags.has(FrameFlags.END_STREAM()):
                self.ended[sid] = True

    def wait_ended(mut self, sid: Int) raises:
        while sid not in self.ended:
            if self.closed:
                raise Error("connection closed before stream " + String(sid))
            self.pump()

    def close(mut self):
        self.s.close()


def _loop_tag(loop: String) -> String:
    if loop == "unified":
        return ""
    return "-" + loop


def _have_bufring() -> Bool:
    """Whether this host can run the io_uring buffer-ring loop."""
    comptime if not CompilationTarget.is_linux():
        return False
    return use_uring_backend()


def _tag(tls: Bool) -> String:
    if tls:
        return "-tls"
    return ""


# ── Routing: blocking() reaches an Offload through wrappers ────────────────


def test_router_reports_offloaded_routes() raises:
    var r = _router("/nonexistent-")
    assert_true(r.may_block())
    assert_false(r.blocking(Request(method="GET", url="/fast")))
    assert_true(r.blocking(Request(method="GET", url="/slow/a")))
    assert_false(r.blocking(Request(method="POST", url="/slow/a")))
    assert_true(r.blocking(Request(method="GET", url="/api/slow/b?x=1")))
    assert_false(r.blocking(Request(method="GET", url="/missing")))


def test_router_without_offload_never_blocks() raises:
    var r = Router()
    r.get("/fast", _fast)
    assert_false(r.may_block())
    assert_false(r.blocking(Request(method="GET", url="/fast")))


# ── HTTP/1.1 ───────────────────────────────────────────────────────────────


def test_bufring_keeps_serving_a_handler_that_may_block() raises:
    """The io_uring buffer ring has the pool, so opting into it with an
    ``Offload`` route keeps it."""
    if not _have_bufring():
        return
    var config = ServerConfig(
        idle_timeout_ms=0,
        write_timeout_ms=0,
        read_body_timeout_ms=0,
        request_timeout_ms=0,
        header_timeout_ms=0,
        min_body_rate=0,
        max_connections=-1,
        use_bufring=True,
    )
    var srv = HttpServer.bind(SocketAddr.localhost(0), config^)
    srv._resolve_bufring()
    assert_true(srv.config.use_bufring)


def _h1_offloaded_response_and_keep_alive(
    tls: Bool, loop: String = "unified"
) raises:
    """The offloaded response arrives, through a mounted router and
    middleware, and the connection serves the next request."""
    var prefix = _prefix("h1ok" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("a")
    var srv = _spawn_server(prefix, ServerConfig(), tls, loop=loop)
    var got = String("")
    var next_resp = String("")
    try:
        var s = _Conn(srv[1], tls)
        s.get("/api/slow/a")
        _wait_file(prefix + "started-a")
        _touch(prefix + "release-a")
        got = s.response()
        s.get("/fast")
        next_resp = s.response()
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(got.startswith("HTTP/1.1 200"), got)
    assert_true(got.endswith("done a"), got)
    assert_true(next_resp.endswith("fast"), next_resp)


def test_h1_offloaded_response_and_keep_alive() raises:
    _h1_offloaded_response_and_keep_alive(False)


def test_h1_offloaded_response_and_keep_alive_tls() raises:
    _h1_offloaded_response_and_keep_alive(True)


def test_h1_offloaded_response_and_keep_alive_cancellable() raises:
    _h1_offloaded_response_and_keep_alive(False, loop="cancel")


def test_h1_offloaded_response_and_keep_alive_h1_loop() raises:
    _h1_offloaded_response_and_keep_alive(False, loop="h1")


def test_h1_offloaded_response_and_keep_alive_bufring() raises:
    if not _have_bufring():
        return
    _h1_offloaded_response_and_keep_alive(False, loop="bufring")


def _h1_slow_offload_does_not_stall_other_connections(
    tls: Bool, loop: String = "unified"
) raises:
    """With one worker, a second connection is served while the first
    connection's handler is provably still running (it waits for a file
    the test writes only afterwards)."""
    var prefix = _prefix("h1stall" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("b")
    var srv = _spawn_server(prefix, ServerConfig(), tls, loop=loop)
    var fast = String("")
    var slow = String("")
    var still_running = False
    try:
        var a = _Conn(srv[1], tls)
        a.get("/slow/b")
        _wait_file(prefix + "started-b")
        var other = _Conn(srv[1], tls)
        other.get("/fast")
        fast = other.response()
        still_running = not exists(prefix + "release-b")
        _touch(prefix + "release-b")
        slow = a.response()
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(fast.endswith("fast"), fast)
    assert_true(still_running)
    assert_true(slow.endswith("done b"), slow)


def test_h1_slow_offload_does_not_stall_other_connections() raises:
    _h1_slow_offload_does_not_stall_other_connections(False)


def test_h1_slow_offload_does_not_stall_other_connections_tls() raises:
    _h1_slow_offload_does_not_stall_other_connections(True)


def test_h1_slow_offload_does_not_stall_other_connections_cancellable() raises:
    _h1_slow_offload_does_not_stall_other_connections(False, loop="cancel")


def test_h1_slow_offload_does_not_stall_other_connections_h1_loop() raises:
    _h1_slow_offload_does_not_stall_other_connections(False, loop="h1")


def test_h1_slow_offload_does_not_stall_other_connections_stream() raises:
    _h1_slow_offload_does_not_stall_other_connections(False, loop="stream")


def test_h1_slow_offload_does_not_stall_other_connections_bufring() raises:
    if not _have_bufring():
        return
    _h1_slow_offload_does_not_stall_other_connections(False, loop="bufring")


def _h1_pipelined_requests_answer_in_order(
    tls: Bool, loop: String = "unified"
) raises:
    """An inline request, an offloaded one and another inline one sent in
    one write are answered in order."""
    var prefix = _prefix("h1pipe" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("p")
    var srv = _spawn_server(prefix, ServerConfig(), tls, loop=loop)
    var first = String("")
    var second = String("")
    var third = String("")
    try:
        var s = _Conn(srv[1], tls)
        s.send(
            String(
                "GET /fast HTTP/1.1\r\nHost: x\r\n\r\n"
                "GET /slow/p HTTP/1.1\r\nHost: x\r\n\r\n"
                "GET /fast HTTP/1.1\r\nHost: x\r\n\r\n"
            )
        )
        first = s.response()
        _wait_file(prefix + "started-p")
        _touch(prefix + "release-p")
        second = s.response()
        third = s.response()
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(first.endswith("fast"), first)
    assert_true(second.endswith("done p"), second)
    assert_true(third.endswith("fast"), third)


def test_h1_pipelined_requests_answer_in_order() raises:
    _h1_pipelined_requests_answer_in_order(False)


def test_h1_pipelined_requests_answer_in_order_tls() raises:
    _h1_pipelined_requests_answer_in_order(True)


def test_h1_pipelined_requests_answer_in_order_cancellable() raises:
    _h1_pipelined_requests_answer_in_order(False, loop="cancel")


def test_h1_pipelined_requests_answer_in_order_h1_loop() raises:
    _h1_pipelined_requests_answer_in_order(False, loop="h1")


def test_h1_pipelined_requests_answer_in_order_bufring() raises:
    if not _have_bufring():
        return
    _h1_pipelined_requests_answer_in_order(False, loop="bufring")


def _h1_timeout_answers_503_and_cancels(
    tls: Bool, loop: String = "unified"
) raises:
    var prefix = _prefix("h1timeout" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("c")
    var srv = _spawn_server(
        prefix,
        ServerConfig(handler_timeout_ms=200),
        tls,
        loop=loop,
    )
    var got = String("")
    var reason = String("")
    try:
        var s = _Conn(srv[1], tls)
        s.get("/slow/c")
        got = s.response()
        _wait_file(prefix + "cancel-c")
        reason = _read_file(prefix + "cancel-c")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(got.startswith("HTTP/1.1 503"), got)
    assert_true("Retry-After: 1" in got, got)
    assert_equal(reason, String(CancelReason.TIMEOUT))


def test_h1_timeout_answers_503_and_cancels() raises:
    _h1_timeout_answers_503_and_cancels(False)


def test_h1_timeout_answers_503_and_cancels_tls() raises:
    _h1_timeout_answers_503_and_cancels(True)


def test_h1_timeout_answers_503_and_cancels_cancellable() raises:
    _h1_timeout_answers_503_and_cancels(False, loop="cancel")


def test_h1_timeout_answers_503_and_cancels_h1_loop() raises:
    _h1_timeout_answers_503_and_cancels(False, loop="h1")


def test_h1_timeout_answers_503_and_cancels_stream() raises:
    _h1_timeout_answers_503_and_cancels(False, loop="stream")


def test_h1_timeout_answers_503_and_cancels_bufring() raises:
    if not _have_bufring():
        return
    _h1_timeout_answers_503_and_cancels(False, loop="bufring")


def _h1_full_queue_answers_503_at_once(
    tls: Bool, loop: String = "unified"
) raises:
    """One pool thread and room for one queued request: the third
    offloaded request is refused at once, the other two are served."""
    var prefix = _prefix("h1full" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("d1")
    names.append("d2")
    names.append("d3")
    var srv = _spawn_server(
        prefix,
        ServerConfig(offload_threads=1, offload_queue_depth=1),
        tls,
        loop=loop,
    )
    var refused = String("")
    var r1 = String("")
    var r2 = String("")
    var d3_ran = True
    try:
        var c1 = _Conn(srv[1], tls)
        c1.get("/slow/d1")
        _wait_file(prefix + "started-d1")
        # The inline answer to /fast proves the worker has read this
        # connection, and so queued /slow/d2 behind it.
        var c2 = _Conn(srv[1], tls)
        c2.send(
            String(
                "GET /fast HTTP/1.1\r\nHost: x\r\n\r\n"
                "GET /slow/d2 HTTP/1.1\r\nHost: x\r\n\r\n"
            )
        )
        _ = c2.response()
        var c3 = _Conn(srv[1], tls)
        c3.get("/slow/d3")
        refused = c3.response()
        _touch(prefix + "release-d1")
        _touch(prefix + "release-d2")
        r1 = c1.response()
        r2 = c2.response()
        d3_ran = exists(prefix + "started-d3")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(refused.startswith("HTTP/1.1 503"), refused)
    assert_true("Retry-After: 1" in refused, refused)
    assert_true(r1.endswith("done d1"), r1)
    assert_true(r2.endswith("done d2"), r2)
    assert_false(d3_ran, "a refused request must not run")


def test_h1_full_queue_answers_503_at_once() raises:
    _h1_full_queue_answers_503_at_once(False)


def test_h1_full_queue_answers_503_at_once_tls() raises:
    _h1_full_queue_answers_503_at_once(True)


def test_h1_full_queue_answers_503_at_once_cancellable() raises:
    _h1_full_queue_answers_503_at_once(False, loop="cancel")


def test_h1_full_queue_answers_503_at_once_h1_loop() raises:
    _h1_full_queue_answers_503_at_once(False, loop="h1")


def test_h1_full_queue_answers_503_at_once_bufring() raises:
    if not _have_bufring():
        return
    _h1_full_queue_answers_503_at_once(False, loop="bufring")


def _h1_client_close_cancels_the_handler(
    tls: Bool, loop: String = "unified"
) raises:
    var prefix = _prefix("h1gone" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("f")
    var srv = _spawn_server(prefix, ServerConfig(), tls, loop=loop)
    var reason = String("")
    try:
        var s = _Conn(srv[1], tls)
        s.get("/slow/f")
        _wait_file(prefix + "started-f")
        s.close()
        _wait_file(prefix + "cancel-f")
        reason = _read_file(prefix + "cancel-f")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_equal(reason, String(CancelReason.PEER_CLOSED))


def test_h1_client_close_cancels_the_handler() raises:
    _h1_client_close_cancels_the_handler(False)


def test_h1_client_close_cancels_the_handler_tls() raises:
    _h1_client_close_cancels_the_handler(True)


def test_h1_client_close_cancels_the_handler_cancellable() raises:
    _h1_client_close_cancels_the_handler(False, loop="cancel")


def test_h1_client_close_cancels_the_handler_h1_loop() raises:
    _h1_client_close_cancels_the_handler(False, loop="h1")


def test_h1_client_close_cancels_the_handler_stream() raises:
    _h1_client_close_cancels_the_handler(False, loop="stream")


def test_h1_client_close_cancels_the_handler_bufring() raises:
    if not _have_bufring():
        return
    _h1_client_close_cancels_the_handler(False, loop="bufring")


def _h1_handler_error_is_500(tls: Bool, loop: String = "unified") raises:
    var prefix = _prefix("h1raise" + _tag(tls) + _loop_tag(loop))
    var srv = _spawn_server(prefix, ServerConfig(), tls, loop=loop)
    var got = String("")
    try:
        var s = _Conn(srv[1], tls)
        s.get("/raise")
        got = s.response()
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, List[String]())
    assert_true(got.startswith("HTTP/1.1 500"), got)


def test_h1_handler_error_is_500() raises:
    _h1_handler_error_is_500(False)


def test_h1_handler_error_is_500_tls() raises:
    _h1_handler_error_is_500(True)


def test_h1_handler_error_is_500_cancellable() raises:
    _h1_handler_error_is_500(False, loop="cancel")


def test_h1_handler_error_is_500_h1_loop() raises:
    _h1_handler_error_is_500(False, loop="h1")


def test_h1_handler_error_is_500_stream() raises:
    _h1_handler_error_is_500(False, loop="stream")


def test_h1_handler_error_is_500_bufring() raises:
    if not _have_bufring():
        return
    _h1_handler_error_is_500(False, loop="bufring")


def _h1_shutdown_waits_for_the_offloaded_request(
    tls: Bool, loop: String = "unified"
) raises:
    """A graceful stop with a request on the pool: the worker keeps the
    connection until the handler (which ignores cancellation) returns,
    sends its response, then exits."""
    var prefix = _prefix("h1drain" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("g")
    var srv = _spawn_server(
        prefix,
        ServerConfig(shutdown_timeout_ms=10_000),
        tls,
        loop=loop,
    )
    var got = String("")
    var exited_early = True
    try:
        var s = _Conn(srv[1], tls)
        s.get("/stubborn/g")
        _wait_file(prefix + "started-g")
        _touch(prefix + "stop")
        exited_early = exists(prefix + "exited")
        _touch(prefix + "release-g")
        got = s.response()
        _wait_file(prefix + "exited")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_false(exited_early)
    assert_true(got.endswith("done g"), got)


def test_h1_shutdown_waits_for_the_offloaded_request() raises:
    _h1_shutdown_waits_for_the_offloaded_request(False)


def test_h1_shutdown_waits_for_the_offloaded_request_tls() raises:
    _h1_shutdown_waits_for_the_offloaded_request(True)


def test_h1_shutdown_waits_for_the_offloaded_request_cancellable() raises:
    _h1_shutdown_waits_for_the_offloaded_request(False, loop="cancel")


def test_h1_shutdown_waits_for_the_offloaded_request_h1_loop() raises:
    _h1_shutdown_waits_for_the_offloaded_request(False, loop="h1")


def test_h1_shutdown_waits_for_the_offloaded_request_stream() raises:
    _h1_shutdown_waits_for_the_offloaded_request(False, loop="stream")


def test_h1_shutdown_waits_for_the_offloaded_request_bufring() raises:
    if not _have_bufring():
        return
    _h1_shutdown_waits_for_the_offloaded_request(False, loop="bufring")


def _h1_shutdown_gives_up_after_its_timeout(
    tls: Bool, loop: String = "unified"
) raises:
    """Past ``shutdown_timeout_ms`` the connection is closed unanswered
    and ``serve`` returns while the handler still runs. The handler then
    finishes on the pool's copy of it, and the process stays healthy."""
    var prefix = _prefix("h1cut" + _tag(tls) + _loop_tag(loop))
    var names = List[String]()
    names.append("h")
    var srv = _spawn_server(
        prefix,
        ServerConfig(shutdown_timeout_ms=200),
        tls,
        loop=loop,
    )
    var closed = False
    var ran_past_serve = False
    try:
        var s = _Conn(srv[1], tls)
        s.get("/stubborn/h")
        _wait_file(prefix + "started-h")
        _touch(prefix + "stop")
        closed = s.closed_by_server()
        _wait_file(prefix + "exited")
        ran_past_serve = not exists(prefix + "finished-h")
        _touch(prefix + "release-h")
        _wait_file(prefix + "finished-h")
        # Give the pool thread time to free the job and the port.
        usleep(50_000)
        _touch(prefix + "quit")
        _wait_file(prefix + "bye")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(closed)
    assert_true(ran_past_serve)


def test_h1_shutdown_gives_up_after_its_timeout() raises:
    _h1_shutdown_gives_up_after_its_timeout(False)


def test_h1_shutdown_gives_up_after_its_timeout_tls() raises:
    _h1_shutdown_gives_up_after_its_timeout(True)


def test_h1_shutdown_gives_up_after_its_timeout_cancellable() raises:
    _h1_shutdown_gives_up_after_its_timeout(False, loop="cancel")


def test_h1_shutdown_gives_up_after_its_timeout_h1_loop() raises:
    _h1_shutdown_gives_up_after_its_timeout(False, loop="h1")


def test_h1_shutdown_gives_up_after_its_timeout_stream() raises:
    _h1_shutdown_gives_up_after_its_timeout(False, loop="stream")


def test_h1_shutdown_gives_up_after_its_timeout_bufring() raises:
    if not _have_bufring():
        return
    _h1_shutdown_gives_up_after_its_timeout(False, loop="bufring")


def test_h1_shutdown_gives_up_after_its_timeout_move_only() raises:
    """A handler that is not ``Copyable`` is shared with the pool, so the
    worker still returns at the deadline while its job runs on."""
    _h1_shutdown_gives_up_after_its_timeout(False, loop="moveonly")


def test_h1_shutdown_gives_up_after_its_timeout_cancel_move_only() raises:
    _h1_shutdown_gives_up_after_its_timeout(False, loop="cancel-moveonly")


def test_cancel_handler_sees_timeout_through_its_cancel_argument() raises:
    """On ``serve_cancellable``, a ``CancelHandler`` that marks a request
    ``blocking`` runs it on the pool with ``cancel`` bound to the job, so
    the handler deadline reaches it there."""
    var prefix = _prefix("cancelarg")
    var names = List[String]()
    names.append("x")
    var srv = _spawn_server(
        prefix, ServerConfig(handler_timeout_ms=200), loop="cancel"
    )
    var got = String("")
    var reason = String("")
    try:
        var s = _Conn(srv[1])
        s.get("/cancel/x")
        got = s.response()
        _wait_file(prefix + "cancel-x")
        reason = _read_file(prefix + "cancel-x")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(got.startswith("HTTP/1.1 503"), got)
    assert_equal(reason, String(CancelReason.TIMEOUT))


def test_stream_full_queue_answers_503_at_once() raises:
    """On ``serve_streaming``, one pool thread and room for one queued
    request: the third offloaded request gets 503 at once and never
    runs."""
    var prefix = _prefix("streamfull")
    var names = List[String]()
    names.append("d1")
    names.append("d2")
    names.append("d3")
    var srv = _spawn_server(
        prefix,
        ServerConfig(offload_threads=1, offload_queue_depth=1),
        loop="stream",
    )
    var refused = String("")
    var r1 = String("")
    var r2 = String("")
    var d3_ran = True
    try:
        var c1 = _Conn(srv[1])
        c1.get("/slow/d1")
        _wait_file(prefix + "started-d1")
        var c2 = _Conn(srv[1])
        c2.get("/slow/d2")
        # Connections are opened in order, so d2 is queued before d3.
        var c3 = _Conn(srv[1])
        c3.get("/slow/d3")
        refused = c3.response()
        _touch(prefix + "release-d1")
        _touch(prefix + "release-d2")
        r1 = c1.response()
        r2 = c2.response()
        d3_ran = exists(prefix + "started-d3")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(refused.startswith("HTTP/1.1 503"), refused)
    assert_true("Retry-After: 1" in refused, refused)
    assert_true(r1.endswith("done d1"), r1)
    assert_true(r2.endswith("done d2"), r2)
    assert_false(d3_ran, "a refused request must not run")


def test_stream_one_connection_offloads_two_requests_at_once() raises:
    """A front may offload several requests on one connection. They run
    side by side, and ``on_offload_done`` gets them in the order they
    were offloaded even when the second finishes first."""
    var prefix = _prefix("streampair")
    var names = List[String]()
    names.append("p1")
    names.append("p2")
    var srv = _spawn_server(
        prefix, ServerConfig(offload_threads=2), loop="stream"
    )
    var got = String("")
    try:
        var c = _Conn(srv[1])
        c.get("/pair/p1/p2")
        _wait_file(prefix + "started-p1")
        _wait_file(prefix + "started-p2")
        _touch(prefix + "release-p2")
        _wait_file(prefix + "finished-p2")
        _touch(prefix + "release-p1")
        got = c.response()
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(got.endswith("done p1,done p2"), got)


def test_stream_timeout_of_one_offload_keeps_the_order() raises:
    """The first of two offloaded requests runs out of time: its 503
    still comes first, and the second, already finished, follows."""
    var prefix = _prefix("streampairto")
    var names = List[String]()
    names.append("t1")
    names.append("t2")
    _touch(prefix + "release-t2")
    var srv = _spawn_server(
        prefix,
        ServerConfig(offload_threads=2, handler_timeout_ms=300),
        loop="stream",
    )
    var got = String("")
    var reason = String("")
    try:
        var c = _Conn(srv[1])
        c.get("/pair/t1/t2")
        got = c.response()
        _wait_file(prefix + "cancel-t1")
        reason = _read_file(prefix + "cancel-t1")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(got.endswith("503,done t2"), got)
    assert_equal(reason, String(CancelReason.TIMEOUT))


def test_stream_client_close_cancels_every_offload() raises:
    """A client that leaves with two offloaded requests out cancels
    both with ``PEER_CLOSED``."""
    var prefix = _prefix("streampairgone")
    var names = List[String]()
    names.append("g1")
    names.append("g2")
    var srv = _spawn_server(
        prefix, ServerConfig(offload_threads=2), loop="stream"
    )
    var r1 = String("")
    var r2 = String("")
    try:
        var c = _Conn(srv[1])
        c.get("/pair/g1/g2")
        _wait_file(prefix + "started-g1")
        _wait_file(prefix + "started-g2")
        c.close()
        _wait_file(prefix + "cancel-g1")
        _wait_file(prefix + "cancel-g2")
        r1 = _read_file(prefix + "cancel-g1")
        r2 = _read_file(prefix + "cancel-g2")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_equal(r1, String(CancelReason.PEER_CLOSED))
    assert_equal(r2, String(CancelReason.PEER_CLOSED))


def test_stream_blocking_driver_runs_the_offload_in_place() raises:
    """``run_stream_connection`` has no pool, so an offloaded request
    has run and been answered by the time it returns."""
    var prefix = _prefix("streamhere")
    var names = List[String]()
    names.append("h")
    _touch(prefix + "release-h")
    var got = String("")
    var finished = False
    try:
        var listener = TcpListener.bind(SocketAddr.localhost(0))
        var client = TcpStream.connect(listener.local_addr())
        var request = String("GET /slow/h HTTP/1.1\r\nHost: x\r\n\r\n")
        _ = client.write(request.as_bytes())
        var server = listener.accept()
        var front = _StreamFront(prefix)
        run_stream_connection(front, server^)
        finished = exists(prefix + "finished-h")
        var buf = List[UInt8](capacity=4096)
        while True:
            buf.resize(4096, 0)
            var n = client.read(buf.unsafe_ptr(), 4096)
            if n == 0:
                break
            got += String(unsafe_from_utf8=Span[UInt8, _](buf)[:n])
        client.close()
    finally:
        _cleanup(prefix, names)
    assert_true(
        finished, "the handler must have run before the driver returned"
    )
    assert_true(got.startswith("HTTP/1.1 200"), got)
    assert_true(got.endswith("done h"), got)


# ── HTTP/2 ─────────────────────────────────────────────────────────────────


def _h2_parked_stream_lets_the_connection_go_on(tls: Bool) raises:
    """While stream 1 waits on the pool, a PING is answered and stream 3
    is served on the same connection."""
    var prefix = _prefix("h2park" + _tag(tls))
    var names = List[String]()
    names.append("m")
    var srv = _spawn_server(prefix, ServerConfig(), tls)
    var still_running = False
    var c = _H2(srv[1], tls)
    try:
        c.get(1, "/slow/m")
        _wait_file(prefix + "started-m")
        c.ping()
        c.get(3, "/fast")
        c.wait_ended(3)
        while c.ping_acks == 0:
            c.pump()
        still_running = 1 not in c.ended and not exists(prefix + "release-m")
        _touch(prefix + "release-m")
        c.wait_ended(1)
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(still_running)
    assert_equal(c.status[3], "200")
    assert_equal(c.body[3], "fast")
    assert_equal(c.status[1], "200")
    assert_equal(c.body[1], "done m")


def test_h2_parked_stream_lets_the_connection_go_on() raises:
    _h2_parked_stream_lets_the_connection_go_on(False)


def test_h2_parked_stream_lets_the_connection_go_on_tls() raises:
    _h2_parked_stream_lets_the_connection_go_on(True)


def _h2_timeout_answers_503_and_cancels(tls: Bool) raises:
    var prefix = _prefix("h2timeout" + _tag(tls))
    var names = List[String]()
    names.append("n")
    var srv = _spawn_server(prefix, ServerConfig(handler_timeout_ms=200), tls)
    var reason = String("")
    var c = _H2(srv[1], tls)
    try:
        c.get(1, "/slow/n")
        c.wait_ended(1)
        _wait_file(prefix + "cancel-n")
        reason = _read_file(prefix + "cancel-n")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_equal(c.status[1], "503")
    assert_equal(c.retry_after[1], "1")
    assert_equal(reason, String(CancelReason.TIMEOUT))


def test_h2_timeout_answers_503_and_cancels() raises:
    _h2_timeout_answers_503_and_cancels(False)


def test_h2_timeout_answers_503_and_cancels_tls() raises:
    _h2_timeout_answers_503_and_cancels(True)


def _h2_full_queue_answers_503_at_once(tls: Bool) raises:
    """One pool thread busy and room for one queued request: of two
    streams sent in one write, the second is refused at once."""
    var prefix = _prefix("h2full" + _tag(tls))
    var names = List[String]()
    names.append("q1")
    names.append("q3")
    names.append("q5")
    var srv = _spawn_server(
        prefix, ServerConfig(offload_threads=1, offload_queue_depth=1), tls
    )
    var q5_ran = True
    var c = _H2(srv[1], tls)
    try:
        c.get(1, "/slow/q1")
        _wait_file(prefix + "started-q1")
        var both = c.headers(3, "/slow/q3")
        both.extend(Span[UInt8, _](c.headers(5, "/slow/q5")))
        c.send(both)
        c.wait_ended(5)
        _touch(prefix + "release-q1")
        _touch(prefix + "release-q3")
        c.wait_ended(1)
        c.wait_ended(3)
        q5_ran = exists(prefix + "started-q5")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_equal(c.status[5], "503")
    assert_equal(c.retry_after[5], "1")
    assert_equal(c.body[1], "done q1")
    assert_equal(c.body[3], "done q3")
    assert_false(q5_ran, "a refused stream must not run")


def test_h2_full_queue_answers_503_at_once() raises:
    _h2_full_queue_answers_503_at_once(False)


def test_h2_full_queue_answers_503_at_once_tls() raises:
    _h2_full_queue_answers_503_at_once(True)


def _h2_rst_stream_cancels_only_that_stream(tls: Bool) raises:
    var prefix = _prefix("h2rst" + _tag(tls))
    var names = List[String]()
    names.append("r")
    var srv = _spawn_server(prefix, ServerConfig(), tls)
    var reason = String("")
    var c = _H2(srv[1], tls)
    try:
        c.get(1, "/slow/r")
        _wait_file(prefix + "started-r")
        c.rst(1)
        _wait_file(prefix + "cancel-r")
        reason = _read_file(prefix + "cancel-r")
        c.get(3, "/fast")
        c.wait_ended(3)
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_equal(reason, String(CancelReason.PEER_CLOSED))
    assert_equal(c.status[3], "200")
    assert_false(1 in c.status, "a reset stream must get no response")


def test_h2_rst_stream_cancels_only_that_stream() raises:
    _h2_rst_stream_cancels_only_that_stream(False)


def test_h2_rst_stream_cancels_only_that_stream_tls() raises:
    _h2_rst_stream_cancels_only_that_stream(True)


def _h2_connection_close_cancels_every_parked_stream(tls: Bool) raises:
    var prefix = _prefix("h2gone" + _tag(tls))
    var names = List[String]()
    names.append("u1")
    names.append("u3")
    var srv = _spawn_server(prefix, ServerConfig(offload_threads=2), tls)
    var r1 = String("")
    var r3 = String("")
    try:
        var c = _H2(srv[1], tls)
        c.get(1, "/slow/u1")
        c.get(3, "/slow/u3")
        _wait_file(prefix + "started-u1")
        _wait_file(prefix + "started-u3")
        c.close()
        _wait_file(prefix + "cancel-u1")
        _wait_file(prefix + "cancel-u3")
        r1 = _read_file(prefix + "cancel-u1")
        r3 = _read_file(prefix + "cancel-u3")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_equal(r1, String(CancelReason.PEER_CLOSED))
    assert_equal(r3, String(CancelReason.PEER_CLOSED))


def test_h2_connection_close_cancels_every_parked_stream() raises:
    _h2_connection_close_cancels_every_parked_stream(False)


def test_h2_connection_close_cancels_every_parked_stream_tls() raises:
    _h2_connection_close_cancels_every_parked_stream(True)


def _h2_shutdown_sends_goaway_and_waits(tls: Bool) raises:
    """A graceful stop sends GOAWAY, then still answers the parked stream
    before the connection closes and the server exits."""
    var prefix = _prefix("h2drain" + _tag(tls))
    var names = List[String]()
    names.append("w")
    var srv = _spawn_server(
        prefix, ServerConfig(shutdown_timeout_ms=10_000), tls
    )
    var answered_before_release = True
    var c = _H2(srv[1], tls)
    try:
        c.get(1, "/stubborn/w")
        _wait_file(prefix + "started-w")
        _touch(prefix + "stop")
        while not c.goaway:
            c.pump()
        answered_before_release = 1 in c.ended
        _touch(prefix + "release-w")
        c.wait_ended(1)
        _wait_file(prefix + "exited")
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_false(answered_before_release)
    assert_equal(c.status[1], "200")
    assert_equal(c.body[1], "done w")


def test_h2_shutdown_sends_goaway_and_waits() raises:
    _h2_shutdown_sends_goaway_and_waits(False)


def test_h2_shutdown_sends_goaway_and_waits_tls() raises:
    _h2_shutdown_sends_goaway_and_waits(True)


# ── Several workers ────────────────────────────────────────────────────────


def test_multi_worker_offloads_share_one_pool() raises:
    """With two workers and four pool threads, four connections all reach
    the pool at once, wherever the kernel put them, and a fifth is served
    while they run."""
    var prefix = _prefix("workers")
    var names = List[String]()
    for i in range(4):
        names.append("k" + String(i))
    var srv = _spawn_server(prefix, ServerConfig(offload_threads=4), workers=2)
    var fast = String("")
    var still_running = False
    var bodies = List[String]()
    try:
        var conns = List[_Conn]()
        for i in range(4):
            conns.append(_Conn(srv[1]))
            conns[i].get("/slow/" + names[i])
        for i in range(4):
            _wait_file(prefix + "started-" + names[i])
        var other = _Conn(srv[1])
        other.get("/fast")
        fast = other.response()
        still_running = not exists(prefix + "release-k0")
        for i in range(4):
            _touch(prefix + "release-" + names[i])
        for i in range(4):
            bodies.append(conns[i].response())
    finally:
        _stop_server(srv[0])
        _cleanup(prefix, names)
    assert_true(fast.endswith("fast"), fast)
    assert_true(still_running)
    for i in range(4):
        assert_true(bodies[i].endswith("done " + names[i]), bodies[i])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

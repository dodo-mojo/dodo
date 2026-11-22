"""``LoopClient``: the outgoing HTTP/1.1 calls of one reactor worker
(ADR-0006).

A parked request hands its round of calls over as a :class:`CallTask`.
Each call becomes an exchange: find an address (a literal, the DNS
cache, or a lookup on the offload pool), take an idle connection to the
origin or open one (through a proxy tunnel and TLS when needed), send
the request, frame the reply, follow redirects and unzip the body. When
the last call of a round has its reply, the task is ready and the worker
runs the handler's ``finish``.

Nothing here blocks. The worker's reactor watches the client's sockets;
events for an fd the server does not own come to :meth:`on_event`, and
the loop calls :meth:`run` once per pass to start rounds, read lookups
and fire timers.

Timer tokens on the client's own wheel are pool addresses: an exchange
deadline uses the exchange's (even) address, a connection's attempt or
idle timer uses its address plus one.
"""

from std.collections import Dict, List, Optional
from std.ffi import c_int
from std.sys import stderr

from dodo.dns import DnsCache
from dodo.dns.async_resolve import order_happy_eyeballs
from dodo.http._client.exchange import (
    ProxyEnv,
    RedirectHop,
    connect_request,
    may_replay,
    request_head,
    tunnel_status_ok,
    unzip_body,
)
from dodo.http._client.parse import H1ResponseReader
from dodo.http._loop_calls.conn import (
    CONNECTING,
    HANDSHAKE,
    IDLE,
    IO_CLOSED,
    IO_DONE,
    IO_FAILED,
    IO_UNCLEAN,
    IO_WANT_BOTH,
    IO_WANT_READ,
    IO_WANT_WRITE,
    READING,
    SENDING,
    TUNNEL_READ,
    TUNNEL_SEND,
    CallConn,
)
from dodo.http._loop_calls.lookup import (
    literal_address,
    lookup_port_open,
    lookup_result,
    lookup_submit,
)
from dodo.http._loop_calls.task import CallTask, task_free, task_ptr
from dodo.http._offload_pool import offload_free, offload_take_done
from dodo.http._reactor.lifecycle import _poll_timeout_ms
from dodo.http._reactor.offload_loop import close_offload_port
from dodo.http._reactor.tls_transport import TLS_ESTABLISHED
from dodo.http._scan import find_crlfcrlf
from dodo.http.calls import CallError, CallReply
from dodo.http.client import DEFAULT_USER_AGENT
from dodo.http.encoding import DEFAULT_MAX_DECOMPRESSED_BYTES
from dodo.http.redirect_policy import RedirectPolicy
from dodo.http.response import Response
from dodo.http._server.config import ServerConfig
from dodo.http.url import Url
from dodo.net import IpAddr, SocketAddr, _find_dodo_lib
from dodo.runtime import Reactor
from dodo.runtime._libc_time import monotonic_now_ms
from dodo.runtime.event import INTEREST_READ, INTEREST_WRITE
from dodo.runtime.pool import Pool
from dodo.runtime.timer_wheel import TimerWheel
from dodo.tls.config import TlsConfig, TlsVerify
from dodo.tls.stream import (
    OwnedDLHandle,
    _build_ssl_ctx,
    _c_err,
    _classify_tls_error,
    _do_ssl_connect_ex,
    _do_ssl_ctx_free,
    _do_ssl_new,
)
from dodo.tls._server_ffi import SSL_IO_WANT_READ, SSL_IO_WANT_WRITE


comptime CONNECT_ATTEMPT_MS = 2_000
"""How long one address may take to connect while others remain."""
comptime TUNNEL_HEAD_MAX = 16_384
"""The largest proxy reply head to ``CONNECT`` that is read."""

comptime WAIT_NONE = 0
"""The exchange is on a connection, or about to be."""
comptime WAIT_LOOKUP = 1
"""The exchange waits for its host to resolve."""
comptime WAIT_QUEUE = 2
"""The exchange waits for a connection to its origin to come free."""


@fieldwise_init
struct CallLimits(Copyable):
    """How much one worker's client may hold open."""

    var conns_per_host: Int
    """Connections to one origin, busy and idle."""
    var idle_per_host: Int
    """Idle connections kept for reuse per origin."""
    var idle_timeout_ms: Int
    """How long an idle connection is kept."""
    var lookup_threads: Int
    """Threads of the offload pool, when the lookups open it first."""
    var lookup_depth: Int
    """Lookups that may wait for a pool thread."""


@fieldwise_init
struct _HostPool(Copyable):
    """The connections of one pool key."""

    var open: Int
    """Connections open, busy or idle."""
    var idle: List[Int]
    """Idle connections, the last released first."""
    var queued: List[Int]
    """Exchanges waiting for a connection, oldest first."""


@fieldwise_init
struct _Target(Copyable):
    """Where one hop of an exchange goes, and how."""

    var key: String
    """Which connections can carry it."""
    var origin_tls: Bool
    var sni: String
    var tunnel_host: String
    """The origin a proxy is asked for, or empty when there is none."""
    var tunnel_port: UInt16
    var dial_host: String
    """The host connected to: the origin, or the proxy."""
    var dial_port: UInt16


struct _Exchange(Movable):
    """One call: its redirects, its deadline and where it waits."""

    var task: Int
    var slot: Int
    """The call's place in the task's round."""
    var hop: RedirectHop
    var tls: TlsConfig
    var timeout_ms: Int
    var deadline: UInt64
    """The deadline timer, or 0 once it fired."""
    var target: _Target
    var conn: Int
    """The connection carrying the exchange, or 0."""
    var waits: Int
    var replayed: Bool
    """Sent again once already after a stale connection."""
    var fresh_only: Bool
    """Must not take an idle connection."""

    def __init__(
        out self,
        task: Int,
        slot: Int,
        var hop: RedirectHop,
        tls: TlsConfig,
        timeout_ms: Int,
    ):
        self.task = task
        self.slot = slot
        self.hop = hop^
        self.tls = tls.copy()
        self.timeout_ms = timeout_ms
        self.deadline = 0
        self.target = _Target("", False, "", "", 0, "", 0)
        self.conn = 0
        self.waits = WAIT_NONE
        self.replayed = False
        self.fresh_only = False


def _ex(addr: Int) -> Pointer[_Exchange, MutUntrackedOrigin]:
    return Pool[_Exchange].get_ptr(addr)


def _cn(addr: Int) -> Pointer[CallConn, MutUntrackedOrigin]:
    return Pool[CallConn].get_ptr(addr)


def _tls_fingerprint(tls: TlsConfig) -> String:
    """What tells two TLS settings apart for a pool key and a context."""
    var out = String(tls.verify) + "|" + tls.ca_bundle
    out += "|" + tls.cert_file + "|" + tls.key_file
    out += "|" + String(tls.enable_session_resumption)
    return out^


def _remove(mut items: List[Int], value: Int):
    """Drop the first ``value`` from ``items``, keeping the order."""
    for i in range(len(items)):
        if items[i] == value:
            _ = items.pop(i)
            return


struct LoopClient(Movable):
    """The outgoing calls of one reactor worker."""

    var limits: CallLimits
    var fds: Dict[Int, Int]
    """Socket fd to connection."""
    var conns: Dict[Int, Bool]
    """Connections alive, for timers that fire late."""
    var exchanges: Dict[Int, Bool]
    """Exchanges alive, for timers that fire late."""
    var pools: Dict[String, _HostPool]
    var lookups: Dict[String, List[Int]]
    """Host to the exchanges waiting for it."""
    var lookup_jobs: Dict[Int, String]
    """Lookup job to its host."""
    var lookup_port: Int
    """Opened at the first lookup; 0 before."""
    var dns: DnsCache
    var ctxs: Dict[String, Int]
    """One ``SSL_CTX`` per TLS setting."""
    var lib: Optional[OwnedDLHandle]
    var wheel: TimerWheel
    var held: Dict[Int, Bool]
    """Tasks the client has, from ``submit`` to ``take_ready``."""
    var submitted: List[Int]
    """Tasks whose next round has not started."""
    var abandoned: List[Int]
    var ready: List[Int]
    var proxies: ProxyEnv
    var policy: RedirectPolicy
    var user_agent: String

    def __init__(out self, limits: CallLimits):
        self.limits = limits.copy()
        self.fds = Dict[Int, Int]()
        self.conns = Dict[Int, Bool]()
        self.exchanges = Dict[Int, Bool]()
        self.pools = Dict[String, _HostPool]()
        self.lookups = Dict[String, List[Int]]()
        self.lookup_jobs = Dict[Int, String]()
        self.lookup_port = 0
        self.dns = DnsCache()
        self.ctxs = Dict[String, Int]()
        self.lib = Optional[OwnedDLHandle]()
        self.wheel = TimerWheel(UInt64(monotonic_now_ms()))
        self.held = Dict[Int, Bool]()
        self.submitted = List[Int]()
        self.abandoned = List[Int]()
        self.ready = List[Int]()
        self.proxies = ProxyEnv()
        self.policy = RedirectPolicy.follow_all(10)
        self.user_agent = String(DEFAULT_USER_AGENT)

    # ── What the worker calls ───────────────────────────────────────────────

    def submit(mut self, task: Int):
        """Take ``task``, whose calls for the next round are waiting. The
        round starts at the next :meth:`run`."""
        self.held[task] = True
        self.submitted.append(task)

    def cancel(mut self, task: Int):
        """The request behind ``task`` stopped waiting. Its calls end at
        the next :meth:`run`, which frees the task. A task the client no
        longer has is left alone."""
        if task not in self.held:
            return
        var tp = task_ptr(task)
        if tp[].abandoned:
            return
        tp[].abandoned = True
        self.abandoned.append(task)

    def owns(self, fd: Int) -> Bool:
        return fd in self.fds

    def on_event(
        mut self, fd: Int, readable: Bool, writable: Bool, mut reactor: Reactor
    ):
        """Move the connection on ``fd`` on as far as it goes."""
        var c = self.fds.get(fd)
        if not c:
            return
        self._drive(c.value(), reactor)

    def run(mut self, mut reactor: Reactor):
        """End abandoned tasks, start new rounds, hand out finished
        lookups and fire due timers."""
        self._end_abandoned(reactor)
        while len(self.submitted) > 0:
            var tasks = self.submitted^
            self.submitted = List[Int]()
            for i in range(len(tasks)):
                self._start_round(tasks[i], reactor)
        self._collect_lookups(reactor)
        self._fire_timers(reactor)

    def take_ready(mut self) -> List[Int]:
        """Tasks whose round has every reply. The client no longer has
        them: the caller runs ``finish`` and submits again or frees."""
        var out = List[Int]()
        var ready = self.ready^
        self.ready = List[Int]()
        for i in range(len(ready)):
            var task = ready[i]
            if task not in self.held:
                continue
            _ = self.held.pop(task, False)
            out.append(task)
        return out^

    def has_work(self) -> Bool:
        """Something waits for :meth:`run` rather than for an event."""
        if len(self.submitted) > 0:
            return True
        if len(self.abandoned) > 0:
            return True
        return len(self.ready) > 0

    def next_timeout_ms(self, cap_ms: Int) -> Int:
        """How long the worker may sleep for the client's sake."""
        if self.has_work():
            return 0
        return _poll_timeout_ms(self.wheel, cap_ms)

    def busy(self) -> Bool:
        """Whether any task is still with the client."""
        return len(self.held) > 0

    def close(mut self, mut reactor: Reactor):
        """Cancel every task, close every connection and the lookup port,
        and free the TLS contexts. The worker is stopping."""
        for entry in self.held.items():
            self.cancel(entry.key)
        self._end_abandoned(reactor)
        var all = List[Int]()
        for entry in self.conns.items():
            all.append(entry.key)
        for i in range(len(all)):
            self._close(all[i], reactor)
        close_offload_port(self.lookup_port)
        self.lookup_port = 0
        if self.lib:
            for entry in self.ctxs.items():
                try:
                    _do_ssl_ctx_free(self.lib.value(), entry.value)
                except:
                    pass
        self.ctxs = Dict[String, Int]()

    # ── Rounds ──────────────────────────────────────────────────────────────

    def _start_round(mut self, task: Int, mut reactor: Reactor):
        var tp = task_ptr(task)
        if tp[].abandoned:
            return
        var calls = tp[].calls.take_waiting()
        var count = len(calls)
        tp[].slots = List[Optional[CallReply]]()
        tp[].running = List[Int]()
        tp[].left = count
        if count == 0:
            self.ready.append(task)
            return
        var now = UInt64(monotonic_now_ms())
        for i in range(count):
            tp[].slots.append(Optional[CallReply]())
            var hop = RedirectHop(calls[i].request, "", True)
            var ex = _Exchange(task, i, hop^, calls[i].tls, calls[i].timeout_ms)
            var addr: Int
            try:
                addr = Pool[_Exchange].alloc_move(ex^)
            except e:
                _ = tp[].fill(
                    i, CallReply(error=CallError.FAILED, message=String(e))
                )
                tp[].running.append(0)
                continue
            tp[].running.append(addr)
            self.exchanges[addr] = True
            try:
                _ex(addr)[].deadline = self.wheel.schedule(
                    calls[i].timeout_ms, UInt64(addr), now
                )
            except:
                pass
        if tp[].left == 0:
            self.ready.append(task)
            return
        for i in range(count):
            var addr = task_ptr(task)[].running[i]
            if addr != 0:
                self._begin(addr, reactor)

    def _end_abandoned(mut self, mut reactor: Reactor):
        var tasks = self.abandoned^
        self.abandoned = List[Int]()
        for i in range(len(tasks)):
            var task = tasks[i]
            # Waiting calls end first, so a connection the others free
            # does not start one of them only to cancel it.
            self._cancel_calls(task, True, reactor)
            self._cancel_calls(task, False, reactor)
            _remove(self.ready, task)
            _remove(self.submitted, task)
            _ = self.held.pop(task, False)
            task_free(task)

    def _cancel_calls(mut self, task: Int, waiting: Bool, mut reactor: Reactor):
        """End ``task``'s calls with ``CANCELLED``: those still waiting
        for an address or a connection, or those on one."""
        var running = task_ptr(task)[].running.copy()
        for j in range(len(running)):
            var ex = running[j]
            if ex == 0:
                continue
            var is_waiting = _ex(ex)[].waits != WAIT_NONE
            if is_waiting != waiting:
                continue
            self._finish(
                ex,
                CallReply(
                    error=CallError.CANCELLED,
                    message="Cancelled: the request stopped waiting",
                ),
                reactor,
            )

    def _finish(mut self, ex: Int, var reply: CallReply, mut reactor: Reactor):
        """End exchange ``ex`` with ``reply`` and free it."""
        var ep = _ex(ex)
        if ep[].deadline != 0:
            try:
                _ = self.wheel.cancel(ep[].deadline)
            except:
                pass
        if ep[].waits == WAIT_LOOKUP:
            var host = ep[].target.dial_host
            if host in self.lookups:
                try:
                    _remove(self.lookups[host], ex)
                except:
                    pass
        if ep[].waits == WAIT_QUEUE:
            var key = ep[].target.key
            if key in self.pools:
                try:
                    _remove(self.pools[key].queued, ex)
                except:
                    pass
        var c = ep[].conn
        if c != 0:
            _cn(c)[].exchange = 0
            self._close(c, reactor)
        var task = ep[].task
        var slot = ep[].slot
        _ = self.exchanges.pop(ex, False)
        Pool[_Exchange].free(ex)
        var tp = task_ptr(task)
        tp[].running[slot] = 0
        if tp[].fill(slot, reply^) and not tp[].abandoned:
            self.ready.append(task)

    def _fail_ex(
        mut self, ex: Int, kind: Int, message: String, mut reactor: Reactor
    ):
        self._finish(ex, CallReply(error=kind, message=message), reactor)

    # ── Starting one hop ────────────────────────────────────────────────────

    def _target(self, ref ep: _Exchange) raises -> _Target:
        """Where the next hop of ``ep`` goes.

        Raises:
            Error: The URL is not a full ``http://`` or ``https://`` URL.
        """
        var u = Url.parse(ep.hop.url)
        if u.scheme != "http" and u.scheme != "https":
            raise Error("UrlParseError: not an http:// or https:// URL")
        if u.host.byte_length() == 0:
            raise Error("UrlParseError: no host")
        var origin_tls = u.is_tls()
        var sni = ep.tls.server_name
        if sni.byte_length() == 0:
            sni = u.host
        var origin = (
            u.scheme + "://" + u.host.lower() + ":" + String(Int(u.port))
        )
        var key = origin + "|"
        var tunnel_host = String("")
        var tunnel_port = UInt16(0)
        var dial_host = u.host
        var dial_port = u.port
        var proxy = self.proxies.pick(u)
        if proxy.byte_length() > 0:
            var pu = Url.parse(proxy)
            tunnel_host = u.host
            tunnel_port = u.port
            dial_host = pu.host
            dial_port = pu.port
            key += pu.host.lower() + ":" + String(Int(pu.port))
        if origin_tls:
            key += "|" + _tls_fingerprint(ep.tls) + "|" + sni
        return _Target(
            key, origin_tls, sni, tunnel_host, tunnel_port, dial_host, dial_port
        )

    def _begin(mut self, ex: Int, mut reactor: Reactor):
        """Start the current hop of ``ex``: reuse, queue, resolve or dial."""
        var ep = _ex(ex)
        try:
            ep[].target = self._target(ep[])
        except e:
            self._fail_ex(ex, CallError.BAD_URL, String(e), reactor)
            return
        var key = ep[].target.key
        if key not in self.pools:
            self.pools[key] = _HostPool(0, List[Int](), List[Int]())
        if not ep[].fresh_only:
            var idle = self._take_idle(key, reactor)
            if idle != 0:
                self._attach(ex, idle, reactor)
                return
        var open = 0
        try:
            open = self.pools[key].open
        except:
            pass
        if open >= self.limits.conns_per_host:
            try:
                self.pools[key].queued.append(ex)
            except:
                pass
            ep[].waits = WAIT_QUEUE
            return
        var host = ep[].target.dial_host
        var literal = literal_address(host)
        if literal:
            var one = List[IpAddr]()
            one.append(literal.value())
            self._dial(ex, one, reactor)
            return
        var hit = self.dns.cached(host)
        if hit:
            self._dial(ex, order_happy_eyeballs(hit.value()), reactor)
            return
        self._wait_lookup(ex, host, reactor)

    def _take_idle(mut self, key: String, mut reactor: Reactor) -> Int:
        """An idle connection for ``key``, or 0."""
        var c = 0
        try:
            ref pool = self.pools[key]
            if len(pool.idle) > 0:
                c = pool.idle.pop()
        except:
            return 0
        return c

    def _wait_lookup(mut self, ex: Int, host: String, mut reactor: Reactor):
        _ex(ex)[].waits = WAIT_LOOKUP
        if host in self.lookups:
            try:
                self.lookups[host].append(ex)
            except:
                pass
            return
        try:
            if self.lookup_port == 0:
                self.lookup_port = lookup_port_open(
                    reactor.wake_fd(),
                    self.limits.lookup_threads,
                    self.limits.lookup_depth,
                )
            var job = lookup_submit(self.lookup_port, host)
            if job == 0:
                _ex(ex)[].waits = WAIT_NONE
                self._fail_ex(
                    ex,
                    CallError.CONNECT,
                    "DnsError: too many lookups waiting for " + host,
                    reactor,
                )
                return
            var waiting = List[Int]()
            waiting.append(ex)
            self.lookups[host] = waiting^
            self.lookup_jobs[job] = host
        except e:
            _ex(ex)[].waits = WAIT_NONE
            self._fail_ex(ex, CallError.CONNECT, String(e), reactor)

    def _collect_lookups(mut self, mut reactor: Reactor):
        if self.lookup_port == 0:
            return
        var done = offload_take_done(self.lookup_port)
        for i in range(len(done)):
            var job = done[i]
            var result = lookup_result(job)
            offload_free(job)
            var host: String
            try:
                host = self.lookup_jobs.pop(job)
            except:
                continue
            var waiting = List[Int]()
            try:
                waiting = self.lookups.pop(host)
            except:
                pass
            if result.error.byte_length() == 0:
                self.dns.remember(host, result.addrs.copy())
            for j in range(len(waiting)):
                var ex = waiting[j]
                _ex(ex)[].waits = WAIT_NONE
                if result.error.byte_length() > 0:
                    self._fail_ex(ex, CallError.CONNECT, result.error, reactor)
                else:
                    self._dial(ex, order_happy_eyeballs(result.addrs), reactor)

    # ── Connections ─────────────────────────────────────────────────────────

    def _dial(mut self, ex: Int, addrs: List[IpAddr], mut reactor: Reactor):
        """Open a connection for ``ex`` to the first address that takes it."""
        var ep = _ex(ex)
        ref t = ep[].target
        var key = t.key
        var open = 0
        try:
            open = self.pools[key].open
        except:
            pass
        if open >= self.limits.conns_per_host:
            try:
                self.pools[key].queued.append(ex)
            except:
                pass
            ep[].waits = WAIT_QUEUE
            return
        var ctx = 0
        if t.origin_tls:
            try:
                ctx = self._ctx_for(ep[].tls)
            except e:
                self._fail_ex(ex, CallError.FAILED, String(e), reactor)
                return
        var sockaddrs = List[SocketAddr]()
        for i in range(len(addrs)):
            sockaddrs.append(SocketAddr(addrs[i], t.dial_port))
        var conn = CallConn(
            key,
            t.origin_tls,
            t.sni,
            ctx,
            t.tunnel_host,
            t.tunnel_port,
            t.dial_host,
            sockaddrs^,
        )
        var c: Int
        try:
            c = Pool[CallConn].alloc_move(conn^)
        except e:
            self._fail_ex(ex, CallError.FAILED, String(e), reactor)
            return
        self.conns[c] = True
        try:
            self.pools[key].open += 1
        except:
            pass
        _cn(c)[].exchange = ex
        ep[].conn = c
        ep[].waits = WAIT_NONE
        self._connect_next(c, reactor)

    def _ctx_for(mut self, tls: TlsConfig) raises -> Int:
        """The ``SSL_CTX`` for ``tls``, made on first use."""
        var fingerprint = _tls_fingerprint(tls)
        var have = self.ctxs.get(fingerprint)
        if have:
            return have.value()
        if not self.lib:
            self.lib = Optional[OwnedDLHandle](OwnedDLHandle(_find_dodo_lib()))
        if tls.verify == TlsVerify.NONE:
            print(
                (
                    "[dodo TLS SECURITY WARNING] An outgoing call does not"
                    " verify certificates. It is open to man-in-the-middle"
                    " attacks."
                ),
                file=stderr,
            )
        var cfg = tls.copy()
        cfg.alpn = List[String]()
        cfg.alpn.append("http/1.1")
        var ctx = _build_ssl_ctx(self.lib.value(), cfg)
        self.ctxs[fingerprint] = ctx
        return ctx

    def _connect_next(mut self, c: Int, mut reactor: Reactor):
        """Try the connection's next address; fail the exchange once none
        is left."""
        var cp = _cn(c)
        self._cancel_conn_timer(c)
        while cp[].has_more_addresses():
            self._unwatch(c, reactor)
            var r: Int
            try:
                r = cp[].connect_next()
            except e:
                cp[].error = String(e)
                continue
            self.fds[cp[].fd()] = c
            cp[].phase = CONNECTING
            if r == IO_DONE:
                self._connected(c, reactor)
                return
            if not self._watch(c, INTEREST_WRITE, reactor):
                return
            if cp[].has_more_addresses():
                self._arm_conn_timer(c, CONNECT_ATTEMPT_MS)
            return
        var reason = cp[].error
        self._fail(
            c,
            CallError.CONNECT,
            "NetworkError: all addresses failed for "
            + cp[].dial_host
            + ": "
            + reason,
            False,
            reactor,
        )

    def _connected(mut self, c: Int, mut reactor: Reactor):
        """The TCP connection is up: tunnel, handshake or send."""
        var cp = _cn(c)
        self._cancel_conn_timer(c)
        try:
            cp[].sock.set_tcp_nodelay(True)
        except:
            pass
        if cp[].proxied():
            var req = connect_request(cp[].tunnel_host, cp[].tunnel_port)
            cp[].load(List[UInt8](req.as_bytes()))
            cp[].phase = TUNNEL_SEND
        else:
            self._after_tunnel(c, reactor)
            return
        self._drive(c, reactor)

    def _after_tunnel(mut self, c: Int, mut reactor: Reactor):
        """Start TLS for an ``https`` origin, else send the request."""
        var cp = _cn(c)
        if cp[].origin_tls:
            try:
                var ssl = _do_ssl_new(
                    self.lib.value(), cp[].ctx, c_int(cp[].fd())
                )
                if ssl == 0:
                    raise Error(
                        "TlsHandshakeError: " + _c_err(self.lib.value())
                    )
                cp[].start_tls(ssl)
            except e:
                self._fail(c, CallError.FAILED, String(e), False, reactor)
                return
            cp[].phase = HANDSHAKE
        else:
            self._load_request(c)
        self._drive(c, reactor)

    def _load_request(mut self, c: Int):
        """Make the exchange's request what the connection sends next."""
        var cp = _cn(c)
        var ep = _ex(cp[].exchange)
        ref hop = ep[].hop
        var head = String("")
        try:
            var u = Url.parse(hop.url)
            head = request_head(
                hop.method,
                u,
                hop.headers,
                len(hop.body),
                hop.auth_header,
                self.user_agent,
                True,
            )
        except:
            pass
        var bytes = List[UInt8](head.as_bytes())
        bytes.extend(hop.body.copy())
        cp[].load(bytes^)
        cp[].reader = H1ResponseReader(hop.method)
        cp[].phase = SENDING

    def _attach(mut self, ex: Int, c: Int, mut reactor: Reactor):
        """Put ``ex`` on idle connection ``c``."""
        self._cancel_conn_timer(c)
        _cn(c)[].exchange = ex
        var ep = _ex(ex)
        ep[].conn = c
        ep[].waits = WAIT_NONE
        self._load_request(c)
        self._drive(c, reactor)

    def _release(mut self, c: Int, mut reactor: Reactor):
        """``c`` finished an exchange and may carry another."""
        var cp = _cn(c)
        cp[].reused = True
        cp[].exchange = 0
        cp[].phase = IDLE
        cp[].reader = H1ResponseReader("GET")
        var key = cp[].key
        var next = 0
        var keep = False
        try:
            ref pool = self.pools[key]
            if len(pool.queued) > 0:
                next = pool.queued.pop(0)
            elif len(pool.idle) < self.limits.idle_per_host:
                pool.idle.append(c)
                keep = True
        except:
            pass
        if next != 0:
            self._attach(next, c, reactor)
            return
        if not keep:
            self._close(c, reactor)
            return
        if self._watch(c, INTEREST_READ, reactor):
            self._arm_conn_timer(c, self.limits.idle_timeout_ms)

    def _close(mut self, c: Int, mut reactor: Reactor):
        """Close ``c``, then let a waiting exchange open another."""
        if c not in self.conns:
            return
        var cp = _cn(c)
        self._cancel_conn_timer(c)
        self._unwatch(c, reactor)
        var key = cp[].key
        try:
            ref pool = self.pools[key]
            _remove(pool.idle, c)
            pool.open -= 1
        except:
            pass
        var ex = cp[].exchange
        if ex != 0:
            _ex(ex)[].conn = 0
        cp[].close_politely()
        _ = self.conns.pop(c, False)
        Pool[CallConn].free(c)
        self._serve_queue(key, reactor)

    def _serve_queue(mut self, key: String, mut reactor: Reactor):
        """Start the oldest exchange waiting on ``key`` now one fewer is
        open; forget ``key`` once nothing uses it."""
        var next = 0
        var unused = False
        try:
            ref pool = self.pools[key]
            if len(pool.queued) > 0 and pool.open < self.limits.conns_per_host:
                next = pool.queued.pop(0)
            elif pool.open == 0 and len(pool.queued) == 0:
                unused = True
        except:
            return
        if unused:
            _ = self.pools.pop(key, _HostPool(0, List[Int](), List[Int]()))
            return
        if next != 0:
            _ex(next)[].waits = WAIT_NONE
            self._begin(next, reactor)

    def _fail(
        mut self,
        c: Int,
        kind: Int,
        message: String,
        write_failed: Bool,
        mut reactor: Reactor,
    ):
        """``c`` failed. Its exchange is sent once more on a fresh
        connection when ``c`` was a reused one that went stale, else it
        ends with ``kind``."""
        var cp = _cn(c)
        var ex = cp[].exchange
        var phase = cp[].phase
        var reused = cp[].reused
        var no_reply = cp[].reader.got_nothing()
        cp[].exchange = 0
        self._close(c, reactor)
        if ex == 0:
            return
        var ep = _ex(ex)
        ep[].conn = 0
        var sent = phase == SENDING or phase == READING
        if reused and sent and not ep[].replayed:
            if may_replay(ep[].hop.method, write_failed, no_reply):
                ep[].replayed = True
                ep[].fresh_only = True
                self._begin(ex, reactor)
                return
        self._fail_ex(ex, kind, message, reactor)

    # ── Moving bytes ────────────────────────────────────────────────────────

    def _drive(mut self, c: Int, mut reactor: Reactor):
        """Step ``c`` until it waits for an event or is gone."""
        var going = True
        while going:
            if c not in self.conns:
                return
            try:
                going = self._step(c, reactor)
            except e:
                self._fail(c, CallError.FAILED, String(e), False, reactor)
                return

    def _step(mut self, c: Int, mut reactor: Reactor) raises -> Bool:
        """One step of ``c``'s phase. True when it should step again."""
        var phase = _cn(c)[].phase
        if phase == CONNECTING:
            return self._step_connect(c, reactor)
        if phase == TUNNEL_SEND:
            return self._step_send(c, TUNNEL_READ, reactor)
        if phase == TUNNEL_READ:
            return self._step_tunnel_read(c, reactor)
        if phase == HANDSHAKE:
            return self._step_handshake(c, reactor)
        if phase == SENDING:
            return self._step_send(c, READING, reactor)
        if phase == READING:
            return self._step_read(c, reactor)
        return self._step_idle(c, reactor)

    def _step_connect(mut self, c: Int, mut reactor: Reactor) raises -> Bool:
        var r = _cn(c)[].check_connected()
        if r == IO_WANT_WRITE:
            return self._watch(c, INTEREST_WRITE, reactor)
        if r == IO_FAILED:
            self._connect_next(c, reactor)
            return False
        self._connected(c, reactor)
        return False

    def _step_send(
        mut self, c: Int, next_phase: Int, mut reactor: Reactor
    ) raises -> Bool:
        var cp = _cn(c)
        var r = cp[].send_out()
        if r == IO_WANT_WRITE:
            _ = self._watch(c, INTEREST_WRITE, reactor)
            return False
        if r == IO_WANT_BOTH:
            _ = self._watch(c, INTEREST_READ | INTEREST_WRITE, reactor)
            return False
        if r == IO_FAILED:
            self._fail(c, CallError.FAILED, cp[].error, True, reactor)
            return False
        cp[].phase = next_phase
        cp[].head = List[UInt8]()
        _ = self._watch(c, INTEREST_READ, reactor)
        return False

    def _step_tunnel_read(
        mut self, c: Int, mut reactor: Reactor
    ) raises -> Bool:
        var cp = _cn(c)
        var got = List[UInt8]()
        var n = cp[].read_some(got)
        if n == -IO_WANT_READ:
            return False
        if n <= 0:
            self._fail(
                c,
                CallError.FAILED,
                "NetworkError: proxy CONNECT: closed before reply",
                False,
                reactor,
            )
            return False
        cp[].head.extend(got^)
        var end = find_crlfcrlf(cp[].head, 0)
        if end < 0:
            if len(cp[].head) > TUNNEL_HEAD_MAX:
                self._fail(
                    c,
                    CallError.FAILED,
                    "NetworkError: proxy CONNECT: reply head too large",
                    False,
                    reactor,
                )
                return False
            return True
        if not tunnel_status_ok(Span(cp[].head)):
            self._fail(
                c,
                CallError.FAILED,
                "NetworkError: proxy CONNECT: non-2xx from proxy",
                False,
                reactor,
            )
            return False
        if end < len(cp[].head):
            self._fail(
                c,
                CallError.FAILED,
                "NetworkError: proxy CONNECT: bytes after the reply",
                False,
                reactor,
            )
            return False
        cp[].head = List[UInt8]()
        self._after_tunnel(c, reactor)
        return False

    def _step_handshake(mut self, c: Int, mut reactor: Reactor) raises -> Bool:
        var cp = _cn(c)
        var ssl = cp[].tls.value().ssl_addr
        var rc = _do_ssl_connect_ex(self.lib.value(), ssl, cp[].sni)
        if rc == 0:
            cp[].tls.value().phase = TLS_ESTABLISHED
            self._load_request(c)
            return True
        if rc == SSL_IO_WANT_READ:
            _ = self._watch(c, INTEREST_READ, reactor)
            return False
        if rc == SSL_IO_WANT_WRITE:
            _ = self._watch(c, INTEREST_WRITE, reactor)
            return False
        var message = String("")
        try:
            _classify_tls_error(_c_err(self.lib.value()), cp[].sni)
        except e:
            message = String(e)
        self._fail(c, CallError.FAILED, message, False, reactor)
        return False

    def _step_read(mut self, c: Int, mut reactor: Reactor) raises -> Bool:
        var cp = _cn(c)
        var got = List[UInt8]()
        var n = cp[].read_some(got)
        if n > 0:
            if cp[].reader.feed(Span(got)):
                self._response_done(c, reactor)
                return False
            return True
        if n == -IO_WANT_READ:
            _ = self._watch(c, INTEREST_READ, reactor)
            return False
        if n == -IO_WANT_BOTH:
            _ = self._watch(c, INTEREST_READ | INTEREST_WRITE, reactor)
            return False
        if n == -IO_CLOSED or n == -IO_UNCLEAN:
            try:
                cp[].reader.end_of_stream(unclean_tls=n == -IO_UNCLEAN)
            except e:
                self._fail(c, CallError.FAILED, String(e), False, reactor)
                return False
            self._response_done(c, reactor)
            return False
        self._fail(c, CallError.FAILED, cp[].error, False, reactor)
        return False

    def _step_idle(mut self, c: Int, mut reactor: Reactor) raises -> Bool:
        """An idle connection became readable: a TLS ticket, or the
        server closing it."""
        var got = List[UInt8]()
        var n = _cn(c)[].read_some(got)
        if n == -IO_WANT_READ:
            return False
        self._close(c, reactor)
        return False

    def _response_done(mut self, c: Int, mut reactor: Reactor):
        """The reply on ``c`` is complete: free ``c`` for the next
        exchange, then follow a redirect or end the exchange."""
        var cp = _cn(c)
        var ex = cp[].exchange
        var resp_or: Optional[Response]
        try:
            resp_or = Optional[Response](cp[].reader.take())
        except e:
            self._fail(c, CallError.FAILED, String(e), False, reactor)
            return
        var reusable = cp[].reader.reusable()
        cp[].exchange = 0
        var ep = _ex(ex)
        ep[].conn = 0
        if reusable:
            self._release(c, reactor)
        else:
            self._close(c, reactor)
        var resp = resp_or.take()
        var follow: Bool
        try:
            follow = ep[].hop.follow(resp, self.policy)
        except e:
            self._fail_ex(ex, CallError.FAILED, String(e), reactor)
            return
        if follow:
            ep[].replayed = False
            ep[].fresh_only = False
            self._begin(ex, reactor)
            return
        var body = unzip_body(resp^, DEFAULT_MAX_DECOMPRESSED_BYTES)
        self._finish(ex, CallReply(body^), reactor)

    # ── Reactor interest and timers ─────────────────────────────────────────

    def _watch(mut self, c: Int, interest: Int, mut reactor: Reactor) -> Bool:
        """Make the reactor wait for ``interest`` on ``c``. False when it
        could not, and ``c`` has failed."""
        var cp = _cn(c)
        if cp[].interest == interest:
            return True
        var fd = c_int(cp[].fd())
        try:
            if cp[].interest == 0:
                reactor.register(fd, UInt64(cp[].fd()), interest)
            else:
                reactor.modify(fd, interest)
            cp[].interest = interest
            return True
        except e:
            self._fail(c, CallError.FAILED, String(e), False, reactor)
            return False

    def _unwatch(mut self, c: Int, mut reactor: Reactor):
        var cp = _cn(c)
        var fd = cp[].fd()
        if cp[].interest != 0:
            try:
                reactor.unregister(c_int(fd))
            except:
                pass
            cp[].interest = 0
        if fd >= 0:
            _ = self.fds.pop(fd, 0)

    def _arm_conn_timer(mut self, c: Int, after_ms: Int):
        try:
            _cn(c)[].timer = self.wheel.schedule(
                after_ms, UInt64(c + 1), UInt64(monotonic_now_ms())
            )
        except:
            pass

    def _cancel_conn_timer(mut self, c: Int):
        var cp = _cn(c)
        if cp[].timer == 0:
            return
        try:
            _ = self.wheel.cancel(cp[].timer)
        except:
            pass
        cp[].timer = 0

    def _fire_timers(mut self, mut reactor: Reactor):
        var fired = List[UInt64]()
        try:
            self.wheel.advance(UInt64(monotonic_now_ms()), fired)
        except:
            return
        for i in range(len(fired)):
            var token = Int(fired[i])
            if token % 2 == 1:
                var c = token - 1
                if c in self.conns:
                    self._conn_timer(c, reactor)
            elif token in self.exchanges:
                self._deadline(token, reactor)

    def _conn_timer(mut self, c: Int, mut reactor: Reactor):
        var cp = _cn(c)
        cp[].timer = 0
        if cp[].phase == CONNECTING:
            cp[].error = String("connect attempt timed out")
            self._connect_next(c, reactor)
            return
        if cp[].phase == IDLE:
            self._close(c, reactor)

    def _deadline(mut self, ex: Int, mut reactor: Reactor):
        """``ex`` ran out of time. Before a TCP connection it could not
        reach the server; after, the call was too slow."""
        var ep = _ex(ex)
        ep[].deadline = 0
        var connecting = ep[].waits == WAIT_LOOKUP
        if ep[].conn != 0:
            if _cn(ep[].conn)[].phase == CONNECTING:
                connecting = True
        var took = (
            String(" took longer than ") + String(ep[].timeout_ms) + " ms"
        )
        if connecting:
            self._fail_ex(
                ex,
                CallError.CONNECT,
                "ConnectionTimeout: connect to " + ep[].target.dial_host + took,
                reactor,
            )
            return
        self._fail_ex(
            ex, CallError.TIMEOUT, "Timeout: the call" + took, reactor
        )


def loop_client_new(limits: CallLimits) raises -> Int:
    """Put a worker's client on the heap. Its address is what the loop
    and its connections share; free it with :func:`loop_client_free`."""
    return Pool[LoopClient].alloc_move(LoopClient(limits))


def loop_client(addr: Int) -> Pointer[LoopClient, MutUntrackedOrigin]:
    """The client at ``addr``."""
    return Pool[LoopClient].get_ptr(addr)


def loop_client_free(addr: Int):
    """Free the client at ``addr``, after :meth:`LoopClient.close`."""
    Pool[LoopClient].free(addr)


def call_limits(config: ServerConfig) -> CallLimits:
    """The client limits a server configuration sets."""
    return CallLimits(
        config.call_conns_per_host,
        config.call_idle_per_host,
        config.call_idle_timeout_ms,
        config.offload_threads,
        config.offload_queue_depth,
    )

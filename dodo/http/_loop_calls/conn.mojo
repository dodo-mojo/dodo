"""``CallConn``: one outgoing HTTP/1.1 connection of the loop client.

The socket is non-blocking and every method returns at once: a step
either finishes or says which edge (readable or writable) it waits for.
:class:`LoopClient` drives the phases; this file only moves bytes.
"""

from std.collections import List, Optional
from std.ffi import ErrNo, c_int, c_size_t, c_uint, get_errno
from std.memory import stack_allocation, unsafe_memcpy

from dodo.http._client.parse import H1ResponseReader
from dodo.http._reactor.tls_transport import TLS_HANDSHAKE, TlsTransport
from dodo.net import SocketAddr
from dodo.net._libc import (
    MSG_NOSIGNAL,
    SOL_SOCKET,
    SO_ERROR,
    _connect,
    _getsockopt,
    _recv,
    _send,
    _strerror,
)
from dodo.net.socket import (
    AF_INET,
    AF_INET6,
    RawSocket,
    SOCK_STREAM,
    _build_sockaddr_in,
)
from dodo.tls._server_ffi import (
    SSL_IO_CLOSED,
    SSL_IO_WANT_READ,
    SSL_IO_WANT_WRITE,
)


# ── Phases ─────────────────────────────────────────────────────────────────

comptime CONNECTING = 0
"""``connect`` is in progress; waits for writable."""
comptime TUNNEL_SEND = 1
"""Sending ``CONNECT`` to a proxy."""
comptime TUNNEL_READ = 2
"""Reading the proxy's reply to ``CONNECT``."""
comptime HANDSHAKE = 3
"""The TLS client handshake."""
comptime SENDING = 4
"""Sending the request."""
comptime READING = 5
"""Reading the response."""
comptime IDLE = 6
"""In the pool, waiting for the next request; read only to see it close."""


# ── What one I/O step came to ──────────────────────────────────────────────

comptime IO_DONE = 0
"""Everything was sent, or the socket connected."""
comptime IO_WANT_READ = 1
"""Blocked until readable."""
comptime IO_WANT_WRITE = 2
"""Blocked until writable."""
comptime IO_WANT_BOTH = 3
"""TLS needs the other direction too (a renegotiation or key update)."""
comptime IO_CLOSED = 4
"""The peer closed cleanly."""
comptime IO_UNCLEAN = 5
"""A TLS peer closed without ``close_notify``."""
comptime IO_FAILED = 6
"""An error; ``CallConn.error`` says which."""

comptime _READ_CHUNK = 16384


struct CallConn(Movable):
    """One outgoing connection and where it is in its exchange."""

    var sock: RawSocket
    var tls: Optional[TlsTransport]
    var key: String
    """The pool key: who this connection can carry requests to."""
    var origin_tls: Bool
    """The origin is ``https``."""
    var sni: String
    """The name TLS sends and checks."""
    var ctx: Int
    """The ``SSL_CTX`` for this connection's TLS setting."""
    var tunnel_host: String
    """The origin to ask a proxy for with ``CONNECT``, or empty when the
    connection goes straight to the origin."""
    var tunnel_port: UInt16
    var dial_host: String
    """The host the addresses are for: the origin, or the proxy."""
    var addrs: List[SocketAddr]
    """Where to connect, tried in order."""
    var next_addr: Int
    var phase: Int
    var out: List[UInt8]
    """Bytes to send in this phase."""
    var out_pos: Int
    var head: List[UInt8]
    """The proxy's reply to ``CONNECT``, while it is read."""
    var reader: H1ResponseReader
    var reused: Bool
    """Carried a request before the current one."""
    var exchange: Int
    """The exchange using this connection, or 0."""
    var timer: UInt64
    """The connect-attempt or idle timer, or 0."""
    var interest: Int
    """The interest the reactor has for the socket."""
    var error: String
    """Why the last step failed."""

    def __init__(
        out self,
        key: String,
        origin_tls: Bool,
        sni: String,
        ctx: Int,
        tunnel_host: String,
        tunnel_port: UInt16,
        dial_host: String,
        var addrs: List[SocketAddr],
    ):
        self.sock = RawSocket(c_int(-1), AF_INET, SOCK_STREAM, True)
        self.tls = Optional[TlsTransport]()
        self.key = key
        self.origin_tls = origin_tls
        self.sni = sni
        self.ctx = ctx
        self.tunnel_host = tunnel_host
        self.tunnel_port = tunnel_port
        self.dial_host = dial_host
        self.addrs = addrs^
        self.next_addr = 0
        self.phase = CONNECTING
        self.out = List[UInt8]()
        self.out_pos = 0
        self.head = List[UInt8]()
        self.reader = H1ResponseReader("GET")
        self.reused = False
        self.exchange = 0
        self.timer = 0
        self.interest = 0
        self.error = String()

    def fd(self) -> Int:
        return Int(self.sock.fd)

    def proxied(self) -> Bool:
        """Whether the connection goes through a proxy tunnel."""
        return self.tunnel_host.byte_length() > 0

    def has_more_addresses(self) -> Bool:
        return self.next_addr < len(self.addrs)

    # ── Connect ─────────────────────────────────────────────────────────────

    def connect_next(mut self) raises -> Int:
        """Close any socket and start connecting to the next address.
        Returns ``IO_DONE`` when it connected at once, else
        ``IO_WANT_WRITE``.

        Raises:
            Error: This address failed at once; try the next one.
        """
        self.sock.close()
        var addr = self.addrs[self.next_addr]
        self.next_addr += 1
        var family = AF_INET
        if addr.ip.is_v6():
            family = AF_INET6
        self.sock = RawSocket(family, SOCK_STREAM)
        self.sock.set_nonblocking(True)
        var sa = _build_sockaddr_in(addr)
        var rc = _connect(self.sock.fd, sa[0], sa[1])
        var err = get_errno()
        sa[0].unsafe_free()
        if rc == c_int(0):
            return IO_DONE
        if err == ErrNo.EINPROGRESS or err == ErrNo.EINTR:
            return IO_WANT_WRITE
        raise Error(_connect_error(err.value, addr))

    def check_connected(mut self) raises -> Int:
        """Whether the pending connect finished: ``IO_DONE``,
        ``IO_WANT_WRITE`` while still in progress, or ``IO_FAILED``.

        ``SO_ERROR`` gives a failure; a second ``connect`` tells a
        finished connect (``EISCONN``) from one still going, since a
        stray writable edge can arrive before it finishes.
        """
        var so_err = stack_allocation[1, c_int]()
        so_err.unsafe_write(c_int(0))
        var so_len = stack_allocation[1, c_uint]()
        so_len.unsafe_write(c_uint(4))
        _ = _getsockopt(
            self.sock.fd,
            SOL_SOCKET,
            SO_ERROR,
            so_err.unsafe_bitcast[UInt8](),
            so_len,
        )
        var addr = self.addrs[self.next_addr - 1]
        var pending = Int(so_err.unsafe_load())
        if pending != 0:
            self.error = _connect_error(c_int(pending), addr)
            return IO_FAILED
        var sa = _build_sockaddr_in(addr)
        var rc = _connect(self.sock.fd, sa[0], sa[1])
        var err = get_errno()
        sa[0].unsafe_free()
        if rc == c_int(0) or err == ErrNo.EISCONN:
            return IO_DONE
        if err == ErrNo.EALREADY or err == ErrNo.EINPROGRESS:
            return IO_WANT_WRITE
        if err == ErrNo.EINTR:
            return IO_WANT_WRITE
        self.error = _connect_error(err.value, addr)
        return IO_FAILED

    def start_tls(mut self, ssl: Int) raises:
        """Take ``ssl``, made on this socket, for the handshake."""
        self.tls = Optional[TlsTransport](
            TlsTransport.adopt(ssl, TLS_HANDSHAKE)
        )

    # ── Bytes ───────────────────────────────────────────────────────────────

    def load(mut self, var bytes: List[UInt8]):
        """Make ``bytes`` what the next :meth:`send_out` sends."""
        self.out = bytes^
        self.out_pos = 0

    def send_out(mut self) raises -> Int:
        """Send what is left of ``out``. ``IO_DONE`` once all of it went."""
        while self.out_pos < len(self.out):
            if self.tls:
                var n = self.tls.value().send(Span(self.out), self.out_pos)
                if n > 0:
                    self.out_pos += n
                    continue
                if n == SSL_IO_WANT_WRITE:
                    return IO_WANT_WRITE
                if n == SSL_IO_WANT_READ:
                    return IO_WANT_BOTH
                self.error = String("TLS write failed")
                return IO_FAILED
            var left = len(self.out) - self.out_pos
            var ptr = self.out.unsafe_ptr().unsafe_offset(self.out_pos)
            var sent = _send(
                self.sock.fd, ptr, c_size_t(left), c_int(MSG_NOSIGNAL)
            )
            if sent > 0:
                self.out_pos += Int(sent)
                continue
            var err = get_errno()
            if err == ErrNo.EINTR:
                continue
            if err == ErrNo.EAGAIN or err == ErrNo.EWOULDBLOCK:
                return IO_WANT_WRITE
            self.error = String("write failed: ") + _strerror(err.value)
            return IO_FAILED
        return IO_DONE

    def read_some(mut self, mut into: List[UInt8]) raises -> Int:
        """Append what the socket has to ``into``. Returns the byte count
        when it got some, else one of ``IO_WANT_READ``, ``IO_WANT_BOTH``,
        ``IO_CLOSED``, ``IO_UNCLEAN`` or ``IO_FAILED`` as a negative
        number."""
        if self.tls:
            var got = self.tls.value().recv(into, _READ_CHUNK)
            if got > 0:
                return got
            if got == SSL_IO_WANT_READ:
                return -IO_WANT_READ
            if got == SSL_IO_WANT_WRITE:
                return -IO_WANT_BOTH
            if got == SSL_IO_CLOSED:
                return -IO_CLOSED
            return -IO_UNCLEAN
        var chunk = stack_allocation[_READ_CHUNK, UInt8]()
        while True:
            var n = _recv(self.sock.fd, chunk, c_size_t(_READ_CHUNK), c_int(0))
            if n > 0:
                var old = len(into)
                into.resize(old + Int(n), UInt8(0))
                unsafe_memcpy(
                    dest=into.unsafe_ptr().unsafe_offset(old),
                    src=chunk,
                    count=Int(n),
                )
                return Int(n)
            if n == 0:
                return -IO_CLOSED
            var err = get_errno()
            if err == ErrNo.EINTR:
                continue
            if err == ErrNo.EAGAIN or err == ErrNo.EWOULDBLOCK:
                return -IO_WANT_READ
            self.error = String("read failed: ") + _strerror(err.value)
            return -IO_FAILED

    def close_politely(mut self):
        """Send TLS ``close_notify`` when the socket takes it; the
        connection is closing anyway."""
        if self.tls:
            try:
                self.tls.value().send_close_notify()
            except:
                pass


def _connect_error(errno: c_int, addr: SocketAddr) -> String:
    """The message for a failed connect, worded like the blocking
    client's so both paths read the same in logs."""
    return (
        String("NetworkError: ")
        + _strerror(errno)
        + " (connect "
        + String(addr)
        + ")"
    )

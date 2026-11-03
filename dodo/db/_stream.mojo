"""A buffered, blocking connection to a database server, over TCP or TLS.

Every network driver reads and writes through this. It turns socket and
TLS failures into `DbError.io`, so a driver deals with one error type.
"""

from std.collections import Optional
from std.memory import Pointer

from ..tcp import TcpStream
from ..tls import TlsConfig, TlsStream
from .error import DbError


comptime _MIN_READ = 16 * 1024


struct DbStream(Movable):
    var _tcp: Optional[TcpStream]
    var _tls: Optional[TlsStream]
    var _buf: List[UInt8]
    var _start: Int
    var _end: Int
    var database: String
    """Which driver owns this stream, for error messages."""

    def __init__(out self, var tcp: TcpStream, database: String):
        self._tcp = tcp^
        self._tls = None
        self._buf = List[UInt8](length=_MIN_READ, fill=0)
        self._start = 0
        self._end = 0
        self.database = database

    @staticmethod
    def connect(
        host: String, port: Int, timeout_ms: Int, database: String
    ) raises DbError -> DbStream:
        try:
            var tcp = TcpStream.connect(host, UInt16(port), timeout_ms)
            return DbStream(tcp^, database)
        except e:
            raise DbError.connect(
                database, String("can't reach ", host, ":", port, ": ", e)
            )

    def set_timeout(self, ms: Int) raises DbError:
        """Fail a read or write that waits longer than `ms`. 0: wait forever."""
        try:
            if self._tls:
                self._tls.value().set_recv_timeout(ms)
            else:
                self._tcp.value().set_recv_timeout(ms)
                self._tcp.value().set_send_timeout(ms)
        except e:
            raise DbError.io(self.database, String(e))

    def start_tls(mut self, host: String, config: TlsConfig) raises DbError:
        """Upgrade the plain connection to TLS, for protocols that negotiate
        it in-band (PostgreSQL's SSLRequest, MySQL's SSL capability)."""
        if not self._tcp:
            raise DbError.usage(self.database, "connection already uses TLS")
        if self._end > self._start:
            # Bytes after the server's yes and before the handshake would
            # be a downgrade or injection attempt (CVE-2021-23214).
            raise DbError.protocol(
                self.database, "server sent data before the TLS handshake"
            )
        var tcp = self._tcp.take()
        try:
            self._tls = TlsStream.connect_over_tcp(tcp^, host, config)
        except e:
            raise DbError.connect(self.database, String("TLS: ", e))

    def is_tls(self) -> Bool:
        return Bool(self._tls)

    # ── Writing ─────────────────────────────────────────────────────────────

    def write(mut self, data: Span[UInt8, _]) raises DbError:
        try:
            if self._tls:
                self._tls.value().write_all(data)
            else:
                self._tcp.value().write_all(data)
        except e:
            raise DbError.io(self.database, String("write failed: ", e))

    # ── Reading ─────────────────────────────────────────────────────────────

    def available(self) -> Int:
        return self._end - self._start

    def fill(mut self, need: Int) raises DbError:
        """Make at least `need` unread bytes available."""
        if self._end - self._start >= need:
            return
        self._compact()
        if len(self._buf) < need:
            self._buf.resize(max(need, 2 * len(self._buf)), 0)
        while self._end - self._start < need:
            var room = len(self._buf) - self._end
            if room < _MIN_READ // 4:
                self._buf.resize(len(self._buf) + _MIN_READ, 0)
                room = len(self._buf) - self._end
            var n = self._read_some(room)
            if n == 0:
                raise DbError.io(self.database, "server closed the connection")
            self._end += n

    def _read_some(mut self, room: Int) raises DbError -> Int:
        var dest = self._buf.unsafe_ptr().unsafe_offset(self._end)
        try:
            if self._tls:
                return self._tls.value().read(dest, room)
            return self._tcp.value().read(dest, room)
        except e:
            raise DbError.io(self.database, String("read failed: ", e))

    def _compact(mut self):
        if self._start == 0:
            return
        var unread = self._end - self._start
        # The regions can overlap, so no memcpy. Copying forward is safe
        # because the destination comes first.
        for i in range(unread):
            self._buf[i] = self._buf[self._start + i]
        self._start = 0
        self._end = unread

    def peek(self, offset: Int) -> UInt8:
        """The unread byte at `offset`; `fill` first."""
        return self._buf[self._start + offset]

    def unread(self) -> Span[UInt8, origin_of(self._buf)]:
        """Every unread byte, without consuming it."""
        return Span(self._buf)[self._start : self._end]

    def take(mut self, n: Int) raises DbError -> List[UInt8]:
        """Read exactly `n` bytes."""
        self.fill(n)
        var out = List[UInt8](self._buf[self._start : self._start + n])
        self._start += n
        return out^

    def skip(mut self, n: Int):
        """Consume `n` bytes already made available by `fill`."""
        self._start += n

    def read_line(mut self, limit: Int) raises DbError -> List[UInt8]:
        """Read up to and including CRLF; return the line without it."""
        var i = self._start
        while True:
            while i + 1 < self._end:
                if self._buf[i] == 13 and self._buf[i + 1] == 10:
                    var line = List[UInt8](self._buf[self._start : i])
                    self._start = i + 2
                    return line^
                i += 1
            if self._end - self._start > limit:
                raise DbError.protocol(self.database, "line too long")
            # `fill` may move the unread bytes to the front of the buffer.
            var scanned = i - self._start
            self.fill(self._end - self._start + 1)
            i = self._start + scanned

    def close(mut self):
        """Close the socket. Never raises."""
        if self._tls:
            self._tls.value().close()
        elif self._tcp:
            self._tcp.value().close()

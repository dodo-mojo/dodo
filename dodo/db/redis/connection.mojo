"""One connection to a Redis or Valkey server."""

from ...tls import TlsConfig, TlsVerify
from .._stream import DbStream
from .._url import DbUrl
from ..error import DbError
from ..param import Param
from ..pool import Connection
from . import protocol
from .protocol import DB, RedisReply, ReplyTree


struct RedisConfig(Copyable, Writable):
    """Where and how to connect.

    Usually built from a URL:

    `redis://user:password@host:6379/0`, or `rediss://` for TLS.

    The user may be left out (`redis://:password@host`). The path is the
    database number. URL options:

    - `ssl_cert_reqs` (`rediss://` only): `required` (default: the
      certificate must be trusted and name the host) or `none` (encrypt
      without checking it).
    - `ssl_ca_certs`: a CA bundle for a server with a private CA.
    - `connect_timeout_ms` (default 5000) and `timeout_ms` (default 30000).
    """

    var host: String
    var port: Int
    var user: String
    var password: String
    var database: Int
    var use_tls: Bool
    var tls: TlsConfig
    var connect_timeout_ms: Int
    var timeout_ms: Int

    def __init__(out self):
        self.host = "127.0.0.1"
        self.port = 6379
        self.user = String()
        self.password = String()
        self.database = 0
        self.use_tls = False
        self.tls = TlsConfig()
        self.connect_timeout_ms = 5_000
        self.timeout_ms = 30_000

    @staticmethod
    def from_url(url: String) raises DbError -> RedisConfig:
        var parsed = DbUrl.parse(url, 6379)
        if (
            parsed.scheme != "redis"
            and parsed.scheme != "rediss"
            and parsed.scheme != "valkey"
        ):
            raise DbError.usage(
                DB,
                String("expected a redis:// URL, got ", parsed.scheme, "://"),
            )
        var config = RedisConfig()
        config.host = parsed.host
        config.port = parsed.port
        config.user = parsed.user
        config.password = parsed.password
        if parsed.database != "":
            try:
                config.database = Int(parsed.database)
            except:
                raise DbError.usage(
                    DB, "the URL path must be a database number"
                )
        config.use_tls = parsed.scheme == "rediss"
        var reqs = parsed.option("ssl_cert_reqs", "required").lower()
        if reqs == "none":
            config.tls.verify = TlsVerify.ENCRYPT_ONLY
        elif reqs != "required":
            raise DbError.usage(
                DB, "ssl_cert_reqs must be required or none, got '" + reqs + "'"
            )
        var ca = parsed.option("ssl_ca_certs", "")
        if ca != "":
            config.tls.ca_bundle = ca
        config.connect_timeout_ms = parsed.int_option(
            "connect_timeout_ms", 5_000
        )
        config.timeout_ms = parsed.int_option("timeout_ms", 30_000)
        return config^

    def write_to[W: Writer](self, mut writer: W):
        var scheme = "rediss://" if self.use_tls else "redis://"
        writer.write(scheme, self.host, ":", self.port, "/", self.database)


struct RedisConnection(Connection):
    """A session with the server. Not safe to share between threads; a
    `Redis` pool hands each caller its own."""

    comptime Config = RedisConfig

    var _stream: DbStream
    var _broken: Bool
    var _in_multi: Bool
    var _watching: Bool

    def __init__(out self, var stream: DbStream):
        self._stream = stream^
        self._broken = False
        self._in_multi = False
        self._watching = False

    @staticmethod
    def open(config: RedisConfig) raises DbError -> RedisConnection:
        var stream = DbStream.connect(
            config.host, config.port, config.connect_timeout_ms, DB
        )
        if config.use_tls:
            stream.start_tls(config.host, config.tls)
        stream.set_timeout(config.timeout_ms)
        var conn = RedisConnection(stream^)
        if config.password != "":
            var auth = List[Param]()
            auth.append("AUTH")
            if config.user != "":
                auth.append(config.user)
            auth.append(config.password)
            conn._setup(auth)
        if config.database != 0:
            var select = List[Param]()
            select.append("SELECT")
            select.append(config.database)
            conn._setup(select)
        return conn^

    def _setup(mut self, args: List[Param]) raises DbError:
        var reply = self._round_trip(args)
        if reply.is_error():
            var error = protocol.reply_error(reply)
            if error.kind == DbError.SERVER:
                error.kind = DbError.CONNECT
            raise error^

    # ── Commands ────────────────────────────────────────────────────────────

    def command(mut self, args: List[Param]) raises DbError -> RedisReply:
        """Run one command; raise if the server answers with an error."""
        var name = protocol.command_name(args)
        if protocol.is_refused(name):
            raise DbError.usage(
                DB,
                name
                + " is not allowed on a pooled connection; set the user,"
                " password and database in the URL",
            )
        var reply = self._round_trip(args)
        self._track(name, reply)
        if reply.is_error():
            raise protocol.reply_error(reply)
        return reply^

    def pipeline(
        mut self, commands: List[List[Param]]
    ) raises DbError -> List[RedisReply]:
        """Send every command in one write, then read every reply. Error
        replies come back in the list rather than raising, so one failed
        command doesn't hide the others' results."""
        var out = List[UInt8]()
        for ref args in commands:
            var name = protocol.command_name(args)
            if protocol.is_refused(name):
                raise DbError.usage(
                    DB, name + " is not allowed on a pooled connection"
                )
            protocol.encode(out, args)
        var replies = List[RedisReply](capacity=len(commands))
        self._check_usable()
        try:
            self._stream.write(Span(out))
            for ref args in commands:
                var reply = self._read_reply()
                self._track(protocol.command_name(args), reply)
                replies.append(reply^)
        except e:
            if e.breaks_connection():
                self._broken = True
            raise e^
        return replies^

    def _round_trip(mut self, args: List[Param]) raises DbError -> RedisReply:
        var out = List[UInt8]()
        protocol.encode(out, args)
        self._check_usable()
        try:
            self._stream.write(Span(out))
            return self._read_reply()
        except e:
            if e.breaks_connection():
                self._broken = True
            raise e^

    def _track(mut self, name: String, reply: RedisReply):
        """Follow MULTI and WATCH so `reset` can undo them."""
        if reply.is_error():
            return
        if name == "MULTI":
            self._in_multi = True
        elif name == "EXEC" or name == "DISCARD":
            self._in_multi = False
            self._watching = False
        elif name == "WATCH":
            self._watching = True
        elif name == "UNWATCH":
            self._watching = False

    # ── Replies ─────────────────────────────────────────────────────────────

    def _read_reply(mut self) raises DbError -> RedisReply:
        var tree = ReplyTree()
        self._read_node(tree, 0)
        return RedisReply(tree^)

    def _read_node(mut self, mut tree: ReplyTree, depth: Int) raises DbError:
        var line = self._stream.read_line(protocol.MAX_LINE)
        if len(line) == 0:
            raise DbError.protocol(DB, "empty reply line")
        var tag = Int(line[0])
        var empty = List[UInt8]()
        if tag == ord("+"):
            _ = tree.push(RedisReply.STATUS, 0, Span(line)[1:])
        elif tag == ord("-"):
            _ = tree.push(RedisReply.ERROR, 0, Span(line)[1:])
        elif tag == ord(":"):
            _ = tree.push(
                RedisReply.INT, protocol.parse_length(Span(line)), Span(empty)
            )
        elif tag == ord("$"):
            var n = protocol.parse_length(Span(line))
            if n < 0:
                _ = tree.push(RedisReply.NIL, 0, Span(empty))
                return
            if n > protocol.MAX_BULK:
                raise DbError.protocol(
                    DB, String("bulk string of ", n, " bytes is too long")
                )
            self._stream.fill(n + 2)
            var body = self._stream.unread()
            if Int(body[n]) != 13 or Int(body[n + 1]) != 10:
                raise DbError.protocol(DB, "bulk string not followed by CRLF")
            _ = tree.push(RedisReply.BULK, 0, body[0:n])
            self._stream.skip(n + 2)
        elif tag == ord("*"):
            var n = protocol.parse_length(Span(line))
            if n < 0:
                _ = tree.push(RedisReply.NIL, 0, Span(empty))
                return
            if depth >= protocol.MAX_DEPTH:
                raise DbError.protocol(DB, "reply nested too deeply")
            var index = tree.push(RedisReply.ARRAY, n, Span(empty))
            for _ in range(n):
                self._read_node(tree, depth + 1)
            tree.close(index)
        else:
            raise DbError.protocol(DB, String("unknown reply type byte ", tag))

    def _check_usable(self) raises DbError:
        if self._broken:
            raise DbError.io(DB, "connection is broken by an earlier error")

    # ── Pool hooks ──────────────────────────────────────────────────────────

    def ping(mut self) -> Bool:
        try:
            var args = List[Param]()
            args.append("PING")
            var reply = self._round_trip(args)
            return not reply.is_error()
        except:
            self._broken = True
            return False

    def broken(self) -> Bool:
        return self._broken

    def reset(mut self) -> Bool:
        try:
            if self._in_multi:
                var args = List[Param]()
                args.append("DISCARD")
                _ = self.command(args)
            if self._watching:
                var args = List[Param]()
                args.append("UNWATCH")
                _ = self.command(args)
            return True
        except:
            return False

    def close(mut self):
        self._broken = True
        self._stream.close()

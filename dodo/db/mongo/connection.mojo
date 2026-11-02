"""One connection to a MongoDB server."""

from std.sys import CompilationTarget

from ...tls import TlsConfig, TlsVerify
from .._scram import ScramClient
from .._stream import DbStream
from .._url import DbUrl
from ..error import DbError
from ..pool import Connection
from . import protocol
from .bson import DB, Bson, BsonValue


struct MongoConfig(Copyable, Writable):
    """Where and how to connect.

    Usually built from a URL:

    `mongodb://user:password@host:27017/database?authSource=admin`

    One host only: replica-set seed lists and `mongodb+srv://` are not
    supported yet. URL options (MongoDB's own names):

    - `authSource`: the database holding the user (default: the URL's
      database, else `admin`).
    - `tls=true`: TLS from the first byte. The certificate must be trusted
      and name the host, unless `tlsAllowInvalidCertificates=true`.
    - `tlsCAFile`: a CA bundle for a server with a private CA.
    - `connectTimeoutMS` (default 5000), `socketTimeoutMS` (default 30000).
    - `appName`: shown in the server's logs and `currentOp`.
    """

    var host: String
    var port: Int
    var user: String
    var password: String
    var database: String
    var auth_source: String
    var use_tls: Bool
    var tls: TlsConfig
    var connect_timeout_ms: Int
    var timeout_ms: Int
    var app_name: String

    def __init__(out self):
        self.host = "127.0.0.1"
        self.port = 27017
        self.user = String()
        self.password = String()
        self.database = "test"
        self.auth_source = "admin"
        self.use_tls = False
        self.tls = TlsConfig()
        self.connect_timeout_ms = 5_000
        self.timeout_ms = 30_000
        self.app_name = "dodo"

    @staticmethod
    def from_url(url: String) raises DbError -> MongoConfig:
        if url.startswith("mongodb+srv://"):
            raise DbError.usage(
                DB, "mongodb+srv:// URLs are not supported yet; give one host"
            )
        var parsed = DbUrl.parse(url, 27017)
        if parsed.scheme != "mongodb":
            raise DbError.usage(
                DB,
                String("expected a mongodb:// URL, got ", parsed.scheme, "://"),
            )
        if parsed.host.find(",") >= 0:
            raise DbError.usage(
                DB,
                "replica-set seed lists are not supported yet; give one host",
            )
        var config = MongoConfig()
        config.host = parsed.host
        config.port = parsed.port
        config.user = parsed.user
        config.password = parsed.password
        if parsed.database != "":
            config.database = parsed.database
        config.auth_source = parsed.option(
            "authSource", parsed.database if parsed.database != "" else "admin"
        )
        var tls = parsed.option("tls", parsed.option("ssl", "false")).lower()
        config.use_tls = tls == "true"
        if (
            parsed.option("tlsAllowInvalidCertificates", "false").lower()
            == "true"
        ):
            config.tls.verify = TlsVerify.ENCRYPT_ONLY
        if parsed.option("tlsInsecure", "false").lower() == "true":
            config.tls.verify = TlsVerify.ENCRYPT_ONLY
        var ca = parsed.option("tlsCAFile", "")
        if ca != "":
            config.tls.ca_bundle = ca
        config.connect_timeout_ms = parsed.int_option("connectTimeoutMS", 5_000)
        config.timeout_ms = parsed.int_option("socketTimeoutMS", 30_000)
        config.app_name = parsed.option("appName", "dodo")
        return config^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "mongodb://",
            self.user,
            "@",
            self.host,
            ":",
            self.port,
            "/",
            self.database,
        )


struct MongoConnection(Connection):
    """A session with the server. Not safe to share between threads; a
    `Mongo` pool hands each caller its own."""

    comptime Config = MongoConfig

    var _stream: DbStream
    var _broken: Bool
    var _next_id: Int
    var max_document_size: Int
    """The server's largest document, from `hello`."""

    def __init__(out self, var stream: DbStream):
        self._stream = stream^
        self._broken = False
        self._next_id = 1
        self.max_document_size = 16 * 1024 * 1024

    @staticmethod
    def open(config: MongoConfig) raises DbError -> MongoConnection:
        var stream = DbStream.connect(
            config.host, config.port, config.connect_timeout_ms, DB
        )
        if config.use_tls:
            stream.start_tls(config.host, config.tls)
        stream.set_timeout(config.timeout_ms)
        var conn = MongoConnection(stream^)
        conn._hello(config)
        if config.user != "":
            conn._authenticate(config)
        return conn^

    def _hello(mut self, config: MongoConfig) raises DbError:
        var driver = Bson().add("name", "dodo").add("version", "0.0.1")
        var os_type = String("Linux")
        comptime if CompilationTarget.is_macos():
            os_type = "Darwin"
        var client = (
            Bson()
            .add("driver", driver)
            .add("os", Bson().add("type", os_type))
            .add("application", Bson().add("name", config.app_name))
        )
        var reply = self.command(
            "admin", Bson().add("hello", 1).add("client", client)
        )
        var wire = reply.find("maxWireVersion")
        # OP_MSG arrived with wire version 6 (MongoDB 3.6).
        if not wire or wire.value().as_int() < 6:
            raise DbError.connect(DB, "server is older than MongoDB 3.6")
        var size = reply.find("maxBsonObjectSize")
        if size:
            self.max_document_size = size.value().as_int()

    def _authenticate(mut self, config: MongoConfig) raises DbError:
        """SCRAM-SHA-256 over saslStart and saslContinue."""
        var scram = ScramClient(config.user, config.password, DB)
        var first = scram.client_first()
        var start = (
            Bson()
            .add("saslStart", 1)
            .add("mechanism", "SCRAM-SHA-256")
            .add("payload", BsonValue.binary(first.as_bytes()))
            .add("options", Bson().add("skipEmptyExchange", True))
        )
        var reply = self._auth_step(config, start)
        var conversation = reply.get("conversationId")
        var final = scram.client_final(protocol.binary_text(reply, "payload"))
        var next = (
            Bson()
            .add("saslContinue", 1)
            .add("conversationId", conversation.copy())
            .add("payload", BsonValue.binary(final.as_bytes()))
        )
        reply = self._auth_step(config, next)
        scram.verify(protocol.binary_text(reply, "payload"))
        # Without skipEmptyExchange support the server wants one more
        # empty round before it says done.
        while not reply.bool("done"):
            var empty = List[UInt8]()
            var more = (
                Bson()
                .add("saslContinue", 1)
                .add("conversationId", conversation.copy())
                .add("payload", BsonValue.binary(Span(empty)))
            )
            reply = self._auth_step(config, more)

    def _auth_step(
        mut self, config: MongoConfig, step: Bson
    ) raises DbError -> Bson:
        try:
            return self.command(config.auth_source, step)
        except e:
            var error = e.copy()
            if error.kind == DbError.SERVER:
                error.kind = DbError.AUTH
            raise error^

    # ── Commands ────────────────────────────────────────────────────────────

    def command(
        mut self, database: String, command: Bson
    ) raises DbError -> Bson:
        """Run one command against `database`; raise if `ok` isn't 1."""
        var reply = self.run(database, command)
        protocol.check_ok(reply)
        return reply^

    def run(mut self, database: String, command: Bson) raises DbError -> Bson:
        """Run one command; return the reply as it came, errors included."""
        self._check_usable()
        var message = protocol.op_msg(
            self._next_id, protocol.with_db(command, database)
        )
        if len(message) > protocol.MAX_MESSAGE:
            raise DbError.usage(
                DB, String("command of ", len(message), " bytes is too large")
            )
        var request_id = self._next_id
        self._next_id += 1
        try:
            self._stream.write(Span(message))
            self._stream.fill(protocol.HEADER)
            var header = protocol.parse_header(
                self._stream.unread()[0 : protocol.HEADER]
            )
            if header.response_to != request_id:
                raise DbError.protocol(DB, "reply answers a different request")
            self._stream.skip(protocol.HEADER)
            var rest = self._stream.take(header.length - protocol.HEADER)
            return protocol.parse_body(Span(rest))
        except e:
            if e.breaks_connection():
                self._broken = True
            raise e^

    def _check_usable(self) raises DbError:
        if self._broken:
            raise DbError.io(DB, "connection is broken by an earlier error")

    # ── Pool hooks ──────────────────────────────────────────────────────────

    def ping(mut self) -> Bool:
        try:
            _ = self.command("admin", Bson().add("ping", 1))
            return True
        except:
            self._broken = True
            return False

    def broken(self) -> Bool:
        return self._broken

    def reset(mut self) -> Bool:
        return True

    def close(mut self):
        self._broken = True
        self._stream.close()

"""One blocking connection to PostgreSQL or CockroachDB."""

from std.collections import Optional

from ...tls import TlsConfig, TlsVerify
from .._scram import ScramClient
from .._stream import DbStream
from .._url import DbUrl
from ..error import DbError
from ..param import Param
from ..pool import Connection
from ..rows import Rows
from . import protocol
from .protocol import DB


struct PgConfig(Copyable, Writable):
    """Where and how to connect.

    Usually built from a URL:

    `postgres://user:password@host:5432/database?sslmode=prefer`

    URL options:

    - `sslmode`, as in libpq: `disable`; `prefer` (default: TLS when the
      server offers it); `require` (TLS or fail); `verify-full` (TLS, and
      the certificate must be trusted and name the host). Only
      `verify-full` stops an active man in the middle.
    - `sslrootcert`: a CA bundle for `verify-full` against a private CA.
    - `connect_timeout_ms` (default 5000) and `timeout_ms`, the longest a
      read or write may wait (default 30000; 0 waits forever).
    - `application_name`: shown in `pg_stat_activity`.
    """

    var host: String
    var port: Int
    var user: String
    var password: String
    var database: String
    var sslmode: String
    var tls: TlsConfig
    var connect_timeout_ms: Int
    var timeout_ms: Int
    var application: String

    def __init__(out self):
        self.host = "127.0.0.1"
        self.port = 5432
        self.user = "postgres"
        self.password = String()
        self.database = String()
        self.sslmode = "prefer"
        self.tls = TlsConfig(verify=TlsVerify.ENCRYPT_ONLY)
        self.connect_timeout_ms = 5_000
        self.timeout_ms = 30_000
        self.application = "dodo"

    @staticmethod
    def from_url(url: String) raises DbError -> PgConfig:
        var parsed = DbUrl.parse(url, 5432)
        if parsed.scheme != "postgres" and parsed.scheme != "postgresql":
            raise DbError.usage(
                DB,
                String(
                    "expected a postgres:// URL, got ", parsed.scheme, "://"
                ),
            )
        var config = PgConfig()
        config.host = parsed.host
        config.port = parsed.port
        if parsed.user != "":
            config.user = parsed.user
        config.password = parsed.password
        config.database = parsed.database
        config.sslmode = parsed.option("sslmode", "prefer")
        if (
            config.sslmode != "disable"
            and config.sslmode != "prefer"
            and config.sslmode != "require"
            and config.sslmode != "verify-full"
        ):
            raise DbError.usage(
                DB,
                String(
                    (
                        "sslmode must be disable, prefer, require or"
                        " verify-full, got '"
                    ),
                    config.sslmode,
                    "'",
                ),
            )
        if config.sslmode == "verify-full":
            config.tls.verify = TlsVerify.REQUIRED
        var root = parsed.option("sslrootcert", "")
        if root != "":
            config.tls.ca_bundle = root
        config.connect_timeout_ms = parsed.int_option(
            "connect_timeout_ms", 5_000
        )
        config.timeout_ms = parsed.int_option("timeout_ms", 30_000)
        config.application = parsed.option("application_name", "dodo")
        return config^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "postgres://",
            self.user,
            "@",
            self.host,
            ":",
            self.port,
            "/",
            self.database,
        )


struct PgConnection(Connection):
    """A session with the server. Not safe to share between threads; a
    `Postgres` pool hands each caller its own."""

    comptime Config = PgConfig

    var _stream: DbStream
    var _broken: Bool
    var _tx_status: Int
    """From the last ReadyForQuery: `I` idle, `T` in a transaction, `E`
    in a failed transaction."""
    var server_version: String

    def __init__(out self, var stream: DbStream):
        self._stream = stream^
        self._broken = False
        self._tx_status = ord("I")
        self.server_version = String()

    @staticmethod
    def open(config: PgConfig) raises DbError -> PgConnection:
        var stream = DbStream.connect(
            config.host, config.port, config.connect_timeout_ms, DB
        )
        stream.set_timeout(config.timeout_ms)
        if config.sslmode != "disable":
            stream.write(protocol.ssl_request())
            var answer = stream.take(1)
            if Int(answer[0]) == ord("S"):
                stream.start_tls(config.host, config.tls)
            elif Int(answer[0]) == ord("N"):
                if config.sslmode != "prefer":
                    raise DbError.connect(
                        DB,
                        "server does not offer TLS (sslmode="
                        + config.sslmode
                        + ")",
                    )
            else:
                raise DbError.protocol(DB, "unexpected answer to SSLRequest")
        var conn = PgConnection(stream^)
        conn._startup(config)
        return conn^

    # ── Messages ────────────────────────────────────────────────────────────

    def _read(mut self) raises DbError -> Tuple[Int, List[UInt8]]:
        """The next message: its tag and its body."""
        self._stream.fill(5)
        var length = protocol.frame_length(self._stream.unread()[0:5])
        var tag = Int(self._stream.peek(0))
        self._stream.skip(5)
        var body = self._stream.take(length)
        return (tag, body^)

    def _startup(mut self, config: PgConfig) raises DbError:
        self._stream.write(
            protocol.startup(config.user, config.database, config.application)
        )
        var scram = Optional[ScramClient](None)
        while True:
            var message = self._read()
            var tag = message[0]
            ref body = message[1]
            if tag == ord("R"):
                self._authenticate(config, body, scram)
            elif tag == ord("E"):
                var error = protocol.parse_error(body)
                if error.kind == DbError.SERVER:
                    error.kind = DbError.CONNECT
                raise error^
            elif tag == ord("S"):
                self._parameter_status(body)
            elif tag == ord("Z"):
                self._tx_status = Int(body[0]) if len(body) > 0 else ord("I")
                return
            # BackendKeyData ('K') and notices ('N') need no answer.

    def _authenticate(
        mut self,
        config: PgConfig,
        body: List[UInt8],
        mut scram: Optional[ScramClient],
    ) raises DbError:
        if len(body) < 4:
            raise DbError.protocol(DB, "short authentication message")
        var code = (
            (Int(body[0]) << 24)
            | (Int(body[1]) << 16)
            | (Int(body[2]) << 8)
            | Int(body[3])
        )
        if code == 0:
            return
        if code == 3:
            self._stream.write(protocol.password(config.password))
        elif code == 5:
            if len(body) < 8:
                raise DbError.protocol(DB, "short MD5 salt")
            self._stream.write(
                protocol.md5_password(
                    config.user, config.password, Span(body)[4:8]
                )
            )
        elif code == 10:
            var offered = String(from_utf8_lossy=Span(body)[4:])
            if offered.find("SCRAM-SHA-256\0") < 0:
                raise DbError.auth(
                    DB, "server offers no SASL mechanism dodo supports"
                )
            var client = ScramClient(String(), config.password, DB)
            self._stream.write(
                protocol.sasl_initial("SCRAM-SHA-256", client.client_first())
            )
            scram = client^
        elif code == 11:
            if not scram:
                raise DbError.protocol(DB, "SASL continue without SASL start")
            var server_first = String(from_utf8_lossy=Span(body)[4:])
            self._stream.write(
                protocol.sasl_response(scram.value().client_final(server_first))
            )
        elif code == 12:
            if not scram:
                raise DbError.protocol(DB, "SASL final without SASL start")
            scram.value().verify(String(from_utf8_lossy=Span(body)[4:]))
        else:
            raise DbError.auth(
                DB, String("unsupported authentication method ", code)
            )

    def _parameter_status(mut self, body: List[UInt8]) raises DbError:
        var r = protocol.ByteReader(Span(body), DB)
        var name = r.cstr()
        var value = r.cstr()
        if name == "server_version":
            self.server_version = value

    # ── Queries ─────────────────────────────────────────────────────────────

    def query(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Rows:
        """Run one statement with `$1`-style parameters; return its rows."""
        self._check_usable()
        try:
            self._stream.write(protocol.extended_query(sql, params))
            return self._read_results()
        except e:
            if e.breaks_connection():
                self._broken = True
            raise e^

    def execute(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Int:
        """Run one statement; return how many rows it changed."""
        return self.query(sql, params).affected

    def execute_script(mut self, sql: String) raises DbError -> Int:
        """Run several `;`-separated statements without parameters, as one
        implicit transaction. Returns the last statement's row count."""
        self._check_usable()
        try:
            self._stream.write(protocol.simple_query(sql))
            return self._read_results().affected
        except e:
            if e.breaks_connection():
                self._broken = True
            raise e^

    def _read_results(mut self) raises DbError -> Rows:
        var rows = Rows()
        var oids = List[Int]()
        var failure = Optional[DbError](None)
        while True:
            var message = self._read()
            var tag = message[0]
            ref body = message[1]
            if tag == ord("D"):
                if not failure:
                    protocol.parse_data_row(body, oids, rows)
            elif tag == ord("T"):
                # A script returns one description per statement; keep the
                # last result set, as psql shows the last one.
                rows = Rows()
                oids = protocol.parse_row_description(body, rows)
            elif tag == ord("C"):
                rows.affected = protocol.parse_command_tag(body)
            elif tag == ord("E"):
                if not failure:
                    failure = protocol.parse_error(body)
            elif tag == ord("Z"):
                self._tx_status = Int(body[0]) if len(body) > 0 else ord("I")
                if failure:
                    raise failure.take()
                return rows^
            elif tag == ord("S"):
                self._parameter_status(body)
            elif (
                tag == ord("1")
                or tag == ord("2")
                or tag == ord("n")
                or tag == ord("I")
                or tag == ord("N")
                or tag == ord("A")
                or tag == ord("s")
            ):
                pass
            else:
                raise DbError.protocol(
                    DB, String("unexpected message '", chr(tag), "'")
                )

    def _check_usable(self) raises DbError:
        if self._broken:
            raise DbError.io(DB, "connection is broken by an earlier error")

    def in_transaction(self) -> Bool:
        return self._tx_status != ord("I")

    # ── Pool hooks ──────────────────────────────────────────────────────────

    def ping(mut self) -> Bool:
        if self._broken:
            return False
        try:
            self._stream.write(protocol.sync())
            var message = self._read()
            if message[0] != ord("Z"):
                self._broken = True
                return False
            return True
        except:
            self._broken = True
            return False

    def broken(self) -> Bool:
        return self._broken

    def reset(mut self) -> Bool:
        if self._tx_status == ord("I"):
            return True
        try:
            _ = self.execute_script("ROLLBACK")
            return self._tx_status == ord("I")
        except:
            return False

    def close(mut self):
        if not self._broken:
            try:
                self._stream.write(protocol.terminate())
            except:
                pass
        self._broken = True
        self._stream.close()

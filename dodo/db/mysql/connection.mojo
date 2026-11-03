"""One blocking connection to MySQL or MariaDB."""

from std.collections import Optional

from ...crypto.rsa import rsa_oaep_encrypt
from ...tls import TlsConfig, TlsVerify
from .._bytes import ByteReader
from .._stream import DbStream
from .._url import DbUrl
from ..error import DbError
from ..param import Param
from ..pool import Connection
from ..rows import Rows
from . import protocol
from .protocol import DB, ColumnInfo


struct MySqlConfig(Copyable, Writable):
    """Where and how to connect.

    Usually built from a URL:

    `mysql://user:password@host:3306/database?ssl_mode=preferred`

    URL options:

    - `ssl_mode`, as in the mysql client: `disabled`; `preferred`
      (default: TLS when the server offers it); `required` (TLS or fail);
      `verify_identity` (TLS, and the certificate must be trusted and name
      the host). Only `verify_identity` stops an active man in the middle.
    - `ssl_ca`: a CA bundle for `verify_identity` against a private CA.
    - `connect_timeout_ms` (default 5000) and `timeout_ms` (default 30000).
    """

    var host: String
    var port: Int
    var user: String
    var password: String
    var database: String
    var ssl_mode: String
    var tls: TlsConfig
    var connect_timeout_ms: Int
    var timeout_ms: Int

    def __init__(out self):
        self.host = "127.0.0.1"
        self.port = 3306
        self.user = "root"
        self.password = String()
        self.database = String()
        self.ssl_mode = "preferred"
        self.tls = TlsConfig(verify=TlsVerify.ENCRYPT_ONLY)
        self.connect_timeout_ms = 5_000
        self.timeout_ms = 30_000

    @staticmethod
    def from_url(url: String) raises DbError -> MySqlConfig:
        var parsed = DbUrl.parse(url, 3306)
        if parsed.scheme != "mysql" and parsed.scheme != "mariadb":
            raise DbError.usage(
                DB,
                String("expected a mysql:// URL, got ", parsed.scheme, "://"),
            )
        var config = MySqlConfig()
        config.host = parsed.host
        config.port = parsed.port
        if parsed.user != "":
            config.user = parsed.user
        config.password = parsed.password
        config.database = parsed.database
        config.ssl_mode = parsed.option("ssl_mode", "preferred").lower()
        if (
            config.ssl_mode != "disabled"
            and config.ssl_mode != "preferred"
            and config.ssl_mode != "required"
            and config.ssl_mode != "verify_identity"
        ):
            raise DbError.usage(
                DB,
                String(
                    (
                        "ssl_mode must be disabled, preferred, required or"
                        " verify_identity, got '"
                    ),
                    config.ssl_mode,
                    "'",
                ),
            )
        if config.ssl_mode == "verify_identity":
            config.tls.verify = TlsVerify.REQUIRED
        var ca = parsed.option("ssl_ca", "")
        if ca != "":
            config.tls.ca_bundle = ca
        config.connect_timeout_ms = parsed.int_option(
            "connect_timeout_ms", 5_000
        )
        config.timeout_ms = parsed.int_option("timeout_ms", 30_000)
        return config^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "mysql://",
            self.user,
            "@",
            self.host,
            ":",
            self.port,
            "/",
            self.database,
        )


struct MySqlConnection(Connection):
    """A session with the server. A `MySql` pool hands each caller its own."""

    comptime Config = MySqlConfig

    var _stream: DbStream
    var _seq: Int
    var _capabilities: Int
    var _status: Int
    var _broken: Bool
    var server_version: String

    def __init__(out self, var stream: DbStream):
        self._stream = stream^
        self._seq = 0
        self._capabilities = 0
        self._status = 0
        self._broken = False
        self.server_version = String()

    @staticmethod
    def open(config: MySqlConfig) raises DbError -> MySqlConnection:
        var stream = DbStream.connect(
            config.host, config.port, config.connect_timeout_ms, DB
        )
        stream.set_timeout(config.timeout_ms)
        var conn = MySqlConnection(stream^)
        conn._handshake(config)
        return conn^

    # ── Packets ─────────────────────────────────────────────────────────────

    def _read_packet(mut self) raises DbError -> List[UInt8]:
        """One logical packet, joined from 16 MB pieces if it was split."""
        var payload = List[UInt8]()
        while True:
            self._stream.fill(4)
            var header = self._stream.unread()
            var length = (
                Int(header[0]) | (Int(header[1]) << 8) | (Int(header[2]) << 16)
            )
            var seq = Int(header[3])
            if seq != self._seq:
                raise DbError.protocol(
                    DB,
                    String(
                        "packet out of order: got ",
                        seq,
                        ", expected ",
                        self._seq,
                    ),
                )
            self._seq = (seq + 1) & 0xFF
            self._stream.skip(4)
            payload.extend(Span(self._stream.take(length)))
            if length < protocol.MAX_PACKET:
                return payload^

    def _write_packet(mut self, payload: Span[UInt8, _]) raises DbError:
        var framed = protocol.frame(payload, self._seq)
        self._seq = framed[1]
        self._stream.write(framed[0])

    def _command(mut self, payload: Span[UInt8, _]) raises DbError:
        self._seq = 0
        self._write_packet(payload)

    # ── Connecting ──────────────────────────────────────────────────────────

    def _handshake(mut self, config: MySqlConfig) raises DbError:
        var greeting = protocol.parse_handshake(self._read_packet())
        self.server_version = greeting.server_version
        var server_tls = greeting.capabilities & protocol.CLIENT_SSL != 0
        var use_tls = config.ssl_mode != "disabled" and server_tls
        if (
            config.ssl_mode != "disabled"
            and config.ssl_mode != "preferred"
            and not server_tls
        ):
            raise DbError.connect(
                DB,
                "server does not offer TLS (ssl_mode=" + config.ssl_mode + ")",
            )
        self._capabilities = protocol.client_capabilities(
            greeting.capabilities, use_tls
        )
        if use_tls:
            self._write_packet(protocol.ssl_request(self._capabilities))
            self._stream.start_tls(config.host, config.tls)

        var plugin = greeting.plugin
        if (
            plugin != "caching_sha2_password"
            and plugin != "mysql_native_password"
        ):
            plugin = "mysql_native_password"
        var nonce = greeting.nonce.copy()
        self._write_packet(
            protocol.handshake_response(
                self._capabilities,
                config.user,
                protocol.scramble(plugin, config.password, nonce),
                config.database,
                plugin,
            )
        )
        self._finish_auth(config, plugin^, nonce^)

    def _finish_auth(
        mut self,
        config: MySqlConfig,
        var plugin: String,
        var nonce: List[UInt8],
    ) raises DbError:
        while True:
            var packet = self._read_packet()
            if len(packet) == 0:
                raise DbError.protocol(DB, "empty packet during authentication")
            var head = Int(packet[0])
            if head == 0x00:
                self._status = protocol.parse_ok(packet).status
                return
            if head == 0xFF:
                var error = protocol.parse_error(packet, DbError.AUTH)
                error.kind = DbError.AUTH
                raise error^
            if head == 0xFE:
                # Auth switch: the server wants another plugin.
                var r = ByteReader(Span(packet), DB)
                r.skip(1)
                plugin = r.cstr()
                nonce = List[UInt8](r.rest())
                if len(nonce) > 0 and nonce[len(nonce) - 1] == 0:
                    _ = nonce.pop()
                self._write_packet(
                    protocol.scramble(plugin, config.password, nonce)
                )
            elif head == 0x01:
                self._more_auth_data(config, packet, nonce)
            else:
                raise DbError.protocol(
                    DB, String("unexpected authentication packet ", head)
                )

    def _more_auth_data(
        mut self, config: MySqlConfig, packet: List[UInt8], nonce: List[UInt8]
    ) raises DbError:
        """caching_sha2_password's extra steps."""
        if len(packet) == 2 and packet[1] == 3:
            return  # fast path: the server had our hash cached; OK follows
        if len(packet) == 2 and packet[1] == 4:
            if self._stream.is_tls():
                var plain = List[UInt8](config.password.as_bytes())
                plain.append(0)
                self._write_packet(plain)
            else:
                self._write_packet([UInt8(2)])  # ask for the RSA public key
            return
        # The public key, after we asked for it.
        try:
            var encrypted = rsa_oaep_encrypt(
                Span(packet)[1:], protocol.xor_password(config.password, nonce)
            )
            self._write_packet(encrypted)
        except e:
            raise DbError.auth(DB, String(e))

    # ── Queries ─────────────────────────────────────────────────────────────

    def query(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Rows:
        """Run one statement with `?` placeholders; return its rows."""
        self._check_usable()
        try:
            if len(params) == 0:
                self._command(
                    protocol.command(protocol.COM_QUERY, sql.as_bytes())
                )
                return self._read_results(binary=False)
            return self._prepared(sql, params)
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
        """Run several `;`-separated statements without parameters. Multi
        statements are switched on for this call only."""
        self._check_usable()
        try:
            self._set_multi_statements(True)
            self._command(protocol.command(protocol.COM_QUERY, sql.as_bytes()))
            var failure = Optional[DbError](None)
            var affected = 0
            try:
                affected = self._read_results(binary=False).affected
            except e:
                if e.breaks_connection():
                    raise e^
                failure = e^
            self._set_multi_statements(False)
            if failure:
                raise failure.take()
            return affected
        except e:
            if e.breaks_connection():
                self._broken = True
            raise e^

    def _set_multi_statements(mut self, on: Bool) raises DbError:
        var option = List[UInt8]()
        option.append(UInt8(0) if on else UInt8(1))
        option.append(0)
        self._command(protocol.command(protocol.COM_SET_OPTION, option))
        var reply = self._read_packet()
        if protocol.is_err(reply):
            raise protocol.parse_error(reply)

    def _prepared(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Rows:
        self._command(
            protocol.command(protocol.COM_STMT_PREPARE, sql.as_bytes())
        )
        var first = self._read_packet()
        if protocol.is_err(first):
            raise protocol.parse_error(first)
        var prepared = protocol.parse_prepare_ok(first)
        var scratch = Rows()
        for _ in range(prepared.params):
            _ = protocol.parse_column(self._read_packet(), scratch)
        if prepared.params > 0:
            self._skip_eof()
        for _ in range(prepared.columns):
            _ = protocol.parse_column(self._read_packet(), scratch)
        if prepared.columns > 0:
            self._skip_eof()
        if prepared.params != len(params):
            self._close_statement(prepared.statement_id)
            raise DbError.usage(
                DB,
                String(
                    "statement has ",
                    prepared.params,
                    " placeholders, got ",
                    len(params),
                    " values",
                ),
            )
        self._command(protocol.stmt_execute(prepared.statement_id, params))
        var failure = Optional[DbError](None)
        var rows = Rows()
        try:
            rows = self._read_results(binary=True)
        except e:
            if e.breaks_connection():
                raise e^
            failure = e^
        self._close_statement(prepared.statement_id)
        if failure:
            raise failure.take()
        return rows^

    def _close_statement(mut self, statement_id: Int) raises DbError:
        var body = List[UInt8]()
        protocol.put_le(body, statement_id, 4)
        self._command(protocol.command(protocol.COM_STMT_CLOSE, body))
        # No reply to COM_STMT_CLOSE.

    def _skip_eof(mut self) raises DbError:
        if self._capabilities & protocol.CLIENT_DEPRECATE_EOF == 0:
            _ = self._read_packet()

    def _read_results(mut self, binary: Bool) raises DbError -> Rows:
        """Every result set of the command; keeps the last one with rows."""
        var kept = Rows()
        while True:
            var first = self._read_packet()
            if protocol.is_err(first):
                raise protocol.parse_error(first)
            if protocol.is_ok(first):
                var ok = protocol.parse_ok(first)
                self._status = ok.status
                kept.affected = ok.affected
                kept.last_insert_id = ok.last_insert_id
                if ok.status & protocol.STATUS_MORE_RESULTS == 0:
                    return kept^
                continue
            var rows = Rows()
            var r = ByteReader(Span(first), DB)
            var count = protocol.read_lenenc(r)
            var columns = List[ColumnInfo](capacity=count)
            for _ in range(count):
                columns.append(protocol.parse_column(self._read_packet(), rows))
            self._skip_eof()
            while True:
                var packet = self._read_packet()
                if protocol.is_err(packet):
                    raise protocol.parse_error(packet)
                if protocol.is_eof(packet):
                    var status = 0
                    if self._capabilities & protocol.CLIENT_DEPRECATE_EOF != 0:
                        status = protocol.parse_ok(packet).status
                    elif len(packet) >= 5:
                        status = Int(packet[3]) | (Int(packet[4]) << 8)
                    self._status = status
                    break
                if binary:
                    protocol.parse_binary_row(packet, columns, rows)
                else:
                    protocol.parse_text_row(packet, columns, rows)
            kept = rows^
            if self._status & protocol.STATUS_MORE_RESULTS == 0:
                return kept^

    def _check_usable(self) raises DbError:
        if self._broken:
            raise DbError.io(DB, "connection is broken by an earlier error")

    def in_transaction(self) -> Bool:
        return self._status & protocol.STATUS_IN_TRANS != 0

    # ── Pool hooks ──────────────────────────────────────────────────────────

    def ping(mut self) -> Bool:
        if self._broken:
            return False
        try:
            self._command(protocol.command(protocol.COM_PING, List[UInt8]()))
            var reply = self._read_packet()
            if protocol.is_ok(reply):
                return True
        except:
            pass
        self._broken = True
        return False

    def broken(self) -> Bool:
        return self._broken

    def reset(mut self) -> Bool:
        if not self.in_transaction():
            return True
        try:
            _ = self.query("ROLLBACK", List[Param]())
            return not self.in_transaction()
        except:
            return False

    def close(mut self):
        if not self._broken:
            try:
                self._command(
                    protocol.command(protocol.COM_QUIT, List[UInt8]())
                )
            except:
                pass
        self._broken = True
        self._stream.close()

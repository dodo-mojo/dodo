"""One HTTP keep-alive connection to a ClickHouse server."""

from ...http import HttpClient
from ...http.request import Request
from ...tls import TlsConfig, TlsVerify
from .._url import DbUrl
from ..error import DbError
from ..param import Param
from ..pool import Connection
from ..rows import Rows
from . import protocol
from .protocol import DB


struct ClickHouseConfig(Copyable, Writable):
    """Where and how to connect.

    Usually built from a URL:

    `clickhouse://user:password@host:8123/database` (HTTP), or
    `clickhouses://user:password@host:8443/database` (HTTPS).

    URL options:

    - `tls_verify` (`clickhouses://` only): `true` (default: the
      certificate must be trusted and name the host) or `false`.
    - `tls_ca`: a CA bundle for a server with a private CA.
    - `connect_timeout_ms` (default 5000) and `timeout_ms` (default
      300000; analytical queries run long).
    - Any other option is passed on as a ClickHouse setting, for
      example `max_execution_time=60`.
    """

    var host: String
    var port: Int
    var user: String
    var password: String
    var database: String
    var use_tls: Bool
    var tls: TlsConfig
    var connect_timeout_ms: Int
    var timeout_ms: Int
    var settings: List[Tuple[String, String]]

    def __init__(out self):
        self.host = "127.0.0.1"
        self.port = 8123
        self.user = "default"
        self.password = String()
        self.database = "default"
        self.use_tls = False
        self.tls = TlsConfig()
        self.connect_timeout_ms = 5_000
        self.timeout_ms = 300_000
        self.settings = List[Tuple[String, String]]()

    @staticmethod
    def from_url(url: String) raises DbError -> ClickHouseConfig:
        var secure = url.startswith("clickhouses://")
        var parsed = DbUrl.parse(url, 8443 if secure else 8123)
        if parsed.scheme != "clickhouse" and not secure:
            raise DbError.usage(
                DB,
                String(
                    "expected a clickhouse:// URL, got ", parsed.scheme, "://"
                ),
            )
        var config = ClickHouseConfig()
        config.host = parsed.host
        config.port = parsed.port
        if parsed.user != "":
            config.user = parsed.user
        config.password = parsed.password
        if parsed.database != "":
            config.database = parsed.database
        config.use_tls = secure
        for ref pair in parsed.options:
            var key = pair[0]
            var value = pair[1]
            if key == "tls_verify":
                if value.lower() == "false":
                    config.tls.verify = TlsVerify.ENCRYPT_ONLY
            elif key == "tls_ca":
                config.tls.ca_bundle = value
            elif key == "connect_timeout_ms":
                config.connect_timeout_ms = parsed.int_option(key, 5_000)
            elif key == "timeout_ms":
                config.timeout_ms = parsed.int_option(key, 300_000)
            else:
                config.settings.append((key, value))
        return config^

    def base_url(self) -> String:
        var scheme = "https://" if self.use_tls else "http://"
        return String(scheme, self.host, ":", self.port, "/")

    def write_to[W: Writer](self, mut writer: W):
        var scheme = "clickhouses://" if self.use_tls else "clickhouse://"
        writer.write(
            scheme,
            self.user,
            "@",
            self.host,
            ":",
            self.port,
            "/",
            self.database,
        )


struct ClickHouseConnection(Connection):
    """An HTTP client with one keep-alive connection. Not safe to share
    between threads; a `ClickHouse` pool hands each caller its own."""

    comptime Config = ClickHouseConfig

    var _client: HttpClient
    var _config: ClickHouseConfig
    var _broken: Bool

    def __init__(out self, var client: HttpClient, config: ClickHouseConfig):
        self._client = client^
        self._config = config.copy()
        self._broken = False

    @staticmethod
    def open(config: ClickHouseConfig) raises DbError -> ClickHouseConnection:
        var client: HttpClient
        try:
            client = (
                HttpClient(
                    config.tls,
                    max_redirects=0,
                    timeout_ms=config.connect_timeout_ms,
                )
                .with_pool(max_idle_per_host=1, max_idle_total=1)
                .with_read_timeout(config.timeout_ms)
            )
        except e:
            raise DbError.connect(
                DB, String("can't set up the HTTP client: ", e)
            )
        var conn = ClickHouseConnection(client^, config)
        # HTTP authenticates per request; one cheap query now makes a bad
        # password or an unreachable server fail here, not on first use.
        try:
            _ = conn.query("SELECT 1", List[Param]())
        except e:
            var error = e.copy()
            if error.kind != DbError.AUTH:
                error.kind = DbError.CONNECT
            raise error^
        return conn^

    def query(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Rows:
        """Run one statement with `{p1:Type}` parameters; return its rows.
        `affected` is the rows an INSERT wrote."""
        if self._broken:
            raise DbError.io(DB, "connection is broken by an earlier error")
        var url = self._config.base_url() + protocol.query_string(
            self._config.database, self._config.settings, params, sql
        )
        var status: Int
        var code: String
        var summary: String
        var body: List[UInt8]
        try:
            var request = Request("POST", url, List[UInt8](sql.as_bytes()))
            request.headers.set("X-ClickHouse-User", self._config.user)
            request.headers.set("X-ClickHouse-Key", self._config.password)
            var response = self._client.send(request)
            status = response.status
            code = response.headers.get("X-ClickHouse-Exception-Code")
            summary = response.headers.get("X-ClickHouse-Summary")
            body = response.body.copy()
        except e:
            self._broken = True
            raise DbError.io(DB, String("request failed: ", e))
        if status != 200:
            raise protocol.server_error(
                status, code, String(from_utf8_lossy=Span(body))
            )
        var rows = protocol.decode(Span(body))
        rows.affected = protocol.written_rows(summary)
        return rows^

    def execute(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Int:
        return self.query(sql, params).affected

    def execute_script(mut self, sql: String) raises DbError -> Int:
        """Run `;`-separated statements one by one (ClickHouse takes one
        per request). Returns the rows the last one wrote."""
        var affected = 0
        for statement in protocol.split_script(sql):
            affected = self.query(statement, List[Param]()).affected
        return affected

    # ── Pool hooks ──────────────────────────────────────────────────────────

    def ping(mut self) -> Bool:
        try:
            _ = self.query("SELECT 1", List[Param]())
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

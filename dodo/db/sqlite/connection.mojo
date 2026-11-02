"""One connection to an SQLite database file, through libsqlite3."""

from std.ffi import c_int

from .._url import _decode
from ..error import DbError
from ..param import Param
from ..pool import Connection
from ..rows import Rows
from . import _ffi
from ._ffi import Api, c_bytes, c_string, nul_terminated


comptime DB = "sqlite"


struct SqliteConfig(Copyable, Writable):
    """Which file and how to open it.

    Usually built from a URL:

    - `sqlite:///var/app/data.db`: an absolute path.
    - `sqlite://data.db`: relative to the working directory.
    - `sqlite://:memory:`: a private in-memory database. Every connection
      would get its own, so a pool of one is used.

    URL options:

    - `mode`: `rwc` (default: read, write, create), `rw`, `ro`.
    - `busy_timeout_ms` (default 5000): how long a write waits for
      another connection's lock before failing with `SQLITE_BUSY`.
    - `journal_mode` (default `wal`, so readers don't block the writer;
      `keep` leaves the file's mode alone). WAL also sets
      `synchronous=NORMAL`, the pairing SQLite recommends.
    - `foreign_keys` (default `on`).
    """

    var path: String
    var mode: String
    var busy_timeout_ms: Int
    var journal_mode: String
    var foreign_keys: Bool

    def __init__(out self, path: String = ":memory:"):
        self.path = path
        self.mode = "rwc"
        self.busy_timeout_ms = 5_000
        self.journal_mode = "wal"
        self.foreign_keys = True

    @staticmethod
    def from_url(url: String) raises DbError -> SqliteConfig:
        var rest: String
        if url.startswith("sqlite://"):
            rest = String(url[byte=9:])
        elif url.startswith("sqlite:"):
            rest = String(url[byte=7:])
        else:
            raise DbError.usage(DB, "expected a sqlite:// URL")
        var query = String()
        var path = rest
        var mark = rest.find("?")
        if mark >= 0:
            query = String(rest[byte = mark + 1 :])
            path = String(rest[byte=:mark])
        var config = SqliteConfig(_decode(path))
        if config.path == "":
            raise DbError.usage(DB, "the URL names no database file")
        for item in query.split("&"):
            var eq = item.find("=")
            if eq < 0:
                continue
            var key = String(item[byte=:eq])
            var value = _decode(String(item[byte = eq + 1 :])).lower()
            if key == "mode":
                if value != "rwc" and value != "rw" and value != "ro":
                    raise DbError.usage(
                        DB, "mode must be rwc, rw or ro, got '" + value + "'"
                    )
                config.mode = value
            elif key == "busy_timeout_ms":
                try:
                    config.busy_timeout_ms = Int(value)
                except:
                    raise DbError.usage(DB, "busy_timeout_ms must be a number")
            elif key == "journal_mode":
                if not _is_journal_mode(value):
                    raise DbError.usage(
                        DB, "unknown journal_mode '" + value + "'"
                    )
                config.journal_mode = value
            elif key == "foreign_keys":
                config.foreign_keys = (
                    value == "on" or value == "true" or value == "1"
                )
        return config^

    def in_memory(self) -> Bool:
        return self.path == ":memory:"

    def write_to[W: Writer](self, mut writer: W):
        writer.write("sqlite://", self.path)


def _is_journal_mode(mode: String) -> Bool:
    return (
        mode == "wal"
        or mode == "delete"
        or mode == "truncate"
        or mode == "persist"
        or mode == "memory"
        or mode == "off"
        or mode == "keep"
    )


struct SqliteConnection(Connection):
    """An open database handle. Not safe to share between threads; a
    `Sqlite` pool hands each caller its own."""

    comptime Config = SqliteConfig

    var _api: Api
    var _db: Int
    var _broken: Bool

    def __init__(out self, var api: Api, db: Int):
        self._api = api^
        self._db = db
        self._broken = False

    @staticmethod
    def open(config: SqliteConfig) raises DbError -> SqliteConnection:
        var api: Api
        try:
            api = Api()
        except e:
            raise DbError.connect(DB, String("can't load libsqlite3: ", e))
        var flags = _ffi.OPEN_NOMUTEX
        if config.mode == "ro":
            flags |= _ffi.OPEN_READONLY
        elif config.mode == "rw":
            flags |= _ffi.OPEN_READWRITE
        else:
            flags |= _ffi.OPEN_READWRITE | _ffi.OPEN_CREATE
        var name = nul_terminated(config.path)
        var handle = List[Int](length=1, fill=0)
        var rc = Int(
            api.open_v2(
                Int(name.unsafe_ptr()),
                Int(handle.unsafe_ptr()),
                c_int(flags),
                0,
            )
        )
        _ = name^
        # SQLite allocates a handle even when the open fails; the
        # connection owns it from here and closes it either way.
        var conn = SqliteConnection(api^, handle[0])
        if rc != _ffi.OK:
            var error = conn._error(rc)
            error.kind = DbError.CONNECT
            error.message = String(
                "can't open ", config.path, ": ", error.message
            )
            conn.close()
            raise error^
        _ = conn._api.extended_result_codes(conn._db, c_int(1))
        _ = conn._api.busy_timeout(conn._db, c_int(config.busy_timeout_ms))
        try:
            if config.foreign_keys:
                _ = conn.execute_script("PRAGMA foreign_keys = ON")
            if (
                config.journal_mode != "keep"
                and not config.in_memory()
                and config.mode != "ro"
            ):
                _ = conn.execute_script(
                    "PRAGMA journal_mode = " + config.journal_mode
                )
                if config.journal_mode == "wal":
                    _ = conn.execute_script("PRAGMA synchronous = NORMAL")
        except e:
            conn.close()
            var error = e.copy()
            error.kind = DbError.CONNECT
            raise error^
        return conn^

    # ── Statements ──────────────────────────────────────────────────────────

    def query(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Rows:
        """Run one statement with `?` parameters; return its rows,
        `affected` and `last_insert_id`. More than one statement is
        refused, so a value spliced into the SQL can't add another."""
        self._check_usable()
        var text = nul_terminated(sql)
        var handle = List[Int](length=1, fill=0)
        var tail = List[Int](length=1, fill=0)
        var base = Int(text.unsafe_ptr())
        var rc = Int(
            self._api.prepare_v2(
                self._db,
                base,
                c_int(len(text)),
                Int(handle.unsafe_ptr()),
                Int(tail.unsafe_ptr()),
            )
        )
        if rc != _ffi.OK:
            _ = text^
            raise self._error(rc)
        var stmt = handle[0]
        if stmt == 0:
            _ = text^
            return Rows()
        try:
            self._refuse_second_statement(tail[0], base + len(text) - 1)
            _ = text^
            self._bind(stmt, params)
            var rows = self._step_all(stmt)
            _ = self._api.finalize(stmt)
            return rows^
        except e:
            _ = self._api.finalize(stmt)
            raise e^

    def _refuse_second_statement(mut self, tail: Int, end: Int) raises DbError:
        """Compile what follows the first statement: comments and blanks
        compile to nothing, anything else is a second statement."""
        if tail == 0 or tail >= end:
            return
        var handle = List[Int](length=1, fill=0)
        var rc = Int(
            self._api.prepare_v2(
                self._db, tail, c_int(end - tail), Int(handle.unsafe_ptr()), 0
            )
        )
        if handle[0] != 0:
            _ = self._api.finalize(handle[0])
        if rc != _ffi.OK or handle[0] != 0:
            raise DbError.usage(
                DB, "query runs one statement; use execute_script for several"
            )

    def _bind(mut self, stmt: Int, params: List[Param]) raises DbError:
        var expected = Int(self._api.bind_parameter_count(stmt))
        if expected != len(params):
            raise DbError.usage(
                DB,
                String(
                    "statement has ", expected, " parameters, got ", len(params)
                ),
            )
        for i in range(len(params)):
            ref p = params[i]
            var index = c_int(i + 1)
            var rc: Int
            if p.kind == Param.NULL:
                rc = Int(self._api.bind_null(stmt, index))
            elif p.kind == Param.INT or p.kind == Param.BOOL:
                rc = Int(self._api.bind_int64(stmt, index, Int64(p.int_value)))
            elif p.kind == Param.FLOAT:
                rc = Int(self._api.bind_double(stmt, index, p.float_value))
            elif p.kind == Param.BYTES:
                rc = Int(
                    self._api.bind_blob(
                        stmt,
                        index,
                        Int(p.data.unsafe_ptr()),
                        c_int(len(p.data)),
                        _ffi.TRANSIENT,
                    )
                )
            else:
                rc = Int(
                    self._api.bind_text(
                        stmt,
                        index,
                        Int(p.text.unsafe_ptr()),
                        c_int(p.text.byte_length()),
                        _ffi.TRANSIENT,
                    )
                )
            if rc != _ffi.OK:
                raise self._error(rc)

    def _step_all(mut self, stmt: Int) raises DbError -> Rows:
        var rows = Rows()
        var count = Int(self._api.column_count(stmt))
        for c in range(count):
            rows.add_column(
                c_string(self._api.column_name(stmt, c_int(c))),
                c_string(self._api.column_decltype(stmt, c_int(c))),
            )
        while True:
            var rc = Int(self._api.step(stmt))
            if rc == _ffi.DONE:
                break
            if rc != _ffi.ROW:
                raise self._error(rc)
            for c in range(count):
                self._read_cell(stmt, c_int(c), rows)
            rows.end_row()
        if Int(self._api.stmt_readonly(stmt)) == 0:
            rows.affected = Int(self._api.changes64(self._db))
            rows.last_insert_id = Int(self._api.last_insert_rowid(self._db))
        return rows^

    def _read_cell(self, stmt: Int, c: c_int, mut rows: Rows):
        var kind = Int(self._api.column_type(stmt, c))
        if kind == _ffi.TYPE_INTEGER:
            rows.push_int(Int(self._api.column_int64(stmt, c)))
        elif kind == _ffi.TYPE_FLOAT:
            rows.push_float(self._api.column_double(stmt, c))
        elif kind == _ffi.TYPE_TEXT:
            # column_text before column_bytes, as the SQLite docs require.
            var addr = self._api.column_text(stmt, c)
            var n = Int(self._api.column_bytes(stmt, c))
            rows.push_text(c_bytes(addr, n))
        elif kind == _ffi.TYPE_BLOB:
            var addr = self._api.column_blob(stmt, c)
            var n = Int(self._api.column_bytes(stmt, c))
            if n == 0:
                var empty = List[UInt8]()
                rows.push_bytes(Span(empty))
            else:
                rows.push_bytes(c_bytes(addr, n))
        else:
            rows.push_null()

    def execute(
        mut self, sql: String, params: List[Param]
    ) raises DbError -> Int:
        """Run one statement; return how many rows it changed."""
        return self.query(sql, params).affected

    def execute_script(mut self, sql: String) raises DbError -> Int:
        """Run several `;`-separated statements without parameters (schema
        setup). Returns the rows changed by the last one."""
        self._check_usable()
        var text = nul_terminated(sql)
        var message = List[Int](length=1, fill=0)
        var rc = Int(
            self._api.exec(
                self._db,
                Int(text.unsafe_ptr()),
                0,
                0,
                Int(message.unsafe_ptr()),
            )
        )
        _ = text^
        if message[0] != 0:
            self._api.free(message[0])
        if rc != _ffi.OK:
            raise self._error(rc)
        return Int(self._api.changes64(self._db))

    def in_transaction(self) -> Bool:
        return Int(self._api.get_autocommit(self._db)) == 0

    def _error(mut self, rc: Int) -> DbError:
        var code = Int(self._api.extended_errcode(self._db))
        if code == 0:
            code = rc
        var message = c_string(self._api.errmsg(self._db))
        var primary = code & 0xFF
        if primary == 14:  # SQLITE_CANTOPEN
            return DbError.connect(DB, message)
        if primary == 10:  # SQLITE_IOERR
            self._broken = True
            return DbError(DbError.IO, String(code), message, DB)
        if primary == 21:  # SQLITE_MISUSE
            return DbError(DbError.USAGE, String(code), message, DB)
        return DbError.server(DB, String(code), message)

    def _check_usable(self) raises DbError:
        if self._broken:
            raise DbError.io(DB, "connection is broken by an earlier error")

    # ── Pool hooks ──────────────────────────────────────────────────────────

    def ping(mut self) -> Bool:
        return not self._broken

    def broken(self) -> Bool:
        return self._broken

    def reset(mut self) -> Bool:
        if not self.in_transaction():
            return True
        try:
            _ = self.execute_script("ROLLBACK")
            return not self.in_transaction()
        except:
            return False

    def close(mut self):
        if self._db != 0:
            _ = self._api.close_v2(self._db)
            self._db = 0
        self._broken = True

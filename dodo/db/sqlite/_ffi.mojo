"""The parts of the libsqlite3 C API the driver calls, looked up once per
connection."""

from std.ffi import OwnedDLHandle, c_int
from std.memory import Pointer
from std.os import getenv
from std.sys import CompilationTarget

from ...utils.dylib import dl_sym


comptime OK = 0
comptime ROW = 100
comptime DONE = 101

comptime OPEN_READONLY = 0x1
comptime OPEN_READWRITE = 0x2
comptime OPEN_CREATE = 0x4
comptime OPEN_NOMUTEX = 0x8000
"""Each connection is used by one thread at a time (the pool sees to it),
so SQLite's per-connection mutex is wasted work."""

comptime TYPE_INTEGER = 1
comptime TYPE_FLOAT = 2
comptime TYPE_TEXT = 3
comptime TYPE_BLOB = 4
comptime TYPE_NULL = 5

comptime TRANSIENT = -1
"""Tells a bind call to copy the value before it returns."""


def library_path() -> String:
    """`$DODO_SQLITE_LIB` when set, else libsqlite3 from the pixi
    environment, else whatever `dlopen` finds on the system path."""
    var override = getenv("DODO_SQLITE_LIB", "")
    if override != "":
        return override
    var name = String("libsqlite3.so")
    comptime if CompilationTarget.is_macos():
        name = "libsqlite3.dylib"
    var prefix = getenv("CONDA_PREFIX", "")
    if prefix.startswith("/"):
        # Built with +=, not +: see the dodo.tls.config docstring.
        var path = String("")
        path += prefix
        path += "/lib/"
        path += name
        return path^
    return name^


comptime _Open = def(Int, Int, c_int, Int) thin abi("C") -> c_int
comptime _Db = def(Int) thin abi("C") -> c_int
comptime _DbInt = def(Int, c_int) thin abi("C") -> c_int
comptime _DbAddr = def(Int) thin abi("C") -> Int
comptime _DbI64 = def(Int) thin abi("C") -> Int64
comptime _Prepare = def(Int, Int, c_int, Int, Int) thin abi("C") -> c_int
comptime _Exec = def(Int, Int, Int, Int, Int) thin abi("C") -> c_int
comptime _BindI64 = def(Int, c_int, Int64) thin abi("C") -> c_int
comptime _BindF64 = def(Int, c_int, Float64) thin abi("C") -> c_int
comptime _BindData = def(Int, c_int, Int, c_int, Int) thin abi("C") -> c_int
comptime _ColAddr = def(Int, c_int) thin abi("C") -> Int
comptime _ColInt = def(Int, c_int) thin abi("C") -> c_int
comptime _ColI64 = def(Int, c_int) thin abi("C") -> Int64
comptime _ColF64 = def(Int, c_int) thin abi("C") -> Float64
comptime _Free = def(Int) thin abi("C") -> None


struct Api(Movable):
    """The loaded libsqlite3 and its resolved functions."""

    var lib: OwnedDLHandle
    var open_v2: _Open
    var close_v2: _Db
    var extended_result_codes: _DbInt
    var busy_timeout: _DbInt
    var errmsg: _DbAddr
    var extended_errcode: _Db
    var changes64: _DbI64
    var last_insert_rowid: _DbI64
    var get_autocommit: _Db
    var prepare_v2: _Prepare
    var exec: _Exec
    var free: _Free
    var finalize: _Db
    var step: _Db
    var stmt_readonly: _Db
    var bind_parameter_count: _Db
    var bind_null: _DbInt
    var bind_int64: _BindI64
    var bind_double: _BindF64
    var bind_text: _BindData
    var bind_blob: _BindData
    var column_count: _Db
    var column_name: _ColAddr
    var column_decltype: _ColAddr
    var column_type: _ColInt
    var column_int64: _ColI64
    var column_double: _ColF64
    var column_text: _ColAddr
    var column_blob: _ColAddr
    var column_bytes: _ColInt

    def __init__(out self) raises:
        var lib = OwnedDLHandle(library_path())
        self.open_v2 = dl_sym[_Open](lib, "sqlite3_open_v2")
        self.close_v2 = dl_sym[_Db](lib, "sqlite3_close_v2")
        self.extended_result_codes = dl_sym[_DbInt](
            lib, "sqlite3_extended_result_codes"
        )
        self.busy_timeout = dl_sym[_DbInt](lib, "sqlite3_busy_timeout")
        self.errmsg = dl_sym[_DbAddr](lib, "sqlite3_errmsg")
        self.extended_errcode = dl_sym[_Db](lib, "sqlite3_extended_errcode")
        self.changes64 = dl_sym[_DbI64](lib, "sqlite3_changes64")
        self.last_insert_rowid = dl_sym[_DbI64](
            lib, "sqlite3_last_insert_rowid"
        )
        self.get_autocommit = dl_sym[_Db](lib, "sqlite3_get_autocommit")
        self.prepare_v2 = dl_sym[_Prepare](lib, "sqlite3_prepare_v2")
        self.exec = dl_sym[_Exec](lib, "sqlite3_exec")
        self.free = dl_sym[_Free](lib, "sqlite3_free")
        self.finalize = dl_sym[_Db](lib, "sqlite3_finalize")
        self.step = dl_sym[_Db](lib, "sqlite3_step")
        self.stmt_readonly = dl_sym[_Db](lib, "sqlite3_stmt_readonly")
        self.bind_parameter_count = dl_sym[_Db](
            lib, "sqlite3_bind_parameter_count"
        )
        self.bind_null = dl_sym[_DbInt](lib, "sqlite3_bind_null")
        self.bind_int64 = dl_sym[_BindI64](lib, "sqlite3_bind_int64")
        self.bind_double = dl_sym[_BindF64](lib, "sqlite3_bind_double")
        self.bind_text = dl_sym[_BindData](lib, "sqlite3_bind_text")
        self.bind_blob = dl_sym[_BindData](lib, "sqlite3_bind_blob")
        self.column_count = dl_sym[_Db](lib, "sqlite3_column_count")
        self.column_name = dl_sym[_ColAddr](lib, "sqlite3_column_name")
        self.column_decltype = dl_sym[_ColAddr](lib, "sqlite3_column_decltype")
        self.column_type = dl_sym[_ColInt](lib, "sqlite3_column_type")
        self.column_int64 = dl_sym[_ColI64](lib, "sqlite3_column_int64")
        self.column_double = dl_sym[_ColF64](lib, "sqlite3_column_double")
        self.column_text = dl_sym[_ColAddr](lib, "sqlite3_column_text")
        self.column_blob = dl_sym[_ColAddr](lib, "sqlite3_column_blob")
        self.column_bytes = dl_sym[_ColInt](lib, "sqlite3_column_bytes")
        self.lib = lib^


def c_string(addr: Int) -> String:
    """Copy a NUL-terminated C string; empty for a null pointer."""
    if addr == 0:
        return String()
    var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)
    var n = 0
    while p[unsafe_offset=n] != 0:
        n += 1
    return String(from_utf8_lossy=Span(unsafe_ptr=p, length=n))


def c_bytes(addr: Int, n: Int) -> Span[UInt8, MutUntrackedOrigin]:
    """`n` bytes SQLite owns, valid until the next call on the statement."""
    var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)
    return Span(unsafe_ptr=p, length=n)


def nul_terminated(text: String) -> List[UInt8]:
    var out = List[UInt8](capacity=text.byte_length() + 1)
    out.extend(text.as_bytes())
    out.append(0)
    return out^

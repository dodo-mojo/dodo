"""SQLite through libsqlite3 (FFI) spike.

Proves: open (file and :memory:), prepare, bind (int, float, text, null,
blob), step, typed column reads, errors, changes and last insert rowid.
"""

from std.ffi import OwnedDLHandle, c_int
from std.os import getenv

from dodo.utils.dylib import dl_sym

comptime SQLITE_ROW = 100
comptime SQLITE_DONE = 101
comptime OPEN_FLAGS = 0x2 | 0x4 | 0x8000  # READWRITE | CREATE | NOMUTEX
comptime TRANSIENT = -1


def cstr(s: String) -> List[UInt8]:
    var out = List[UInt8](s.as_bytes())
    out.append(0)
    return out^


def from_c(addr: Int) -> String:
    if addr == 0:
        return String()
    var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)
    var n = 0
    while p[unsafe_offset=n] != 0:
        n += 1
    return String(unsafe_from_utf8=Span(unsafe_ptr=p, length=n))


struct Db(Movable):
    var lib: OwnedDLHandle
    var db: Int

    def __init__(out self, path: String) raises:
        var lib_path = getenv("CONDA_PREFIX") + "/lib/libsqlite3.so"
        self.lib = OwnedDLHandle(lib_path)
        var open = dl_sym[def(Int, Int, c_int, Int) thin abi("C") -> c_int](
            self.lib, "sqlite3_open_v2"
        )
        var out = List[Int](length=1, fill=0)
        var name = cstr(path)
        var rc = open(Int(name.unsafe_ptr()), Int(out.unsafe_ptr()), c_int(OPEN_FLAGS), 0)
        _ = name^
        self.db = out[0]
        if Int(rc) != 0:
            raise Error("open failed: " + String(Int(rc)))

    def errmsg(self) raises -> String:
        var f = dl_sym[def(Int) thin abi("C") -> Int](self.lib, "sqlite3_errmsg")
        return from_c(f(self.db))

    def run(self, sql: String, params: List[String]) raises:
        var prepare = dl_sym[def(Int, Int, c_int, Int, Int) thin abi("C") -> c_int](
            self.lib, "sqlite3_prepare_v2"
        )
        var text = cstr(sql)
        var out = List[Int](length=1, fill=0)
        var rc = prepare(self.db, Int(text.unsafe_ptr()), c_int(-1), Int(out.unsafe_ptr()), 0)
        _ = text^
        if Int(rc) != 0:
            print("  error:", self.errmsg())
            return
        var stmt = out[0]
        var bind_text = dl_sym[def(Int, c_int, Int, c_int, Int) thin abi("C") -> c_int](
            self.lib, "sqlite3_bind_text"
        )
        var bind_null = dl_sym[def(Int, c_int) thin abi("C") -> c_int](self.lib, "sqlite3_bind_null")
        var bind_i64 = dl_sym[def(Int, c_int, Int64) thin abi("C") -> c_int](self.lib, "sqlite3_bind_int64")
        var bind_f64 = dl_sym[def(Int, c_int, Float64) thin abi("C") -> c_int](self.lib, "sqlite3_bind_double")
        var bind_blob = dl_sym[def(Int, c_int, Int, c_int, Int) thin abi("C") -> c_int](
            self.lib, "sqlite3_bind_blob"
        )
        for i in range(len(params)):
            var p = params[i]
            var index = c_int(i + 1)
            if p == "NULL":
                _ = bind_null(stmt, index)
            elif p.startswith("i:"):
                _ = bind_i64(stmt, index, Int64(Int(String(p[byte=2:]))))
            elif p.startswith("f:"):
                _ = bind_f64(stmt, index, Float64(String(p[byte=2:])))
            elif p.startswith("b:"):
                var bytes = List[UInt8](p[byte=2:].as_bytes())
                _ = bind_blob(stmt, index, Int(bytes.unsafe_ptr()), c_int(len(bytes)), TRANSIENT)
                _ = bytes^
            else:
                _ = bind_text(stmt, index, Int(p.unsafe_ptr()), c_int(p.byte_length()), TRANSIENT)
            _ = p^

        var step = dl_sym[def(Int) thin abi("C") -> c_int](self.lib, "sqlite3_step")
        var count = dl_sym[def(Int) thin abi("C") -> c_int](self.lib, "sqlite3_column_count")
        var name = dl_sym[def(Int, c_int) thin abi("C") -> Int](self.lib, "sqlite3_column_name")
        var ctype = dl_sym[def(Int, c_int) thin abi("C") -> c_int](self.lib, "sqlite3_column_type")
        var col_i64 = dl_sym[def(Int, c_int) thin abi("C") -> Int64](self.lib, "sqlite3_column_int64")
        var col_f64 = dl_sym[def(Int, c_int) thin abi("C") -> Float64](self.lib, "sqlite3_column_double")
        var col_text = dl_sym[def(Int, c_int) thin abi("C") -> Int](self.lib, "sqlite3_column_text")
        var col_bytes = dl_sym[def(Int, c_int) thin abi("C") -> c_int](self.lib, "sqlite3_column_bytes")
        var finalize = dl_sym[def(Int) thin abi("C") -> c_int](self.lib, "sqlite3_finalize")
        while True:
            rc = step(stmt)
            if Int(rc) == SQLITE_ROW:
                var line = String("  row:")
                for c in range(Int(count(stmt))):
                    var ci = c_int(c)
                    line += " " + from_c(name(stmt, ci)) + "="
                    var t = Int(ctype(stmt, ci))
                    if t == 1:
                        line += String(col_i64(stmt, ci))
                    elif t == 2:
                        line += String(col_f64(stmt, ci))
                    elif t == 3 or t == 4:
                        var ptr = col_text(stmt, ci)
                        var n = Int(col_bytes(stmt, ci))
                        var p = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=ptr)
                        var s = String(unsafe_from_utf8=Span(unsafe_ptr=p, length=n))
                        line += ("blob:" if t == 4 else "") + s
                    else:
                        line += "NULL"
                print(line)
            elif Int(rc) == SQLITE_DONE:
                var changes = dl_sym[def(Int) thin abi("C") -> c_int](self.lib, "sqlite3_changes")
                var rowid = dl_sym[def(Int) thin abi("C") -> Int64](self.lib, "sqlite3_last_insert_rowid")
                print("  done, changes", Int(changes(self.db)), "last rowid", rowid(self.db))
                break
            else:
                print("  error:", self.errmsg())
                break
        _ = finalize(stmt)

    def __deinit__(deinit self):
        try:
            close_db(self.lib, self.db)
        except:
            pass


def main() raises:
    for path in ["/tmp/dodo_spike.db", ":memory:"]:
        print(path)
        var db = Db(path)
        db.run("select sqlite_version() as v", [])
        db.run("drop table if exists users", [])
        db.run("create table users (id integer primary key, name text not null, score real, data blob, note text)", [])
        db.run(
            "insert into users (name, score, data, note) values (?, ?, ?, ?), (?, ?, ?, ?)",
            ["ada", "f:9.5", "b:\x01raw", "NULL", "bob 'q'; drop table x;-- 🦤", "f:-1.25", "NULL", "n"],
        )
        db.run("select * from users where id >= ? order by id", ["i:1"])
        db.run("insert into users (name) values (?)", ["NULL"])
        db.run("select * from no_such_table", [])
        db.run("select count(*) as n from users", [])


def close_db(imm lib: OwnedDLHandle, db: Int) raises:
    var close = dl_sym[def(Int) thin abi("C") -> c_int](lib, "sqlite3_close_v2")
    _ = close(db)

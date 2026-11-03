"""Tests for dodo.db.sqlite against the libsqlite3 that pixi installs. No Docker."""

from std.collections import Optional
from std.os import remove, rmdir
from std.os.path import exists
from std.tempfile import mkdtemp
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, Param, PoolOptions
from dodo.db.sqlite import Sqlite, SqliteConfig


@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String
    var score: Float64
    var active: Bool
    var note: Optional[String]


struct TempDb(Movable):
    """A database file in a fresh directory, deleted with its WAL files."""

    var dir: String
    var path: String

    def __init__(out self) raises:
        self.dir = mkdtemp()
        self.path = self.dir + "/test.db"

    def url(self, options: String = "") -> String:
        var out = "sqlite://" + self.path
        if options != "":
            out += "?" + options
        return out^

    def __deinit__(deinit self):
        for suffix in ["", "-wal", "-shm", "-journal"]:
            var file = self.path + suffix
            if exists(file):
                try:
                    remove(file)
                except:
                    pass
        try:
            rmdir(self.dir)
        except:
            pass


def setup(db: Sqlite) raises:
    _ = db.execute_script(
        "drop table if exists users; create table users (id integer primary"
        " key, name text not null unique, score real, active bool, note text,"
        " data blob)"
    )


def expect_error(db: Sqlite, sql: String, kind: Int, code: String = "") raises:
    var failed = False
    try:
        _ = db.query(sql)
    except e:
        failed = True
        assert_equal(e.kind, kind, String(e))
        if code != "":
            assert_equal(e.code, code, String(e))
    assert_true(failed, sql + " should fail")


def test_round_trip() raises:
    var db = Sqlite("sqlite://:memory:")
    setup(db)
    var evil = String("bob'); drop table users;-- héllo 🦤")
    var result = db.query(
        (
            "insert into users (name, score, active, note) values (?, ?, ?, ?),"
            " (?, ?, ?, ?)"
        ),
        "ada",
        9.5,
        True,
        Param.null(),
        evil,
        -1.25,
        False,
        Optional[String]("n"),
    )
    assert_equal(result.affected, 2)
    assert_equal(result.last_insert_id, 2)
    var rows = db.query(
        (
            "select id, name, score, active, note from users where id >= ?"
            " order by id"
        ),
        1,
    )
    assert_equal(len(rows), 2)
    assert_equal(rows[0].int("id"), 1)
    assert_equal(rows[0].float("score"), 9.5)
    assert_true(rows[0].bool("active"))
    assert_true(rows[0].is_null("note"))
    assert_equal(rows[1].string("name"), evil)
    assert_equal(rows.columns[2].type_name, "REAL")
    var users = rows.to[User]()
    assert_equal(users[1].name, evil)
    assert_equal(users[1].note.value(), "n")
    assert_false(users[1].active)
    assert_equal(db.query("select count(*) as n from users")[0].int("n"), 2)
    # A select changes nothing, whatever ran before it.
    assert_equal(db.query("select 1").affected, 0)


def test_bytes_and_large() raises:
    var db = Sqlite("sqlite://:memory:")
    setup(db)
    var blob = List[UInt8]()
    for i in range(256):
        blob.append(UInt8(i))
    _ = db.execute(
        "insert into users (name, data) values (?, ?)",
        "blob",
        Param.bytes(blob),
    )
    _ = db.execute(
        "insert into users (name, data) values (?, ?)",
        "empty",
        Param.bytes(List[UInt8]()),
    )
    var data = db.query("select data from users where name = ?", "blob")[
        0
    ].bytes("data")
    assert_equal(len(data), 256)
    assert_equal(Int(data[0]), 0)
    assert_equal(Int(data[255]), 255)
    assert_equal(
        len(
            db.query("select data from users where name = ?", "empty")[0].bytes(
                "data"
            )
        ),
        0,
    )

    var big = String()
    for _ in range(100_000):
        big += "0123456789"
    assert_equal(
        db.query("select ? as big", big)[0].string("big").byte_length(),
        1_000_000,
    )
    var many = db.query(
        "with recursive seq(n) as (select 1 union all select n + 1 from seq"
        " where n < 20000) select n from seq"
    )
    assert_equal(len(many), 20_000)
    assert_equal(many[19_999].int("n"), 20_000)


def test_errors() raises:
    var db = Sqlite("sqlite://:memory:")
    setup(db)
    expect_error(db, "selec 1", DbError.SERVER, "1")
    expect_error(db, "select * from no_such_table", DbError.SERVER, "1")
    expect_error(db, "select 1; drop table users", DbError.USAGE)
    expect_error(db, "select 1; select 2", DbError.USAGE)
    var failed = False
    try:
        _ = db.query("select ? + ?", 1)
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "wrong parameter count should fail")
    # Trailing blanks, semicolons and comments are not a second statement.
    assert_equal(db.query("select 2 as two;  -- done\n")[0].int("two"), 2)
    assert_equal(len(db.query("")), 0)
    # The connection survived every error above.
    assert_equal(db.query("select 1 + ? as two", 1)[0].int("two"), 2)


def test_constraints() raises:
    var db = Sqlite("sqlite://:memory:")
    setup(db)
    _ = db.execute("insert into users (id, name) values (?, ?)", 1, "a")
    for sql in [
        "insert into users (id, name) values (1, 'b')",
        "insert into users (id, name) values (2, 'a')",
    ]:
        var failed = False
        try:
            _ = db.execute(sql)
        except e:
            failed = True
            assert_true(e.is_duplicate(), String(e))
        assert_true(failed, sql + " should fail")
    _ = db.execute_script(
        "create table posts (id integer primary key, user_id integer not null"
        " references users(id))"
    )
    expect_error(
        db, "insert into posts (user_id) values (99)", DbError.SERVER, "787"
    )


def test_transactions() raises:
    var file = TempDb()
    var db = Sqlite(file.url())
    setup(db)
    var tx = db.transaction()
    _ = tx.execute("insert into users (id, name) values (?, ?)", 1, "kept")
    tx.commit()
    abandon_transaction(db)
    var tx2 = db.transaction()
    _ = tx2.execute(
        "insert into users (id, name) values (?, ?)", 3, "rolled back"
    )
    tx2.rollback()
    var rows = db.query("select id from users order by id")
    assert_equal(len(rows), 1)
    assert_equal(rows[0].int("id"), 1)
    _ = file^  # keep the directory until the pools are gone


def abandon_transaction(db: Sqlite) raises:
    """Dropped without commit: rolled back when it goes back to the pool."""
    var abandoned = db.transaction()
    _ = abandoned.execute(
        "insert into users (id, name) values (?, ?)", 2, "dropped"
    )


def test_file_settings() raises:
    var file = TempDb()
    var db = Sqlite(file.url())
    assert_equal(
        db.query("pragma journal_mode")[0].string("journal_mode"), "wal"
    )
    assert_equal(db.query("pragma foreign_keys")[0].int("foreign_keys"), 1)
    setup(db)
    _ = db.execute("insert into users (name) values (?)", "ada")

    # Another pool on the same file sees the row; a read-only one can't write.
    var reader = Sqlite(file.url("mode=ro"))
    assert_equal(
        reader.query("select name from users")[0].string("name"), "ada"
    )
    expect_error(
        reader, "insert into users (name) values ('x')", DbError.SERVER, "8"
    )

    var kept = Sqlite(file.url("journal_mode=keep&foreign_keys=off"))
    assert_equal(kept.query("pragma foreign_keys")[0].int("foreign_keys"), 0)
    _ = file^  # keep the directory until the pools are gone


def test_busy_writer() raises:
    """A second writer waits busy_timeout_ms for the lock, then fails."""
    var file = TempDb()
    var db = Sqlite(file.url())
    setup(db)
    var holder = db.transaction()
    _ = holder.execute("insert into users (name) values (?)", "holder")
    var impatient = Sqlite(file.url("busy_timeout_ms=50"))
    var failed = False
    try:
        _ = impatient.execute("insert into users (name) values (?)", "late")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
        assert_equal(e.code, "5")
    assert_true(failed, "a write during another's transaction should time out")
    holder.commit()
    _ = impatient.execute("insert into users (name) values (?)", "late")
    _ = file^  # keep the directory until the pools are gone


def test_pool() raises:
    var memory = Sqlite("sqlite://:memory:")
    _ = memory.execute_script("create table t (x)")
    _ = memory.execute("insert into t values (?)", 1)
    # One connection for :memory:, so the table is still there.
    assert_equal(memory.query("select count(*) as n from t")[0].int("n"), 1)
    assert_equal(memory.open_count(), 1)

    var file = TempDb()
    var options = PoolOptions()
    options.max_size = 1
    options.acquire_timeout_ms = 100
    var db = Sqlite(file.url(), options)
    var held = db.connection()
    var failed = False
    try:
        _ = db.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.POOL_TIMEOUT)
    assert_true(failed, "second checkout should time out")
    _ = held^
    assert_equal(db.query("select 1 as one")[0].int("one"), 1)
    _ = file^  # keep the directory until the pools are gone


def test_urls() raises:
    assert_equal(
        SqliteConfig.from_url("sqlite:///var/app/data.db").path,
        "/var/app/data.db",
    )
    assert_equal(SqliteConfig.from_url("sqlite://data.db").path, "data.db")
    assert_equal(SqliteConfig.from_url("sqlite::memory:").path, ":memory:")
    assert_equal(
        SqliteConfig.from_url("sqlite:///my%20app.db?mode=ro").path,
        "/my app.db",
    )
    assert_equal(SqliteConfig.from_url("sqlite:///a.db?mode=RO").mode, "ro")
    for bad in [
        "postgres://x",
        "sqlite://",
        "sqlite:///a.db?mode=rwx",
        "sqlite:///a.db?journal_mode=nope",
    ]:
        var failed = False
        try:
            _ = SqliteConfig.from_url(bad)
        except e:
            failed = True
            assert_equal(e.kind, DbError.USAGE)
        assert_true(failed, bad + " should be refused")


def test_cant_open() raises:
    var db = Sqlite("sqlite:///no/such/dir/x.db")
    var failed = False
    try:
        _ = db.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.CONNECT)
    assert_true(failed, "a file in a missing directory can't open")
    assert_equal(db.open_count(), 0)


def main() raises:
    test_round_trip()
    test_bytes_and_large()
    test_errors()
    test_constraints()
    test_transactions()
    test_file_settings()
    test_busy_writer()
    test_pool()
    test_urls()
    test_cant_open()
    print("test_sqlite: 10 passed")

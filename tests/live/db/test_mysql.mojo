"""Live tests: dodo.db.mysql against MySQL 8.4 and MariaDB 11 in Docker.

    docker compose -f tests/live/db/compose.yaml up -d --wait
    pixi run tests-db
"""

from std.collections import Optional
from std.os import getenv
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, Param, PoolOptions
from dodo.db.mysql import MySql


def mysql_url() -> String:
    return getenv(
        "DODO_TEST_MYSQL", "mysql://dodo:dodo-test@127.0.0.1:43306/dodo"
    )


def mysql_root_url() -> String:
    return getenv(
        "DODO_TEST_MYSQL_ROOT", "mysql://root:dodo-root@127.0.0.1:43306/dodo"
    )


def mariadb_url() -> String:
    return getenv(
        "DODO_TEST_MARIADB", "mysql://dodo:dodo-test@127.0.0.1:43307/dodo"
    )


@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String
    var score: Float64
    var active: Bool
    var note: Optional[String]


def setup(db: MySql) raises:
    _ = db.execute_script(
        "drop table if exists dodo_users;"
        " create table dodo_users (id bigint primary key auto_increment,"
        " name varchar(200) not null, score double, active bool, note text,"
        " data blob, born date, seen datetime(6), big bigint unsigned)"
        " character set utf8mb4"
    )


def check_round_trip(db: MySql) raises:
    setup(db)
    var evil = String("bob'); drop table dodo_users;-- héllo 🦤")
    var result = db.query(
        (
            "insert into dodo_users (name, score, active, note) values (?, ?,"
            " ?, ?), (?, ?, ?, ?)"
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
    assert_equal(result.last_insert_id, 1)

    # With parameters: prepared statement, binary rows.
    var rows = db.query(
        (
            "select id, name, score, active, note from dodo_users where id >= ?"
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
    var users = rows.to[User]()
    assert_equal(users[1].name, evil)
    assert_equal(users[1].note.value(), "n")

    # Without parameters: text protocol, same answers.
    var text_rows = db.query(
        "select id, name, score, active, note from dodo_users order by id"
    )
    var text_users = text_rows.to[User]()
    assert_equal(text_users[0].score, 9.5)
    assert_false(text_users[1].active)
    assert_equal(text_users[1].name, evil)


def check_types(db: MySql) raises:
    setup(db)
    var blob = List[UInt8]()
    for i in range(256):
        blob.append(UInt8(i))
    _ = db.execute(
        (
            "insert into dodo_users (name, data, born, seen, big) values (?, ?,"
            " ?, ?, ?)"
        ),
        "types",
        Param.bytes(blob),
        "1815-12-10",
        "2026-11-02 10:30:00.123456",
        "18446744073709551615",
    )
    for binary in [True, False]:
        var rows = db.query(
            "select data, born, seen, big from dodo_users where id = ?", 1
        ) if binary else db.query(
            "select data, born, seen, big from dodo_users"
        )
        var data = rows[0].bytes("data")
        assert_equal(len(data), 256)
        assert_equal(Int(data[255]), 255)
        assert_equal(rows[0].string("born"), "1815-12-10")
        assert_equal(rows[0].string("seen"), "2026-11-02 10:30:00.123456")
        assert_equal(rows[0].string("big"), "18446744073709551615")


def check_errors(db: MySql) raises:
    var failed = False
    try:
        _ = db.query("selec 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
        assert_equal(e.code, "1064")
    assert_true(failed, "bad SQL should fail")
    failed = False
    try:
        _ = db.query("select * from no_such_table where id = ?", 1)
    except e:
        failed = True
        assert_equal(e.code, "1146")
    assert_true(failed, "missing table should fail")
    failed = False
    try:
        _ = db.query("select ? + ?", 1)
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "wrong parameter count should fail")
    assert_equal(db.query("select 1 + ? as two", 1)[0].int("two"), 2)


def check_duplicate(db: MySql) raises:
    setup(db)
    _ = db.execute("insert into dodo_users (id, name) values (?, ?)", 1, "a")
    var failed = False
    try:
        _ = db.execute(
            "insert into dodo_users (id, name) values (?, ?)", 1, "b"
        )
    except e:
        failed = True
        assert_true(e.is_duplicate())
    assert_true(failed, "duplicate key should fail")


def abandon_transaction(db: MySql) raises:
    var abandoned = db.transaction()
    _ = abandoned.execute(
        "insert into dodo_users (id, name) values (?, ?)", 2, "dropped"
    )


def check_transactions(db: MySql) raises:
    setup(db)
    var tx = db.transaction()
    _ = tx.execute("insert into dodo_users (id, name) values (?, ?)", 1, "kept")
    tx.commit()
    abandon_transaction(db)
    var tx2 = db.transaction()
    _ = tx2.execute(
        "insert into dodo_users (id, name) values (?, ?)", 3, "rolled back"
    )
    tx2.rollback()
    var rows = db.query("select id from dodo_users order by id")
    assert_equal(len(rows), 1)
    assert_equal(rows[0].int("id"), 1)


def check_large(db: MySql) raises:
    var big = String()
    for _ in range(100_000):
        big += "0123456789"
    var echoed = db.query("select ? as big", big)[0].string("big")
    assert_equal(echoed.byte_length(), 1_000_000)
    var many = db.query(
        "with d(n) as (select 0 union all select 1 union all select 2 union all"
        " select 3 union all select 4 union all select 5 union all select 6"
        " union all select 7 union all select 8 union all select 9) select a.n"
        " + 10 * b.n + 100 * c.n + 1000 * e.n + 10000 * f.n + 1 as n from d a,"
        " d b, d c, d e, d f where a.n + 10 * b.n + 100 * c.n + 1000 * e.n +"
        " 10000 * f.n < 20000 order by n"
    )
    assert_equal(len(many), 20000)
    assert_equal(many[19999].int("n"), 20000)


def check_injection_needs_script(db: MySql) raises:
    """A plain query can't stack a second statement."""
    var failed = False
    try:
        _ = db.query("select 1; drop table dodo_users")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
    assert_true(failed, "stacked statements should be refused")


def pool_of(size: Int) -> PoolOptions:
    var options = PoolOptions()
    options.max_size = size
    options.acquire_timeout_ms = 300
    return options^


def check_pool_limits(url: String) raises:
    var db = MySql(url, pool_of(1))
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
    assert_equal(db.open_count(), 1)


def check_bad_password(url: String) raises:
    var db = MySql(url)
    var failed = False
    try:
        _ = db.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
        assert_equal(e.code, "1045")
    assert_true(failed, "wrong password should fail")


def uses_tls(db: MySql) raises -> Bool:
    return (
        db.query("show session status like 'Ssl_cipher'")[0].string("Value")
        != ""
    )


def fails_to_connect(url: String, why: String) raises:
    var db = MySql(url)
    var failed = False
    try:
        _ = db.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.CONNECT)
    assert_true(failed, why)


def check_tls_modes() raises:
    """The mysql client's modes: preferred and required encrypt without
    checking the certificate; verify_identity checks it against ssl_ca."""
    var base = "mysql://dodo:dodo-test@127.0.0.1:43306/dodo?ssl_mode="
    assert_true(uses_tls(MySql(base + "preferred")), "preferred should encrypt")
    assert_true(uses_tls(MySql(base + "required")), "required should encrypt")
    assert_false(uses_tls(MySql(base + "disabled")), "disabled should not")
    fails_to_connect(
        base + "verify_identity", "a self-signed cert should not verify"
    )
    var verified = MySql(
        "mysql://dodo:dodo-test@localhost:43306/dodo?ssl_mode=verify_identity&ssl_ca="
        + test_ca()
    )
    assert_true(uses_tls(verified), "verify_identity should encrypt")
    # Trusted, but it names localhost, not 127.0.0.1.
    fails_to_connect(
        base + "verify_identity&ssl_ca=" + test_ca(),
        "the cert does not name 127.0.0.1",
    )


def test_ca() -> String:
    return getenv("DODO_TEST_CA", "build/db-certs/server.crt")


def run_suite(label: String, url: String) raises:
    var db = MySql(url)
    check_round_trip(db)
    check_types(db)
    check_errors(db)
    check_duplicate(db)
    check_transactions(db)
    check_large(db)
    check_injection_needs_script(db)
    check_pool_limits(url)
    print("  ", label, ": ok")


def test_mysql() raises:
    run_suite("mysql", mysql_url())
    check_bad_password("mysql://dodo:wrong@127.0.0.1:43306/dodo")
    check_tls_modes()


def test_mysql_full_auth() raises:
    """After FLUSH PRIVILEGES the server has no cached hash, so the next
    login takes full authentication: inside TLS by default, and with the
    server's RSA key on a plain connection."""
    var tls = MySql(mysql_root_url())
    _ = tls.execute("flush privileges")
    var plain = MySql(mysql_root_url() + "?ssl_mode=disabled")
    assert_equal(
        plain.query("select current_user() as u")[0].string("u"), "root@%"
    )
    _ = tls.execute("flush privileges")
    var fresh = MySql(mysql_root_url())
    assert_equal(
        fresh.query("select current_user() as u")[0].string("u"), "root@%"
    )
    var cipher = fresh.query("show session status like 'Ssl_cipher'")
    assert_true(cipher[0].string("Value") != "", "default mode should encrypt")


def test_mariadb() raises:
    run_suite("mariadb", mariadb_url())
    check_bad_password("mysql://dodo:wrong@127.0.0.1:43307/dodo")


def main() raises:
    test_mysql()
    test_mysql_full_auth()
    test_mariadb()
    print("test_mysql: 3 passed")

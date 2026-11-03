"""Live tests: dodo.db.postgres against PostgreSQL and CockroachDB in Docker.

    docker compose -f tests/live/db/compose.yaml up -d --wait
    pixi run tests-db
"""

from std.collections import Optional
from std.os import getenv
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, Param, PoolOptions
from dodo.db.postgres import Postgres


def postgres_url() -> String:
    return getenv(
        "DODO_TEST_POSTGRES",
        "postgres://dodo:dodo-test@127.0.0.1:45432/dodo?sslmode=prefer",
    )


def cockroach_url() -> String:
    return getenv(
        "DODO_TEST_COCKROACH",
        "postgres://root@127.0.0.1:46257/defaultdb?sslmode=disable",
    )


@fieldwise_init
struct User(Movable):
    var id: Int
    var name: String
    var score: Float64
    var active: Bool
    var note: Optional[String]


def setup(db: Postgres) raises:
    _ = db.execute_script(
        "drop table if exists dodo_users;"
        " create table dodo_users (id int8 primary key, name text not null,"
        " score float8, active bool, note text, data bytea)"
    )


def check_round_trip(db: Postgres) raises:
    setup(db)
    var evil = String("bob'); drop table dodo_users;-- héllo 🦤")
    var inserted = db.execute(
        (
            "insert into dodo_users (id, name, score, active, note) values"
            " ($1, $2, $3, $4, $5), ($6, $7, $8, $9, $10)"
        ),
        1,
        "ada",
        9.5,
        True,
        Param.null(),
        2,
        evil,
        -1.25,
        False,
        Optional[String]("n"),
    )
    assert_equal(inserted, 2)
    var rows = db.query(
        "select * from dodo_users where id >= $1 order by id", 1
    )
    assert_equal(len(rows), 2)
    assert_equal(rows[0].int("id"), 1)
    assert_equal(rows[0].string("name"), "ada")
    assert_equal(rows[0].float("score"), 9.5)
    assert_true(rows[0].bool("active"))
    assert_true(rows[0].is_null("note"))
    assert_equal(rows[1].string("name"), evil)
    assert_false(rows[1].bool("active"))

    var users = rows.to[User]()
    assert_equal(len(users), 2)
    assert_equal(users[1].name, evil)
    assert_false(Bool(users[0].note))
    assert_equal(users[1].note.value(), "n")

    var count = 0
    for row in rows:
        count += row.int("id")
    assert_equal(count, 3)


def check_bytes(db: Postgres) raises:
    setup(db)
    var data = List[UInt8]()
    for i in range(256):
        data.append(UInt8(i))
    _ = db.execute(
        "insert into dodo_users (id, name, data) values ($1, $2, $3)",
        7,
        "bin",
        Param.bytes(data),
    )
    var back = db.query("select data from dodo_users where id = $1", 7)[
        0
    ].bytes("data")
    assert_equal(len(back), 256)
    for i in range(256):
        assert_equal(Int(back[i]), i)


def check_one_and_first(db: Postgres) raises:
    setup(db)
    _ = db.execute(
        "insert into dodo_users (id, name, active) values ($1, $2, $3)",
        5,
        "solo",
        True,
    )
    var rows = db.query(
        "select id, name, score, active, note from dodo_users where id = $1", 5
    )
    var failed = False
    try:
        _ = rows.one[User]()
    except e:
        failed = True
        assert_equal(e.kind, DbError.DECODE)
    assert_true(failed, "NULL score should not fill a Float64 field")
    var none = db.query(
        "select id, name, score, active, note from dodo_users where id = $1",
        999,
    )
    assert_false(Bool(none.first[User]()))
    failed = False
    try:
        _ = db.query("select id from dodo_users").to[User]()
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "missing columns should fail")


def check_errors_keep_connection(db: Postgres) raises:
    var single = Postgres(postgres_url(), pool_of(1))
    _ = single  # keep the explicit pool alive in this scope
    var failed = False
    try:
        _ = db.query("selec 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
        assert_equal(e.code, "42601")
    assert_true(failed, "bad SQL should fail")
    assert_equal(db.query("select 1 + $1::int8 as two", 1)[0].int("two"), 2)


def check_duplicate(db: Postgres) raises:
    setup(db)
    _ = db.execute("insert into dodo_users (id, name) values ($1, $2)", 1, "a")
    var failed = False
    try:
        _ = db.execute(
            "insert into dodo_users (id, name) values ($1, $2)", 1, "b"
        )
    except e:
        failed = True
        assert_true(e.is_duplicate())
    assert_true(failed, "duplicate key should fail")


def abandon_transaction(db: Postgres) raises:
    """Dropped without commit: rolled back when it goes back to the pool."""
    var abandoned = db.transaction()
    _ = abandoned.execute(
        "insert into dodo_users (id, name) values ($1, $2)", 2, "dropped"
    )


def check_transactions(db: Postgres) raises:
    setup(db)
    var tx = db.transaction()
    _ = tx.execute(
        "insert into dodo_users (id, name) values ($1, $2)", 1, "kept"
    )
    tx.commit()
    abandon_transaction(db)
    var tx2 = db.transaction()
    _ = tx2.execute(
        "insert into dodo_users (id, name) values ($1, $2)", 3, "rolled back"
    )
    tx2.rollback()
    var rows = db.query("select id from dodo_users order by id")
    assert_equal(len(rows), 1)
    assert_equal(rows[0].int("id"), 1)


def check_large(db: Postgres) raises:
    var big = String()
    for _ in range(100_000):
        big += "0123456789"
    var echoed = db.query("select $1::text as big", big)[0].string("big")
    assert_equal(echoed.byte_length(), 1_000_000)
    var many = db.query("select g as n from generate_series(1, 20000) g")
    assert_equal(len(many), 20000)
    assert_equal(many[19999].int("n"), 20000)


def check_script(db: Postgres) raises:
    _ = db.execute_script(
        "drop table if exists dodo_script; create table dodo_script (n int8);"
        " insert into dodo_script values (1), (2), (3)"
    )
    assert_equal(
        db.query("select count(*) as c from dodo_script")[0].int("c"), 3
    )


def pool_of(size: Int) -> PoolOptions:
    var options = PoolOptions()
    options.max_size = size
    options.acquire_timeout_ms = 300
    return options^


def check_pool_limits(url: String) raises:
    var db = Postgres(url, pool_of(1))
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
    assert_equal(db.idle_count(), 1)


def check_bad_password() raises:
    var db = Postgres(
        "postgres://dodo:wrong@127.0.0.1:45432/dodo?sslmode=disable"
    )
    var failed = False
    try:
        _ = db.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
        assert_equal(e.code, "28P01")
    assert_true(failed, "wrong password should fail")
    assert_equal(db.open_count(), 0)


def check_unreachable() raises:
    var db = Postgres(
        "postgres://dodo@127.0.0.1:1/dodo?sslmode=disable&connect_timeout_ms=500"
    )
    var failed = False
    try:
        _ = db.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.CONNECT)
    assert_true(failed, "closed port should fail")


def uses_tls(db: Postgres) raises -> Bool:
    return db.query("select ssl from pg_stat_ssl where pid = pg_backend_pid()")[
        0
    ].bool("ssl")


def fails_to_connect(url: String, why: String) raises:
    var db = Postgres(url)
    var failed = False
    try:
        _ = db.query("select 1")
    except e:
        failed = True
        assert_equal(e.kind, DbError.CONNECT)
    assert_true(failed, why)


def check_tls_modes() raises:
    """Modes as in libpq: prefer and require encrypt without checking the
    certificate; verify-full checks it against sslrootcert."""
    var base = "postgres://dodo:dodo-test@127.0.0.1:45432/dodo?sslmode="
    assert_true(uses_tls(Postgres(base + "prefer")), "prefer should encrypt")
    assert_true(uses_tls(Postgres(base + "require")), "require should encrypt")
    assert_false(uses_tls(Postgres(base + "disable")), "disable should not")
    fails_to_connect(
        base + "verify-full", "a self-signed cert should not verify"
    )
    var verified = Postgres(
        "postgres://dodo:dodo-test@localhost:45432/dodo?sslmode=verify-full&sslrootcert="
        + test_ca()
    )
    assert_true(uses_tls(verified), "verify-full should encrypt")
    # Trusted, but it names localhost, not 127.0.0.1.
    fails_to_connect(
        base + "verify-full&sslrootcert=" + test_ca(),
        "the cert does not name 127.0.0.1",
    )
    fails_to_connect(
        "postgres://root@127.0.0.1:46257/defaultdb?sslmode=require",
        "require must fail when the server has no TLS",
    )


def test_ca() -> String:
    return getenv("DODO_TEST_CA", "build/db-certs/server.crt")


def run_suite(label: String, url: String) raises:
    var db = Postgres(url)
    check_round_trip(db)
    check_bytes(db)
    check_one_and_first(db)
    check_errors_keep_connection(db)
    check_duplicate(db)
    check_transactions(db)
    check_large(db)
    check_script(db)
    check_pool_limits(url)
    print("  ", label, ": ok")


def test_postgres() raises:
    run_suite("postgres", postgres_url())
    check_bad_password()
    check_unreachable()
    check_tls_modes()


def test_cockroach() raises:
    run_suite("cockroach", cockroach_url())


def main() raises:
    test_postgres()
    test_cockroach()
    print("test_postgres: 2 passed")

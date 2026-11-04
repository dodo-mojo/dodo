"""Live tests: `migrate` on PostgreSQL, CockroachDB, MySQL and MariaDB in
Docker, including several processes migrating one database at once.

    docker compose -f tests/live/db/compose.yaml up -d --wait
    pixi run tests-db
"""

from std.ffi import c_int, external_call
from std.os import getenv
from std.testing import assert_equal, assert_true

from dodo.db import DbError, PoolOptions
from dodo.db.migrate import Migrations
from dodo.db.mysql import MySql
from dodo.db.postgres import Postgres
from dodo.utils import exit, fork


comptime RACERS = 4


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


def mysql_url() -> String:
    return getenv(
        "DODO_TEST_MYSQL", "mysql://dodo:dodo-test@127.0.0.1:43306/dodo"
    )


def mariadb_url() -> String:
    return getenv(
        "DODO_TEST_MARIADB", "mysql://dodo:dodo-test@127.0.0.1:43307/dodo"
    )


comptime DROP_ALL = (
    "drop table if exists dodo_migrations; drop table if exists"
    " dodo_mig_posts; drop table if exists dodo_mig_users"
)


def schema(sleep_sql: String) raises DbError -> Migrations:
    """Three migrations. The first sleeps, so racing processes overlap."""
    var migrations = Migrations()
    migrations.add(
        1,
        "create users",
        sleep_sql + "; create table dodo_mig_users (id bigint primary key)",
    )
    migrations.add(
        2,
        "add email",
        "alter table dodo_mig_users add column email varchar(100)",
    )
    migrations.add(
        3, "create posts", "create table dodo_mig_posts (id bigint primary key)"
    )
    return migrations^


def broken_schema() raises DbError -> Migrations:
    var migrations = Migrations()
    migrations.add(
        1, "create users", "create table dodo_mig_users (id bigint primary key)"
    )
    migrations.add(
        2,
        "half done",
        (
            "create table dodo_mig_posts (id bigint primary key);"
            " insert into dodo_no_such_table values (1)"
        ),
    )
    return migrations^


def exit_code(pid: Int) -> Int:
    """Wait for `pid` and return its exit code (-1 if a signal killed it)."""
    var status = List[c_int](length=1, fill=0)
    _ = external_call["waitpid", c_int](
        c_int(pid), status.unsafe_ptr(), c_int(0)
    )
    var raw = Int(status[0])
    if raw & 0x7F != 0:
        return -1
    return (raw >> 8) & 0xFF


def wait_all(pids: List[Int], label: String) raises:
    for pid in pids:
        assert_equal(exit_code(pid), 0, label + ": a racing process failed")


# ── PostgreSQL and CockroachDB ──────────────────────────────────────────────


def pg_versions(db: Postgres) raises -> List[Int]:
    var out = List[Int]()
    for row in db.query("select version from dodo_migrations order by version"):
        out.append(row.int("version"))
    return out^


def pg_has_table(db: Postgres, name: String) raises -> Bool:
    var rows = db.query(
        "select 1 from information_schema.tables where table_name = $1", name
    )
    return len(rows) > 0


def pg_sequential(url: String, label: String) raises:
    var db = Postgres(url)
    _ = db.execute_script(DROP_ALL)
    var migrations = schema("select pg_sleep(0)")
    assert_true(db.migrate(migrations) == [1, 2, 3], label)
    assert_equal(len(db.migrate(migrations)), 0, label)
    _ = db.execute("insert into dodo_mig_users (id, email) values (1, 'a@b.c')")
    assert_true(pg_versions(db) == [1, 2, 3], label)


def pg_rollback(url: String, label: String) raises:
    var db = Postgres(url)
    _ = db.execute_script(DROP_ALL)
    var failed = False
    try:
        _ = db.migrate(broken_schema())
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER, String(e))
        assert_true("migration 2 (half done) failed" in e.message, String(e))
    assert_true(failed, label + ": migration 2 should fail")
    var got = pg_versions(db)
    assert_true(got == [1], String(label, ": versions ", got))
    assert_true(not pg_has_table(db, "dodo_mig_posts"), label + ": rolled back")


def pg_race(url: String, label: String) raises:
    _ = Postgres(url).execute_script(DROP_ALL)
    var pids = List[Int]()
    for _ in range(RACERS):
        var pid = fork()
        if pid == 0:
            try:
                var mine = Postgres(url, PoolOptions())
                _ = mine.migrate(schema("select pg_sleep(0.3)"))
                exit(0)
            except e:
                print("  racer failed:", e)
                exit(1)
        assert_true(pid > 0, "fork failed")
        pids.append(pid)
    wait_all(pids, label)
    assert_true(pg_versions(Postgres(url)) == [1, 2, 3], label)


def run_pg(url: String, label: String) raises:
    pg_sequential(url, label)
    pg_rollback(url, label)
    pg_race(url, label)
    _ = Postgres(url).execute_script(DROP_ALL)
    print("  ", label, ": ok")


# ── MySQL and MariaDB ───────────────────────────────────────────────────────


def my_versions(db: MySql) raises -> List[Int]:
    var out = List[Int]()
    for row in db.query("select version from dodo_migrations order by version"):
        out.append(row.int("version"))
    return out^


def my_has_table(db: MySql, name: String) raises -> Bool:
    var rows = db.query(
        (
            "select 1 from information_schema.tables where table_schema ="
            " database() and table_name = ?"
        ),
        name,
    )
    return len(rows) > 0


def my_sequential(url: String, label: String) raises:
    var db = MySql(url)
    _ = db.execute_script(DROP_ALL)
    var migrations = schema("do sleep(0)")
    assert_true(db.migrate(migrations) == [1, 2, 3], label)
    assert_equal(len(db.migrate(migrations)), 0, label)
    _ = db.execute("insert into dodo_mig_users (id, email) values (1, 'a@b.c')")
    assert_true(my_versions(db) == [1, 2, 3], label)


def my_partial(url: String, label: String) raises:
    """DDL commits as it runs: the failed migration's table stays, and its
    row doesn't."""
    var db = MySql(url)
    _ = db.execute_script(DROP_ALL)
    var failed = False
    try:
        _ = db.migrate(broken_schema())
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER, String(e))
        assert_true("migration 2 (half done) failed" in e.message, String(e))
        assert_true("by hand" in e.message, String(e))
    assert_true(failed, label + ": migration 2 should fail")
    assert_true(my_versions(db) == [1], label)
    assert_true(my_has_table(db, "dodo_mig_posts"), label + ": DDL committed")


def my_race(url: String, label: String) raises:
    _ = MySql(url).execute_script(DROP_ALL)
    var pids = List[Int]()
    for _ in range(RACERS):
        var pid = fork()
        if pid == 0:
            try:
                var mine = MySql(url, PoolOptions())
                _ = mine.migrate(schema("do sleep(0.3)"))
                exit(0)
            except e:
                print("  racer failed:", e)
                exit(1)
        assert_true(pid > 0, "fork failed")
        pids.append(pid)
    wait_all(pids, label)
    assert_true(my_versions(MySql(url)) == [1, 2, 3], label)


def run_my(url: String, label: String) raises:
    my_sequential(url, label)
    my_partial(url, label)
    my_race(url, label)
    _ = MySql(url).execute_script(DROP_ALL)
    print("  ", label, ": ok")


def test_postgres_migrate() raises:
    run_pg(postgres_url(), "postgres")


def test_cockroach_migrate() raises:
    run_pg(cockroach_url(), "cockroach")


def test_mysql_migrate() raises:
    run_my(mysql_url(), "mysql")


def test_mariadb_migrate() raises:
    run_my(mariadb_url(), "mariadb")


def main() raises:
    test_postgres_migrate()
    test_cockroach_migrate()
    test_mysql_migrate()
    test_mariadb_migrate()
    print("test_migrate: 4 passed")

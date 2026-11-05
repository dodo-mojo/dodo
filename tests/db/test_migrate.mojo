"""Tests for dodo.db.migrate: the planner, migration files, and
`Sqlite.migrate` end to end. No Docker."""

from std.os import listdir, mkdir, remove, rmdir
from std.os.path import exists
from std.pathlib import Path
from std.tempfile import mkdtemp
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError
from dodo.db.migrate import (
    AppliedMigration,
    Migration,
    Migrations,
    checksum_of,
    lost_race,
    plan,
)
from dodo.db.sqlite import Sqlite


struct TempDir(Movable):
    """A fresh directory, deleted with every file in it."""

    var path: String

    def __init__(out self) raises:
        self.path = mkdtemp()

    def write(self, name: String, text: String) raises:
        (Path(self.path) / name).write_text(text)

    def file(self, name: String) -> String:
        return self.path + "/" + name

    def __deinit__(deinit self):
        try:
            for name in listdir(self.path):
                remove(self.path + "/" + name)
            rmdir(self.path)
        except:
            pass


def expect_usage(
    migrations: Migrations, applied: List[AppliedMigration], says: String
) raises:
    var failed = False
    try:
        _ = plan(migrations, applied, "test")
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE, String(e))
        assert_true(says in e.message, String(e))
    assert_true(failed, "plan should refuse: " + says)


def two_migrations() raises DbError -> Migrations:
    var migrations = Migrations()
    migrations.add(2, "add email", "alter table users add column email text")
    migrations.add(
        1, "create users", "create table users (id integer primary key)"
    )
    return migrations^


def row(m: Migration) -> AppliedMigration:
    return AppliedMigration(m.version, m.name, m.checksum)


def test_add_keeps_version_order() raises:
    var migrations = two_migrations()
    migrations.add(10, "ten", "select 10")
    migrations.add(5, "five", "select 5")
    assert_equal(len(migrations), 4)
    var versions = List[Int]()
    for i in range(len(migrations)):
        versions.append(migrations[i].version)
    assert_true(versions == [1, 2, 5, 10], String(versions))


def test_add_refuses_bad_migrations() raises:
    var migrations = two_migrations()
    for bad in [
        (2, "select 1", "two migrations"),
        (0, "select 1", "start at 1"),
        (-3, "select 1", "start at 1"),
        (7, "  \n ", "empty"),
    ]:
        var failed = False
        try:
            migrations.add(bad[0], "x", bad[1])
        except e:
            failed = True
            assert_equal(e.kind, DbError.USAGE)
            assert_true(bad[2] in e.message, String(e))
        assert_true(failed, String("add should refuse version ", bad[0]))
    assert_equal(len(migrations), 2)


def test_checksum() raises:
    var lf = checksum_of("create table t (id int);\nselect 1;\n")
    assert_equal(lf, checksum_of("create table t (id int);\r\nselect 1;\r\n"))
    assert_equal(lf.byte_length(), 64)
    assert_true(lf != checksum_of("create table t (id int);\nselect 2;\n"))
    # The SHA-256 of "abc".
    assert_equal(
        checksum_of("abc"),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    )


def test_plan_fresh_and_partial() raises:
    var migrations = two_migrations()
    var all = plan(migrations, List[AppliedMigration](), "test")
    assert_equal(len(all), 2)
    assert_equal(all[0].version, 1)
    assert_equal(all[1].version, 2)

    var applied = List[AppliedMigration]()
    applied.append(row(migrations[0]))
    var rest = plan(migrations, applied, "test")
    assert_equal(len(rest), 1)
    assert_equal(rest[0].name, "add email")

    applied.append(row(migrations[1]))
    assert_equal(len(plan(migrations, applied, "test")), 0)


def test_plan_refuses_edited_migration() raises:
    var migrations = two_migrations()
    var applied = List[AppliedMigration]()
    applied.append(
        AppliedMigration(
            1, "create users", checksum_of("create table users (id int)")
        )
    )
    expect_usage(migrations, applied, "changed after it ran")


def test_plan_refuses_unknown_version() raises:
    var migrations = two_migrations()
    var applied = List[AppliedMigration]()
    applied.append(row(migrations[0]))
    applied.append(AppliedMigration(3, "from a newer build", "00"))
    expect_usage(migrations, applied, "doesn't have")


def test_plan_refuses_out_of_order() raises:
    var migrations = two_migrations()
    migrations.add(3, "three", "select 3")
    var applied = List[AppliedMigration]()
    applied.append(row(migrations[0]))
    applied.append(row(migrations[2]))
    expect_usage(migrations, applied, "already at version 3")


def test_from_dir() raises:
    var dir = TempDir()
    dir.write(
        "0002_add_email.sql", "alter table users add column email text;\n"
    )
    dir.write(
        "0001_create_users.sql",
        "create table users (id integer primary key, name text);\n",
    )
    dir.write("README.md", "not a migration")
    dir.write("._0003_resource_fork.sql", "macOS metadata")
    dir.write("10.sql", "create table ten (id integer)")
    var migrations = Migrations.from_dir(dir.path)
    assert_equal(len(migrations), 3)
    assert_equal(migrations[0].version, 1)
    assert_equal(migrations[0].name, "create users")
    assert_equal(migrations[1].name, "add email")
    assert_equal(migrations[2].version, 10)
    assert_equal(migrations[2].name, "")


def test_from_dir_refuses_bad_names() raises:
    for bad in ["create_users.sql", "0001-create-users.sql"]:
        var dir = TempDir()
        dir.write(bad, "select 1")
        var failed = False
        try:
            _ = Migrations.from_dir(dir.path)
        except e:
            failed = True
            assert_equal(e.kind, DbError.USAGE)
            assert_true(bad in e.message, String(e))
        assert_true(failed, bad + " should be refused")

    var failed = False
    try:
        _ = Migrations.from_dir("/no/such/dodo/dir")
    except e:
        failed = True
        assert_true("/no/such/dodo/dir" in e.message, String(e))
    assert_true(failed, "a missing directory should fail")


def test_lost_race() raises:
    assert_true(lost_race(DbError(DbError.SERVER, "23505", "dup", "postgres")))
    assert_true(
        lost_race(DbError(DbError.SERVER, "40001", "retry", "postgres"))
    )
    assert_true(
        lost_race(DbError(DbError.SERVER, "40P01", "deadlock", "postgres"))
    )
    assert_true(lost_race(DbError(DbError.SERVER, "1062", "dup", "mysql")))
    assert_true(lost_race(DbError(DbError.SERVER, "1555", "dup", "sqlite")))
    assert_false(
        lost_race(DbError(DbError.SERVER, "42601", "syntax", "postgres"))
    )
    assert_false(lost_race(DbError(DbError.SERVER, "40001", "x", "mysql")))
    assert_false(lost_race(DbError(DbError.IO, "40001", "x", "postgres")))


def sqlite_db(dir: TempDir) raises -> Sqlite:
    return Sqlite("sqlite://" + dir.file("app.db"))


def test_sqlite_migrate() raises:
    var dir = TempDir()
    var db = sqlite_db(dir)
    var migrations = two_migrations()

    var applied = db.migrate(migrations)
    assert_true(applied == [1, 2], String(applied))
    _ = db.execute("insert into users (id, email) values (1, 'a@b.c')")

    # A second run, or a second process starting later, does nothing.
    assert_equal(len(db.migrate(migrations)), 0)
    assert_equal(len(sqlite_db(dir).migrate(migrations)), 0)

    var rows = db.query(
        "select version, name, checksum, applied_at from dodo_migrations order"
        " by version"
    )
    assert_equal(len(rows), 2)
    assert_equal(rows[0].string("name"), "create users")
    assert_equal(rows[1].string("checksum"), migrations[1].checksum)
    assert_false(rows[0].is_null("applied_at"))

    # A new migration later runs alone.
    migrations.add(3, "add score", "alter table users add column score real")
    assert_true(db.migrate(migrations) == [3])
    _ = dir^  # Mojo destroys values after their last use; keep the files.


def test_sqlite_migrate_rolls_back_a_failed_migration() raises:
    var dir = TempDir()
    var db = sqlite_db(dir)
    var migrations = Migrations()
    migrations.add(
        1, "create users", "create table users (id integer primary key)"
    )
    migrations.add(
        2,
        "half done",
        (
            "create table posts (id integer primary key);\n"
            "insert into no_such_table values (1);"
        ),
    )
    var failed = False
    try:
        _ = db.migrate(migrations)
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER, String(e))
        assert_true("migration 2 (half done) failed" in e.message, String(e))
    assert_true(failed, "migration 2 should fail")

    # Migration 1 stays; migration 2 left nothing behind, not even posts.
    var versions = db.query("select version from dodo_migrations")
    assert_equal(len(versions), 1)
    assert_equal(versions[0].int("version"), 1)
    var posts = db.query("select name from sqlite_master where name = 'posts'")
    assert_equal(len(posts), 0)
    _ = dir^


def test_sqlite_migrate_refuses_an_edited_migration() raises:
    var dir = TempDir()
    var db = sqlite_db(dir)
    _ = db.migrate(two_migrations())
    var edited = Migrations()
    edited.add(
        1,
        "create users",
        "create table users (id integer primary key, name text)",
    )
    edited.add(2, "add email", "alter table users add column email text")
    var failed = False
    try:
        _ = db.migrate(edited)
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
        assert_true("changed after it ran" in e.message, String(e))
    assert_true(failed, "an edited migration should be refused")
    _ = dir^


def main() raises:
    test_add_keeps_version_order()
    test_add_refuses_bad_migrations()
    test_checksum()
    test_plan_fresh_and_partial()
    test_plan_refuses_edited_migration()
    test_plan_refuses_unknown_version()
    test_plan_refuses_out_of_order()
    test_from_dir()
    test_from_dir_refuses_bad_names()
    test_lost_race()
    test_sqlite_migrate()
    test_sqlite_migrate_rolls_back_a_failed_migration()
    test_sqlite_migrate_refuses_an_edited_migration()
    print("test_migrate: 13 passed")

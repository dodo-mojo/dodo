"""Schema migrations for the SQL drivers (ADR-0010).

A migration is a version, a name and SQL. Keep them as files named
`<version>_<name>.sql` and run them at startup, before serving:

```mojo
from dodo.db.migrate import Migrations
from dodo.db.postgres import Postgres

def main() raises:
    var db = Postgres("postgres://app:secret@localhost/app")
    var applied = db.migrate(Migrations.from_dir("migrations"))
    print("applied", len(applied), "migrations")
```

`Postgres`, `MySql` and `Sqlite` each have `migrate`. It records every
migration it runs in a `dodo_migrations` table and runs each one once,
even when several processes start at the same time. This module only
plans: it checks the migrations against that table and says what to run.
"""

from std.os import listdir
from std.pathlib import Path

from ..crypto.digest import sha256
from .error import DbError


comptime MAX_RACES = 100
"""How many times one `migrate` call yields a version to another process
before it gives up. Each lost race means that process made progress."""


struct Migration(Copyable, Writable):
    """One schema change: a version, a name for people, and SQL."""

    var version: Int
    var name: String
    var sql: String
    var checksum: String
    """Hex SHA-256 of `sql`, with `\\r\\n` line endings read as `\\n`."""

    def __init__(
        out self, version: Int, name: String, sql: String
    ) raises DbError:
        if version <= 0:
            raise DbError.usage(
                "",
                String(
                    "migration versions start at 1, got ",
                    version,
                    " (",
                    name,
                    ")",
                ),
            )
        if sql.strip() == "":
            raise DbError.usage(
                "", String("migration ", version, " (", name, ") is empty")
            )
        self.version = version
        self.name = name
        self.sql = sql
        self.checksum = checksum_of(sql)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.version, " (", self.name, ")")


@fieldwise_init
struct AppliedMigration(Copyable, Writable):
    """A row of the `dodo_migrations` table."""

    var version: Int
    var name: String
    var checksum: String

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.version, " (", self.name, ")")


struct Migrations(Copyable, Sized):
    """The migrations an app knows, kept in version order."""

    var _list: List[Migration]

    def __init__(out self):
        self._list = List[Migration]()

    def add(mut self, version: Int, name: String, sql: String) raises DbError:
        """Add a migration. Versions must be unique; the order of calls
        doesn't matter."""
        var migration = Migration(version, name, sql)
        var at = len(self._list)
        for i in range(len(self._list)):
            if self._list[i].version == version:
                raise DbError.usage(
                    "",
                    String(
                        "two migrations have version ",
                        version,
                        ": ",
                        self._list[i].name,
                        " and ",
                        name,
                    ),
                )
            if self._list[i].version > version and at == len(self._list):
                at = i
        self._list.insert(at, migration^)

    @staticmethod
    def from_dir(path: String) raises DbError -> Migrations:
        """Read every `<version>_<name>.sql` file in `path`.

        `0001_create_users.sql` is version 1, named "create users".
        Other files are skipped, and so are names starting with `.`; a
        `.sql` file without a version is an error.
        """
        var entries: List[String]
        try:
            entries = listdir(path)
        except e:
            raise DbError.usage(
                "", String("can't list migrations in ", path, ": ", e)
            )
        var out = Migrations()
        for entry in entries:
            if not entry.endswith(".sql") or entry.startswith("."):
                continue
            var version_and_name = _parse_file_name(entry)
            var sql: String
            try:
                sql = (Path(path) / entry).read_text()
            except e:
                raise DbError.usage(
                    "", String("can't read migration ", entry, ": ", e)
                )
            out.add(version_and_name[0], version_and_name[1], sql)
        return out^

    def __len__(self) -> Int:
        return len(self._list)

    def __getitem__(self, index: Int) -> Migration:
        """A copy of the migration at `index`, in version order."""
        return self._list[index].copy()


def plan(
    migrations: Migrations, applied: List[AppliedMigration], database: String
) raises DbError -> List[Migration]:
    """The migrations still to run, in order.

    `applied` is what the `dodo_migrations` table holds. Raises a `USAGE`
    error, and plans nothing, when:

    - a migration that ran has changed since (its checksum differs);
    - the table has a version the app doesn't know;
    - a migration that hasn't run has a lower version than one that has.
    """
    var highest = 0
    for row in applied:
        var known = _find(migrations, row.version)
        if known < 0:
            raise DbError.usage(
                database,
                String(
                    "the database has migration ",
                    row,
                    ", which this app doesn't have. Is an older build",
                    " running against a newer database?",
                ),
            )
        if migrations._list[known].checksum != row.checksum:
            raise DbError.usage(
                database,
                String(
                    "migration ",
                    row,
                    " changed after it ran. Undo the edit and put the",
                    " change in a new migration.",
                ),
            )
        highest = max(highest, row.version)

    var pending = List[Migration]()
    for migration in migrations._list:
        if _was_applied(applied, migration.version):
            continue
        if migration.version < highest:
            raise DbError.usage(
                database,
                String(
                    "migration ",
                    migration,
                    " hasn't run, but the database is already at version ",
                    highest,
                    ". Give it a version above ",
                    highest,
                    ".",
                ),
            )
        pending.append(migration.copy())
    return pending^


def checksum_of(sql: String) raises DbError -> String:
    """Hex SHA-256 of `sql` with `\\r\\n` read as `\\n`, so a checkout with
    Windows line endings matches one without."""
    var text = sql.replace("\r\n", "\n")
    try:
        return _hex(sha256(text.as_bytes()))
    except e:
        raise DbError.usage("", String("can't hash a migration: ", e))


def lost_race(error: DbError) -> Bool:
    """Whether another process ran the same migration first: its row
    already exists (a duplicate key), or the database aborted this
    transaction in its favour (PostgreSQL and CockroachDB SQLSTATE 40001
    or 40P01)."""
    if error.is_duplicate():
        return True
    if error.kind != DbError.SERVER or error.database != "postgres":
        return False
    return error.code == "40001" or error.code == "40P01"


def failed(migration: Migration, error: DbError, note: String = "") -> DbError:
    """`error`, with the migration that raised it named in the message."""
    var message = String("migration ", migration, " failed: ", error.message)
    if note != "":
        message += " " + note
    return DbError(error.kind, error.code, message^, error.database)


def _find(migrations: Migrations, version: Int) -> Int:
    for i in range(len(migrations._list)):
        if migrations._list[i].version == version:
            return i
    return -1


def _was_applied(applied: List[AppliedMigration], version: Int) -> Bool:
    for row in applied:
        if row.version == version:
            return True
    return False


comptime _ZERO = UInt8(ord("0"))
comptime _NINE = UInt8(ord("9"))
comptime _UNDERSCORE = UInt8(ord("_"))


def _parse_file_name(file_name: String) raises DbError -> Tuple[Int, String]:
    """`0001_create_users.sql` -> (1, "create users")."""
    var bytes = file_name.as_bytes()
    var stem_end = file_name.byte_length() - 4  # ".sql"
    var version = 0
    var i = 0
    while i < stem_end and bytes[i] >= _ZERO and bytes[i] <= _NINE:
        version = version * 10 + Int(bytes[i] - _ZERO)
        i += 1
    if i == 0 or i > 18:
        raise DbError.usage(
            "",
            String(
                "migration file ",
                file_name,
                " needs a version up front, as in 0001_create_users.sql",
            ),
        )
    var name = String()
    if i < stem_end:
        if bytes[i] != _UNDERSCORE:
            raise DbError.usage(
                "",
                String(
                    "migration file ",
                    file_name,
                    " needs an underscore after its version, as in",
                    " 0001_create_users.sql",
                ),
            )
        name = String(file_name[byte = i + 1 : stem_end]).replace("_", " ")
    return (version, name^)


def _hex(data: List[UInt8]) -> String:
    comptime digits = "0123456789abcdef"
    var out = String()
    for b in data:
        out += digits[byte=Int(b >> 4)]
        out += digits[byte=Int(b & 15)]
    return out^

"""The MySQL pool most code uses, and transactions on it."""

from ..error import DbError
from ..migrate import AppliedMigration, Migrations, failed, plan
from ..param import Param, params_of
from ..pool import Pool, PoolOptions, Pooled
from ..rows import Rows
from .connection import MySqlConfig, MySqlConnection


struct MySql(Copyable):
    """A pool of connections to MySQL or MariaDB.

    Cheap to copy; every copy shares the connections, so keep one in the
    app state. Each call checks a connection out and gives it back.

    ```mojo
    var db = MySql("mysql://dodo:secret@localhost:3306/app")
    var rows = db.query("select id, name from users where id = ?", 42)
    var id = db.query("insert into users (name) values (?)", "ada").last_insert_id
    ```
    """

    var _pool: Pool[MySqlConnection]

    def __init__(
        out self, url: String, options: PoolOptions = PoolOptions()
    ) raises DbError:
        self._pool = Pool[MySqlConnection](MySqlConfig.from_url(url), options)

    def __init__(
        out self, config: MySqlConfig, options: PoolOptions = PoolOptions()
    ):
        self._pool = Pool[MySqlConnection](config, options)

    def query(self, sql: String, *params: Param) raises DbError -> Rows:
        """Run one statement; return its rows, `affected` and
        `last_insert_id`."""
        var conn = self._pool.acquire()
        return conn.conn().query(sql, params_of(params))

    def execute(self, sql: String, *params: Param) raises DbError -> Int:
        """Run one statement; return how many rows it changed."""
        var conn = self._pool.acquire()
        return conn.conn().execute(sql, params_of(params))

    def execute_script(self, sql: String) raises DbError -> Int:
        """Run `;`-separated statements without parameters (schema setup)."""
        var conn = self._pool.acquire()
        return conn.conn().execute_script(sql)

    def transaction(self) raises DbError -> MySqlTransaction:
        """Start a transaction on a connection of its own. It rolls back
        unless `commit` is called."""
        var conn = self._pool.acquire()
        _ = conn.conn().query("START TRANSACTION", List[Param]())
        return MySqlTransaction(conn^)

    def migrate(self, migrations: Migrations) raises DbError -> List[Int]:
        """Run the migrations that haven't run yet, in version order, and
        return their versions (ADR-0010).

        MySQL and MariaDB commit each DDL statement as it runs, so this
        holds a named lock (`GET_LOCK`) for the whole run instead of a
        transaction. Safe when several processes start at once. A
        migration that fails halfway keeps the statements before the
        failure; keep one DDL statement per migration.
        """
        var conn = self._pool.acquire()
        var got = conn.conn().query(
            "select get_lock(" + _LOCK_NAME + ", 600)", List[Param]()
        )
        if got[0].is_null(0) or got[0].int(0) != 1:
            raise DbError.usage(
                "mysql",
                "another process held the migration lock for 10 minutes",
            )
        var ran: List[Int]
        try:
            ran = _migrate_locked(conn, migrations)
        except e:
            _release_lock(conn)
            raise e^
        _release_lock(conn)
        return ran^

    def connection(self) raises DbError -> Pooled[MySqlConnection]:
        """A connection for several calls in a row."""
        return self._pool.acquire()

    def open_count(self) -> Int:
        return self._pool.open_count()

    def idle_count(self) -> Int:
        return self._pool.idle_count()


struct MySqlTransaction(Movable):
    """Statements that commit or roll back together. Destroying it without
    `commit` rolls back."""

    var _conn: Pooled[MySqlConnection]

    def __init__(out self, var conn: Pooled[MySqlConnection]):
        self._conn = conn^

    def query(mut self, sql: String, *params: Param) raises DbError -> Rows:
        return self._conn.conn().query(sql, params_of(params))

    def execute(mut self, sql: String, *params: Param) raises DbError -> Int:
        return self._conn.conn().execute(sql, params_of(params))

    def commit(mut self) raises DbError:
        _ = self._conn.conn().query("COMMIT", List[Param]())

    def rollback(mut self) raises DbError:
        _ = self._conn.conn().query("ROLLBACK", List[Param]())


comptime _LOCK_NAME = "left(concat('dodo_migrate:', database()), 64)"
"""Per database, so apps sharing one server don't wait on each other."""


def _migrate_locked(
    mut conn: Pooled[MySqlConnection], migrations: Migrations
) raises DbError -> List[Int]:
    _ = conn.conn().execute_script(
        "create table if not exists dodo_migrations (version bigint primary"
        " key, name varchar(255) not null, checksum char(64) not null,"
        " applied_at timestamp not null default current_timestamp)"
    )
    var applied = (
        conn.conn()
        .query(
            (
                "select version, name, checksum from dodo_migrations order by"
                " version"
            ),
            List[Param](),
        )
        .to[AppliedMigration]()
    )
    var pending = plan(migrations, applied, "mysql")
    var ran = List[Int]()
    for migration in pending:
        try:
            _ = conn.conn().execute_script(migration.sql)
        except e:
            raise failed(
                migration,
                e,
                (
                    "MySQL commits DDL as it runs, so its statements before the"
                    " failure stay applied: undo them by hand, then run again."
                ),
            )
        var row = List[Param]()
        row.append(migration.version)
        row.append(migration.name)
        row.append(migration.checksum)
        _ = conn.conn().execute(
            (
                "insert into dodo_migrations (version, name, checksum) values"
                " (?, ?, ?)"
            ),
            row,
        )
        ran.append(migration.version)
    return ran^


def _release_lock(mut conn: Pooled[MySqlConnection]):
    # The pool's reset doesn't release named locks. If this fails, the
    # connection is broken, and the server drops the lock when it closes.
    try:
        _ = conn.conn().query(
            "select release_lock(" + _LOCK_NAME + ")", List[Param]()
        )
    except:
        pass

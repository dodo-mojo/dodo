"""The SQLite pool most code uses, and transactions on it."""

from ..error import DbError
from ..migrate import (
    MAX_RACES,
    AppliedMigration,
    Migrations,
    failed,
    lost_race,
    plan,
)
from ..param import Param, params_of
from ..pool import Pool, PoolOptions, Pooled
from ..rows import Rows
from .connection import SqliteConfig, SqliteConnection


struct Sqlite(Copyable):
    """A pool of connections to one SQLite database file.

    Cheap to copy; every copy shares the connections, so keep one in the
    app state. Each call checks a connection out and gives it back. Many
    connections read at once; SQLite lets one write at a time, and a
    writer waits up to `busy_timeout_ms` for the lock.

    ```mojo
    var db = Sqlite("sqlite:///var/app/data.db")
    _ = db.execute_script("create table if not exists users (id integer primary key, name text)")
    var id = db.query("insert into users (name) values (?)", "ada").last_insert_id
    var users = db.query("select id, name from users").to[User]()
    ```
    """

    var _pool: Pool[SqliteConnection]

    def __init__(
        out self, url: String, options: PoolOptions = PoolOptions()
    ) raises DbError:
        self = Self(SqliteConfig.from_url(url), options)

    def __init__(
        out self, config: SqliteConfig, options: PoolOptions = PoolOptions()
    ):
        var sized = options.copy()
        if config.in_memory():
            # Each connection to :memory: is a database of its own.
            sized.max_size = 1
        self._pool = Pool[SqliteConnection](config, sized)

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

    def transaction(self) raises DbError -> SqliteTransaction:
        """Start a write transaction on a connection of its own. It takes
        the write lock up front (BEGIN IMMEDIATE), so two transactions
        can't deadlock upgrading from read to write. It rolls back unless
        `commit` is called."""
        var conn = self._pool.acquire()
        _ = conn.conn().execute_script("BEGIN IMMEDIATE")
        return SqliteTransaction(conn^)

    def migrate(self, migrations: Migrations) raises DbError -> List[Int]:
        """Run the migrations that haven't run yet, in version order, and
        return their versions (ADR-0010).

        Each migration runs in a transaction with its `dodo_migrations`
        row, so one that fails leaves nothing behind. Safe when several
        processes start at once: each migration still runs once.
        """
        self._create_migrations_table()
        var ran = List[Int]()
        var races = 0
        while True:
            var applied = self.query(
                "select version, name, checksum from dodo_migrations"
                " order by version"
            ).to[AppliedMigration]()
            var pending = plan(migrations, applied, "sqlite")
            if len(pending) == 0:
                return ran^
            var next = pending[0].copy()
            try:
                var tx = self.transaction()
                # BEGIN IMMEDIATE makes a second process wait here; once it
                # gets in, this version is already recorded: a duplicate.
                _ = tx.execute(
                    (
                        "insert into dodo_migrations (version, name, checksum)"
                        " values (?, ?, ?)"
                    ),
                    next.version,
                    next.name,
                    next.checksum,
                )
                _ = tx.execute_script(next.sql)
                tx.commit()
            except e:
                if lost_race(e) and races < MAX_RACES:
                    races += 1
                    continue
                raise failed(next, e)
            ran.append(next.version)

    def _create_migrations_table(self) raises DbError:
        # Two processes creating it at once can collide; one wins.
        for attempt in range(3):
            try:
                _ = self.execute_script(
                    "create table if not exists dodo_migrations (version"
                    " integer primary key, name text not null, checksum text"
                    " not null, applied_at text not null default"
                    " current_timestamp)"
                )
                return
            except e:
                if not lost_race(e) or attempt == 2:
                    raise e^

    def connection(self) raises DbError -> Pooled[SqliteConnection]:
        """A connection for several calls in a row."""
        return self._pool.acquire()

    def open_count(self) -> Int:
        return self._pool.open_count()

    def idle_count(self) -> Int:
        return self._pool.idle_count()


struct SqliteTransaction(Movable):
    """Statements that commit or roll back together. Destroying it without
    `commit` rolls back."""

    var _conn: Pooled[SqliteConnection]

    def __init__(out self, var conn: Pooled[SqliteConnection]):
        self._conn = conn^

    def query(mut self, sql: String, *params: Param) raises DbError -> Rows:
        return self._conn.conn().query(sql, params_of(params))

    def execute(mut self, sql: String, *params: Param) raises DbError -> Int:
        return self._conn.conn().execute(sql, params_of(params))

    def execute_script(mut self, sql: String) raises DbError -> Int:
        """Run `;`-separated statements without parameters, inside the
        transaction."""
        return self._conn.conn().execute_script(sql)

    def commit(mut self) raises DbError:
        _ = self._conn.conn().execute_script("COMMIT")

    def rollback(mut self) raises DbError:
        _ = self._conn.conn().execute_script("ROLLBACK")

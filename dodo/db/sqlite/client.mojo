"""The SQLite pool most code uses, and transactions on it."""

from ..error import DbError
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

    def commit(mut self) raises DbError:
        _ = self._conn.conn().execute_script("COMMIT")

    def rollback(mut self) raises DbError:
        _ = self._conn.conn().execute_script("ROLLBACK")

"""The MySQL pool most code uses, and transactions on it."""

from ..error import DbError
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

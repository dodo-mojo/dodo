"""The PostgreSQL pool most code uses, and transactions on it."""

from ..error import DbError
from ..param import Param, params_of
from ..pool import Pool, PoolOptions, Pooled
from ..rows import Rows
from .connection import PgConfig, PgConnection


struct Postgres(Copyable):
    """A pool of connections to PostgreSQL or CockroachDB.

    Cheap to copy; every copy shares the connections, so keep one in the
    app state. Each call checks a connection out and gives it back.

    ```mojo
    var db = Postgres("postgres://dodo:secret@localhost:5432/app")
    var rows = db.query("select id, name from users where id = $1", 42)
    var n = db.execute("update users set name = $1 where id = $2", "ada", 42)

    var tx = db.transaction()
    _ = tx.execute("insert into audit (msg) values ($1)", "renamed")
    tx.commit()
    ```
    """

    var _pool: Pool[PgConnection]

    def __init__(
        out self, url: String, options: PoolOptions = PoolOptions()
    ) raises DbError:
        self._pool = Pool[PgConnection](PgConfig.from_url(url), options)

    def __init__(
        out self, config: PgConfig, options: PoolOptions = PoolOptions()
    ):
        self._pool = Pool[PgConnection](config, options)

    def query(self, sql: String, *params: Param) raises DbError -> Rows:
        """Run one statement; return its rows."""
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

    def transaction(self) raises DbError -> PgTransaction:
        """Start a transaction on a connection of its own. It rolls back
        unless `commit` is called."""
        var conn = self._pool.acquire()
        _ = conn.conn().execute_script("BEGIN")
        return PgTransaction(conn^)

    def connection(self) raises DbError -> Pooled[PgConnection]:
        """A connection for several calls in a row (session settings,
        temporary tables). It goes back to the pool when destroyed."""
        return self._pool.acquire()

    def open_count(self) -> Int:
        return self._pool.open_count()

    def idle_count(self) -> Int:
        return self._pool.idle_count()


struct PgTransaction(Movable):
    """Statements that commit or roll back together. Destroying it without
    `commit` rolls back."""

    var _conn: Pooled[PgConnection]

    def __init__(out self, var conn: Pooled[PgConnection]):
        self._conn = conn^

    def query(mut self, sql: String, *params: Param) raises DbError -> Rows:
        return self._conn.conn().query(sql, params_of(params))

    def execute(mut self, sql: String, *params: Param) raises DbError -> Int:
        return self._conn.conn().execute(sql, params_of(params))

    def commit(mut self) raises DbError:
        _ = self._conn.conn().execute_script("COMMIT")

    def rollback(mut self) raises DbError:
        _ = self._conn.conn().execute_script("ROLLBACK")

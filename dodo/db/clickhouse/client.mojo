"""The ClickHouse pool most code uses."""

from ..error import DbError
from ..param import Param, params_of
from ..pool import Pool, PoolOptions, Pooled
from ..rows import Rows
from .connection import ClickHouseConfig, ClickHouseConnection


struct ClickHouse(Copyable):
    """A pool of HTTP connections to ClickHouse.

    Cheap to copy; every copy shares the connections, so keep one in the
    app state. Parameters are positional and named `p1`, `p2`, ... in the
    SQL, each with its ClickHouse type:

    ```mojo
    var ch = ClickHouse("clickhouse://app:secret@localhost:8123/analytics")
    var rows = ch.query(
        "select path, count() as hits from visits where day = {p1:Date}"
        " group by path order by hits desc limit {p2:UInt32}",
        "2026-11-02", 10,
    )
    ```

    Dates and times come back as text in UTC (`2026-11-02 10:30:00`);
    arrays, tuples and maps as ClickHouse literals (`['a', 'b']`).
    ClickHouse has no transactions, so there is no `transaction()`.
    """

    var _pool: Pool[ClickHouseConnection]

    def __init__(
        out self, url: String, options: PoolOptions = PoolOptions()
    ) raises DbError:
        self._pool = Pool[ClickHouseConnection](
            ClickHouseConfig.from_url(url), options
        )

    def __init__(
        out self, config: ClickHouseConfig, options: PoolOptions = PoolOptions()
    ):
        self._pool = Pool[ClickHouseConnection](config, options)

    def query(self, sql: String, *params: Param) raises DbError -> Rows:
        """Run one statement; return its rows."""
        var conn = self._pool.acquire()
        return conn.conn().query(sql, params_of(params))

    def execute(self, sql: String, *params: Param) raises DbError -> Int:
        """Run one statement; return the rows an INSERT wrote."""
        var conn = self._pool.acquire()
        return conn.conn().execute(sql, params_of(params))

    def execute_script(self, sql: String) raises DbError -> Int:
        """Run `;`-separated statements without parameters (schema setup)."""
        var conn = self._pool.acquire()
        return conn.conn().execute_script(sql)

    def connection(self) raises DbError -> Pooled[ClickHouseConnection]:
        return self._pool.acquire()

    def open_count(self) -> Int:
        return self._pool.open_count()

    def idle_count(self) -> Int:
        return self._pool.idle_count()

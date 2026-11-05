"""The PostgreSQL pool most code uses, and transactions on it."""

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

    def migrate(self, migrations: Migrations) raises DbError -> List[Int]:
        """Run the migrations that haven't run yet, in version order, and
        return their versions (ADR-0010).

        Each migration runs in a transaction with its `dodo_migrations`
        row, so one that fails leaves nothing behind. Safe when several
        processes start at once: each migration still runs once.
        """
        self._create_migrations_table()
        # CockroachDB 25.1+ commits an open transaction before each DDL
        # statement (`autocommit_before_ddl`), which would keep the row of
        # a migration that failed. PostgreSQL has no such setting (NULL).
        var cockroach_autocommit = not self.query(
            "select current_setting('autocommit_before_ddl', true) as s"
        )[0].is_null("s")
        var ran = List[Int]()
        var races = 0
        while True:
            var applied = self.query(
                "select version, name, checksum from dodo_migrations"
                " order by version"
            ).to[AppliedMigration]()
            var pending = plan(migrations, applied, "postgres")
            if len(pending) == 0:
                return ran^
            var next = pending[0].copy()
            try:
                var tx = self.transaction()
                if cockroach_autocommit:
                    _ = tx.execute_script(
                        "set local autocommit_before_ddl = false"
                    )
                # The row goes in first: a second process trying the same
                # version waits on it, then fails as a duplicate.
                _ = tx.execute(
                    (
                        "insert into dodo_migrations (version, name, checksum)"
                        " values ($1, $2, $3)"
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
                    "create table if not exists dodo_migrations (version bigint"
                    " primary key, name text not null, checksum text not null,"
                    " applied_at timestamptz not null default now())"
                )
                return
            except e:
                if not lost_race(e) or attempt == 2:
                    raise e^

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

    def execute_script(mut self, sql: String) raises DbError -> Int:
        """Run `;`-separated statements without parameters, inside the
        transaction."""
        return self._conn.conn().execute_script(sql)

    def commit(mut self) raises DbError:
        _ = self._conn.conn().execute_script("COMMIT")

    def rollback(mut self) raises DbError:
        _ = self._conn.conn().execute_script("ROLLBACK")

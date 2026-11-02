"""The one error every database driver raises."""


@fieldwise_init
struct DbError(Copyable, Writable):
    """A database call failed.

    `kind` says what part failed, so a caller can branch on it as a group:

    - `CONNECT`: the server could not be reached.
    - `AUTH`: the server rejected the credentials.
    - `IO`: the connection broke mid-call. The connection is closed.
    - `PROTOCOL`: the server sent something the driver can't read. The
      connection is closed.
    - `SERVER`: the server ran the call and refused it (bad SQL, a
      constraint, a missing table). The connection stays usable.
    - `DECODE`: a value could not be read as the type asked for.
    - `POOL_TIMEOUT`: no connection came free in time.
    - `USAGE`: the call itself was wrong (bad URL, unknown column).

    `code` is the database's own code when it gave one: the SQLSTATE for
    PostgreSQL, the error number for MySQL and MariaDB, the extended
    result code for SQLite, the error code for MongoDB and ClickHouse, the
    error prefix (`WRONGTYPE`) for Redis.

    ```mojo
    try:
        _ = db.execute("insert into users (email) values ($1)", email)
    except e:
        if e.is_duplicate():
            return conflict("email already registered")
        raise e
    ```
    """

    var kind: Int
    var code: String
    var message: String
    var database: String

    comptime CONNECT = 1
    comptime AUTH = 2
    comptime IO = 3
    comptime PROTOCOL = 4
    comptime SERVER = 5
    comptime DECODE = 6
    comptime POOL_TIMEOUT = 7
    comptime USAGE = 8

    @staticmethod
    def connect(database: String, message: String) -> Self:
        return Self(Self.CONNECT, String(), message, database)

    @staticmethod
    def auth(database: String, message: String, code: String = "") -> Self:
        return Self(Self.AUTH, code, message, database)

    @staticmethod
    def io(database: String, message: String) -> Self:
        return Self(Self.IO, String(), message, database)

    @staticmethod
    def protocol(database: String, message: String) -> Self:
        return Self(Self.PROTOCOL, String(), message, database)

    @staticmethod
    def server(database: String, code: String, message: String) -> Self:
        return Self(Self.SERVER, code, message, database)

    @staticmethod
    def decode(message: String) -> Self:
        return Self(Self.DECODE, String(), message, String())

    @staticmethod
    def usage(database: String, message: String) -> Self:
        return Self(Self.USAGE, String(), message, database)

    def breaks_connection(self) -> Bool:
        """Whether the connection that raised this can't be used again."""
        return (
            self.kind == Self.IO
            or self.kind == Self.PROTOCOL
            or self.kind == Self.CONNECT
            or self.kind == Self.AUTH
        )

    def is_duplicate(self) -> Bool:
        """Whether a unique constraint or primary key refused the write."""
        if self.kind != Self.SERVER:
            return False
        if self.database == "postgres":
            return self.code == "23505"
        if self.database == "mysql":
            return self.code == "1062"
        if self.database == "sqlite":
            return self.code == "2067" or self.code == "1555"
        if self.database == "mongo":
            return self.code == "11000"
        return False

    def kind_name(self) -> String:
        if self.kind == Self.CONNECT:
            return "connect"
        if self.kind == Self.AUTH:
            return "auth"
        if self.kind == Self.IO:
            return "io"
        if self.kind == Self.PROTOCOL:
            return "protocol"
        if self.kind == Self.SERVER:
            return "server"
        if self.kind == Self.DECODE:
            return "decode"
        if self.kind == Self.POOL_TIMEOUT:
            return "pool timeout"
        return "usage"

    def write_to[W: Writer](self, mut writer: W):
        """Write `postgres server error 23505: duplicate key ...`."""
        if self.database != "":
            writer.write(self.database, " ")
        writer.write(self.kind_name(), " error")
        if self.code != "":
            writer.write(" ", self.code)
        writer.write(": ", self.message)

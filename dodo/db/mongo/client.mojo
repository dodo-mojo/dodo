"""The MongoDB pool most code uses, and collections on it."""

from std.collections import Optional

from ..error import DbError
from ..pool import Pool, PoolOptions, Pooled
from ..rows import Rows
from . import bson as bson_types
from . import protocol
from .bson import DB, Bson, BsonArray, BsonValue
from .connection import MongoConfig, MongoConnection


struct Mongo(Copyable):
    """A pool of connections to one MongoDB server.

    Cheap to copy; every copy shares the connections, so keep one in the
    app state.

    ```mojo
    var mongo = Mongo("mongodb://app:secret@localhost:27017/app")
    var users = mongo.collection("users")
    var id = users.insert_one(Bson().add("name", "ada").add("score", 9.5))
    var top = users.find(Bson().add("score", Bson().add("$gt", 5))).to[User]()
    ```

    Filters and updates are documents, never strings, so a value from a
    request can't turn into an operator unless the code puts it in a key.
    """

    var _pool: Pool[MongoConnection]
    var _database: String

    def __init__(
        out self, url: String, options: PoolOptions = PoolOptions()
    ) raises DbError:
        self = Self(MongoConfig.from_url(url), options)

    def __init__(
        out self, config: MongoConfig, options: PoolOptions = PoolOptions()
    ):
        self._database = config.database
        self._pool = Pool[MongoConnection](config, options)

    def collection(
        self, name: String, database: String = ""
    ) -> MongoCollection:
        """A collection in `database`, or in the URL's database."""
        return MongoCollection(
            self, name, database if database != "" else self._database
        )

    def command(
        self, command: Bson, database: String = ""
    ) raises DbError -> Bson:
        """Run any command (`{"ping": 1}`, `{"dbStats": 1}`) and return the
        reply. Raises when the server answers `ok: 0`."""
        var conn = self._pool.acquire()
        return conn.conn().command(
            database if database != "" else self._database, command
        )

    def connection(self) raises DbError -> Pooled[MongoConnection]:
        return self._pool.acquire()

    def open_count(self) -> Int:
        return self._pool.open_count()

    def idle_count(self) -> Int:
        return self._pool.idle_count()


@fieldwise_init
struct UpdateResult(Copyable, Writable):
    var matched: Int
    var modified: Int
    var upserted_id: Optional[BsonValue]

    def write_to[W: Writer](self, mut writer: W):
        writer.write("matched=", self.matched, " modified=", self.modified)


struct MongoCollection(Copyable):
    """One collection. Cheap to make and copy."""

    var _client: Mongo
    var name: String
    var database: String

    def __init__(out self, client: Mongo, name: String, database: String):
        self._client = client.copy()
        self.name = name
        self.database = database

    def _command(self, command: Bson) raises DbError -> Bson:
        var conn = self._client._pool.acquire()
        return conn.conn().command(self.database, command)

    def _write(self, command: Bson) raises DbError -> Bson:
        var conn = self._client._pool.acquire()
        var reply = conn.conn().run(self.database, command)
        protocol.check_write(reply)
        return reply^

    # ── Writes ──────────────────────────────────────────────────────────────

    def insert_one(self, doc: Bson) raises DbError -> BsonValue:
        """Insert a document; return its `_id`, generated here when the
        document has none."""
        var id = doc.find("_id")
        var stored = doc.copy()
        if not id:
            id = BsonValue.new_object_id()
            stored = doc.with_first("_id", id.value())
        _ = self._write(
            Bson()
            .add("insert", self.name)
            .add("documents", BsonArray().append(stored))
        )
        return id.take()

    def insert_many(
        self, docs: List[Bson], ordered: Bool = True
    ) raises DbError -> Int:
        """Insert documents (with generated `_id`s where missing); return
        how many went in. `ordered` stops at the first failure."""
        if len(docs) == 0:
            return 0
        var items = BsonArray()
        for ref doc in docs:
            if doc.has("_id"):
                items.push(doc.copy())
            else:
                items.push(doc.with_first("_id", BsonValue.new_object_id()))
        var reply = self._write(
            Bson()
            .add("insert", self.name)
            .add("documents", items)
            .add("ordered", ordered)
        )
        return reply.int("n")

    def update_one(
        self, filter: Bson, update: Bson, upsert: Bool = False
    ) raises DbError -> UpdateResult:
        """Apply `update` (`{"$set": {...}}`, or a pipeline) to the first
        document matching `filter`."""
        return self._update(filter, update, upsert, False)

    def update_many(
        self, filter: Bson, update: Bson, upsert: Bool = False
    ) raises DbError -> UpdateResult:
        return self._update(filter, update, upsert, True)

    def _update(
        self, filter: Bson, update: Bson, upsert: Bool, multi: Bool
    ) raises DbError -> UpdateResult:
        var statement = (
            Bson()
            .add("q", filter.copy())
            .add("u", update.copy())
            .add("upsert", upsert)
            .add("multi", multi)
        )
        var reply = self._write(
            Bson()
            .add("update", self.name)
            .add("updates", BsonArray().append(statement))
        )
        var upserted = Optional[BsonValue](None)
        var ids = reply.find("upserted")
        if ids:
            var items = ids.value().as_array()
            if len(items) > 0:
                upserted = items[0].as_doc().get("_id")
        var matched = reply.int("n")
        if upserted:
            matched -= 1
        return UpdateResult(matched, reply.int("nModified"), upserted^)

    def delete_one(self, filter: Bson) raises DbError -> Int:
        return self._delete(filter, 1)

    def delete_many(self, filter: Bson) raises DbError -> Int:
        """Delete every match. An empty filter deletes everything."""
        return self._delete(filter, 0)

    def _delete(self, filter: Bson, limit: Int) raises DbError -> Int:
        var statement = Bson().add("q", filter.copy()).add("limit", limit)
        var reply = self._write(
            Bson()
            .add("delete", self.name)
            .add("deletes", BsonArray().append(statement))
        )
        return reply.int("n")

    # ── Reads ───────────────────────────────────────────────────────────────

    def find(
        self,
        filter: Bson = Bson(),
        sort: Bson = Bson(),
        limit: Int = 0,
        skip: Int = 0,
        projection: Bson = Bson(),
    ) raises DbError -> Documents:
        """Every match, following the cursor to the end."""
        var command = Bson().add("find", self.name).add("filter", filter.copy())
        if len(sort) > 0:
            command.put("sort", sort.copy())
        if len(projection) > 0:
            command.put("projection", projection.copy())
        if limit > 0:
            command.put("limit", limit)
        if skip > 0:
            command.put("skip", skip)
        return self._cursor(command)

    def find_one(
        self, filter: Bson = Bson(), sort: Bson = Bson()
    ) raises DbError -> Optional[Bson]:
        var found = self.find(filter, sort, limit=1)
        if len(found) == 0:
            return None
        return found[0].copy()

    def count(self, filter: Bson = Bson()) raises DbError -> Int:
        return self._command(
            Bson().add("count", self.name).add("query", filter.copy())
        ).int("n")

    def aggregate(self, pipeline: BsonArray) raises DbError -> Documents:
        """Run an aggregation pipeline:
        `BsonArray().append(Bson().add("$group", ...))`."""
        return self._cursor(
            Bson()
            .add("aggregate", self.name)
            .add("pipeline", pipeline.copy())
            .add("cursor", Bson())
        )

    def _cursor(self, command: Bson) raises DbError -> Documents:
        """Run a command that opens a cursor and drain it on the same
        connection."""
        var conn = self._client._pool.acquire()
        var reply = conn.conn().command(self.database, command)
        var cursor = reply.doc("cursor")
        var docs = List[Bson]()
        _collect(cursor.get("firstBatch"), docs)
        var id = cursor.int("id")
        while id != 0:
            var more = (
                Bson()
                .add("getMore", BsonValue.int64(id))
                .add("collection", self.name)
            )
            var next = conn.conn().command(self.database, more).doc("cursor")
            _collect(next.get("nextBatch"), docs)
            id = next.int("id")
        return Documents(docs^)

    # ── Admin ───────────────────────────────────────────────────────────────

    def create_index(
        self, keys: Bson, unique: Bool = False
    ) raises DbError -> String:
        """Create an index (`Bson().add("email", 1)`); return its name."""
        var name = String()
        for key in keys.keys():
            if name != "":
                name += "_"
            name += key + "_" + String(keys.get(key))
        var index = Bson().add("key", keys.copy()).add("name", name)
        if unique:
            index.put("unique", True)
        _ = self._command(
            Bson()
            .add("createIndexes", self.name)
            .add("indexes", BsonArray().append(index))
        )
        return name^

    def drop(self) raises DbError:
        """Drop the collection; nothing happens when it doesn't exist."""
        try:
            _ = self._command(Bson().add("drop", self.name))
        except e:
            if e.code != "26":  # NamespaceNotFound
                raise e^


def _collect(batch: BsonValue, mut docs: List[Bson]) raises DbError:
    for item in batch.as_array():
        docs.append(item.as_doc())


struct Documents(Copyable, Sized, Writable):
    """Documents a query returned.

    `to[T]` fills structs by field name, like `Rows.to[T]`: a missing or
    null field reads as an empty `Optional`, an ObjectId as its hex text,
    a date as milliseconds.
    """

    var docs: List[Bson]

    def __init__(out self, var docs: List[Bson]):
        self.docs = docs^

    def __len__(self) -> Int:
        return len(self.docs)

    def __getitem__(self, index: Int) -> Bson:
        return self.docs[index].copy()

    def to[T: Movable & Deinitable](self) raises DbError -> List[T]:
        return self._rows[T]().to[T]()

    def one[T: Movable & Deinitable](self) raises DbError -> T:
        """The first document; raises when there are none."""
        return self._rows[T]().one[T]()

    def first[T: Movable & Deinitable](self) raises DbError -> Optional[T]:
        return self._rows[T]().first[T]()

    def _rows[T: AnyType](self) raises DbError -> Rows:
        comptime count = reflect[T].field_count()
        comptime names = reflect[T].field_names()
        var rows = Rows()
        comptime for idx in range(count):
            comptime name = names[idx]
            rows.add_column(name, "")
        for ref doc in self.docs:
            comptime for idx in range(count):
                comptime name = names[idx]
                _push(rows, doc.find(name))
            rows.end_row()
        return rows^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("[")
        for i in range(len(self.docs)):
            if i > 0:
                writer.write(", ")
            writer.write(self.docs[i])
        writer.write("]")


def _push(mut rows: Rows, found: Optional[BsonValue]) raises DbError:
    if not found:
        rows.push_null()
        return
    ref value = found.value()
    var kind = value.kind
    if value.is_null():
        rows.push_null()
    elif (
        kind == bson_types.INT32
        or kind == bson_types.INT64
        or kind == bson_types.DATETIME
    ):
        rows.push_int(value.as_int())
    elif kind == bson_types.DOUBLE:
        rows.push_float(value.as_float())
    elif kind == bson_types.BOOL:
        rows.push_int(1 if value.as_bool() else 0)
    elif kind == bson_types.BINARY:
        rows.push_bytes(Span(value.as_bytes()))
    elif (
        kind == bson_types.STRING
        or kind == bson_types.OBJECT_ID
        or kind == bson_types.SYMBOL
    ):
        rows.push_text(value.as_string().as_bytes())
    else:
        rows.push_text(String(value).as_bytes())

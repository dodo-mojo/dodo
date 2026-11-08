# `dodo.db.mongo.client`

The MongoDB pool most code uses, and collections on it.

## Structs

### `Mongo`

```mojo
struct Mongo
```

A pool of connections to one MongoDB server.

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

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `Mongo.__init__`

```mojo
def __init__(out self, url: String, options: PoolOptions = PoolOptions()) raises
```

```mojo
def __init__(out self, config: MongoConfig, options: PoolOptions = PoolOptions())
```

#### `Mongo.collection`

```mojo
def collection(self, name: String, database: String = "") -> MongoCollection
```

A collection in `database`, or in the URL's database.

#### `Mongo.command`

```mojo
def command(self, command: Bson, database: String = "") raises -> Bson
```

Run any command (`{"ping": 1}`, `{"dbStats": 1}`) and return the reply. Raises when the server answers `ok: 0`.

#### `Mongo.connection`

```mojo
def connection(self) raises -> Pooled[MongoConnection]
```

#### `Mongo.open_count`

```mojo
def open_count(self) -> Int
```

#### `Mongo.idle_count`

```mojo
def idle_count(self) -> Int
```

### `UpdateResult`

```mojo
struct UpdateResult
```

Fields:

- `matched` (`Int`)
- `modified` (`Int`)
- `upserted_id` (`Optional[BsonValue]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `UpdateResult.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

### `MongoCollection`

```mojo
struct MongoCollection
```

One collection. Cheap to make and copy.

Fields:

- `name` (`String`)
- `database` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `MongoCollection.__init__`

```mojo
def __init__(out self, client: Mongo, name: String, database: String)
```

#### `MongoCollection.insert_one`

```mojo
def insert_one(self, doc: Bson) raises -> BsonValue
```

Insert a document; return its `_id`, generated here when the document has none.

#### `MongoCollection.insert_many`

```mojo
def insert_many(self, docs: List[Bson], ordered: Bool = True) raises -> Int
```

Insert documents (with generated `_id`s where missing); return how many went in. `ordered` stops at the first failure.

#### `MongoCollection.update_one`

```mojo
def update_one(self, filter: Bson, update: Bson, upsert: Bool = False) raises -> UpdateResult
```

Apply `update` (`{"$set": {...}}`, or a pipeline) to the first document matching `filter`.

#### `MongoCollection.update_many`

```mojo
def update_many(self, filter: Bson, update: Bson, upsert: Bool = False) raises -> UpdateResult
```

#### `MongoCollection.delete_one`

```mojo
def delete_one(self, filter: Bson) raises -> Int
```

#### `MongoCollection.delete_many`

```mojo
def delete_many(self, filter: Bson) raises -> Int
```

Delete every match. An empty filter deletes everything.

#### `MongoCollection.find`

```mojo
def find(self, filter: Bson = Bson(), sort: Bson = Bson(), limit: Int = Int(0), skip: Int = Int(0), projection: Bson = Bson()) raises -> Documents
```

Every match, following the cursor to the end.

#### `MongoCollection.find_one`

```mojo
def find_one(self, filter: Bson = Bson(), sort: Bson = Bson()) raises -> Optional[Bson]
```

#### `MongoCollection.count`

```mojo
def count(self, filter: Bson = Bson()) raises -> Int
```

#### `MongoCollection.aggregate`

```mojo
def aggregate(self, pipeline: BsonArray) raises -> Documents
```

Run an aggregation pipeline: `BsonArray().append(Bson().add("$group", ...))`.

#### `MongoCollection.create_index`

```mojo
def create_index(self, keys: Bson, unique: Bool = False) raises -> String
```

Create an index (`Bson().add("email", 1)`); return its name.

#### `MongoCollection.drop`

```mojo
def drop(self) raises
```

Drop the collection; nothing happens when it doesn't exist.

### `Documents`

```mojo
struct Documents
```

Documents a query returned.

`to[T]` fills structs by field name, like `Rows.to[T]`: a missing or
null field reads as an empty `Optional`, an ObjectId as its hex text,
a date as milliseconds.

Fields:

- `docs` (`List[Bson]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Sized`, `Writable`

#### `Documents.__init__`

```mojo
def __init__(out self, var docs: List[Bson])
```

#### `Documents.__getitem__`

```mojo
def __getitem__(self, index: Int) -> Bson
```

#### `Documents.__len__`

```mojo
def __len__(self) -> Int
```

#### `Documents.to`

```mojo
def to[T: Deinitable & Movable](self) raises -> List[T]
```

#### `Documents.one`

```mojo
def one[T: Deinitable & Movable](self) raises -> T
```

The first document; raises when there are none.

#### `Documents.first`

```mojo
def first[T: Deinitable & Movable](self) raises -> Optional[T]
```

#### `Documents.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

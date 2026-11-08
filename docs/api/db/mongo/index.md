# `dodo.db.mongo`

MongoDB, over OP_MSG with BSON.

```mojo
from dodo.db.mongo import Bson, Mongo

var mongo = Mongo("mongodb://app:secret@localhost:27017/app")
var users = mongo.collection("users")
_ = users.insert_one(Bson().add("name", "ada").add("score", 9.5))
var ada = users.find_one(Bson().add("name", "ada"))
```

Authentication is SCRAM-SHA-256. One server at a time: replica-set
discovery, `mongodb+srv://` and multi-document transactions are not
supported yet. See ADR-0009.

## Modules

- [`dodo.db.mongo.bson`](bson.md): BSON, MongoDB's document format: building, validating and reading.
- [`dodo.db.mongo.client`](client.md): The MongoDB pool most code uses, and collections on it.
- [`dodo.db.mongo.connection`](connection.md): One connection to a MongoDB server.
- [`dodo.db.mongo.protocol`](protocol.md): MongoDB's OP_MSG framing and command replies, without I/O.

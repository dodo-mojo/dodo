"""MongoDB, over OP_MSG with BSON.

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
"""

from .bson import Bson, BsonArray, BsonValue
from .client import Documents, Mongo, MongoCollection, UpdateResult
from .connection import MongoConfig, MongoConnection

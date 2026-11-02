"""Live tests: dodo.db.mongo against MongoDB 8 in Docker.

    docker compose -f tests/live/db/compose.yaml up -d --wait
    pixi run tests-db
"""

from std.collections import Optional
from std.os import getenv
from std.testing import assert_equal, assert_false, assert_true

from dodo.db import DbError, PoolOptions
from dodo.db.mongo import Bson, BsonArray, BsonValue, Mongo, MongoCollection


def mongo_url() -> String:
    return getenv(
        "DODO_TEST_MONGO",
        "mongodb://dodo:dodo-test@127.0.0.1:47017/dodo?authSource=admin",
    )


@fieldwise_init
struct User(Movable):
    var _id: String
    var name: String
    var score: Float64
    var active: Bool
    var note: Optional[String]


def fresh(mongo: Mongo, name: String) raises -> MongoCollection:
    var users = mongo.collection(name)
    users.drop()
    return users^


def check_round_trip(mongo: Mongo) raises:
    var users = fresh(mongo, "users")
    var evil = String("bob {$ne: 1} '); db.dropDatabase(); héllo 🦤")
    var id = users.insert_one(
        Bson()
        .add("name", "ada")
        .add("score", 9.5)
        .add("active", True)
        .add("note", BsonValue.null())
    )
    assert_equal(id.object_id_hex().byte_length(), 24)
    _ = users.insert_one(
        Bson()
        .add("_id", "bob")
        .add("name", evil)
        .add("score", -1.25)
        .add("active", False)
        .add("note", "n")
    )
    assert_equal(users.count(), 2)

    var all = users.find(sort=Bson().add("score", -1)).to[User]()
    assert_equal(len(all), 2)
    assert_equal(all[0].name, "ada")
    assert_equal(all[0]._id, id.object_id_hex())
    assert_false(Bool(all[0].note))
    assert_equal(all[1]._id, "bob")
    assert_equal(all[1].name, evil)
    assert_equal(all[1].note.value(), "n")

    # The value is matched literally; it is not an operator.
    assert_equal(len(users.find(Bson().add("name", evil))), 1)
    assert_equal(len(users.find(Bson().add("name", "{$ne: 1}"))), 0)

    var positive = users.find(Bson().add("score", Bson().add("$gt", 0)))
    assert_equal(len(positive), 1)
    assert_equal(positive[0].string("name"), "ada")
    var one = users.find_one(Bson().add("_id", "bob")).value().copy()
    assert_equal(one.float("score"), -1.25)
    assert_false(Bool(users.find_one(Bson().add("_id", "nobody"))))

    var picked = users.find(
        projection=Bson().add("name", 1).add("_id", 0),
        sort=Bson().add("name", 1),
    )
    assert_equal(len(picked[0]), 1)
    assert_equal(len(users.find(limit=1)), 1)
    assert_equal(len(users.find(skip=1)), 1)


def check_types(mongo: Mongo) raises:
    var things = fresh(mongo, "things")
    var blob = List[UInt8]()
    for i in range(256):
        blob.append(UInt8(i))
    _ = things.insert_one(
        Bson()
        .add("_id", 1)
        .add("small", 7)
        .add("big", 1 << 40)
        .add("long", BsonValue.int64(5))
        .add("float", 2.5)
        .add("data", BsonValue.binary(blob))
        .add("when", BsonValue.date_ms(1_700_000_000_000))
        .add("oid", BsonValue.object_id("0123456789abcdef01234567"))
        .add(
            "tags",
            BsonArray().append("a").append(2).append(Bson().add("deep", True)),
        )
        .add("address", Bson().add("city", "Pune").add("pin", 411001))
    )
    var doc = things.find_one(Bson().add("_id", 1)).value().copy()
    assert_equal(doc.int("small"), 7)
    assert_equal(doc.int("big"), 1 << 40)
    assert_equal(doc.int("long"), 5)
    assert_equal(doc.float("float"), 2.5)
    var data = doc.get("data").as_bytes()
    assert_equal(len(data), 256)
    assert_equal(Int(data[255]), 255)
    assert_equal(doc.int("when"), 1_700_000_000_000)
    assert_equal(doc.get("oid").object_id_hex(), "0123456789abcdef01234567")
    var tags = doc.array("tags")
    assert_equal(len(tags), 3)
    assert_equal(tags[0].as_string(), "a")
    assert_equal(tags[1].as_int(), 2)
    assert_true(tags[2].as_doc().bool("deep"))
    assert_equal(doc.doc("address").string("city"), "Pune")
    assert_equal(doc.doc("address").int("pin"), 411001)
    assert_equal(String(doc.doc("address")), '{"city": "Pune", "pin": 411001}')
    var failed = False
    try:
        _ = doc.string("small")
    except e:
        failed = True
        assert_equal(e.kind, DbError.DECODE)
    assert_true(failed, "an int is not a string")


def check_updates(mongo: Mongo) raises:
    var users = fresh(mongo, "users")
    _ = users.insert_many(
        [
            Bson().add("_id", 1).add("name", "a").add("score", 1),
            Bson().add("_id", 2).add("name", "b").add("score", 2),
            Bson().add("_id", 3).add("name", "c").add("score", 3),
        ]
    )
    var one = users.update_one(
        Bson().add("_id", 1), Bson().add("$set", Bson().add("name", "A"))
    )
    assert_equal(one.matched, 1)
    assert_equal(one.modified, 1)
    var many = users.update_many(
        Bson().add("score", Bson().add("$gte", 2)),
        Bson().add("$inc", Bson().add("score", 10)),
    )
    assert_equal(many.matched, 2)
    assert_equal(users.find_one(Bson().add("_id", 3)).value().int("score"), 13)
    var up = users.update_one(
        Bson().add("_id", 9),
        Bson().add("$set", Bson().add("name", "new")),
        upsert=True,
    )
    assert_equal(up.matched, 0)
    assert_equal(up.upserted_id.value().as_int(), 9)
    assert_equal(users.delete_one(Bson().add("_id", 9)), 1)
    assert_equal(
        users.delete_many(Bson().add("score", Bson().add("$gt", 10))), 2
    )
    assert_equal(users.count(), 1)

    var grouped = users.aggregate(
        BsonArray().append(
            Bson().add(
                "$group",
                Bson()
                .add("_id", BsonValue.null())
                .add("total", Bson().add("$sum", "$score")),
            )
        )
    )
    assert_equal(grouped[0].int("total"), 1)


def check_errors(mongo: Mongo) raises:
    var users = fresh(mongo, "users")
    _ = users.create_index(Bson().add("email", 1), unique=True)
    _ = users.insert_one(Bson().add("email", "a@x"))
    var failed = False
    try:
        _ = users.insert_one(Bson().add("email", "a@x"))
    except e:
        failed = True
        assert_true(e.is_duplicate(), String(e))
    assert_true(failed, "duplicate key should fail")
    failed = False
    try:
        _ = users.find(Bson().add("score", Bson().add("$nosuchop", 1)))
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
        assert_equal(e.code, "2")
    assert_true(failed, "an unknown operator should fail")
    failed = False
    try:
        _ = mongo.command(Bson().add("noSuchCommand", 1))
    except e:
        failed = True
        assert_equal(e.code, "59")
    assert_true(failed, "an unknown command should fail")
    # The connection survived every error above.
    assert_equal(mongo.command(Bson().add("ping", 1)).float("ok"), 1.0)


def check_cursor_and_large(mongo: Mongo) raises:
    var many = fresh(mongo, "many")
    var docs = List[Bson]()
    for i in range(1000):
        docs.append(Bson().add("_id", i).add("n", i))
    assert_equal(many.insert_many(docs), 1000)
    var all = many.find(sort=Bson().add("_id", 1))
    assert_equal(len(all), 1000)
    assert_equal(all[999].int("n"), 999)

    var big = String()
    for _ in range(100_000):
        big += "0123456789"
    var large = fresh(mongo, "large")
    _ = large.insert_one(Bson().add("_id", 1).add("big", big))
    assert_equal(
        large.find_one().value().string("big").byte_length(), 1_000_000
    )


def pool_of(size: Int) -> PoolOptions:
    var options = PoolOptions()
    options.max_size = size
    options.acquire_timeout_ms = 300
    return options^


def check_pool_limits(url: String) raises:
    var mongo = Mongo(url, pool_of(1))
    var held = mongo.connection()
    var failed = False
    try:
        _ = mongo.command(Bson().add("ping", 1))
    except e:
        failed = True
        assert_equal(e.kind, DbError.POOL_TIMEOUT)
    assert_true(failed, "second checkout should time out")
    _ = held^
    assert_equal(mongo.command(Bson().add("ping", 1)).float("ok"), 1.0)
    assert_equal(mongo.open_count(), 1)


def check_auth() raises:
    var failed = False
    try:
        _ = Mongo(
            "mongodb://dodo:wrong@127.0.0.1:47017/dodo?authSource=admin"
        ).command(Bson().add("ping", 1))
    except e:
        failed = True
        assert_equal(e.kind, DbError.AUTH)
        assert_equal(e.code, "18")
    assert_true(failed, "wrong password should fail")
    failed = False
    try:
        _ = Mongo("mongodb://127.0.0.1:47017/dodo").collection("users").count()
    except e:
        failed = True
        assert_equal(e.kind, DbError.SERVER)
        assert_equal(e.code, "13")
    assert_true(failed, "no credentials should be unauthorized")
    failed = False
    try:
        _ = Mongo("mongodb://a,b/x")
    except e:
        failed = True
        assert_equal(e.kind, DbError.USAGE)
    assert_true(failed, "seed lists are refused")


def test_mongo() raises:
    var mongo = Mongo(mongo_url())
    check_round_trip(mongo)
    check_types(mongo)
    check_updates(mongo)
    check_errors(mongo)
    check_cursor_and_large(mongo)
    check_pool_limits(mongo_url())
    check_auth()
    print("   mongo : ok")


def main() raises:
    test_mongo()
    print("test_mongo: 1 passed")

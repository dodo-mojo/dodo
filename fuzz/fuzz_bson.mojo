"""Fuzz harness: MongoDB replies, BSON documents inside OP_MSG.

Two targets:

- a BSON document: `Bson.parse`, then every value read every way
  (`as_string`, `as_int`, `as_bytes`, nested documents and arrays), and the
  whole document written out as JSON
- an OP_MSG reply: the 16-byte header, then the body section, then the
  `ok` check a connection does on every reply

A hostile server must get a `DbError`, never a crash.

Run:
    pixi run fuzz bson
"""

from mozz import fuzz, FuzzConfig
from dodo.db.mongo import Bson, BsonArray
from dodo.db.mongo.bson import ARRAY, DOCUMENT, BsonValue
from dodo.db.mongo.protocol import HEADER, check_ok, op_msg, parse_body
from dodo.db.mongo.protocol import parse_header


def target_document(data: List[UInt8]) raises:
    _walk(Bson.parse(Span(data)))


def target_op_msg(data: List[UInt8]) raises:
    if len(data) < HEADER:
        return
    var header = parse_header(Span(data)[0:HEADER])
    if header.length > len(data):
        return
    var reply = parse_body(Span(data)[HEADER : header.length])
    _walk(reply)
    check_ok(reply)


def _walk(doc: Bson) raises:
    _ = String(doc)
    _ = len(doc)
    for key in doc.keys():
        _ = doc.has(key)
    for value in doc.values():
        _read(value)


def _read(value: BsonValue) raises:
    _ = String(value)
    _ = value.is_null()
    if value.kind == DOCUMENT or value.kind == ARRAY:
        _walk(value.as_doc())
        if value.kind == ARRAY:
            for item in value.as_array():
                _read(item)
        return
    try:
        _ = value.as_string()
    except:
        pass
    try:
        _ = value.as_int()
    except:
        pass
    try:
        _ = value.as_float()
    except:
        pass
    try:
        _ = value.as_bool()
    except:
        pass
    try:
        _ = value.as_bytes()
    except:
        pass


def _sample() raises -> Bson:
    var tags = BsonArray().append(1).append("two").append(3.5)
    var bytes = List[UInt8]()
    for i in range(6):
        bytes.append(UInt8(i))
    return (
        Bson()
        .add("ok", 1.0)
        .add("n", 42)
        .add("big", BsonValue.int64(1 << 40))
        .add("name", "ada")
        .add("yes", True)
        .add("none", BsonValue.null())
        .add("when", BsonValue.date_ms(1_700_000_000_000))
        .add("id", BsonValue.object_id("65f0a1b2c3d4e5f601234567"))
        .add("raw", BsonValue.binary(Span(bytes), 4))
        .add("tags", tags)
        .add("inner", Bson().add("x", -1).add("deep", Bson().add("y", "z")))
    )


def _error_reply() raises -> Bson:
    return (
        Bson()
        .add("ok", 0.0)
        .add("errmsg", "auth failed")
        .add("code", 18)
        .add("codeName", "AuthenticationFailed")
    )


def main() raises:
    var docs = List[List[UInt8]]()
    docs.append(_sample().encoded())
    docs.append(_error_reply().encoded())
    docs.append(Bson().encoded())

    print("[mozz] fuzzing BSON documents\n")
    fuzz(
        target_document,
        FuzzConfig(
            max_runs=200_000,
            seed=0,
            verbose=True,
            crash_dir=".mozz_crashes/bson",
            max_input_len=1024,
        ),
        docs,
    )

    var messages = List[List[UInt8]]()
    messages.append(op_msg(1, _sample()))
    messages.append(op_msg(2, _error_reply()))

    print("\n[mozz] fuzzing OP_MSG replies\n")
    fuzz(
        target_op_msg,
        FuzzConfig(
            max_runs=200_000,
            seed=1,
            verbose=True,
            crash_dir=".mozz_crashes/op_msg",
            max_input_len=1024,
        ),
        messages,
    )

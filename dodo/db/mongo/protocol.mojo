"""MongoDB's OP_MSG framing and command replies, without I/O."""

from ..error import DbError
from .bson import DB, Bson, BsonValue, _le, _put_le


comptime OP_MSG = 2013
comptime HEADER = 16
comptime MAX_MESSAGE = 48 * 1000 * 1000
"""MongoDB's maxMessageSizeBytes; larger replies are refused."""
comptime CHECKSUM_PRESENT = 1


def op_msg(request_id: Int, command: Bson) -> List[UInt8]:
    """One command as an OP_MSG with a single body section."""
    var body = command.encoded()
    var out = List[UInt8](capacity=HEADER + 5 + len(body))
    _put_le(out, HEADER + 5 + len(body), 4)
    _put_le(out, request_id, 4)
    _put_le(out, 0, 4)
    _put_le(out, OP_MSG, 4)
    _put_le(out, 0, 4)  # flags
    out.append(0)  # section kind 0: the body
    out.extend(Span(body))
    return out^


@fieldwise_init
struct Header(Copyable):
    var length: Int
    var response_to: Int
    var opcode: Int


def parse_header(data: Span[UInt8, _]) raises DbError -> Header:
    var header = Header(_le(data, 0, 4), _le(data, 8, 4), _le(data, 12, 4))
    if header.length < HEADER + 5 or header.length > MAX_MESSAGE:
        raise DbError.protocol(DB, String("bad message length ", header.length))
    if header.opcode != OP_MSG:
        raise DbError.protocol(DB, String("unexpected opcode ", header.opcode))
    return header^


def parse_body(data: Span[UInt8, _]) raises DbError -> Bson:
    """The body document of an OP_MSG, given everything after the header."""
    var end = len(data)
    var flags = _le(data, 0, 4)
    if flags & CHECKSUM_PRESENT != 0:
        end -= 4
    if end < 5 or data[4] != 0:
        raise DbError.protocol(DB, "reply has no body section")
    var size = _le(data, 5, 4)
    if size < 5 or 5 + size > end:
        raise DbError.protocol(DB, "reply body runs past the message")
    if 5 + size != end:
        raise DbError.protocol(DB, "reply has sections dodo doesn't read")
    return Bson.parse(data[5 : 5 + size])


def check_ok(reply: Bson) raises DbError:
    """Raise the server's error when `ok` isn't 1."""
    var ok = reply.find("ok")
    if ok:
        try:
            if ok.value().as_float() == 1.0:
                return
        except:
            pass
    var code = 0
    var message = String("command failed")
    try:
        code = reply.int("code")
    except:
        pass
    try:
        message = reply.string("errmsg")
    except:
        pass
    var name = String()
    try:
        name = reply.string("codeName")
    except:
        pass
    if name != "":
        message = name + ": " + message
    if code == 18:  # AuthenticationFailed
        raise DbError.auth(DB, message, String(code))
    raise DbError.server(DB, String(code), message)


def check_write(reply: Bson) raises DbError:
    """Raise the first write error of an insert, update or delete. Those
    report `ok: 1` and list per-document failures beside it."""
    check_ok(reply)
    var errors = reply.find("writeErrors")
    if errors:
        var items = errors.value().as_array()
        if len(items) > 0:
            var first = items[0].as_doc()
            var extra = String()
            if len(items) > 1:
                extra = String(" (and ", len(items) - 1, " more)")
            raise DbError.server(
                DB, String(first.int("code")), first.string("errmsg") + extra
            )
    var concern = reply.find("writeConcernError")
    if concern:
        var error = concern.value().as_doc()
        raise DbError.server(
            DB, String(error.int("code")), error.string("errmsg")
        )


def with_db(command: Bson, database: String) raises DbError -> Bson:
    """The command with its `$db` field, which OP_MSG requires."""
    var out = command.copy()
    out.put("$db", database)
    return out^


def binary_text(reply: Bson, key: String) raises DbError -> String:
    """A binary field as text (SCRAM payloads)."""
    return String(from_utf8_lossy=reply.get(key).as_bytes())

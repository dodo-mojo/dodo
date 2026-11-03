"""PostgreSQL frontend/backend protocol v3, sans I/O.

Builds the messages a client sends and reads the ones a server sends. No
sockets here: `connection.mojo` moves the bytes.

Reference: https://www.postgresql.org/docs/current/protocol-message-formats.html
"""

from ...crypto.digest import md5
from .._bytes import ByteReader, has_nul, hex_digit, put_be, put_cstr
from ..error import DbError
from ..param import Param
from ..rows import Rows

comptime DB = "postgres"

comptime PROTOCOL_3_0 = 196608
comptime SSL_REQUEST_CODE = 80877103
comptime MAX_MESSAGE = 1 << 30
"""Largest backend message accepted. PostgreSQL caps a field at 1 GB."""

comptime OID_BOOL = 16
comptime OID_BYTEA = 17
comptime OID_INT8 = 20
comptime OID_INT2 = 21
comptime OID_INT4 = 23
comptime OID_TEXT = 25
comptime OID_FLOAT4 = 700
comptime OID_FLOAT8 = 701


# ── Frontend messages ───────────────────────────────────────────────────────


def _message(tag: String, body: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8](capacity=len(body) + 5)
    out.append(tag.as_bytes()[0])
    put_be(out, len(body) + 4, 4)
    out.extend(Span(body))
    return out^


def ssl_request() -> List[UInt8]:
    var out = List[UInt8]()
    put_be(out, 8, 4)
    put_be(out, SSL_REQUEST_CODE, 4)
    return out^


def startup(
    user: String, database: String, application: String
) raises DbError -> List[UInt8]:
    if has_nul(user) or has_nul(database) or has_nul(application):
        raise DbError.usage(
            DB, "user, database and application name can't hold NUL"
        )
    var body = List[UInt8]()
    put_be(body, PROTOCOL_3_0, 4)
    put_cstr(body, "user")
    put_cstr(body, user)
    if database != "":
        put_cstr(body, "database")
        put_cstr(body, database)
    put_cstr(body, "client_encoding")
    put_cstr(body, "UTF8")
    if application != "":
        put_cstr(body, "application_name")
        put_cstr(body, application)
    body.append(0)
    var out = List[UInt8]()
    put_be(out, len(body) + 4, 4)
    out.extend(Span(body))
    return out^


def password(text: String) raises DbError -> List[UInt8]:
    if has_nul(text):
        raise DbError.usage(DB, "password can't hold NUL")
    var body = List[UInt8]()
    put_cstr(body, text)
    return _message("p", body)


def md5_password(
    user: String, password_text: String, salt: Span[UInt8, _]
) raises DbError -> List[UInt8]:
    """`md5` + hex(md5(hex(md5(password + user)) + salt))."""
    try:
        var inner = List[UInt8](password_text.as_bytes())
        inner.extend(user.as_bytes())
        var outer = List[UInt8](_hex(md5(inner)).as_bytes())
        outer.extend(salt)
        return password("md5" + _hex(md5(outer)))
    except e:
        raise DbError.auth(DB, String("MD5: ", e))


def sasl_initial(mechanism: String, data: String) -> List[UInt8]:
    var body = List[UInt8]()
    put_cstr(body, mechanism)
    put_be(body, data.byte_length(), 4)
    body.extend(data.as_bytes())
    return _message("p", body)


def sasl_response(data: String) -> List[UInt8]:
    return _message("p", List[UInt8](data.as_bytes()))


def simple_query(sql: String) raises DbError -> List[UInt8]:
    if has_nul(sql):
        raise DbError.usage(DB, "SQL text can't hold NUL")
    var body = List[UInt8]()
    put_cstr(body, sql)
    return _message("Q", body)


def extended_query(
    sql: String, params: List[Param]
) raises DbError -> List[UInt8]:
    """Parse, Bind, Describe, Execute and Sync for the unnamed statement,
    in one buffer, so a query costs one write and one round trip."""
    if has_nul(sql):
        raise DbError.usage(DB, "SQL text can't hold NUL")
    if len(params) > 65535:
        raise DbError.usage(DB, "at most 65535 parameters per statement")

    var parse = List[UInt8]()
    put_cstr(parse, "")
    put_cstr(parse, sql)
    put_be(parse, len(params), 2)
    for p in params:
        put_be(parse, _oid_of(p), 4)

    var bind = List[UInt8]()
    put_cstr(bind, "")
    put_cstr(bind, "")
    put_be(bind, len(params), 2)
    for p in params:
        put_be(bind, 1 if p.kind == Param.BYTES else 0, 2)
    put_be(bind, len(params), 2)
    for p in params:
        if p.kind == Param.NULL:
            put_be(bind, -1 & 0xFFFFFFFF, 4)
        elif p.kind == Param.BYTES:
            put_be(bind, len(p.data), 4)
            bind.extend(Span(p.data))
        else:
            var text = p.as_text()
            put_be(bind, text.byte_length(), 4)
            bind.extend(text.as_bytes())
    put_be(bind, 0, 2)  # every result column in text format

    var describe = List[UInt8]()
    describe.append(UInt8(ord("P")))
    put_cstr(describe, "")

    var execute = List[UInt8]()
    put_cstr(execute, "")
    put_be(execute, 0, 4)

    var out = _message("P", parse)
    out.extend(Span(_message("B", bind)))
    out.extend(Span(_message("D", describe)))
    out.extend(Span(_message("E", execute)))
    out.extend(Span(sync()))
    return out^


def sync() -> List[UInt8]:
    return _message("S", List[UInt8]())


def terminate() -> List[UInt8]:
    return _message("X", List[UInt8]())


def _oid_of(p: Param) -> Int:
    """The parameter's type, or 0 to let the server infer it from the SQL."""
    if p.kind == Param.BYTES:
        return OID_BYTEA
    return 0


# ── Backend messages ────────────────────────────────────────────────────────


def frame_length(header: Span[UInt8, _]) raises DbError -> Int:
    """The body length of a message from its 5-byte header (tag + Int32)."""
    var r = ByteReader(header, DB)
    r.skip(1)
    var length = r.be(4)
    if length < 4 or length > MAX_MESSAGE:
        raise DbError.protocol(DB, String("bad message length ", length))
    return length - 4


def parse_error(body: Span[UInt8, _]) -> DbError:
    """An ErrorResponse as a `DbError`: SQLSTATE as the code, the message
    with its detail and hint. A malformed one becomes a protocol error."""
    try:
        return _read_error(body)
    except e:
        return e^


def _read_error(body: Span[UInt8, _]) raises DbError -> DbError:
    """An ErrorResponse as a `DbError`: SQLSTATE as the code, the message
    with its detail and hint."""
    var r = ByteReader(body, DB)
    var code = String()
    var message = String()
    var detail = String()
    var hint = String()
    while not r.done():
        var field = r.u8()
        if field == 0:
            break
        var value = r.cstr()
        if field == ord("C"):
            code = value
        elif field == ord("M"):
            message = value
        elif field == ord("D"):
            detail = value
        elif field == ord("H"):
            hint = value
    if detail != "":
        message += " (" + detail + ")"
    if hint != "":
        message += " Hint: " + hint
    var kind = DbError.SERVER
    # Class 28: invalid authorization. Class 08: connection exceptions.
    if code.startswith("28"):
        kind = DbError.AUTH
    elif code.startswith("08"):
        kind = DbError.CONNECT
    return DbError(kind, code, message, DB)


def parse_row_description(
    body: Span[UInt8, _], mut rows: Rows
) raises DbError -> List[Int]:
    """Add the columns to `rows`; return each column's type OID."""
    var r = ByteReader(body, DB)
    var count = r.be(2)
    var oids = List[Int](capacity=count)
    for _ in range(count):
        var name = r.cstr()
        r.skip(6)  # table OID, column number
        var oid = r.be(4)
        r.skip(8)  # type size, type modifier, format code
        rows.add_column(name, type_name(oid))
        oids.append(oid)
    return oids^


def parse_data_row(
    body: Span[UInt8, _], oids: List[Int], mut rows: Rows
) raises DbError:
    var r = ByteReader(body, DB)
    var count = r.be(2)
    if count != len(oids):
        raise DbError.protocol(
            DB, String("row has ", count, " values for ", len(oids), " columns")
        )
    for i in range(count):
        var length = r.be_signed(4)
        if length < 0:
            rows.push_null()
            continue
        var value = r.bytes(length)
        if oids[i] == OID_BYTEA:
            rows.push_bytes(_decode_bytea(value))
        else:
            rows.push_text(value)
    rows.end_row()


def parse_command_tag(body: Span[UInt8, _]) raises DbError -> Int:
    """The row count in a CommandComplete tag (`INSERT 0 3`, `UPDATE 2`),
    or 0 for tags without one (`CREATE TABLE`)."""
    var r = ByteReader(body, DB)
    var tag = r.cstr()
    var words = tag.split(" ")
    if len(words) < 2:
        return 0
    try:
        return Int(String(words[len(words) - 1]))
    except:
        return 0


def _decode_bytea(text: Span[UInt8, _]) raises DbError -> List[UInt8]:
    """bytea's hex output form: `\\x` then two hex digits per byte."""
    if len(text) < 2 or Int(text[0]) != ord("\\") or Int(text[1]) != ord("x"):
        raise DbError.protocol(
            DB, "bytea not in hex format (bytea_output = hex)"
        )
    if len(text) % 2 != 0:
        raise DbError.protocol(DB, "bytea hex has an odd length")
    var out = List[UInt8](capacity=(len(text) - 2) // 2)
    var i = 2
    while i < len(text):
        var high = hex_digit(text[i])
        var low = hex_digit(text[i + 1])
        if high < 0 or low < 0:
            raise DbError.protocol(DB, "bad hex digit in bytea")
        out.append(UInt8(high * 16 + low))
        i += 2
    return out^


def _hex(data: List[UInt8]) -> String:
    var digits = "0123456789abcdef"
    var out = String()
    for b in data:
        out += digits[byte=Int(b >> 4)]
        out += digits[byte=Int(b & 15)]
    return out


def type_name(oid: Int) -> String:
    if oid == OID_BOOL:
        return "bool"
    if oid == OID_BYTEA:
        return "bytea"
    if oid == OID_INT8:
        return "int8"
    if oid == OID_INT2:
        return "int2"
    if oid == OID_INT4:
        return "int4"
    if oid == OID_TEXT:
        return "text"
    if oid == OID_FLOAT4:
        return "float4"
    if oid == OID_FLOAT8:
        return "float8"
    if oid == 1043:
        return "varchar"
    if oid == 1042:
        return "bpchar"
    if oid == 1700:
        return "numeric"
    if oid == 1082:
        return "date"
    if oid == 1083:
        return "time"
    if oid == 1114:
        return "timestamp"
    if oid == 1184:
        return "timestamptz"
    if oid == 1186:
        return "interval"
    if oid == 2950:
        return "uuid"
    if oid == 114:
        return "json"
    if oid == 3802:
        return "jsonb"
    if oid == 19:
        return "name"
    if oid == 26:
        return "oid"
    return String("oid ", oid)

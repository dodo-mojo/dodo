"""MySQL client/server protocol (also MariaDB), sans I/O.

Builds the packets a client sends and reads the ones a server sends.
`connection.mojo` moves the bytes.

Reference: https://dev.mysql.com/doc/dev/mysql-server/latest/PAGE_PROTOCOL.html
"""

from ...crypto.digest import sha1, sha256
from .._bytes import ByteReader, put_le
from ..error import DbError
from ..param import Param
from ..rows import Rows

comptime DB = "mysql"

comptime CLIENT_LONG_PASSWORD = 0x1
comptime CLIENT_CONNECT_WITH_DB = 0x8
comptime CLIENT_PROTOCOL_41 = 0x200
comptime CLIENT_SSL = 0x800
comptime CLIENT_TRANSACTIONS = 0x2000
comptime CLIENT_SECURE_CONNECTION = 0x8000
comptime CLIENT_MULTI_RESULTS = 0x20000
comptime CLIENT_PLUGIN_AUTH = 0x80000
comptime CLIENT_PLUGIN_AUTH_LENENC = 0x200000
comptime CLIENT_DEPRECATE_EOF = 0x1000000

comptime STATUS_IN_TRANS = 0x1
comptime STATUS_MORE_RESULTS = 0x8

comptime COM_QUIT = 0x01
comptime COM_QUERY = 0x03
comptime COM_PING = 0x0E
comptime COM_STMT_PREPARE = 0x16
comptime COM_STMT_EXECUTE = 0x17
comptime COM_STMT_CLOSE = 0x19
comptime COM_SET_OPTION = 0x1B

comptime CHARSET_UTF8MB4 = 45
"""Collation utf8mb4_general_ci, known to every MySQL 5.5+ and MariaDB."""
comptime CHARSET_BINARY = 63
comptime MAX_PACKET = 0xFFFFFF

comptime TYPE_DECIMAL = 0x00
comptime TYPE_TINY = 0x01
comptime TYPE_SHORT = 0x02
comptime TYPE_LONG = 0x03
comptime TYPE_FLOAT = 0x04
comptime TYPE_DOUBLE = 0x05
comptime TYPE_NULL = 0x06
comptime TYPE_TIMESTAMP = 0x07
comptime TYPE_LONGLONG = 0x08
comptime TYPE_INT24 = 0x09
comptime TYPE_DATE = 0x0A
comptime TYPE_TIME = 0x0B
comptime TYPE_DATETIME = 0x0C
comptime TYPE_YEAR = 0x0D
comptime TYPE_BLOB = 0xFC
comptime TYPE_VAR_STRING = 0xFD

comptime FLAG_UNSIGNED = 0x20


# ── Packets ─────────────────────────────────────────────────────────────────


def frame(payload: Span[UInt8, _], first_seq: Int) -> Tuple[List[UInt8], Int]:
    """Wrap `payload` in packet headers, splitting at 16 MB. Returns the
    bytes and the next sequence id."""
    var out = List[UInt8](capacity=len(payload) + 4)
    var seq = first_seq
    var at = 0
    while True:
        var chunk = min(len(payload) - at, MAX_PACKET)
        put_le(out, chunk, 3)
        out.append(UInt8(seq & 0xFF))
        out.extend(payload[at : at + chunk])
        seq = (seq + 1) & 0xFF
        at += chunk
        # A payload that is an exact multiple of 16 MB ends with an empty
        # packet, so the reader knows it stopped.
        if chunk < MAX_PACKET:
            break
    return (out^, seq)


def is_ok(packet: Span[UInt8, _]) -> Bool:
    return len(packet) > 0 and packet[0] == 0x00


def is_err(packet: Span[UInt8, _]) -> Bool:
    return len(packet) > 0 and packet[0] == 0xFF


def is_eof(packet: Span[UInt8, _]) -> Bool:
    """The end of a result set: an EOF packet, or an OK packet with the
    0xFE header when CLIENT_DEPRECATE_EOF is on."""
    return len(packet) > 0 and packet[0] == 0xFE and len(packet) < 0xFFFFFF


# ── Lengths and strings ─────────────────────────────────────────────────────


def read_lenenc(mut r: ByteReader) raises DbError -> Int:
    var first = r.u8()
    if first < 0xFB:
        return first
    if first == 0xFC:
        return r.le(2)
    if first == 0xFD:
        return r.le(3)
    if first == 0xFE:
        var value = r.le(8)
        if value < 0:
            raise DbError.protocol(DB, "length-encoded integer out of range")
        return value
    raise DbError.protocol(
        DB, String("bad length-encoded integer prefix ", first)
    )


def read_lenenc_bytes[
    o: ImmOrigin
](mut r: ByteReader[o]) raises DbError -> Span[UInt8, o]:
    var length = read_lenenc(r)
    return r.bytes(length)


def put_lenenc(mut out: List[UInt8], value: Int):
    if value < 0xFB:
        out.append(UInt8(value))
    elif value < 0x10000:
        out.append(0xFC)
        put_le(out, value, 2)
    elif value < 0x1000000:
        out.append(0xFD)
        put_le(out, value, 3)
    else:
        out.append(0xFE)
        put_le(out, value, 8)


# ── Handshake ───────────────────────────────────────────────────────────────


@fieldwise_init
struct Handshake(Movable):
    var server_version: String
    var capabilities: Int
    var nonce: List[UInt8]
    var plugin: String


def parse_handshake(packet: Span[UInt8, _]) raises DbError -> Handshake:
    if is_err(packet):
        raise parse_error(packet, DbError.CONNECT)
    var r = ByteReader(packet, DB)
    var version = r.u8()
    if version != 10:
        raise DbError.protocol(
            DB, String("unsupported handshake version ", version)
        )
    var server_version = r.cstr()
    r.skip(4)  # connection id
    var nonce = List[UInt8](r.bytes(8))
    r.skip(1)
    var capabilities = r.le(2)
    var plugin = String("mysql_native_password")
    if not r.done():
        r.skip(3)  # charset, status
        capabilities |= r.le(2) << 16
        var auth_length = r.u8()
        r.skip(10)
        if capabilities & CLIENT_SECURE_CONNECTION != 0:
            var rest = max(13, auth_length - 8)
            var part2 = r.bytes(min(rest, r.remaining()))
            # The nonce is 20 bytes; the server adds a NUL terminator.
            for i in range(min(12, len(part2))):
                nonce.append(part2[i])
        if capabilities & CLIENT_PLUGIN_AUTH != 0 and not r.done():
            plugin = r.cstr()
    if capabilities & CLIENT_PROTOCOL_41 == 0:
        raise DbError.protocol(DB, "server is older than MySQL 4.1")
    return Handshake(server_version^, capabilities, nonce^, plugin^)


def client_capabilities(server: Int, use_tls: Bool) -> Int:
    var wanted = (
        CLIENT_LONG_PASSWORD
        | CLIENT_CONNECT_WITH_DB
        | CLIENT_PROTOCOL_41
        | CLIENT_TRANSACTIONS
        | CLIENT_SECURE_CONNECTION
        | CLIENT_MULTI_RESULTS
        | CLIENT_PLUGIN_AUTH
        | CLIENT_PLUGIN_AUTH_LENENC
        | CLIENT_DEPRECATE_EOF
    )
    if use_tls:
        wanted |= CLIENT_SSL
    # Never ask for CLIENT_MULTI_STATEMENTS here: a query built by string
    # concatenation could then stack a second statement. `execute_script`
    # turns it on for one call only.
    return wanted & server


def ssl_request(capabilities: Int) -> List[UInt8]:
    var out = List[UInt8]()
    put_le(out, capabilities, 4)
    put_le(out, 1 << 24, 4)
    out.append(UInt8(CHARSET_UTF8MB4))
    for _ in range(23):
        out.append(0)
    return out^


def handshake_response(
    capabilities: Int,
    user: String,
    auth: List[UInt8],
    database: String,
    plugin: String,
) -> List[UInt8]:
    var out = ssl_request(capabilities)
    out.extend(user.as_bytes())
    out.append(0)
    put_lenenc(out, len(auth))
    out.extend(Span(auth))
    if capabilities & CLIENT_CONNECT_WITH_DB != 0:
        out.extend(database.as_bytes())
        out.append(0)
    out.extend(plugin.as_bytes())
    out.append(0)
    return out^


def scramble(
    plugin: String, password: String, nonce: Span[UInt8, _]
) raises DbError -> List[UInt8]:
    """The first authentication answer for `plugin`."""
    if password == "":
        return List[UInt8]()
    try:
        if plugin == "caching_sha2_password":
            # XOR(SHA256(pw), SHA256(SHA256(SHA256(pw)) + nonce))
            var once = sha256(password.as_bytes())
            var mix = sha256(once)
            mix.extend(nonce)
            return _xor(once, sha256(mix))
        if plugin == "mysql_native_password":
            # XOR(SHA1(pw), SHA1(nonce + SHA1(SHA1(pw))))
            var once = sha1(password.as_bytes())
            var mix = List[UInt8](nonce)
            mix.extend(Span(sha1(once)))
            return _xor(once, sha1(mix))
    except e:
        raise DbError.auth(DB, String(e))
    raise DbError.auth(DB, String("unsupported authentication plugin ", plugin))


def _xor(a: List[UInt8], b: List[UInt8]) -> List[UInt8]:
    var out = List[UInt8](capacity=len(a))
    for i in range(len(a)):
        out.append(a[i] ^ b[i % len(b)])
    return out^


def xor_password(password: String, nonce: Span[UInt8, _]) -> List[UInt8]:
    """The NUL-terminated password XORed with the nonce, for RSA."""
    var plain = List[UInt8](password.as_bytes())
    plain.append(0)
    var key = List[UInt8](nonce)
    return _xor(plain, key)


# ── Errors and OK ───────────────────────────────────────────────────────────


def parse_error(packet: Span[UInt8, _], kind: Int = DbError.SERVER) -> DbError:
    """An ERR packet as a `DbError`, with the error number as the code."""
    try:
        return _read_error(packet, kind)
    except e:
        return e^


def _read_error(packet: Span[UInt8, _], kind: Int) raises DbError -> DbError:
    var r = ByteReader(packet, DB)
    r.skip(1)
    var code = r.le(2)
    if r.remaining() > 0 and r.peek() == ord("#"):
        r.skip(6)  # '#' and the SQLSTATE
    var message = String(from_utf8_lossy=r.rest())
    var error_kind = kind
    # 1045: access denied. 1044: no access to that database.
    if code == 1045 or code == 1044 or code == 1698:
        error_kind = DbError.AUTH
    return DbError(error_kind, String(code), message, DB)


@fieldwise_init
struct Ok(Movable):
    var affected: Int
    var last_insert_id: Int
    var status: Int


def parse_ok(packet: Span[UInt8, _]) raises DbError -> Ok:
    var r = ByteReader(packet, DB)
    r.skip(1)
    var affected = read_lenenc(r)
    var last_id = read_lenenc(r)
    var status = 0
    if r.remaining() >= 2:
        status = r.le(2)
    return Ok(affected, last_id, status)


# ── Commands ────────────────────────────────────────────────────────────────


def command(code: Int, body: Span[UInt8, _]) -> List[UInt8]:
    var out = List[UInt8](capacity=len(body) + 1)
    out.append(UInt8(code))
    out.extend(body)
    return out^


def stmt_execute(statement_id: Int, params: List[Param]) -> List[UInt8]:
    var out = List[UInt8]()
    out.append(UInt8(COM_STMT_EXECUTE))
    put_le(out, statement_id, 4)
    out.append(0)  # no cursor
    put_le(out, 1, 4)  # iteration count
    if len(params) == 0:
        return out^
    var bitmap = List[UInt8](length=(len(params) + 7) // 8, fill=0)
    for i in range(len(params)):
        if params[i].kind == Param.NULL:
            bitmap[i // 8] |= UInt8(1 << (i % 8))
    out.extend(Span(bitmap))
    out.append(1)  # types follow
    for p in params:
        out.append(UInt8(_param_type(p)))
        out.append(0)
    for p in params:
        if p.kind == Param.INT:
            put_le(out, p.int_value, 8)
        elif p.kind == Param.FLOAT:
            put_le(out, Int(p.float_value.to_bits()), 8)
        elif p.kind == Param.BOOL:
            out.append(UInt8(p.int_value))
        elif p.kind == Param.TEXT:
            put_lenenc(out, p.text.byte_length())
            out.extend(p.text.as_bytes())
        elif p.kind == Param.BYTES:
            put_lenenc(out, len(p.data))
            out.extend(Span(p.data))
    return out^


def _param_type(p: Param) -> Int:
    if p.kind == Param.INT:
        return TYPE_LONGLONG
    if p.kind == Param.FLOAT:
        return TYPE_DOUBLE
    if p.kind == Param.BOOL:
        return TYPE_TINY
    if p.kind == Param.BYTES:
        return TYPE_BLOB
    if p.kind == Param.NULL:
        return TYPE_NULL
    return TYPE_VAR_STRING


@fieldwise_init
struct Prepared(Movable):
    var statement_id: Int
    var columns: Int
    var params: Int


def parse_prepare_ok(packet: Span[UInt8, _]) raises DbError -> Prepared:
    var r = ByteReader(packet, DB)
    r.skip(1)
    var statement_id = r.le(4)
    var columns = r.le(2)
    var params = r.le(2)
    return Prepared(statement_id, columns, params)


# ── Result sets ─────────────────────────────────────────────────────────────


@fieldwise_init
struct ColumnInfo(Copyable):
    var type_code: Int
    var flags: Int
    var charset: Int


def parse_column(
    packet: Span[UInt8, _], mut rows: Rows
) raises DbError -> ColumnInfo:
    var r = ByteReader(packet, DB)
    for _ in range(4):  # catalog, schema, table, original table
        _ = read_lenenc_bytes(r)
    var name = String(from_utf8_lossy=read_lenenc_bytes(r))
    _ = read_lenenc_bytes(r)  # original name
    _ = read_lenenc(r)  # length of the fixed fields, always 0x0C
    var charset = r.le(2)
    r.skip(4)  # display length
    var type_code = r.u8()
    var flags = r.le(2)
    rows.add_column(name, type_name(type_code, flags))
    return ColumnInfo(type_code, flags, charset)


def parse_text_row(
    packet: Span[UInt8, _], columns: List[ColumnInfo], mut rows: Rows
) raises DbError:
    var r = ByteReader(packet, DB)
    for column in columns:
        if r.peek() == 0xFB:
            r.skip(1)
            rows.push_null()
            continue
        var value = read_lenenc_bytes(r)
        if column.charset == CHARSET_BINARY and _is_string_type(
            column.type_code
        ):
            rows.push_bytes(value)
        else:
            rows.push_text(value)
    rows.end_row()


def parse_binary_row(
    packet: Span[UInt8, _], columns: List[ColumnInfo], mut rows: Rows
) raises DbError:
    var r = ByteReader(packet, DB)
    r.skip(1)  # 0x00 header
    var bitmap = r.bytes((len(columns) + 7 + 2) // 8)
    for i in range(len(columns)):
        var bit = i + 2
        if (Int(bitmap[bit // 8]) >> (bit % 8)) & 1 == 1:
            rows.push_null()
            continue
        _binary_value(r, columns[i], rows)
    rows.end_row()


def _binary_value(
    mut r: ByteReader, column: ColumnInfo, mut rows: Rows
) raises DbError:
    var t = column.type_code
    var unsigned = column.flags & FLAG_UNSIGNED != 0
    if t == TYPE_TINY:
        rows.push_int(r.le(1) if unsigned else r.le_signed(1))
    elif t == TYPE_SHORT or t == TYPE_YEAR:
        rows.push_int(r.le(2) if unsigned else r.le_signed(2))
    elif t == TYPE_LONG or t == TYPE_INT24:
        rows.push_int(r.le(4) if unsigned else r.le_signed(4))
    elif t == TYPE_LONGLONG:
        var value = r.le(8)
        if unsigned and value < 0:
            # Past Int64: keep the exact digits as text.
            rows.push_text(String(UInt64(value)).as_bytes())
        else:
            rows.push_int(value)
    elif t == TYPE_FLOAT:
        rows.push_float(Float64(Float32(from_bits=UInt32(r.le(4)))))
    elif t == TYPE_DOUBLE:
        rows.push_float(Float64(from_bits=UInt64(r.le(8))))
    elif t == TYPE_DATE or t == TYPE_DATETIME or t == TYPE_TIMESTAMP:
        rows.push_text(_datetime_text(r, t == TYPE_DATE).as_bytes())
    elif t == TYPE_TIME:
        rows.push_text(_time_text(r).as_bytes())
    else:
        var value = read_lenenc_bytes(r)
        if column.charset == CHARSET_BINARY and _is_string_type(t):
            rows.push_bytes(value)
        else:
            rows.push_text(value)


def _pad(value: Int, width: Int) -> String:
    var text = String(value)
    while text.byte_length() < width:
        text = "0" + text
    return text^


def _datetime_text(mut r: ByteReader, date_only: Bool) raises DbError -> String:
    """`YYYY-MM-DD`, or `YYYY-MM-DD HH:MM:SS[.ffffff]`, as the text
    protocol prints it."""
    var length = r.u8()
    var year = 0
    var month = 0
    var day = 0
    var hour = 0
    var minute = 0
    var second = 0
    var micros = 0
    if length >= 4:
        year = r.le(2)
        month = r.u8()
        day = r.u8()
    if length >= 7:
        hour = r.u8()
        minute = r.u8()
        second = r.u8()
    if length >= 11:
        micros = r.le(4)
    if length != 0 and length != 4 and length != 7 and length != 11:
        raise DbError.protocol(DB, String("bad date length ", length))
    var text = String(_pad(year, 4), "-", _pad(month, 2), "-", _pad(day, 2))
    if date_only:
        return text^
    text += String(
        " ", _pad(hour, 2), ":", _pad(minute, 2), ":", _pad(second, 2)
    )
    if micros > 0:
        text += "." + _pad(micros, 6)
    return text^


def _time_text(mut r: ByteReader) raises DbError -> String:
    """`[-]HHH:MM:SS[.ffffff]`; TIME can exceed 24 hours."""
    var length = r.u8()
    if length == 0:
        return "00:00:00"
    if length != 8 and length != 12:
        raise DbError.protocol(DB, String("bad time length ", length))
    var negative = r.u8() == 1
    var days = r.le(4)
    var hours = days * 24 + r.u8()
    var minutes = r.u8()
    var seconds = r.u8()
    var micros = 0
    if length == 12:
        micros = r.le(4)
    var text = String()
    if negative:
        text += "-"
    text += String(_pad(hours, 2), ":", _pad(minutes, 2), ":", _pad(seconds, 2))
    if micros > 0:
        text += "." + _pad(micros, 6)
    return text^


def _is_string_type(t: Int) -> Bool:
    return t >= 0xF9 or t == 0x0F


def type_name(t: Int, flags: Int) -> String:
    var unsigned = (
        String(" unsigned") if flags & FLAG_UNSIGNED != 0 else String()
    )
    if t == TYPE_TINY:
        return "tinyint" + unsigned
    if t == TYPE_SHORT:
        return "smallint" + unsigned
    if t == TYPE_INT24:
        return "mediumint" + unsigned
    if t == TYPE_LONG:
        return "int" + unsigned
    if t == TYPE_LONGLONG:
        return "bigint" + unsigned
    if t == TYPE_FLOAT:
        return "float"
    if t == TYPE_DOUBLE:
        return "double"
    if t == TYPE_DECIMAL or t == 0xF6:
        return "decimal"
    if t == TYPE_DATE:
        return "date"
    if t == TYPE_DATETIME:
        return "datetime"
    if t == TYPE_TIMESTAMP:
        return "timestamp"
    if t == TYPE_TIME:
        return "time"
    if t == TYPE_YEAR:
        return "year"
    if t == 0xF5:
        return "json"
    if t == 0x10:
        return "bit"
    if t == TYPE_BLOB or t == 0xF9 or t == 0xFA or t == 0xFB:
        return "blob"
    if t == TYPE_NULL:
        return "null"
    return "varchar"

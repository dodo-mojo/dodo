# `dodo.db.mysql.protocol`

MySQL client/server protocol (also MariaDB), sans I/O.

Builds the packets a client sends and reads the ones a server sends.
`connection.mojo` moves the bytes.

Reference: https://dev.mysql.com/doc/dev/mysql-server/latest/PAGE_PROTOCOL.html

## Aliases

### `DB`

```mojo
comptime DB = "mysql"
```

### `CLIENT_LONG_PASSWORD`

```mojo
comptime CLIENT_LONG_PASSWORD = 1
```

### `CLIENT_CONNECT_WITH_DB`

```mojo
comptime CLIENT_CONNECT_WITH_DB = 8
```

### `CLIENT_PROTOCOL_41`

```mojo
comptime CLIENT_PROTOCOL_41 = 512
```

### `CLIENT_SSL`

```mojo
comptime CLIENT_SSL = 2048
```

### `CLIENT_TRANSACTIONS`

```mojo
comptime CLIENT_TRANSACTIONS = 8192
```

### `CLIENT_SECURE_CONNECTION`

```mojo
comptime CLIENT_SECURE_CONNECTION = 32768
```

### `CLIENT_MULTI_RESULTS`

```mojo
comptime CLIENT_MULTI_RESULTS = 131072
```

### `CLIENT_PLUGIN_AUTH`

```mojo
comptime CLIENT_PLUGIN_AUTH = 524288
```

### `CLIENT_PLUGIN_AUTH_LENENC`

```mojo
comptime CLIENT_PLUGIN_AUTH_LENENC = 2097152
```

### `CLIENT_DEPRECATE_EOF`

```mojo
comptime CLIENT_DEPRECATE_EOF = 16777216
```

### `STATUS_IN_TRANS`

```mojo
comptime STATUS_IN_TRANS = 1
```

### `STATUS_MORE_RESULTS`

```mojo
comptime STATUS_MORE_RESULTS = 8
```

### `COM_QUIT`

```mojo
comptime COM_QUIT = 1
```

### `COM_QUERY`

```mojo
comptime COM_QUERY = 3
```

### `COM_PING`

```mojo
comptime COM_PING = 14
```

### `COM_STMT_PREPARE`

```mojo
comptime COM_STMT_PREPARE = 22
```

### `COM_STMT_EXECUTE`

```mojo
comptime COM_STMT_EXECUTE = 23
```

### `COM_STMT_CLOSE`

```mojo
comptime COM_STMT_CLOSE = 25
```

### `COM_SET_OPTION`

```mojo
comptime COM_SET_OPTION = 27
```

### `CHARSET_UTF8MB4`

```mojo
comptime CHARSET_UTF8MB4 = 45
```

Collation utf8mb4_general_ci, known to every MySQL 5.5+ and MariaDB.

### `CHARSET_BINARY`

```mojo
comptime CHARSET_BINARY = 63
```

### `MAX_PACKET`

```mojo
comptime MAX_PACKET = 16777215
```

### `TYPE_DECIMAL`

```mojo
comptime TYPE_DECIMAL = 0
```

### `TYPE_TINY`

```mojo
comptime TYPE_TINY = 1
```

### `TYPE_SHORT`

```mojo
comptime TYPE_SHORT = 2
```

### `TYPE_LONG`

```mojo
comptime TYPE_LONG = 3
```

### `TYPE_FLOAT`

```mojo
comptime TYPE_FLOAT = 4
```

### `TYPE_DOUBLE`

```mojo
comptime TYPE_DOUBLE = 5
```

### `TYPE_NULL`

```mojo
comptime TYPE_NULL = 6
```

### `TYPE_TIMESTAMP`

```mojo
comptime TYPE_TIMESTAMP = 7
```

### `TYPE_LONGLONG`

```mojo
comptime TYPE_LONGLONG = 8
```

### `TYPE_INT24`

```mojo
comptime TYPE_INT24 = 9
```

### `TYPE_DATE`

```mojo
comptime TYPE_DATE = 10
```

### `TYPE_TIME`

```mojo
comptime TYPE_TIME = 11
```

### `TYPE_DATETIME`

```mojo
comptime TYPE_DATETIME = 12
```

### `TYPE_YEAR`

```mojo
comptime TYPE_YEAR = 13
```

### `TYPE_BLOB`

```mojo
comptime TYPE_BLOB = 252
```

### `TYPE_VAR_STRING`

```mojo
comptime TYPE_VAR_STRING = 253
```

### `FLAG_UNSIGNED`

```mojo
comptime FLAG_UNSIGNED = 32
```

## Structs

### `Handshake`

```mojo
struct Handshake
```

Fields:

- `server_version` (`String`)
- `capabilities` (`Int`)
- `nonce` (`List[UInt8]`)
- `plugin` (`String`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

### `Ok`

```mojo
struct Ok
```

Fields:

- `affected` (`Int`)
- `last_insert_id` (`Int`)
- `status` (`Int`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

### `Prepared`

```mojo
struct Prepared
```

Fields:

- `statement_id` (`Int`)
- `columns` (`Int`)
- `params` (`Int`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

### `ColumnInfo`

```mojo
struct ColumnInfo
```

Fields:

- `type_code` (`Int`)
- `flags` (`Int`)
- `charset` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

## Functions

### `frame`

```mojo
def frame(payload: Span[UInt8], first_seq: Int) -> Tuple[List[UInt8], Int]
```

Wrap `payload` in packet headers, splitting at 16 MB. Returns the bytes and the next sequence id.

### `is_ok`

```mojo
def is_ok(packet: Span[UInt8]) -> Bool
```

### `is_err`

```mojo
def is_err(packet: Span[UInt8]) -> Bool
```

### `is_eof`

```mojo
def is_eof(packet: Span[UInt8]) -> Bool
```

The end of a result set: an EOF packet, or an OK packet with the 0xFE header when CLIENT_DEPRECATE_EOF is on.

### `read_lenenc`

```mojo
def read_lenenc(mut r: ByteReader) raises -> Int
```

### `read_lenenc_bytes`

```mojo
def read_lenenc_bytes[o: ImmOrigin](mut r: ByteReader[o]) raises -> Span[UInt8, o]
```

### `put_lenenc`

```mojo
def put_lenenc(mut out: List[UInt8], value: Int)
```

### `parse_handshake`

```mojo
def parse_handshake(packet: Span[UInt8]) raises -> Handshake
```

### `client_capabilities`

```mojo
def client_capabilities(server: Int, use_tls: Bool) -> Int
```

### `ssl_request`

```mojo
def ssl_request(capabilities: Int) -> List[UInt8]
```

### `handshake_response`

```mojo
def handshake_response(capabilities: Int, user: String, auth: List[UInt8], database: String, plugin: String) -> List[UInt8]
```

### `scramble`

```mojo
def scramble(plugin: String, password: String, nonce: Span[UInt8]) raises -> List[UInt8]
```

The first authentication answer for `plugin`.

### `xor_password`

```mojo
def xor_password(password: String, nonce: Span[UInt8]) -> List[UInt8]
```

The NUL-terminated password XORed with the nonce, for RSA.

### `parse_error`

```mojo
def parse_error(packet: Span[UInt8], kind: Int = Int(5)) -> DbError
```

An ERR packet as a `DbError`, with the error number as the code.

### `parse_ok`

```mojo
def parse_ok(packet: Span[UInt8]) raises -> Ok
```

### `command`

```mojo
def command(code: Int, body: Span[UInt8]) -> List[UInt8]
```

### `stmt_execute`

```mojo
def stmt_execute(statement_id: Int, params: List[Param]) -> List[UInt8]
```

### `parse_prepare_ok`

```mojo
def parse_prepare_ok(packet: Span[UInt8]) raises -> Prepared
```

### `parse_column`

```mojo
def parse_column(packet: Span[UInt8], mut rows: Rows) raises -> ColumnInfo
```

### `parse_text_row`

```mojo
def parse_text_row(packet: Span[UInt8], columns: List[ColumnInfo], mut rows: Rows) raises
```

### `parse_binary_row`

```mojo
def parse_binary_row(packet: Span[UInt8], columns: List[ColumnInfo], mut rows: Rows) raises
```

### `type_name`

```mojo
def type_name(t: Int, flags: Int) -> String
```

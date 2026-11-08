# `dodo.db.postgres.protocol`

PostgreSQL frontend/backend protocol v3, sans I/O.

Builds the messages a client sends and reads the ones a server sends. No
sockets here: `connection.mojo` moves the bytes.

Reference: https://www.postgresql.org/docs/current/protocol-message-formats.html

## Aliases

### `DB`

```mojo
comptime DB = "postgres"
```

### `PROTOCOL_3_0`

```mojo
comptime PROTOCOL_3_0 = 196608
```

### `SSL_REQUEST_CODE`

```mojo
comptime SSL_REQUEST_CODE = 80877103
```

### `MAX_MESSAGE`

```mojo
comptime MAX_MESSAGE = 1073741824
```

Largest backend message accepted. PostgreSQL caps a field at 1 GB.

### `OID_BOOL`

```mojo
comptime OID_BOOL = 16
```

### `OID_BYTEA`

```mojo
comptime OID_BYTEA = 17
```

### `OID_INT8`

```mojo
comptime OID_INT8 = 20
```

### `OID_INT2`

```mojo
comptime OID_INT2 = 21
```

### `OID_INT4`

```mojo
comptime OID_INT4 = 23
```

### `OID_TEXT`

```mojo
comptime OID_TEXT = 25
```

### `OID_FLOAT4`

```mojo
comptime OID_FLOAT4 = 700
```

### `OID_FLOAT8`

```mojo
comptime OID_FLOAT8 = 701
```

## Functions

### `ssl_request`

```mojo
def ssl_request() -> List[UInt8]
```

### `startup`

```mojo
def startup(user: String, database: String, application: String) raises -> List[UInt8]
```

### `password`

```mojo
def password(text: String) raises -> List[UInt8]
```

### `md5_password`

```mojo
def md5_password(user: String, password_text: String, salt: Span[UInt8]) raises -> List[UInt8]
```

`md5` + hex(md5(hex(md5(password + user)) + salt)).

### `sasl_initial`

```mojo
def sasl_initial(mechanism: String, data: String) -> List[UInt8]
```

### `sasl_response`

```mojo
def sasl_response(data: String) -> List[UInt8]
```

### `simple_query`

```mojo
def simple_query(sql: String) raises -> List[UInt8]
```

### `extended_query`

```mojo
def extended_query(sql: String, params: List[Param]) raises -> List[UInt8]
```

Parse, Bind, Describe, Execute and Sync for the unnamed statement, in one buffer, so a query costs one write and one round trip.

### `sync`

```mojo
def sync() -> List[UInt8]
```

### `terminate`

```mojo
def terminate() -> List[UInt8]
```

### `frame_length`

```mojo
def frame_length(header: Span[UInt8]) raises -> Int
```

The body length of a message from its 5-byte header (tag + Int32).

### `parse_error`

```mojo
def parse_error(body: Span[UInt8]) -> DbError
```

An ErrorResponse as a `DbError`: SQLSTATE as the code, the message with its detail and hint. A malformed one becomes a protocol error.

### `parse_row_description`

```mojo
def parse_row_description(body: Span[UInt8], mut rows: Rows) raises -> List[Int]
```

Add the columns to `rows`; return each column's type OID.

### `parse_data_row`

```mojo
def parse_data_row(body: Span[UInt8], oids: List[Int], mut rows: Rows) raises
```

### `parse_command_tag`

```mojo
def parse_command_tag(body: Span[UInt8]) raises -> Int
```

The row count in a CommandComplete tag (`INSERT 0 3`, `UPDATE 2`), or 0 for tags without one (`CREATE TABLE`).

### `type_name`

```mojo
def type_name(oid: Int) -> String
```

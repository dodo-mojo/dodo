# `dodo.db.mongo.protocol`

MongoDB's OP_MSG framing and command replies, without I/O.

## Aliases

### `OP_MSG`

```mojo
comptime OP_MSG = 2013
```

### `HEADER`

```mojo
comptime HEADER = 16
```

### `MAX_MESSAGE`

```mojo
comptime MAX_MESSAGE = 48000000
```

MongoDB's maxMessageSizeBytes; larger replies are refused.

### `CHECKSUM_PRESENT`

```mojo
comptime CHECKSUM_PRESENT = 1
```

## Structs

### `Header`

```mojo
struct Header
```

Fields:

- `length` (`Int`)
- `response_to` (`Int`)
- `opcode` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

## Functions

### `op_msg`

```mojo
def op_msg(request_id: Int, command: Bson) -> List[UInt8]
```

One command as an OP_MSG with a single body section.

### `parse_header`

```mojo
def parse_header(data: Span[UInt8]) raises -> Header
```

### `parse_body`

```mojo
def parse_body(data: Span[UInt8]) raises -> Bson
```

The body document of an OP_MSG, given everything after the header.

### `check_ok`

```mojo
def check_ok(reply: Bson) raises
```

Raise the server's error when `ok` isn't 1.

### `check_write`

```mojo
def check_write(reply: Bson) raises
```

Raise the first write error of an insert, update or delete. Those report `ok: 1` and list per-document failures beside it.

### `with_db`

```mojo
def with_db(command: Bson, database: String) raises -> Bson
```

The command with its `$db` field, which OP_MSG requires.

### `binary_text`

```mojo
def binary_text(reply: Bson, key: String) raises -> String
```

A binary field as text (SCRAM payloads).

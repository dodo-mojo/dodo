# `dodo.db.redis.protocol`

RESP2, the Redis wire protocol, without I/O.

A command goes out as an array of bulk strings. A reply is a status, an
error, an integer, a bulk string, nil, or an array of replies. Mojo can't
nest a struct inside a list of itself, so `RedisReply` keeps a whole reply,
nested arrays included, as a flat list of nodes in one shared tree.

## Aliases

### `DB`

```mojo
comptime DB = "redis"
```

### `MAX_BULK`

```mojo
comptime MAX_BULK = 536870912
```

Redis's own limit on a string value.

### `MAX_DEPTH`

```mojo
comptime MAX_DEPTH = 32
```

Arrays nested deeper than this are refused, so a hostile server can't exhaust the stack.

### `MAX_LINE`

```mojo
comptime MAX_LINE = 65536
```

Longest status, error or length line accepted.

## Structs

### `ReplyTree`

```mojo
struct ReplyTree
```

Every node of one reply, in depth-first order, and their bytes.

Fields:

- `nodes` (`List[_Node]`)
- `data` (`List[UInt8]`)

Implemented traits: `AnyType`, `Deinitable`, `Movable`

#### `ReplyTree.__init__`

```mojo
def __init__(out self)
```

#### `ReplyTree.push`

```mojo
def push(mut self, kind: Int, value: Int, bytes: Span[UInt8]) -> Int
```

Add a node; return its index. Call `close` after its children.

#### `ReplyTree.close`

```mojo
def close(mut self, index: Int)
```

### `RedisReply`

```mojo
struct RedisReply
```

One reply. Cheap to copy: copies and the elements of an array share one tree.

```mojo
var reply = db.command("LRANGE", "jobs", 0, -1)
for i in range(len(reply)):
    print(reply[i].string())
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Sized`, `Writable`

Aliases:

- `STATUS = 1`
- `ERROR = 2`
- `INT = 3`
- `BULK = 4`
- `NIL = 5`
- `ARRAY = 6`

#### `RedisReply.__init__`

```mojo
def __init__(out self, var tree: ReplyTree)
```

```mojo
def __init__(out self, tree: ArcPointer[ReplyTree], at: Int)
```

#### `RedisReply.__getitem__`

```mojo
def __getitem__(self, index: Int) raises -> Self
```

#### `RedisReply.kind`

```mojo
def kind(self) -> Int
```

#### `RedisReply.is_nil`

```mojo
def is_nil(self) -> Bool
```

#### `RedisReply.is_error`

```mojo
def is_error(self) -> Bool
```

#### `RedisReply.string`

```mojo
def string(self) raises -> String
```

A status, error, bulk string or integer as text.

#### `RedisReply.bytes`

```mojo
def bytes(self) raises -> List[UInt8]
```

A bulk string's raw bytes.

#### `RedisReply.int`

```mojo
def int(self) raises -> Int
```

An integer reply, or a bulk string holding one (`GET counter`).

#### `RedisReply.__len__`

```mojo
def __len__(self) -> Int
```

Elements in an array reply; 0 for anything else.

#### `RedisReply.items`

```mojo
def items(self) -> List[Self]
```

An array's elements in order; empty for anything else.

#### `RedisReply.strings`

```mojo
def strings(self) raises -> List[String]
```

An array of strings (`LRANGE`, `SMEMBERS`, `KEYS`).

#### `RedisReply.error_code`

```mojo
def error_code(self) -> String
```

An error's first word: `ERR`, `WRONGTYPE`, `NOAUTH`.

#### `RedisReply.kind_name`

```mojo
def kind_name(self) -> String
```

#### `RedisReply.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

## Functions

### `encode`

```mojo
def encode(mut out: List[UInt8], args: List[Param]) raises
```

Append one command. Every argument goes as a bulk string, so values are binary-safe and never parsed as part of the command.

### `command_name`

```mojo
def command_name(args: List[Param]) -> String
```

The command's first word in upper case, or empty.

### `is_refused`

```mojo
def is_refused(name: String) -> Bool
```

Commands that would leave a pooled connection in a state the next user can't see: a subscriber or monitor stream, another protocol version, another database or user, or a closed socket.

### `parse_length`

```mojo
def parse_length(line: Span[UInt8]) raises -> Int
```

The signed number after a reply's type byte.

### `reply_error`

```mojo
def reply_error(reply: RedisReply) -> DbError
```

The `DbError` for an error reply. Credential errors are `AUTH`.

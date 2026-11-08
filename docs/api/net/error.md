# `dodo.net.error`

Typed network errors for dodo.

Every error type implements ``Writable`` so it can be
used with ``print()`` and ``String()``. All types also implement ``Copyable``
and ``Movable`` because errors are often returned from functions, stored in
Result types, or logged.

Design principle: every error instance carries enough context to understand
the failure without a stack trace. Include the peer address, hostname, or
port wherever relevant.

## Structs

### `NetworkError`

```mojo
struct NetworkError
```

Generic network error — a catch-all for OS errors without a more specific typed variant.

Fields:
    message: Human-readable description (from ``strerror`` or caller).
    code: OS ``errno`` value (0 if not applicable).

Example:
```mojo
raise NetworkError("connect failed", 111)
```

Fields:

- `message` (`String`)
- `code` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `NetworkError.__init__`

```mojo
def __init__(out self, message: String, code: Int = Int(0))
```

Initialise a NetworkError.

Args:

- `message`: Human-readable description of the failure.
- `code`: OS errno value. Defaults to 0 (not an OS error).

#### `NetworkError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write a one-line description to ``writer``.

Args:

- `writer`: Destination writer (e.g. stdout, a String).

### `ConnectionRefused`

```mojo
struct ConnectionRefused
```

Raised when a TCP ``connect()`` fails with ``ECONNREFUSED``.

Fields:
    addr: String representation of the refused address (e.g. ``"127.0.0.1:8080"``).
    code: OS errno value (always ``ECONNREFUSED``).

Example:
```mojo
raise ConnectionRefused("127.0.0.1:8080", 111)
```

Fields:

- `addr` (`String`)
- `code` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `ConnectionRefused.__init__`

```mojo
def __init__(out self, addr: String, code: Int = Int(0))
```

#### `ConnectionRefused.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write ``"ConnectionRefused: addr"`` to ``writer``.

Args:

- `writer`: Destination writer.

### `ConnectionTimeout`

```mojo
struct ConnectionTimeout
```

Raised when a TCP ``connect()`` times out (``ETIMEDOUT``).

Fields:
    addr: The target address that timed out.
    code: OS errno value.

Example:
```mojo
raise ConnectionTimeout("10.0.0.1:443", 110)
```

Fields:

- `addr` (`String`)
- `code` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `ConnectionTimeout.__init__`

```mojo
def __init__(out self, addr: String, code: Int = Int(0))
```

#### `ConnectionTimeout.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write ``"ConnectionTimeout: addr"`` to ``writer``.

Args:

- `writer`: Destination writer.

### `ConnectionReset`

```mojo
struct ConnectionReset
```

Raised when the peer forcibly closes a connection (``ECONNRESET``).

Fields:
    addr: The remote address that sent a TCP RST.
    code: OS errno value.

Fields:

- `addr` (`String`)
- `code` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `ConnectionReset.__init__`

```mojo
def __init__(out self, addr: String, code: Int = Int(0))
```

#### `ConnectionReset.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write a description to ``writer``.

Args:

- `writer`: Destination writer.

### `AddressInUse`

```mojo
struct AddressInUse
```

Raised when ``bind()`` fails because the port is in use (``EADDRINUSE``).

Fields:
    addr: The address that could not be bound.
    code: OS errno value.

Example:
```mojo
raise AddressInUse("0.0.0.0:8080", 98)
```

Fields:

- `addr` (`String`)
- `code` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `AddressInUse.__init__`

```mojo
def __init__(out self, addr: String, code: Int = Int(0))
```

#### `AddressInUse.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write a description to ``writer``.

Args:

- `writer`: Destination writer.

### `AddressParseError`

```mojo
struct AddressParseError
```

Raised when an address string cannot be parsed.

Fields:
    input: The invalid input string.

Example:
```mojo
raise AddressParseError("not_an_ip")
```

Fields:

- `input` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `AddressParseError.__init__`

```mojo
def __init__(out self, input: String)
```

#### `AddressParseError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write a description to ``writer``.

Args:

- `writer`: Destination writer.

### `BrokenPipe`

```mojo
struct BrokenPipe
```

Raised on write to a connection whose read end is closed (``EPIPE``).

Fields:
    addr: The remote address of the closed connection (may be empty).
    code: OS errno value.

Fields:

- `addr` (`String`)
- `code` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `BrokenPipe.__init__`

```mojo
def __init__(out self, addr: String = "", code: Int = Int(0))
```

#### `BrokenPipe.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write a description to ``writer``.

Args:

- `writer`: Destination writer.

### `Timeout`

```mojo
struct Timeout
```

Raised when a blocking I/O operation exceeds its timeout.

Fields:
    op: Name of the operation that timed out (e.g. ``"recv"``).
    ms: Timeout in milliseconds that was set (0 if unknown).

Example:
```mojo
raise Timeout("recv", 5000)
```

Fields:

- `op` (`String`)
- `ms` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `Timeout.__init__`

```mojo
def __init__(out self, op: String, ms: Int = Int(0))
```

Initialise a Timeout error.

Args:

- `op`: The operation that timed out.
- `ms`: The configured timeout in milliseconds.

#### `Timeout.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write ``"Timeout: op"`` to ``writer``.

Args:

- `writer`: Destination writer.

### `DnsError`

```mojo
struct DnsError
```

Raised when DNS resolution fails.

Fields:
    host: The hostname that could not be resolved.
    code: The ``getaddrinfo`` error code (from ``gai_strerror``).
    reason: Human-readable reason from ``gai_strerror``.

Example:
```mojo
raise DnsError("notexist.example.com", 8, "Servname not supported")
```

Fields:

- `host` (`String`)
- `code` (`Int`)
- `reason` (`String`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`, `Writable`

#### `DnsError.__init__`

```mojo
def __init__(out self, host: String, code: Int = Int(0), reason: String = "")
```

#### `DnsError.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write ``"DnsError(host): reason"`` to ``writer``.

Args:

- `writer`: Destination writer.

# `dodo.net.address`

IP address and socket address types.

Both ``IpAddr`` and ``SocketAddr`` are copyable value types — they hold
no OS resources, so copying is safe and cheap.

IP address parsing uses the OS ``inet_pton(3)`` function for correctness
on both IPv4 and IPv6; formatting uses ``inet_ntop(3)``.

## Structs

### `IpAddr`

```mojo
struct IpAddr
```

An IP address: either IPv4 or IPv6.

The address is stored as a validated string produced by ``inet_ntop``
after successful ``inet_pton`` parsing. This guarantees all instances
hold a canonical, valid representation.

Fields:
    _addr: Canonical string form (e.g. ``"127.0.0.1"`` or ``"::1"``).
    _is_v6: ``True`` for IPv6, ``False`` for IPv4.

Example:
```mojo
var lo = IpAddr.parse("127.0.0.1")
print(lo) # 127.0.0.1
print(lo.is_loopback()) # True
```

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `IpAddr.__init__`

```mojo
def __init__(out self, addr: String, is_v6: Bool)
```

Construct an ``IpAddr`` directly from a pre-validated string.

Prefer ``IpAddr.parse`` for user-supplied strings.

Args:

- `addr`: Canonical IP address string.
- `is_v6`: ``True`` if this is an IPv6 address.

#### `IpAddr.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Return ``True`` if both addresses have the same family and string.

Args:

- `other`: The address to compare with.

#### `IpAddr.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

Return ``True`` if the addresses differ.

Args:

- `other`: The address to compare with.

#### `IpAddr.parse`

```mojo
def parse(s: String) raises -> Self
```

Parse and validate an IP address string.

Accepts dotted-decimal IPv4 (``"192.168.1.1"``) and colon-separated
IPv6 (``"::1"``, ``"2001:db8::1"``). Uses ``inet_pton`` for
correctness, then ``inet_ntop`` to obtain the canonical form.

Example:
```mojo
var v4 = IpAddr.parse("192.168.0.1")
var v6 = IpAddr.parse("::1")
```

Args:

- `s`: The address string to parse.

Returns: A validated ``IpAddr``.

Raises: AddressParseError: If ``s`` is not a valid IPv4 or IPv6 address.

#### `IpAddr.localhost`

```mojo
def localhost() -> Self
```

Return the IPv4 loopback address ``127.0.0.1``.

Returns: ``IpAddr`` for ``127.0.0.1``.

#### `IpAddr.localhost_v6`

```mojo
def localhost_v6() -> Self
```

Return the IPv6 loopback address ``::1``.

Returns: ``IpAddr`` for ``::1``.

#### `IpAddr.unspecified`

```mojo
def unspecified() -> Self
```

Return the IPv4 wildcard address ``0.0.0.0`` (all interfaces).

Returns: ``IpAddr`` for ``0.0.0.0``.

#### `IpAddr.unspecified_v6`

```mojo
def unspecified_v6() -> Self
```

Return the IPv6 wildcard address ``::`` (all interfaces).

Returns: ``IpAddr`` for ``"::"``

#### `IpAddr.is_v4`

```mojo
def is_v4(self) -> Bool
```

Return ``True`` if this is an IPv4 address.

#### `IpAddr.is_v6`

```mojo
def is_v6(self) -> Bool
```

Return ``True`` if this is an IPv6 address.

#### `IpAddr.is_loopback`

```mojo
def is_loopback(self) -> Bool
```

Return ``True`` if this is a loopback address.

IPv4 loopback range is ``127.0.0.0/8``; IPv6 loopback is ``::1``.

#### `IpAddr.is_unspecified`

```mojo
def is_unspecified(self) -> Bool
```

Return ``True`` if this is the wildcard/unspecified address.

IPv4: ``"0.0.0.0"``; IPv6: ``"::"``.

#### `IpAddr.is_private`

```mojo
def is_private(self) -> Bool
```

Return ``True`` if this is an RFC 1918 private address.

Covers ``10.0.0.0/8``, ``172.16.0.0/12``, and ``192.168.0.0/16``.
IPv6 ULA (``fc00::/7``) is not yet detected and returns ``False``.

#### `IpAddr.is_multicast`

```mojo
def is_multicast(self) -> Bool
```

Return ``True`` if this is a multicast address.

IPv4 multicast: ``224.0.0.0/4`` (first octet 224–239).
IPv6 multicast: ``ff00::/8`` (RFC 4291 section 2.7), i.e. the
first byte is ``0xff``. The stored text is ``inet_ntop``'s
(RFC 5952), which drops leading zeros of a group, so first groups
``0x00ff`` and ``0x0ff0``..``0x0fff`` print as ``ff...`` too; a
real multicast first group always has four digits, so the first
``:`` must be at index 4.

#### `IpAddr.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write the canonical address string to ``writer``.

Args:

- `writer`: Destination writer.

### `SocketAddr`

```mojo
struct SocketAddr
```

A socket address: an IP address combined with a port number.

Fields:
    ip: The IP address component.
    port: The port number (0–65535).

Example:
```mojo
var addr = SocketAddr(IpAddr.localhost(), 8080)
print(addr) # 127.0.0.1:8080

var v6 = SocketAddr(IpAddr.localhost_v6(), 443)
print(v6) # [::1]:443
```

Fields:

- `ip` (`IpAddr`)
- `port` (`UInt16`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`

#### `SocketAddr.__init__`

```mojo
def __init__(out self, ip: IpAddr, port: UInt16)
```

Initialise a ``SocketAddr``.

Args:

- `ip`: The IP address component.
- `port`: The port number (0–65535).

#### `SocketAddr.__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

Return ``True`` if IP and port both match.

Args:

- `other`: The address to compare.

#### `SocketAddr.__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

Return ``True`` if IP or port differ.

Args:

- `other`: The address to compare.

#### `SocketAddr.localhost`

```mojo
def localhost(port: UInt16) -> Self
```

Return ``SocketAddr("127.0.0.1", port)``.

Args:

- `port`: The port number.

Returns: A loopback ``SocketAddr``.

#### `SocketAddr.unspecified`

```mojo
def unspecified(port: UInt16) -> Self
```

Return ``SocketAddr("0.0.0.0", port)`` — bind on all interfaces.

Args:

- `port`: The port number.

Returns: A ``SocketAddr`` for the wildcard address.

#### `SocketAddr.parse`

```mojo
def parse(s: String) raises -> Self
```

Parse a ``"host:port"`` or ``"[ipv6]:port"`` string.

Example:
```mojo
var a = SocketAddr.parse("127.0.0.1:9000")
var b = SocketAddr.parse("[::1]:9000")
```

Args:

- `s`: Address string in one of these forms: - ``"1.2.3.4:8080"`` for IPv4. - ``"[::1]:443"`` for IPv6.

Returns: A ``SocketAddr``.

Raises: AddressParseError: If the string cannot be parsed.

#### `SocketAddr.write_to`

```mojo
def write_to[W: Writer](self, mut writer: W)
```

Write ``"ip:port"`` or ``"[ip]:port"`` to ``writer``.

Args:

- `writer`: Destination writer.

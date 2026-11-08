# `dodo.dns.resolver`

DNS hostname resolution via libc ``getaddrinfo(3)``.

References:

```mojo
- https://man7.org/linux/man-pages/man3/getaddrinfo.3.html
- ``dodo/net/_libc.mojo`` for low-level FFI wrappers
```

Memory safety contract:

```mojo
``_freeaddrinfo`` MUST be called on the linked-list head in ALL code
paths — including every error path that follows a successful
``_getaddrinfo`` call. This invariant is maintained by calling
``_freeaddrinfo(head)`` before every ``raise`` and at the successful
return path.
```

## Functions

### `resolve`

```mojo
def resolve(host: String) raises -> List[IpAddr]
```

Resolve a hostname to a list of IP addresses.

Calls ``getaddrinfo(3)`` which respects ``/etc/hosts``,
``/etc/resolv.conf``, and ``nsswitch.conf``. Returns both IPv4 and
IPv6 results in OS-preference order.

Example:
```mojo
var addrs = resolve("localhost")
for a in addrs:
    print(a[])
```

Args:

- `host`: Hostname or numeric IP string to resolve (e.g. ``"example.com"``, ``"localhost"``, ``"127.0.0.1"``).

Returns: A non-empty ``List[IpAddr]``. The first entry is the OS-preferred address for this host.

Raises: AddressParseError: If ``host`` is empty, longer than 253 bytes (one trailing root dot, as in ``"example.com."``, is not counted), has a label over 63 bytes, or contains a NUL, CR, LF or ``@``. The too-long message quotes the first 20 bytes of the host, cut at a character boundary so the text stays valid UTF-8. DnsError: On NXDOMAIN, timeout, or system resolver failure.

### `resolve_v4`

```mojo
def resolve_v4(host: String) raises -> List[IpAddr]
```

Resolve a hostname, returning only IPv4 results.

Example:
```mojo
var addrs = resolve_v4("localhost")
print(addrs[0]) # 127.0.0.1
```

Args:

- `host`: Hostname to resolve.

Returns: A non-empty ``List[IpAddr]`` containing only IPv4 addresses.

Raises: AddressParseError: If ``host`` is empty. DnsError: If no IPv4 address is found, or resolution fails.

### `resolve_v6`

```mojo
def resolve_v6(host: String) raises -> List[IpAddr]
```

Resolve a hostname, returning only IPv6 results.

Args:

- `host`: Hostname to resolve.

Returns: A non-empty ``List[IpAddr]`` containing only IPv6 addresses.

Raises: AddressParseError: If ``host`` is empty. DnsError: If no IPv6 address is found, or resolution fails.

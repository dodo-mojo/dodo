"""Raw POSIX socket primitives — the foundation of the dodo networking stack.

All higher-level modules (`dodo.tcp`, `dodo.udp`, `dodo.dns`, …) import from
here and never call libc directly.

## Public API

```mojo
from dodo.net import IpAddr, SocketAddr, RawSocket
from dodo.net import (
    NetworkError, ConnectionRefused, ConnectionTimeout, ConnectionReset,
    AddressInUse, AddressParseError, BrokenPipe, DnsError, Timeout,
)
```

## Example

```mojo
from dodo.net import IpAddr, SocketAddr

def main() raises:
    var ip = IpAddr.parse("93.184.216.34")
    print(ip.is_global()) # True
    print(ip.is_private()) # False

    var addr = SocketAddr.parse("127.0.0.1:8080")
    print(addr.port) # 8080
    print(addr.ip.is_loopback()) # True

    var local = SocketAddr.localhost(9000)
    print(local) # 127.0.0.1:9000
```
"""

from .address import IpAddr, SocketAddr
from .socket import RawSocket, _find_dodo_lib
from .error import (
    NetworkError,
    ConnectionRefused,
    ConnectionTimeout,
    ConnectionReset,
    AddressInUse,
    AddressParseError,
    BrokenPipe,
    DnsError,
    Timeout,
)

# `dodo.runtime.event`

Event primitives for the dodo reactor.

Every fd registered with the reactor is associated with a user-supplied
``UInt64`` token. When the fd becomes readable/writable/etc., the reactor
reports back an ``Event`` carrying that token and a bitmask of readiness
flags.

Interest bits (what the caller wants):

```mojo
``INTEREST_READ``, ``INTEREST_WRITE``, or both (``INTEREST_READ |
INTEREST_WRITE``).
```

Event bits (what the reactor returns):

```mojo
``EVENT_READABLE``, ``EVENT_WRITABLE``, ``EVENT_ERROR``, ``EVENT_HUP``.
These may be ORed together when multiple conditions are satisfied
simultaneously (e.g. a half-closed socket reports both READABLE and
HUP).
```

## Aliases

### `INTEREST_READ`

```mojo
comptime INTEREST_READ = Int(1)
```

### `INTEREST_WRITE`

```mojo
comptime INTEREST_WRITE = Int(2)
```

### `EVENT_READABLE`

```mojo
comptime EVENT_READABLE = Int(1)
```

### `EVENT_WRITABLE`

```mojo
comptime EVENT_WRITABLE = Int(2)
```

### `EVENT_ERROR`

```mojo
comptime EVENT_ERROR = Int(4)
```

### `EVENT_HUP`

```mojo
comptime EVENT_HUP = Int(8)
```

### `WAKEUP_TOKEN`

```mojo
comptime WAKEUP_TOKEN = UInt64(18446744073709551615)
```

### `LISTENER_TOKEN`

```mojo
comptime LISTENER_TOKEN = UInt64(1099511627776)
```

## Structs

### `Event`

```mojo
struct Event
```

A readiness event for a single registered fd.

Fields:
    token: The caller's per-fd token passed to ``register`` / ``modify``.
           ``WAKEUP_TOKEN`` (all 1s) is reserved for internal wakeup
           events and should be filtered out by the reactor layer.
    flags: Bitmask of ``EVENT_READABLE | WRITABLE | ERROR | HUP``.

Fields:

- `token` (`UInt64`)
- `flags` (`Int`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`

#### `Event.__init__`

```mojo
def __init__(out self, token: UInt64, flags: Int)
```

Construct an event with the given token and flags.

Args:

- `token`: Per-fd token assigned at registration time.
- `flags`: Bitmask of ``EVENT_*`` bits describing which conditions the reactor observed on the fd.

#### `Event.is_readable`

```mojo
def is_readable(self) -> Bool
```

Return True if ``EVENT_READABLE`` is set.

#### `Event.is_writable`

```mojo
def is_writable(self) -> Bool
```

Return True if ``EVENT_WRITABLE`` is set.

#### `Event.is_error`

```mojo
def is_error(self) -> Bool
```

Return True if ``EVENT_ERROR`` is set.

#### `Event.is_hup`

```mojo
def is_hup(self) -> Bool
```

Return True if ``EVENT_HUP`` is set (remote closed).

#### `Event.is_wakeup`

```mojo
def is_wakeup(self) -> Bool
```

Return True if this event is the reactor's internal wakeup.

Callers usually ignore wakeup events — they exist only to break
``poll`` out of its wait when another thread wants attention.

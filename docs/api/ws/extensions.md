# `dodo.ws.extensions`

``Sec-WebSocket-Extensions`` header parser + emitter (RFC 6455 §9 + RFC 7692 §7).

The header is a comma-separated list of *extension offers*; each
offer has a token name and an optional ``;``-separated list of
``key`` or ``key=value`` parameters. Whitespace around tokens is
folded; quoted-string parameter values are unquoted on parse and
re-quoted on emit when they contain bytes outside the RFC 6455
``token`` set.

This module deliberately stays narrow: it only emits / accepts
the parameters used by ``permessage-deflate`` (RFC 7692 §7.1.1):

- ``server_no_context_takeover``        (flag)
- ``client_no_context_takeover``        (flag)
- ``server_max_window_bits``            (int 8..15)
- ``client_max_window_bits``            (int 8..15, may also be a
  flag with no value when offered by the client)

Public surface:

- :class:`ExtensionOffer` -- one parsed offer.
- :func:`parse_extensions(header)` -> ``List[ExtensionOffer]``.
- :func:`build_permessage_deflate_offer(cfg)` -> ``String`` (client
  side: emit our offer).
- :func:`negotiate_permessage_deflate(offers, cfg)` -> the
  ``(accepted_header_value, negotiated_cfg)`` pair (server side:
  pick the first acceptable offer; raises if none match).

## Structs

### `ExtensionParameter`

```mojo
struct ExtensionParameter
```

One ``;``-separated parameter inside an :class:`ExtensionOffer`.

Fields:

- `name` (`String`): Lowercased parameter token (e.g. ``"client_max_window_bits"``).
- `value` (`String`): Parameter value; empty string when the parameter is a flag. Quoted-string values have surrounding quotes stripped.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `ExtensionParameter.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, name: String, value: String)
```

### `ExtensionOffer`

```mojo
struct ExtensionOffer
```

One comma-separated extension offer + its parameters.

Fields:

- `name` (`String`): Lowercased extension token (e.g. ``"permessage-deflate"``).
- `params` (`List[ExtensionParameter]`): Parsed ``;``-separated parameters in declaration order.

Implemented traits: `AnyType`, `Copyable`, `Defaultable`, `Deinitable`, `Movable`

#### `ExtensionOffer.__init__`

```mojo
def __init__(out self)
```

```mojo
def __init__(out self, name: String)
```

#### `ExtensionOffer.get`

```mojo
def get(self, name: String) raises -> Optional[String]
```

Return the value for parameter ``name`` (case-folded) if present; ``None`` otherwise. Flag-shaped parameters return ``Some("")``.

#### `ExtensionOffer.has`

```mojo
def has(self, name: String) raises -> Bool
```

Return ``True`` if parameter ``name`` is present.

## Functions

### `parse_extensions`

```mojo
def parse_extensions(header: String) raises -> List[ExtensionOffer]
```

Parse one ``Sec-WebSocket-Extensions`` header value into its constituent offers.

Multiple header values are comma-joined per RFC 6455 §9.1.
The empty header returns an empty list (no offers).

Args:

- `header`: The raw ``Sec-WebSocket-Extensions`` value.

### `build_permessage_deflate_offer`

```mojo
def build_permessage_deflate_offer(cfg: PermessageDeflateConfig) -> String
```

Build the client-side ``Sec-WebSocket-Extensions`` value for a ``permessage-deflate`` offer.

Always emits ``permessage-deflate`` plus any parameters that
differ from the RFC default. The offer always carries
``client_no_context_takeover`` and
``server_no_context_takeover`` so the negotiated mode is
deterministic.

Args:

- `cfg`: The :class:`PermessageDeflateConfig` to translate.

Returns: The header value (e.g. ``"permessage-deflate; client_no_context_takeover; server_no_context_takeover"``).

### `negotiate_permessage_deflate`

```mojo
def negotiate_permessage_deflate(offers: List[ExtensionOffer], cfg: PermessageDeflateConfig) raises -> Optional[Tuple[String, PermessageDeflateConfig]]
```

Server-side negotiation: pick the first acceptable ``permessage-deflate`` offer.

Returns ``None`` if the client offered nothing acceptable or
the server has the extension disabled. Otherwise returns the
``(Sec-WebSocket-Extensions response value, negotiated_cfg)``
pair the caller writes into the 101 response. The negotiator
always enforces ``no_context_takeover`` on both sides so the
response value is fully deterministic regardless of the
client's offer.

Args:

- `offers`: Parsed offers from the client's ``Sec-WebSocket-Extensions`` header.
- `cfg`: The server's :class:`PermessageDeflateConfig`. Must have ``enabled=True``; otherwise this returns ``None``.

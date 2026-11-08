# `dodo.http.proto.utf8`

Lossy UTF-8 decoding for caller-supplied byte bodies.

``String(unsafe_from_utf8=Span)`` is the wrong tool for bytes that
arrive off the wire: it runs the stdlib UTF-8 validator internally
despite its name (see ``proto/ascii.mojo``), and on malformed input that
validator passes the bytes through in the default build -- yielding an
ill-formed ``String`` -- and aborts the process under ``-D ASSERT=all``.
Since a peer chooses the bytes, neither outcome is acceptable on
``Request.text()`` / ``Response.text()`` / ``MultipartPart.text()``.

:func:`utf8_lossy_string` gives those call sites a total function
instead: well-formed input is copied verbatim, and each maximal
ill-formed subpart becomes one U+FFFD REPLACEMENT CHARACTER (Unicode 15
§3.9, "U+FFFD Substitution of Maximal Subparts"). The result is always
well-formed UTF-8, so it can never abort and never produces an
ill-formed ``String``.

Protocols that must *reject* invalid UTF-8 rather than substitute --
WebSocket TEXT frames under RFC 6455 §8.1 -- keep validating and
raising instead; see ``WsFrame.text_payload``.

## Functions

### `utf8_lossy_string`

```mojo
def utf8_lossy_string(data: Span[UInt8]) -> String
```

Decode ``data`` as UTF-8, substituting U+FFFD for bad sequences.

Args:

- `data`: Source bytes, typically a caller-supplied message body.

Returns: ``data`` as a ``String``, always well-formed UTF-8. Each maximal ill-formed subpart is replaced by one U+FFFD.

# `dodo.http.streaming_serialize`

Streaming response serializer.

Renders a ``StreamingResponse[B: Body]`` to wire bytes per
RFC 7230 §3 (status line + headers) + RFC 7230 §4.1 (chunked
transfer-coding) when ``B.content_length()`` is unknown, or
plain Content-Length framing when it's known.

The reactor does not call it: a handler streams by returning a
``Response`` with ``body_stream`` (see ``dodo/http/response_stream.mojo``).
This serializer is for callers that write a ``StreamingResponse``
themselves.

It is a plain function, with no parametric trait dispatch and no
per-handler specialization, so it compiles fast and is easy to test
on its own.

Wire-framing semantics:

- ``body.content_length()`` returns ``Some(n)``:
  - Header line: ``Content-Length: n\r\n``.
  - Body bytes: emit each chunk inline until ``next_chunk``
    returns None. Total emitted bytes equal n by contract.

- ``body.content_length()`` returns ``None``:
  - Header line: ``Transfer-Encoding: chunked\r\n``.
  - Body bytes: per chunk, emit ``hex_length\r\n`` + chunk +
    ``\r\n``. Final terminator: ``0\r\n\r\n``.

The serializer is cancel-aware: if ``cancel.cancelled()`` flips
between chunks, the write loop emits the final chunked
terminator and returns — the connection closes cleanly without
breaking the framing contract. Callers that need to abort
mid-chunk should close the underlying socket; the framing
guarantee covers cooperative cancel only.

## Functions

### `serialize_streaming_response`

```mojo
def serialize_streaming_response[B: Body](var resp: StreamingResponse[B], cancel: Cancel, keep_alive: Bool = True) raises -> List[UInt8]
```

Render ``resp`` to wire bytes — status line + headers + body (Content-Length or chunked framing).

Args:

- `resp`: Streaming response with a ``Body`` impl. Ownership transferred; the body is consumed chunk by chunk.
- `cancel`: Per-request cancel token. The body's ``next_chunk(cancel)`` polls this; flipping it mid-stream stops chunk emission cleanly (chunked framing's terminator is still written so the framing contract holds).
- `keep_alive`: When ``True``, the response carries ``Connection: keep-alive``; when ``False``, ``Connection: close``. The reactor sets this based on the request's connection disposition.

Returns: The wire bytes ready for ``send`` over the connection.

Raises: Error: Any error from ``body.next_chunk`` propagates.

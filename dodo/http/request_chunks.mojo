"""Streaming-shape adapter for inbound request bodies.

The ``Request.body`` field is a ``List[UInt8]`` — the reactor
pre-buffers the entire request body before dispatching to the
handler. That works for the typical 1KB JSON / form POST, but
a 100MB upload allocates 100MB per concurrent client.

``RequestChunkSource`` lets handlers consume request bodies as
a sequence of bounded-size chunks, mirroring the ``ChunkSource``
shape used for outbound :class:`StreamingResponse` bodies.
The source pulls from the pre-buffered ``Request.body``, so the
peak memory the *server* holds is unchanged; what it bounds is
what the *handler* materializes at once.

Symmetric to ``StreamingResponse[B]`` (outbound):

- ``StreamingResponse[B: Body]`` lets the reactor pull response
  chunks on writable edges via ``B.next_chunk(cancel)``.
- ``RequestChunkSource`` lets handlers pull request chunks via
  ``ChunkSource.next(cancel)`` — same trait, opposite direction.

What this does and does not buy you:

- It bounds the *handler's* working set: a handler that loops
  ``next(cancel)`` never holds more than one chunk of its own,
  and polls cancellation between chunks, so a large upload bails
  immediately on client FIN / drain / deadline.
- It does **not** bound the *reactor's* working set. The body is
  already fully buffered by the time ``serve`` is called.

An earlier version of this note claimed reactor adoption would be
"a pure substitution at the ``Request`` constructor". That is not
true, and the reason is worth stating so nobody re-attempts it:
``Handler.serve(req) -> Response`` is synchronous and one-shot.
Feeding it a body that is still arriving means the handler must
block inside ``serve`` waiting for the socket, which stalls every
other keep-alive connection multiplexed onto that worker. Mojo has
no async to escape with.

Genuinely unbounded inbound therefore lives on the edge-driven
:trait:`dodo.http.streaming_server.StreamHandler` path, where the
front is re-entered per readable edge and pulls with
``StreamConn.read_body()``. That is not a gap to be closed later;
it is the shape the constraint forces. See
``docs/architecture.md`` under "Two handler shapes".

Configuration:

- ``chunk_size`` defaults to 64 KiB — same chunk size the
  ``HttpServer`` uses for outbound writes, picked to fill an
  L1 cache line × 1024 (typical x86-64) without crossing into
  page-fault territory on a 4 KB page system.
- ``cancel_check_chunks`` defaults to 1 (poll cancel after
  every chunk). Power-of-two values let the implementation
  use a bit-mask for the modulo check.
"""

from std.collections import Optional

from dodo.errors import ValidationError

from .body import ChunkSource
from .cancel import Cancel
from .request import Request


comptime _DEFAULT_CHUNK_SIZE: Int = 65536
comptime _DEFAULT_CANCEL_CHECK_INTERVAL: Int = 1


@fieldwise_init
struct RequestChunkSource(ChunkSource, Movable):
    """A ``ChunkSource`` that yields successive slices of a
    request body as bounded-size chunks.

    Owns no state beyond the underlying ``List[UInt8]`` (held by
    the request that constructed this source — *do not outlive
    the source request*) and a few bookkeeping fields:

    - ``buf`` — owned copy of the request body bytes; cheap to
      construct (one ``List[UInt8]`` clone) and lets the source
      outlive the originating ``Request`` if the handler needs
      to.
    - ``cursor`` — byte offset of the next chunk within ``buf``.
    - ``chunk_size`` — max bytes per yielded chunk.
    - ``cancel_check_chunks`` — how often the source should
      poll the ``Cancel`` token; default is every chunk. Bumping
      this can shave the per-chunk cost on tight loops where
      cancellation latency tolerates a few-chunks delay.

    The trait contract says the chunk returned must remain
    valid until the next ``next`` call. This impl returns a
    freshly-allocated ``List[UInt8]`` per chunk (the slice is
    copied out of ``buf``), so callers can stash the chunk
    indefinitely if they want — no aliasing issues.
    """

    var buf: List[UInt8]
    var cursor: Int
    var chunk_size: Int
    var cancel_check_chunks: Int
    var _chunks_emitted: Int

    @staticmethod
    def of(req: Request) -> RequestChunkSource:
        """Build a source pulling from ``req.body`` with default
        chunk size (64 KiB)."""
        return RequestChunkSource(
            req.body.copy(),
            0,
            _DEFAULT_CHUNK_SIZE,
            _DEFAULT_CANCEL_CHECK_INTERVAL,
            0,
        )

    @staticmethod
    def of_with_chunk_size(
        req: Request, chunk_size: Int
    ) raises ValidationError -> RequestChunkSource:
        """Build a source pulling from ``req.body`` with a
        caller-specified chunk size.

        Raises :class:`dodo.errors.ValidationError` (``field=
        "chunk_size"``) on ``chunk_size <= 0`` so the source
        can't enter an infinite loop emitting empty chunks."""
        if chunk_size <= 0:
            raise ValidationError(
                field=String("chunk_size"),
                reason=String("must be > 0, got ") + String(chunk_size),
            )
        return RequestChunkSource(
            req.body.copy(),
            0,
            chunk_size,
            _DEFAULT_CANCEL_CHECK_INTERVAL,
            0,
        )

    def next(mut self, cancel: Cancel) raises -> Optional[List[UInt8]]:
        """Yield the next chunk, or ``None`` at end-of-body.

        Polls ``cancel.cancelled()`` every
        ``cancel_check_chunks`` calls (default: every call). On
        cancel, returns ``None`` so the handler's iteration
        terminates cleanly without raising.
        """
        if self._chunks_emitted % self.cancel_check_chunks == 0:
            if cancel.cancelled():
                return None
        var n = len(self.buf)
        if self.cursor >= n:
            return None
        var end = self.cursor + self.chunk_size
        if end > n:
            end = n
        var chunk = List[UInt8]()
        chunk.reserve(end - self.cursor)
        for i in range(self.cursor, end):
            chunk.append(self.buf[i])
        self.cursor = end
        self._chunks_emitted += 1
        return Optional[List[UInt8]](chunk^)

    def remaining(self) -> Int:
        """Number of bytes that have not yet been emitted as
        chunks. Returns 0 when fully drained."""
        var n = len(self.buf)
        if self.cursor >= n:
            return 0
        return n - self.cursor

    def total(self) -> Int:
        """Total number of bytes in the body (constant once
        constructed)."""
        return len(self.buf)

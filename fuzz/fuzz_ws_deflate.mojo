"""Fuzz harness: ``dodo.ws.permessage_deflate`` codec.

Properties:

1. Crash-only on the decoder: any byte string (sub-cap input
   length) decodes successfully or raises a typed Error. Anything
   else means a bug -- the codec is a thin wrapper around
   ``zlib.inflate`` with raw deflate windows; we want to confirm
   the wrapper never lets a malformed payload escape the FFI
   boundary uncaught.
2. Round-trip parity: ``compress_message(p) -> c``;
   ``decompress_message(c) -> p'`` MUST yield ``p == p'`` for any
   plaintext ``p``.
3. Cap honesty: passing a tiny ``max_decompressed_bytes`` forces
   the decoder to raise rather than allocate beyond the cap. This
   is the zip-bomb / compression-oracle defense the rest of the
   stack relies on.

Run:
    pixi run -e fuzz fuzz ws_deflate
"""

from mozz import fuzz, FuzzConfig

from dodo.ws.permessage_deflate import (
    DEFAULT_DEFLATE_LEVEL,
    DEFAULT_MAX_DECOMPRESSED_BYTES,
    compress_message,
    decompress_message,
)


def target(data: List[UInt8]) raises:
    # 1. Crash-only on the decoder.
    try:
        _ = decompress_message(
            Span[UInt8, _](data), DEFAULT_MAX_DECOMPRESSED_BYTES
        )
    except:
        # Any error is fine; an unhandled crash isn't.
        pass

    # 2. Round-trip parity (only meaningful for non-empty
    # plaintext -- empty input goes through the §7.2.3.6
    # single-byte path which has its own dedicated tests).
    if len(data) == 0:
        return
    var compressed = compress_message(
        Span[UInt8, _](data), DEFAULT_DEFLATE_LEVEL
    )
    var rt = decompress_message(
        Span[UInt8, _](compressed), DEFAULT_MAX_DECOMPRESSED_BYTES
    )
    if len(rt) != len(data):
        raise Error(
            "permessage-deflate: round-trip length drift: src="
            + String(len(data))
            + " rt="
            + String(len(rt))
        )
    for i in range(len(rt)):
        if Int(rt[i]) != Int(data[i]):
            raise Error(
                "permessage-deflate: round-trip byte drift at " + String(i)
            )

    # 3. Cap honesty: re-decompressing the same payload with a
    # cap of 1 byte must raise (or, if the compressed form is
    # already <= 1 byte plaintext, succeed cleanly -- both cases
    # are non-crashing).
    if len(rt) > 1:
        var raised = False
        try:
            _ = decompress_message(Span[UInt8, _](compressed), 1)
        except:
            raised = True
        if not raised:
            raise Error(
                "permessage-deflate: cap=1 failed to raise on a"
                + String(len(rt))
                + "-byte plaintext"
            )


def main() raises:
    print("[mozz] fuzzing permessage-deflate codec...")
    var seeds = List[List[UInt8]]()

    def _bytes(s: StringLiteral) -> List[UInt8]:
        var b = s.as_bytes()
        var out = List[UInt8](capacity=len(b))
        for i in range(len(b)):
            out.append(b[i])
        return out^

    seeds.append(_bytes(""))
    seeds.append(_bytes("hello, world"))
    seeds.append(_bytes("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
    seeds.append(_bytes('{"event":"ping","ts":1234567890}'))
    seeds.append(
        _bytes(
            "the quick brown fox jumps over the lazy dog 0123456789"
            " the quick brown fox jumps over the lazy dog 0123456789"
        )
    )

    fuzz(
        target,
        FuzzConfig(
            max_runs=200_000,
            seed=0,
            verbose=True,
            crash_dir=".mozz_crashes/ws_deflate",
            corpus_dir="fuzz/corpus/ws_deflate",
            max_input_len=4096,
        ),
        seeds,
    )

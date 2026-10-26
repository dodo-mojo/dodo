"""Fuzz harness for dodo.ws.permessage_deflate context-takeover.

Three targets exercise the persistent z_stream lifecycle (context takeover):

1. ``target_decompress_garbage`` -- a fresh
   :class:`PermessageDeflateContext` decompresses arbitrary
   bytes. Structured zlib errors are expected; SIGSEGV / abort
   from a misaligned z_stream is a bug.

2. ``target_roundtrip`` -- compress then decompress through the
   *same* context. The decompressed bytes must equal the input.
   Exercises the LZ77-window invariants between calls.

3. ``target_three_message_chain`` -- compress + decompress three
   sequential inputs through the same context. Catches
   accumulator drift / window-pointer bugs that only surface
   after several messages.

Each target raises and exits cleanly on a logical mismatch
(prints ``[BUG] ...`` and returns); only memory-safety failures
crash. Lifetime of the contexts is bound to the target scope so
the destructor exercises ``deflateEnd`` + ``inflateEnd`` on every
iteration -- 200K runs implies 600K paired allocate/free calls
through ``dodo_pmd_*`` and shakes out double-free / use-after-
free in a way the unit tests cannot.

Run:
    pixi run -e fuzz fuzz pmd_context
"""

from mozz import fuzz, FuzzConfig
from dodo.ws.permessage_deflate import PermessageDeflateContext


def target_decompress_garbage(data: List[UInt8]) raises:
    """Fresh context, arbitrary bytes -> decompress.

    Any zlib error is acceptable; crashes are not.
    """
    try:
        var ctx = PermessageDeflateContext()
        _ = ctx.decompress(Span[UInt8, _](data))
    except:
        pass


def target_roundtrip(data: List[UInt8]) raises:
    """Compress -> decompress through the same context.

    The persistent z_stream is the unit under test: bugs in
    state transitions between calls show up as mismatched bytes
    here. Length-0 input is skipped because the codec emits a
    single-byte sentinel that the decompressor explicitly
    rejects (per RFC 7692 §7.2.3.6).
    """
    if len(data) == 0:
        return
    var ctx = PermessageDeflateContext()
    var compressed = ctx.compress(Span[UInt8, _](data))
    var back = ctx.decompress(Span[UInt8, _](compressed))
    if len(back) != len(data):
        print(
            "[BUG] pmd roundtrip length mismatch: input="
            + String(len(data))
            + " output="
            + String(len(back))
        )
        return
    for i in range(len(data)):
        if back[i] != data[i]:
            print("[BUG] pmd roundtrip byte mismatch at index " + String(i))
            return


def target_three_message_chain(data: List[UInt8]) raises:
    """Three-message chain through one encoder and one decoder.

    Exercises the LZ77 dictionary carry-over: byte 1 of the
    second message should be encoded against the dictionary
    built from the first. Mismatches indicate a window-pointer
    or accumulator bug that would not appear in a single-call
    test.
    """
    if len(data) == 0:
        return
    var enc = PermessageDeflateContext()
    var dec = PermessageDeflateContext()
    for _ in range(3):
        var compressed = enc.compress(Span[UInt8, _](data))
        var back = dec.decompress(Span[UInt8, _](compressed))
        if len(back) != len(data):
            print("[BUG] pmd-chain length mismatch")
            return
        for i in range(len(data)):
            if back[i] != data[i]:
                print("[BUG] pmd-chain byte mismatch at index " + String(i))
                return


def main() raises:
    print("[mozz] fuzzing dodo.ws.permessage_deflate context-takeover...")
    var seeds = List[List[UInt8]]()
    seeds.append(List[UInt8]())
    var s1 = List[UInt8]()
    for b in "hello".as_bytes():
        s1.append(b)
    seeds.append(s1^)
    var s2 = List[UInt8]()
    for b in "the quick brown fox jumps over the lazy dog".as_bytes():
        s2.append(b)
    seeds.append(s2^)
    # Repetitive payload that exercises the LZ77 dictionary.
    var s3 = List[UInt8]()
    for _ in range(64):
        s3.append(UInt8(0x41))
    seeds.append(s3^)

    print(" target: decompress garbage")
    fuzz(
        target_decompress_garbage,
        FuzzConfig(
            max_runs=200_000,
            seed=0,
            verbose=True,
            crash_dir=".mozz_crashes/pmd_context_garbage",
            corpus_dir="fuzz/corpus/pmd_context_garbage",
            max_input_len=4096,
        ),
        seeds,
    )

    print(" target: compress -> decompress round-trip")
    fuzz(
        target_roundtrip,
        FuzzConfig(
            max_runs=100_000,
            seed=42,
            verbose=True,
            crash_dir=".mozz_crashes/pmd_context_roundtrip",
            corpus_dir="fuzz/corpus/pmd_context_roundtrip",
            max_input_len=2048,
        ),
        seeds,
    )

    print(" target: three-message chain")
    fuzz(
        target_three_message_chain,
        FuzzConfig(
            max_runs=50_000,
            seed=7,
            verbose=True,
            crash_dir=".mozz_crashes/pmd_context_chain",
            corpus_dir="fuzz/corpus/pmd_context_chain",
            max_input_len=1024,
        ),
        seeds,
    )

    print("[mozz] done.")

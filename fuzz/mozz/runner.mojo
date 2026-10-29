"""Main fuzzing loop, configuration, and crash handling.

``fuzz()`` is the primary entry point.  It drives the mutation loop,
classifies exceptions as valid rejections or crashes, grows the corpus
when interesting inputs are found, and saves crashes to disk.

Example:
    ```mojo
    from mozz import fuzz, FuzzConfig

    def target(data: List[UInt8]) raises:
        _ = some_parser(data)   # must raise on bad input, not panic

    def main() raises:
        fuzz(target, FuzzConfig(max_runs=100_000, seed=42))
    ```
"""

from .rng import Xoshiro256
from .mutator import MutatorChain, default_mutator
from .corpus import Corpus, _fnv1a64, _mkdir, _write_file, _zero_pad


comptime FuzzTarget = def(List[UInt8]) raises thin -> None


struct FuzzConfig:
    """Configuration for a fuzzing run.

    Fields:
        max_runs:      Total number of mutation iterations (default 100 000).
        max_input_len: Maximum length of a mutated input in bytes
                       (default 65 540, covers a max-sized WS frame).
        seed:          PRNG seed; 0 picks a non-deterministic seed from a
                       stack address.
        corpus_dir:    If non-empty, load seeds from this directory before
                       the run and save new interesting seeds to it.
        crash_dir:     Directory where crashing inputs are saved
                       (default ``".mozz_crashes"``).
        verbose:       Print progress and final summary to stdout
                       (default ``True``).
        report_file:   If non-empty, write the final summary to this file
                       in addition to stdout (default ``""``).  The file is
                       created or overwritten; intermediate directories must
                       already exist.
        timeout_ms:    Per-iteration timeout in milliseconds; 0 = no timeout
                       (timeout enforcement is not implemented; the
                       field is reserved).
    """

    var max_runs: Int
    var max_input_len: Int
    var seed: UInt64
    var corpus_dir: String
    var crash_dir: String
    var verbose: Bool
    var report_file: String
    var timeout_ms: Int

    def __init__(
        out self,
        max_runs: Int = 100_000,
        max_input_len: Int = 65_540,
        seed: UInt64 = 0,
        corpus_dir: String = "",
        crash_dir: String = ".mozz_crashes",
        verbose: Bool = True,
        report_file: String = "",
        timeout_ms: Int = 0,
    ):
        """Create a ``FuzzConfig``.

        Args:
            max_runs:      Number of fuzz iterations.
            max_input_len: Maximum mutated input size (bytes).
            seed:          PRNG seed (0 = non-deterministic).
            corpus_dir:    Directory for persistent corpus (empty = in-memory
                           only).
            crash_dir:     Directory to save crash inputs.
            verbose:       Print progress and final summary to stdout.
            report_file:   Path to write the final report to (empty = no
                           file output).
            timeout_ms:    Per-call timeout (reserved; not enforced).
        """
        self.max_runs = max_runs
        self.max_input_len = max_input_len
        self.seed = seed
        self.corpus_dir = corpus_dir
        self.crash_dir = crash_dir
        self.verbose = verbose
        self.report_file = report_file
        self.timeout_ms = timeout_ms


struct _Stats:
    """Accumulated statistics for a fuzzing run."""

    var runs: Int
    var ok: Int
    var rejections: Int
    var crashes: Int  # total crash hits (including duplicates)
    var unique_crashes: Int  # unique crash inputs saved to disk
    var corpus_grows: Int

    def __init__(out self):
        self.runs = 0
        self.ok = 0
        self.rejections = 0
        self.crashes = 0
        self.unique_crashes = 0
        self.corpus_grows = 0


def fuzz(
    target: FuzzTarget,
    config: FuzzConfig = FuzzConfig(),
    seeds: List[List[UInt8]] = List[List[UInt8]](),
) raises:
    """Run the fuzzing loop against ``target``.

    The loop:
    1. Picks a seed from the corpus.
    2. Applies a random mutator from the default chain.
    3. Truncates the result to ``config.max_input_len``.
    4. Calls ``target(mutated)``.
    5. Classifies the outcome (ok / valid rejection / crash).
    6. Adds inputs that reach new heuristic states to the corpus.
    7. Saves crashes to ``config.crash_dir``.

    Args:
        target: The fuzz target function.
        config: Run configuration (optional; defaults are sensible).
        seeds:  Additional initial seeds merged into the corpus.

    Raises:
        Error: If any crashes are detected (summary included in the message).
    """
    var rng = Xoshiro256(config.seed)
    var stats = _Stats()

    # ── Build corpus ──────────────────────────────────────────────────────────
    var corpus = Corpus.default()
    for i in range(len(seeds)):
        corpus.add(seeds[i].copy())
    if config.corpus_dir.byte_length() > 0:
        try:
            var loaded = Corpus.load(config.corpus_dir)
            # Merge all loaded seeds in order (not random) so every seed is seen.
            for i in range(loaded.size()):
                corpus.add(loaded.get(i))
        except e:
            if config.verbose:
                print("[mozz] warning: could not load corpus dir:", String(e))

    var mutator = default_mutator()

    # Seen error types / length buckets (for corpus heuristic)
    var seen_error_hashes = List[UInt64]()
    var seen_length_buckets = List[Int]()  # bucket = log2(len)

    # Crash deduplication: only save a crash if its content hash is new
    var seen_crash_hashes = List[UInt64]()

    # ── Main loop ─────────────────────────────────────────────────────────────
    var report_interval = max(1, config.max_runs // 20)

    for run in range(config.max_runs):
        # Refresh mutator corpus snapshot every 500 runs
        if run % 500 == 0:
            mutator.update_corpus(corpus._seeds)

        var seed_bytes = corpus.pick(rng)
        var mutated = mutator.mutate(Span[UInt8, _](seed_bytes), rng)

        # Truncate to max_input_len
        if len(mutated) > config.max_input_len:
            var truncated = List[UInt8](capacity=config.max_input_len)
            for i in range(config.max_input_len):
                truncated.append(mutated[i])
            mutated = truncated^

        stats.runs += 1

        try:
            target(mutated)
            stats.ok += 1
            # Input was accepted, note length bucket for heuristic
            _maybe_add_to_corpus(
                corpus,
                mutated,
                "",
                seen_length_buckets,
                seen_error_hashes,
                stats,
            )
        except e:
            var msg = String(e)
            if _is_crash(msg):
                stats.crashes += 1
                # Only save the crash if we haven't seen this exact input before
                var ch = _fnv1a64(Span[UInt8, _](mutated))
                var is_new_crash = True
                for i in range(len(seen_crash_hashes)):
                    if seen_crash_hashes[i] == ch:
                        is_new_crash = False
                        break
                if is_new_crash:
                    seen_crash_hashes.append(ch)
                    stats.unique_crashes += 1
                    _save_crash(
                        mutated,
                        config.crash_dir,
                        stats.unique_crashes,
                        config.verbose,
                    )
            else:
                stats.rejections += 1
                _maybe_add_to_corpus(
                    corpus,
                    mutated,
                    msg,
                    seen_length_buckets,
                    seen_error_hashes,
                    stats,
                )

        if config.verbose and run % report_interval == 0:
            _print_progress(stats, corpus.size(), run, config.max_runs)

    # ── Final report ──────────────────────────────────────────────────────────
    var report = _build_final(
        stats, corpus.size(), config.seed, config.crash_dir
    )
    if config.verbose:
        print(report)
    if config.report_file.byte_length() > 0:
        try:
            with open(config.report_file, "w") as f:
                _ = f.write(report)
        except e:
            if config.verbose:
                print("[mozz] warning: could not write report file:", String(e))

    # Save corpus if persistent
    if config.corpus_dir.byte_length() > 0:
        try:
            corpus.save(config.corpus_dir)
        except e:
            if config.verbose:
                print("[mozz] warning: could not save corpus:", String(e))

    if stats.crashes > 0:
        raise Error(
            "mozz: "
            + String(stats.crashes)
            + " crash(es) found -- inputs saved to "
            + config.crash_dir
        )


# ── Heuristic corpus growth ───────────────────────────────────────────────────


@always_inline
def _length_bucket(n: Int) -> Int:
    """Return the log2 bucket for length ``n`` (0 = empty, 1 = 1, 2 = 2–3, ...).

    Args:
        n: Input length.

    Returns:
        Integer bucket index.
    """
    if n == 0:
        return 0
    var b = 0
    var v = n
    while v > 1:
        v >>= 1
        b += 1
    return b


def _maybe_add_to_corpus(
    mut corpus: Corpus,
    input: List[UInt8],
    error_msg: String,
    mut seen_buckets: List[Int],
    mut seen_error_hashes: List[UInt64],
    mut stats: _Stats,
):
    """Add ``input`` to corpus if it reaches a new heuristic state.

    Heuristics:
    - New length bucket (log2 of input size) not seen before.
    - New error message hash not seen before.

    Args:
        corpus:            Corpus to potentially grow.
        input:             The candidate input.
        error_msg:         Error message (empty if target returned ok).
        seen_buckets:      Accumulator of seen length buckets.
        seen_error_hashes: Accumulator of seen error message hashes.
        stats:             Statistics struct (updated in-place).
    """
    var bucket = _length_bucket(len(input))
    var is_new_bucket = True
    for i in range(len(seen_buckets)):
        if seen_buckets[i] == bucket:
            is_new_bucket = False
            break

    var is_new_error = False
    if error_msg.byte_length() > 0:
        var eh = _fnv1a64(error_msg.as_bytes())
        is_new_error = True
        for i in range(len(seen_error_hashes)):
            if seen_error_hashes[i] == eh:
                is_new_error = False
                break
        if is_new_error:
            seen_error_hashes.append(eh)

    if is_new_bucket:
        seen_buckets.append(bucket)
        corpus.add(input)
        stats.corpus_grows += 1
    elif is_new_error:
        corpus.add(input)
        stats.corpus_grows += 1


# ── Crash detection ───────────────────────────────────────────────────────────


def _is_crash(msg: String) -> Bool:
    """Return ``True`` if ``msg`` looks like a panic/assertion, not a parser
    rejection.

    Args:
        msg: Error message to classify.

    Returns:
        ``True`` if the message contains a crash marker substring.
    """
    var lower = msg.lower()
    if lower.find("assertion failed") >= 0:
        return True
    if lower.find("index out of bounds") >= 0:
        return True
    if lower.find("null pointer") >= 0:
        return True
    if lower.find("use after free") >= 0:
        return True
    if lower.find("stack overflow") >= 0:
        return True
    if lower.find("panic") >= 0:
        return True
    if lower.find("aborted") >= 0:
        return True
    return False


def _save_crash(
    data: List[UInt8],
    crash_dir: String,
    crash_num: Int,
    verbose: Bool,
):
    """Save a crashing input to ``crash_dir``.

    Args:
        data:      Crashing bytes.
        crash_dir: Directory to save into (created if absent).
        crash_num: Crash sequence number (used for filename).
        verbose:   Print a message if ``True``.
    """
    try:
        _mkdir(crash_dir)
        var path = crash_dir + "/crash_" + _zero_pad(crash_num, 4) + ".bin"
        _write_file(path, data)
        if verbose:
            print("[mozz] CRASH saved:", path, "(", len(data), "bytes)")
    except e:
        if verbose:
            print("[mozz] warning: could not save crash:", String(e))


# ── Progress reporting ────────────────────────────────────────────────────────


def _print_progress(stats: _Stats, corpus_size: Int, run: Int, max_runs: Int):
    """Print a one-line progress update.

    Args:
        stats:       Current statistics.
        corpus_size: Current corpus size.
        run:         Current run index.
        max_runs:    Total configured runs.
    """
    var pct = (run * 100) // max_runs if max_runs > 0 else 0
    print(
        "[mozz]"
        + " crashes: "
        + String(stats.crashes)
        + " | runs: "
        + String(stats.runs)
        + " | corpus: "
        + String(corpus_size)
        + " | rejects: "
        + String(stats.rejections)
        + " | "
        + String(pct)
        + "%"
    )


def _build_final(
    stats: _Stats, corpus_size: Int, seed: UInt64, crash_dir: String
) -> String:
    """Build the final run summary as a string.

    Args:
        stats:       Final statistics.
        corpus_size: Final corpus size.
        seed:        PRNG seed used.
        crash_dir:   Directory where crash inputs were saved.

    Returns:
        Multi-line summary string printed to stdout and/or written to
        ``report_file``.
    """
    var crash_note = ""
    if stats.unique_crashes > 0:
        crash_note = (
            "\n[mozz]   crash inputs: "
            + crash_dir
            + "/crash_*.bin"
            + "\n[mozz]   replay:       mojo replay.mojo <crash_file>"
        )
    return (
        "\n[mozz] ── final report ──────────────────────────────\n"
        + "[mozz]   seed:           "
        + String(seed)
        + "\n"
        + "[mozz]   runs:           "
        + String(stats.runs)
        + "\n"
        + "[mozz]   ok:             "
        + String(stats.ok)
        + "\n"
        + "[mozz]   rejections:     "
        + String(stats.rejections)
        + "\n"
        + "[mozz]   corpus:         "
        + String(corpus_size)
        + " seeds\n"
        + "[mozz]   crashes (hits): "
        + String(stats.crashes)
        + "\n"
        + "[mozz]   crashes (uniq): "
        + String(stats.unique_crashes)
        + crash_note
        + "\n"
        + "[mozz] ─────────────────────────────────────────────"
    )

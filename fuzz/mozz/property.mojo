"""Property-based testing frontend.

``forall[T]()`` generates typed values and checks a boolean property over
them.  On failure the run stops and raises an error.

``forall_bytes()`` is a simpler variant for raw-byte properties that works
without the ``Fuzzable`` trait.

Example:
    ```mojo
    from mozz import forall, forall_bytes, FuzzableUInt16

    # Property: addition must not overflow past u16 max
    def no_wrap(v: UInt16) raises -> Bool:
        return Int(v) + Int(v) >= Int(v)

    def gen_u16(mut rng: Xoshiro256) -> UInt16:
        return FuzzableUInt16.generate(rng)

    def minimize_u16(v: UInt16) -> List[UInt16]:
        return FuzzableUInt16.minimize(v)

    forall[UInt16](no_wrap, gen_u16, minimize_u16, trials=2000)

    # Raw bytes: decode_one never over-reads
    def safe_decode(data: List[UInt8]) raises -> Bool:
        try:
            var r = WsFrame.decode_one(Span[UInt8, _](data))
            return r.consumed <= len(data)
        except:
            return True

    forall_bytes(safe_decode, max_len=256, trials=10_000)
    ```
"""

from .rng import Xoshiro256


def forall[
    T: ImplicitlyCopyable & Deinitable
](
    prop: def(T) raises thin -> Bool,
    gen: def(mut Xoshiro256) thin -> T,
    minimize_fn: def(T) thin -> List[T],
    trials: Int = 1_000,
    seed: UInt64 = 0,
) raises:
    """Test a boolean property over ``trials`` random values of type ``T``.

    When a counterexample is found, ``minimize_fn`` is called iteratively to
    minimize it before the error is raised.

    Parameters:
        T: Type of the generated value (must be ``ImplicitlyCopyable``
           and ``Deinitable``; ``ImplicitlyCopyable`` already implies
           ``Movable``).

    Args:
        prop:        The property predicate.  Return ``False`` or raise to
                     signal a counterexample.
        gen:         Generator function -- ``def(mut Xoshiro256) -> T``.
        minimize_fn: Minimizer -- ``def(T) -> List[T]``.  Called to minimize
                     the counterexample before raising.
        trials:      Number of random trials (default 1 000).
        seed:        PRNG seed (0 = derive from stack address).

    Raises:
        Error: If a counterexample is found (after minimization).
    """
    var rng = Xoshiro256(seed)
    for _ in range(trials):
        var value = gen(rng)
        var failed = False
        var fail_msg = String("")
        try:
            if not prop(value):
                failed = True
                fail_msg = "property returned False"
        except e:
            failed = True
            fail_msg = String(e)

        if failed:
            # Minimize the counterexample by iterating minimize_def until no
            # simpler candidate still fails.
            var current = value
            var steps = 0
            var minimize_improved = True
            while minimize_improved:
                minimize_improved = False
                var candidates = minimize_fn(current)
                for i in range(len(candidates)):
                    var candidate = candidates[i]
                    var candidate_fails = False
                    try:
                        if not prop(candidate):
                            candidate_fails = True
                    except:
                        candidate_fails = True
                    if candidate_fails:
                        current = candidate
                        steps += 1
                        minimize_improved = True
                        break
            var minimize_note = ""
            if steps > 0:
                minimize_note = " (minimized " + String(steps) + " step(s))"
            raise Error("mozz: property failed -- " + fail_msg + minimize_note)


def forall_bytes(
    prop: def(List[UInt8]) raises thin -> Bool,
    max_len: Int = 1_024,
    trials: Int = 1_000,
    seed: UInt64 = 0,
) raises:
    """Test a boolean property over ``trials`` random byte sequences.

    Does not require ``Fuzzable``, uses uniform random bytes with length
    in ``[0, max_len]``.  On failure the failing bytes are hex-encoded in
    the error message.

    Args:
        prop:    The property predicate on raw bytes (takes ``List[UInt8]``).
        max_len: Maximum byte sequence length (default 1 024).
        trials:  Number of random trials (default 1 000).
        seed:    PRNG seed (0 = derive from stack address).

    Raises:
        Error: If a counterexample is found, with the failing bytes
               hex-encoded.
    """
    var rng = Xoshiro256(seed)
    for _ in range(trials):
        var length = Int(rng.next_below(UInt64(max_len + 1)))
        var buf = List[UInt8](capacity=length)
        for _ in range(length):
            buf.append(rng.next_byte())

        var failed = False
        var fail_msg = String("")
        try:
            var ok = prop(buf)
            if not ok:
                failed = True
                fail_msg = "property returned False"
        except e:
            failed = True
            fail_msg = String(e)

        if failed:
            var minimal = _ddmin(buf, prop)
            var hex_str = _hex(minimal)
            raise Error(
                "mozz: forall_bytes failed -- "
                + fail_msg
                + "\n  minimal counterexample ("
                + String(len(minimal))
                + " bytes): "
                + hex_str
            )


# ── Internal helpers ──────────────────────────────────────────────────────────


def _ddmin(
    input: List[UInt8],
    prop: def(List[UInt8]) raises thin -> Bool,
) -> List[UInt8]:
    """Minimize a failing byte sequence using delta-debugging (granularity-doubling).

    Uses the same algorithm as ``minimize_bytes``: starts by trying to remove
    half the input, then doubles granularity on failure until no further
    reduction is possible.

    Args:
        input: The failing byte sequence to minimize.
        prop:  Property predicate (True = good, False/raises = failure).

    Returns:
        A byte sequence no larger than ``input`` that still fails the property.
    """
    var current = input.copy()

    var granularity = 2
    while len(current) > 1:
        var n = len(current)
        var chunk_size = max(1, n // granularity)
        var progress = False

        var start = 0
        while start < n:
            var end = min(start + chunk_size, n)
            var candidate = List[UInt8](capacity=n - (end - start))
            for i in range(start):
                candidate.append(current[i])
            for i in range(end, n):
                candidate.append(current[i])
            var fails = False
            if len(candidate) > 0:
                try:
                    fails = not prop(candidate)
                except:
                    fails = True
            if fails:
                current = candidate^
                n = len(current)
                progress = True
                continue
            start = end

        if progress:
            granularity = 2
        else:
            if granularity >= len(current):
                break
            granularity = min(granularity * 2, len(current))

    return current^


def _hex(data: List[UInt8]) -> String:
    """Encode ``data`` as a lowercase hex string.

    Args:
        data: Bytes to encode.

    Returns:
        Hex string, e.g. ``"0a1bff"``.
    """
    comptime HEX = "0123456789abcdef"
    var out = String(capacity_bytes=len(data) * 2)
    for i in range(len(data)):
        out += HEX[byte=Int(data[i] >> 4)]
        out += HEX[byte=Int(data[i] & 0xF)]
    return out^

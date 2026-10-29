"""Delta-debugging input minimizer (Andreas Zeller's ddmin algorithm).

Reduces a crashing input to its minimal reproduction case by binary
partitioning and removing subsets that still trigger the crash.

Example:
    ```mojo
    def is_crash(data: List[UInt8]) raises -> Bool:
        try:
            broken_parser(Span[UInt8, _](data))
            return False
        except e:
            return _is_crash_message(String(e))

    var minimal = minimize_bytes(crashing_input, is_crash)
    print(len(minimal), "bytes (was", len(crashing_input), ")")
    ```
"""


def minimize_bytes(
    input: List[UInt8],
    is_crash: def(List[UInt8]) raises thin -> Bool,
) raises -> List[UInt8]:
    """Minimize ``input`` to the smallest prefix/subset that still crashes.

    Implements ddmin with granularity doubling: starts by trying to remove
    half of the input, recursively narrows until no single-element removal
    preserves the crash.

    Args:
        input:    The crashing input to minimize.
        is_crash: A predicate that returns ``True`` if the given bytes trigger
                  the crash.  May raise; raises from ``is_crash`` itself are
                  treated as ``True`` (crash).

    Returns:
        A minimal ``List[UInt8]`` that still passes ``is_crash``.  May be
        longer than 1 byte if no sub-sequence suffices.

    Raises:
        Error: If the initial input does not pass ``is_crash``.
    """
    if not _check(input, is_crash):
        raise Error(
            "mozz/minimize: initial input does not trigger the crash predicate"
        )

    var current = input.copy()
    var granularity = 2

    while len(current) > 1:
        var n = len(current)
        var chunk_size = max(1, n // granularity)
        var progress = False

        var start = 0
        while start < n:
            var end = min(start + chunk_size, n)

            var candidate = _remove_range(current, start, end)
            if len(candidate) > 0 and _check(candidate, is_crash):
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


def _check(
    data: List[UInt8],
    is_crash: def(List[UInt8]) raises thin -> Bool,
) raises -> Bool:
    """Invoke ``is_crash`` and treat any exception as a crash.

    Args:
        data:     Bytes to test.
        is_crash: Crash predicate.

    Returns:
        ``True`` if ``is_crash`` returned ``True`` or raised an exception.
    """
    try:
        return is_crash(data)
    except:
        return True


def _remove_range(
    data: List[UInt8],
    start: Int,
    end: Int,
) -> List[UInt8]:
    """Return a copy of ``data`` with bytes ``[start, end)`` removed.

    Args:
        data:  Source bytes.
        start: First index to remove (inclusive).
        end:   Last index to remove (exclusive).

    Returns:
        New ``List[UInt8]`` without the specified range.
    """
    var n = len(data)
    var out = List[UInt8](capacity=n - (end - start))
    for i in range(start):
        out.append(data[i])
    for i in range(end, n):
        out.append(data[i])
    return out^

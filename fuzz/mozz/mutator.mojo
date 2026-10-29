"""Byte-level mutation operators for fuzzing.

Seven shipped mutators plus a weighted ``MutatorChain`` that picks one at
random.  All mutators take a ``Span[UInt8, _]`` input and return a new
``List[UInt8]``, they never mutate in place.

Use ``default_mutator()`` to get the standard weighted chain used by
``fuzz()``.

Example:
    ```mojo
    var rng = Xoshiro256(seed=1)
    var chain = default_mutator()
    var input = List[UInt8](0x48, 0x65, 0x6C, 0x6C, 0x6F)  # "Hello"
    var mutated = chain.mutate(Span[UInt8, _](input), rng)
    ```
"""

from .rng import Xoshiro256


def _boundary_bytes() -> List[UInt8]:
    """Return the interesting byte boundary values for substitution."""
    return [0x00, 0x01, 0x7E, 0x7F, 0x80, 0xFE, 0xFF]


def _boundary_u16() -> List[UInt16]:
    """Return the interesting UInt16 boundary values for BoundaryInt."""
    return [
        0x0000,
        0x0001,
        0x007F,
        0x0080,
        0x00FF,
        0x0100,
        0x7FFE,
        0x7FFF,
        0x8000,
        0xFFFE,
        0xFFFF,
    ]


# ── Mutator ID constants ───────────────────────────────────────────────────────


struct MutatorId:
    """Integer IDs for each built-in mutator (used by ``MutatorChain``)."""

    comptime BIT_FLIP: Int = 0
    comptime BYTE_SUBSTITUTION: Int = 1
    comptime BYTE_INSERTION: Int = 2
    comptime BYTE_DELETION: Int = 3
    comptime BLOCK_DUPLICATION: Int = 4
    comptime SPLICE: Int = 5
    comptime BOUNDARY_INT: Int = 6


# ── Concrete mutators ─────────────────────────────────────────────────────────


struct BitFlip:
    """Flip 1–4 random bits at random positions.

    Effective for discovering off-by-one errors and flag-dependent branches.
    """

    def __init__(out self):
        """Create a BitFlip mutator."""
        pass

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Flip 1–4 random bits in a copy of ``input``.

        Args:
            input: The input bytes to mutate.
            rng:   PRNG state (advanced in-place).

        Returns:
            A new ``List[UInt8]`` with bits flipped.
        """
        var out = List[UInt8](Span[UInt8, _](input))
        var n = len(out)
        if n == 0:
            return out^
        var num_flips = Int(rng.next_below(4)) + 1
        for _ in range(num_flips):
            var byte_idx = Int(rng.next_below(UInt64(n)))
            var bit_idx = UInt8(rng.next_below(8))
            out[byte_idx] ^= UInt8(1) << bit_idx
        return out^


struct ByteSubstitution:
    """Replace 1–4 bytes with random or boundary values.

    Boundary values (0x00, 0x7F, 0x80, 0xFF, etc.) are chosen with 30%
    probability to hit common parser edge cases.
    """

    def __init__(out self):
        """Create a ByteSubstitution mutator."""
        pass

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Replace 1–4 bytes with random or boundary values.

        Args:
            input: The input bytes to mutate.
            rng:   PRNG state (advanced in-place).

        Returns:
            A new ``List[UInt8]`` with substituted bytes.
        """
        var out = List[UInt8](Span[UInt8, _](input))
        var n = len(out)
        if n == 0:
            return out^
        var boundaries = _boundary_bytes()
        var count = Int(rng.next_below(4)) + 1
        for _ in range(count):
            var idx = Int(rng.next_below(UInt64(n)))
            if rng.next_below(10) < 3:  # 30% boundary
                var bi = Int(rng.next_below(UInt64(len(boundaries))))
                out[idx] = boundaries[bi]
            else:
                out[idx] = rng.next_byte()
        return out^


struct ByteInsertion:
    """Insert 1–8 random bytes at a random position.

    Exercises length-parsing code paths that may assume fixed-size fields.
    """

    def __init__(out self):
        """Create a ByteInsertion mutator."""
        pass

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Insert 1–8 random bytes at a random position.

        Args:
            input: The input bytes to mutate.
            rng:   PRNG state (advanced in-place).

        Returns:
            A new ``List[UInt8]`` with bytes inserted.
        """
        var n = len(input)
        var count = Int(rng.next_below(8)) + 1
        var pos = Int(rng.next_below(UInt64(n + 1)))
        var out = List[UInt8](capacity=n + count)
        for i in range(pos):
            out.append(input[i])
        for _ in range(count):
            out.append(rng.next_byte())
        for i in range(pos, n):
            out.append(input[i])
        return out^


struct ByteDeletion:
    """Delete 1–8 bytes at a random position.

    Exercises length checks and under-read recovery paths.
    """

    def __init__(out self):
        """Create a ByteDeletion mutator."""
        pass

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Delete 1–8 bytes starting at a random position.

        Args:
            input: The input bytes to mutate.
            rng:   PRNG state (advanced in-place).

        Returns:
            A new ``List[UInt8]`` with bytes removed (may be shorter than
            input, but never empty if input was non-empty).
        """
        var n = len(input)
        if n == 0:
            return List[UInt8](input)
        var count = Int(rng.next_below(UInt64(min(8, n)))) + 1
        var pos = Int(rng.next_below(UInt64(n)))
        var end = min(pos + count, n)
        var out = List[UInt8](capacity=n - (end - pos))
        for i in range(pos):
            out.append(input[i])
        for i in range(end, n):
            out.append(input[i])
        return out^


struct BlockDuplication:
    """Duplicate a random 1–32 byte slice and insert it elsewhere.

    Useful for exercising repeated-field parsers and length-prefix bugs.
    """

    def __init__(out self):
        """Create a BlockDuplication mutator."""
        pass

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Copy a random block and insert it at a random position.

        Args:
            input: The input bytes to mutate.
            rng:   PRNG state (advanced in-place).

        Returns:
            A new ``List[UInt8]`` with a block duplicated.
        """
        var n = len(input)
        if n == 0:
            return List[UInt8](input)
        var block_len = Int(rng.next_below(UInt64(min(32, n)))) + 1
        var src_start = Int(rng.next_below(UInt64(n - block_len + 1)))
        var dst_pos = Int(rng.next_below(UInt64(n + 1)))
        var out = List[UInt8](capacity=n + block_len)
        for i in range(dst_pos):
            out.append(input[i])
        for i in range(block_len):
            out.append(input[src_start + i])
        for i in range(dst_pos, n):
            out.append(input[i])
        return out^


struct Splice:
    """Splice the tail of a second corpus entry onto the current input.

    Cross-pollination across corpus seeds can expose stateful interaction
    bugs that single-input mutation misses.

    When no second seed is available the input is returned unchanged.
    """

    var _corpus_ref: List[List[UInt8]]

    def __init__(out self, corpus: List[List[UInt8]]):
        """Create a Splice mutator with a snapshot of the corpus.

        Args:
            corpus: Current corpus seeds (copied for safety).
        """
        self._corpus_ref = corpus.copy()

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Splice a random corpus entry onto the first half of ``input``.

        Args:
            input: The primary input bytes.
            rng:   PRNG state (advanced in-place).

        Returns:
            A new ``List[UInt8]`` formed by concatenating the first half of
            ``input`` with a random suffix from another corpus entry.
        """
        var n = len(input)
        if len(self._corpus_ref) < 2 or n == 0:
            return List[UInt8](input)
        var other_idx = Int(rng.next_below(UInt64(len(self._corpus_ref))))
        var other = self._corpus_ref[other_idx].copy()
        var m = len(other)
        var split_a = Int(rng.next_below(UInt64(n + 1)))
        var split_b = Int(rng.next_below(UInt64(m + 1)))
        var out = List[UInt8](capacity=split_a + (m - split_b))
        for i in range(split_a):
            out.append(input[i])
        for i in range(split_b, m):
            out.append(other[i])
        return out^


struct BoundaryInt:
    """Replace a 1–2 byte run with an interesting integer boundary value.

    Targets off-by-one errors on integer boundaries commonly exploitable in
    binary protocol parsers (e.g. payload-length fields).
    """

    def __init__(out self):
        """Create a BoundaryInt mutator."""
        pass

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Replace 1 or 2 bytes at a random position with a boundary value.

        Args:
            input: The input bytes to mutate.
            rng:   PRNG state (advanced in-place).

        Returns:
            A new ``List[UInt8]`` with a boundary value substituted.
        """
        var out = List[UInt8](Span[UInt8, _](input))
        var n = len(out)
        if n == 0:
            return out^
        var boundaries = _boundary_bytes()
        var boundaries_u16 = _boundary_u16()
        # 50/50: single byte vs two-byte big-endian uint16
        if rng.next_bool() or n < 2:
            var idx = Int(rng.next_below(UInt64(n)))
            var bi = Int(rng.next_below(UInt64(len(boundaries))))
            out[idx] = boundaries[bi]
        else:
            var idx = Int(rng.next_below(UInt64(n - 1)))
            var vi = Int(rng.next_below(UInt64(len(boundaries_u16))))
            var v = boundaries_u16[vi]
            out[idx] = UInt8(v >> 8)
            out[idx + 1] = UInt8(v & 0xFF)
        return out^


# ── MutatorChain ──────────────────────────────────────────────────────────────


struct MutatorChain:
    """Randomly selects one mutator from a weighted list and applies it.

    Weights are cumulative; selection is O(n) weighted-random using the
    total weight sum.

    Example:
        ```mojo
        var chain = default_mutator()
        var out = chain.mutate(Span[UInt8, _](input), rng)
        ```
    """

    var _ids: List[Int]
    var _weights: List[UInt32]
    var _total: UInt64
    var _corpus_snapshot: List[List[UInt8]]

    def __init__(
        out self,
        ids: List[Int],
        weights: List[UInt32],
        corpus: List[List[UInt8]] = List[List[UInt8]](),
    ):
        """Construct a chain with the given mutator IDs and weights.

        Args:
            ids:     List of ``MutatorId.*`` constants.
            weights: Parallel list of positive integer weights.
            corpus:  Optional corpus snapshot for ``Splice`` (may be empty).
        """
        self._ids = ids.copy()
        self._weights = weights.copy()
        self._corpus_snapshot = corpus.copy()
        var total: UInt64 = 0
        for i in range(len(weights)):
            total += UInt64(weights[i])
        self._total = total

    def update_corpus(mut self, corpus: List[List[UInt8]]):
        """Refresh the corpus snapshot used by the ``Splice`` mutator.

        Args:
            corpus: Updated corpus seeds.
        """
        self._corpus_snapshot = corpus.copy()

    def mutate(self, input: Span[UInt8, _], mut rng: Xoshiro256) -> List[UInt8]:
        """Pick a mutator by weighted random draw and apply it.

        Args:
            input: Input bytes to mutate.
            rng:   PRNG state (advanced in-place).

        Returns:
            Mutated bytes as a new ``List[UInt8]``.
        """
        var pick = rng.next_below(self._total)
        var cumulative: UInt64 = 0
        var chosen_id = self._ids[0]
        for i in range(len(self._ids)):
            cumulative += UInt64(self._weights[i])
            if pick < cumulative:
                chosen_id = self._ids[i]
                break

        if chosen_id == MutatorId.BIT_FLIP:
            return BitFlip().mutate(input, rng)
        elif chosen_id == MutatorId.BYTE_SUBSTITUTION:
            return ByteSubstitution().mutate(input, rng)
        elif chosen_id == MutatorId.BYTE_INSERTION:
            return ByteInsertion().mutate(input, rng)
        elif chosen_id == MutatorId.BYTE_DELETION:
            return ByteDeletion().mutate(input, rng)
        elif chosen_id == MutatorId.BLOCK_DUPLICATION:
            return BlockDuplication().mutate(input, rng)
        elif chosen_id == MutatorId.SPLICE:
            return Splice(self._corpus_snapshot).mutate(input, rng)
        else:  # BOUNDARY_INT
            return BoundaryInt().mutate(input, rng)


def default_mutator() -> MutatorChain:
    """Return the standard weighted mutator chain used by ``fuzz()``.

    Default weights:
    - ``BitFlip``: 30
    - ``ByteSubstitution``: 25
    - ``ByteInsertion``: 15
    - ``ByteDeletion``: 10
    - ``BlockDuplication``: 10
    - ``Splice``: 5
    - ``BoundaryInt``: 5

    Returns:
        A ``MutatorChain`` with the standard weights.
    """
    var ids: List[Int] = [
        MutatorId.BIT_FLIP,
        MutatorId.BYTE_SUBSTITUTION,
        MutatorId.BYTE_INSERTION,
        MutatorId.BYTE_DELETION,
        MutatorId.BLOCK_DUPLICATION,
        MutatorId.SPLICE,
        MutatorId.BOUNDARY_INT,
    ]
    var weights: List[UInt32] = [30, 25, 15, 10, 10, 5, 5]
    return MutatorChain(ids, weights)

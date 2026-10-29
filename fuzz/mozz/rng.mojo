"""Xoshiro256++: fast, seedable, non-cryptographic PRNG.

Implementation of the xoshiro256++ algorithm by Vigna & Blackman (2018).
Period: 2^256 − 1.  Speed: ~1 ns/sample on ARM64.

State is four ``UInt64`` words initialized by running ``splitmix64`` on
the user-supplied seed.  This avoids the degenerate all-zero state.

Example:
    ```mojo
    var rng = Xoshiro256(seed=42)
    var byte = rng.next_byte()          # uniform random UInt8
    var n = rng.next_below(100)         # uniform in [0, 100)
    var buf = List[UInt8](capacity=32)
    for _ in range(32):
        buf.append(0)
    rng.fill(buf)                       # fill with random bytes
    ```
"""

from std.memory import Pointer


@always_inline
def _splitmix64(mut state: UInt64) -> UInt64:
    """Single step of splitmix64, used for seeding.

    Args:
        state: Mutable splitmix64 state; advanced in-place.

    Returns:
        A well-mixed 64-bit value derived from the new state.
    """
    state += 0x9E3779B97F4A7C15
    var z = state
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) * 0x94D049BB133111EB
    return z ^ (z >> 31)


@always_inline
def _rotl64(x: UInt64, k: Int) -> UInt64:
    """Left-rotate ``x`` by ``k`` bits.

    Args:
        x: Value to rotate.
        k: Rotation amount (0–63).

    Returns:
        ``x`` rotated left by ``k`` bits.
    """
    return (x << UInt64(k)) | (x >> UInt64(64 - k))


def _default_seed() -> UInt64:
    """Generate a non-deterministic seed from a stack-variable address.

    Takes the address of a local ``UInt64`` variable; ASLR ensures the
    address differs between processes and (usually) between calls.
    Uses no OS calls or ``time`` module, works on all Mojo targets.

    Returns:
        A ``UInt64`` derived from a stack address XOR'd with a constant.
    """
    var x: UInt64 = 0
    var p = Pointer[UInt64, _](to=x)
    return UInt64(Int(p)) ^ 0xDEADBEEFCAFEBABE


struct Xoshiro256(ImplicitlyCopyable):
    """Xoshiro256++ PRNG.

    Deterministic when constructed with an explicit nonzero ``seed``.
    Passing ``seed=0`` generates entropy from a stack address.

    All internal state is ``UInt64``; no heap allocation.

    Fields:
        s0, s1, s2, s3: The four 64-bit state words.
    """

    var s0: UInt64
    var s1: UInt64
    var s2: UInt64
    var s3: UInt64

    def __init__(out self, seed: UInt64 = 0):
        """Initialize the PRNG from a 64-bit seed.

        If ``seed`` is 0 a non-deterministic seed is derived from a stack
        address (sufficient entropy for fuzzing, not cryptographic).

        Args:
            seed: Seed value.  Pass the same value to replay a run.
        """
        var s = seed if seed != 0 else _default_seed()
        self.s0 = _splitmix64(s)
        self.s1 = _splitmix64(s)
        self.s2 = _splitmix64(s)
        self.s3 = _splitmix64(s)

    @always_inline
    def next_u64(mut self) -> UInt64:
        """Return the next uniformly random ``UInt64``.

        Advances the internal state by one step.

        Returns:
            A pseudo-random ``UInt64`` in ``[0, 2^64)``.
        """
        var result = _rotl64(self.s0 + self.s3, 23) + self.s0
        var t = self.s1 << 17
        self.s2 ^= self.s0
        self.s3 ^= self.s1
        self.s1 ^= self.s2
        self.s0 ^= self.s3
        self.s2 ^= t
        self.s3 = _rotl64(self.s3, 45)
        return result

    @always_inline
    def next_u32(mut self) -> UInt32:
        """Return the next uniformly random ``UInt32``.

        Returns:
            High 32 bits of ``next_u64()``.
        """
        return UInt32(self.next_u64() >> 32)

    @always_inline
    def next_byte(mut self) -> UInt8:
        """Return a uniformly random byte in ``[0, 255]``.

        Returns:
            A pseudo-random ``UInt8``.
        """
        return UInt8(self.next_u64() & 0xFF)

    @always_inline
    def next_below(mut self, n: UInt64) -> UInt64:
        """Return a uniformly random value in ``[0, n)``.

        Uses rejection sampling to avoid modulo bias.

        Args:
            n: Upper bound (exclusive).  Must be > 0.

        Returns:
            A pseudo-random ``UInt64`` in ``[0, n)``.
        """
        if n <= 1:
            return 0
        # Rejection sampling: reject values in the incomplete top bucket
        var threshold = (0 - n) % n  # = (2^64 - n) % n
        while True:
            var r = self.next_u64()
            if r >= threshold:
                return r % n

    @always_inline
    def next_bool(mut self) -> Bool:
        """Return a uniformly random boolean (50 % each side).

        Returns:
            ``True`` or ``False`` with equal probability.
        """
        return (self.next_u64() & 1) == 1

    def fill(mut self, mut buf: List[UInt8]):
        """Fill ``buf`` with uniformly random bytes.

        Uses a single 8-byte store (``bitcast[UInt64]``) per PRNG call instead
        of eight individual byte extractions, avoids 7 shifts, 8 masks, and
        8 casts per 8-byte block.

        Args:
            buf: Destination byte list (modified in-place via unsafe pointer).
        """
        var n = len(buf)
        var ptr = buf.unsafe_ptr()
        var i = 0
        # One u64 store per 8 bytes, no shift/mask overhead
        while i + 8 <= n:
            var v = self.next_u64()
            ptr.unsafe_offset(i).unsafe_bitcast[UInt64]().unsafe_store(v)
            i += 8
        # Scalar tail for remaining < 8 bytes
        while i < n:
            ptr.unsafe_offset(i).unsafe_store(self.next_byte())
            i += 1

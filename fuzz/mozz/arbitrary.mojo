"""Typed random value generation for property-based testing.

The ``Fuzzable`` trait enables ``forall[T: Fuzzable](...)`` to generate
well-typed test cases.  Implementations for all primitive Mojo types ship
with the library.

Example:
    ```mojo
    var rng = Xoshiro256(seed=99)
    var u = FuzzableUInt16.generate(rng)   # random UInt16 (boundary-biased)
    var s = FuzzableString.generate(rng)   # random valid UTF-8 string
    var xs = FuzzableBytes.generate(rng)   # random List[UInt8]
    ```

Custom types:
    ```mojo
    struct Point:
        var x: Int
        var y: Int

        @staticmethod
        def generate(mut rng: Xoshiro256) -> Point:
            return Point(x=FuzzableInt.generate(rng), y=FuzzableInt.generate(rng))

        @staticmethod
        def minimize(value: Point) -> List[Point]:
            var out = List[Point]()
            if value.x != 0:
                out.append(Point(x=0, y=value.y))
            if value.y != 0:
                out.append(Point(x=value.x, y=0))
            return out^
    ```
"""

from std.memory import alloc

from .rng import Xoshiro256


# ── Fuzzable trait ─────────────────────────────────────────────────────────────


trait Fuzzable(Copyable, Movable):
    """Trait for types that can generate random instances of themselves.

    Implement ``generate(rng)`` to produce a random value and optionally
    ``minimize(value)`` to return simpler variants for counterexample
    minimization.

    Types implementing ``Fuzzable`` work automatically with ``forall[T]()``
    and ``forall_bytes()``.

    Note:
        Requires ``Copyable`` and ``Movable`` because ``minimize()`` returns
        ``List[Self]``, which requires ``Self: Copyable``.
    """

    @staticmethod
    def generate(mut rng: Xoshiro256) -> Self:
        """Generate a random instance of ``Self``.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random value of type ``Self``.
        """
        ...

    @staticmethod
    def minimize(value: Self) -> List[Self]:
        """Return simpler variants of ``value`` for counterexample minimization.

        The default implementation returns an empty list (no minimization).
        Override to provide problem-specific simplifications.

        Args:
            value: The counterexample to simplify.

        Returns:
            A list of simpler variants (may be empty).
        """
        return List[Self]()


# ── Primitive implementations ──────────────────────────────────────────────────


struct FuzzableBool:
    """``Fuzzable`` implementation for ``Bool``."""

    @staticmethod
    def generate(mut rng: Xoshiro256) -> Bool:
        """Generate a uniformly random boolean.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            ``True`` or ``False`` with equal probability.
        """
        return rng.next_bool()

    @staticmethod
    def minimize(value: Bool) -> List[Bool]:
        """Minimize: ``True`` → ``[False]``, ``False`` → ``[]``.

        Args:
            value: The value to minimize.

        Returns:
            A simpler variant list.
        """
        var out = List[Bool]()
        if value:
            out.append(False)
        return out^


struct FuzzableUInt8:
    """``Fuzzable`` implementation for ``UInt8``."""

    @staticmethod
    def generate(mut rng: Xoshiro256) -> UInt8:
        """Generate a random ``UInt8`` with 20% boundary bias.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random ``UInt8``.
        """
        if rng.next_below(10) < 2:  # 20% boundary
            var boundaries: Array[UInt8, 6] = [
                0x00,
                0x01,
                0x7F,
                0x80,
                0xFE,
                0xFF,
            ]
            return boundaries[Int(rng.next_below(6))]
        return rng.next_byte()

    @staticmethod
    def minimize(value: UInt8) -> List[UInt8]:
        """Minimize toward 0: ``v`` → ``[0, v/2]`` (if distinct).

        Args:
            value: Value to minimize.

        Returns:
            Simpler variants.
        """
        var out = List[UInt8]()
        if value != 0:
            out.append(0)
        if value // 2 != value and value // 2 != 0:
            out.append(value // 2)
        return out^


struct FuzzableUInt16:
    """``Fuzzable`` implementation for ``UInt16``."""

    @staticmethod
    def generate(mut rng: Xoshiro256) -> UInt16:
        """Generate a random ``UInt16`` with 20% boundary bias.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random ``UInt16``.
        """
        if rng.next_below(10) < 2:
            var boundaries: Array[UInt16, 10] = [
                0,
                1,
                127,
                128,
                255,
                256,
                32767,
                32768,
                65534,
                65535,
            ]
            return boundaries[Int(rng.next_below(10))]
        return UInt16(rng.next_u32() & 0xFFFF)

    @staticmethod
    def minimize(value: UInt16) -> List[UInt16]:
        """Minimize toward 0.

        Args:
            value: Value to minimize.

        Returns:
            Simpler variants.
        """
        var out = List[UInt16]()
        if value != 0:
            out.append(0)
        if value // 2 != value and value // 2 != 0:
            out.append(value // 2)
        return out^


struct FuzzableUInt32:
    """``Fuzzable`` implementation for ``UInt32``."""

    @staticmethod
    def generate(mut rng: Xoshiro256) -> UInt32:
        """Generate a random ``UInt32`` with 20% boundary bias.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random ``UInt32``.
        """
        if rng.next_below(10) < 2:
            var boundaries: Array[UInt32, 14] = [
                0,
                1,
                127,
                128,
                255,
                256,
                32767,
                32768,
                65535,
                65536,
                2147483647,
                2147483648,
                4294967294,
                4294967295,
            ]
            return boundaries[Int(rng.next_below(14))]
        return rng.next_u32()

    @staticmethod
    def minimize(value: UInt32) -> List[UInt32]:
        """Minimize toward 0.

        Args:
            value: Value to minimize.

        Returns:
            Simpler variants.
        """
        var out = List[UInt32]()
        if value != 0:
            out.append(0)
        if value // 2 != value and value // 2 != 0:
            out.append(value // 2)
        return out^


struct FuzzableUInt64:
    """``Fuzzable`` implementation for ``UInt64``."""

    @staticmethod
    def generate(mut rng: Xoshiro256) -> UInt64:
        """Generate a random ``UInt64`` with 20% boundary bias.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random ``UInt64``.
        """
        if rng.next_below(10) < 2:
            var boundaries: Array[UInt64, 18] = [
                0,
                1,
                127,
                128,
                255,
                256,
                32767,
                32768,
                65535,
                65536,
                2147483647,
                2147483648,
                4294967295,
                4294967296,
                9223372036854775807,
                9223372036854775808,
                18446744073709551614,
                18446744073709551615,
            ]
            return boundaries[Int(rng.next_below(18))]
        return rng.next_u64()

    @staticmethod
    def minimize(value: UInt64) -> List[UInt64]:
        """Minimize toward 0.

        Args:
            value: Value to minimize.

        Returns:
            Simpler variants.
        """
        var out = List[UInt64]()
        if value != 0:
            out.append(0)
        if value // 2 != value and value // 2 != 0:
            out.append(value // 2)
        return out^


struct FuzzableInt:
    """``Fuzzable`` implementation for ``Int``."""

    @staticmethod
    def generate(mut rng: Xoshiro256) -> Int:
        """Generate a random ``Int`` with 20% boundary bias.

        Generates values across the full signed range, including negative
        integers.  Boundary values (0, ±1, ±2^7, ±2^31, etc.) are produced
        with 20% probability to increase edge-case coverage.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random ``Int`` covering the full signed 64-bit range.
        """
        if rng.next_below(10) < 2:
            var boundaries: Array[Int, 25] = [
                0,
                1,
                -1,
                127,
                -127,
                128,
                -128,
                255,
                -255,
                256,
                -256,
                32767,
                -32767,
                32768,
                -32768,
                65535,
                -65535,
                65536,
                -65536,
                2147483647,
                -2147483647,
                2147483648,
                -2147483648,
                4294967295,
                -4294967295,
            ]
            return boundaries[Int(rng.next_below(25))]
        # Generate a non-negative magnitude then randomly negate it so that
        # both positive and negative halves of the signed range are covered.
        var magnitude = Int(rng.next_u64() >> 1)
        return -magnitude if rng.next_bool() else magnitude

    @staticmethod
    def minimize(value: Int) -> List[Int]:
        """Minimize toward 0.

        Args:
            value: Value to minimize.

        Returns:
            Simpler variants.
        """
        var out = List[Int]()
        if value != 0:
            out.append(0)
        if value < 0:
            out.append(-value)
        var half = value // 2
        if half != value and half != 0:
            out.append(half)
        return out^


struct FuzzableString:
    """``Fuzzable`` implementation for ``String``.

    Generates valid UTF-8 strings with up to 256 code points.  The character
    set is weighted: 70% ASCII printable, 15% ASCII control, 15% two-byte
    UTF-8.  Because two-byte codepoints occupy 2 bytes each, the maximum byte
    length is 512.
    """

    @staticmethod
    def generate(mut rng: Xoshiro256) -> String:
        """Generate a random valid UTF-8 string.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random ``String`` of up to 256 code points (up to 512
            bytes when two-byte UTF-8 codepoints are selected).
        """
        var length = Int(rng.next_below(257))
        var out = String()
        var i = 0
        while i < length:
            var kind = rng.next_below(20)
            if kind < 14:
                # ASCII printable 0x20–0x7E
                var c = UInt8(0x20 + Int(rng.next_below(0x5F)))
                out += chr(Int(c))
                i += 1
            elif kind < 17:
                # ASCII control (tab, newline, carriage return)
                var ctrl: List[UInt8] = [0x09, 0x0A, 0x0D]
                out += chr(Int(ctrl[Int(rng.next_below(3))]))
                i += 1
            else:
                # 2-byte UTF-8 codepoint (U+0080–U+07FF)
                var cp = UInt32(0x0080) + UInt32(rng.next_below(0x0780))
                out += _encode_utf8_codepoint(cp)
                i += 2
        return out^

    @staticmethod
    def minimize(value: String) -> List[String]:
        """Minimize by dropping the second half or removing a character.

        Args:
            value: String to minimize.

        Returns:
            Simpler string variants.
        """
        var out = List[String]()
        var n = value.byte_length()
        if n == 0:
            return out^
        out.append(String(""))
        if n > 1:
            out.append(String(unsafe_from_utf8=value.as_bytes()[: n // 2]))
        return out^


struct FuzzableBytes:
    """``Fuzzable`` implementation for raw bytes ``List[UInt8]``.

    Generates length 0–256 byte sequences with no UTF-8 constraint.
    Useful for raw byte fuzzing targets.
    """

    @staticmethod
    def generate(mut rng: Xoshiro256) -> List[UInt8]:
        """Generate a random byte sequence of length 0–256.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A ``List[UInt8]`` of pseudo-random bytes.
        """
        var length = Int(rng.next_below(257))
        var out = List[UInt8](length=length, fill=UInt8(0))
        rng.fill(out)
        return out^

    @staticmethod
    def minimize(value: List[UInt8]) -> List[List[UInt8]]:
        """Minimize by halving or truncating.

        Args:
            value: Bytes to minimize.

        Returns:
            Simpler byte sequences.
        """
        var out = List[List[UInt8]]()
        var n = len(value)
        if n == 0:
            return out^
        out.append(List[UInt8]())
        if n > 1:
            out.append(List[UInt8](value[: n // 2]))
        return out^


# ── UTF-8 encoding helper ─────────────────────────────────────────────────────


def _encode_utf8_codepoint(cp: UInt32) -> String:
    """Encode a Unicode codepoint as a UTF-8 ``String``.

    Handles 1–3 byte encodings (covers BMP).  Codepoints above U+FFFF are
    clamped to U+FFFD (replacement character).

    Args:
        cp: Unicode codepoint value.

    Returns:
        UTF-8 encoded string for the codepoint.
    """
    if cp < 0x80:
        return chr(Int(cp))
    elif cp < 0x800:
        var b0 = UInt8(0xC0 | (cp >> 6))
        var b1 = UInt8(0x80 | (cp & 0x3F))
        var s = String()
        s += chr(Int(b0))
        s += chr(Int(b1))
        return s^
    elif cp < 0x10000:
        var b0 = UInt8(0xE0 | (cp >> 12))
        var b1 = UInt8(0x80 | ((cp >> 6) & 0x3F))
        var b2 = UInt8(0x80 | (cp & 0x3F))
        var s = String()
        s += chr(Int(b0))
        s += chr(Int(b1))
        s += chr(Int(b2))
        return s^
    else:
        return chr(0xFFFD)  # replacement character


# ── Parametric generator / minimizer ──────────────────────────────────────────


struct Gen[T: ImplicitlyCopyable]:
    """Compile-time-dispatched generator and minimizer for built-in types.

    Provides a unified parametric API so callers write ``Gen[UInt8].generate(rng)``
    instead of ``FuzzableUInt8.generate(rng)``.  Supported type parameters:
    ``Bool``, ``UInt8``, ``UInt16``, ``UInt32``, ``UInt64``, ``Int``,
    ``String``.  For ``List[UInt8]`` use ``FuzzableBytes`` directly (generic
    list instantiations are not yet dispatchable via ``comptime if``).

    For user-defined types, write a companion ``FuzzableMyType`` struct
    following the same ``generate`` / ``minimize`` static-method pattern and
    pass it explicitly to ``forall()``.

    Example:
        ```mojo
        var rng = Xoshiro256(seed=1)
        var v = Gen[UInt16].generate(rng)      # boundary-biased UInt16
        var smaller = Gen[UInt16].minimize(v)   # simpler candidates
        ```
    """

    @staticmethod
    def generate(mut rng: Xoshiro256) -> Self.T:
        """Generate a random instance of ``T`` using boundary-biased sampling.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A pseudo-random value of type ``T``.
        """
        comptime if Self.T == Bool:
            return rebind[Self.T](FuzzableBool.generate(rng))
        elif Self.T == UInt8:
            return rebind[Self.T](FuzzableUInt8.generate(rng))
        elif Self.T == UInt16:
            return rebind[Self.T](FuzzableUInt16.generate(rng))
        elif Self.T == UInt32:
            return rebind[Self.T](FuzzableUInt32.generate(rng))
        elif Self.T == UInt64:
            return rebind[Self.T](FuzzableUInt64.generate(rng))
        elif Self.T == Int:
            return rebind[Self.T](FuzzableInt.generate(rng))
        elif Self.T == String:
            return rebind[Self.T](FuzzableString.generate(rng))
        else:
            comptime assert (
                False
            ), "Gen[T]: unsupported T; write a FuzzableXXX helper"
        return alloc[Self.T](1)[]

    @staticmethod
    def minimize(value: Self.T) -> List[Self.T]:
        """Return simpler variants of ``value`` for counterexample minimization.

        Args:
            value: The counterexample to simplify.

        Returns:
            A list of simpler variants (may be empty).
        """
        comptime if Self.T == Bool:
            var r = FuzzableBool.minimize(rebind[Bool](value))
            return rebind_var[List[Self.T]](r^)
        elif Self.T == UInt8:
            var r = FuzzableUInt8.minimize(rebind[UInt8](value))
            return rebind_var[List[Self.T]](r^)
        elif Self.T == UInt16:
            var r = FuzzableUInt16.minimize(rebind[UInt16](value))
            return rebind_var[List[Self.T]](r^)
        elif Self.T == UInt32:
            var r = FuzzableUInt32.minimize(rebind[UInt32](value))
            return rebind_var[List[Self.T]](r^)
        elif Self.T == UInt64:
            var r = FuzzableUInt64.minimize(rebind[UInt64](value))
            return rebind_var[List[Self.T]](r^)
        elif Self.T == Int:
            var r = FuzzableInt.minimize(rebind[Int](value))
            return rebind_var[List[Self.T]](r^)
        elif Self.T == String:
            var r = FuzzableString.minimize(rebind[String](value))
            return rebind_var[List[Self.T]](r^)
        else:
            comptime assert (
                False
            ), "Gen[T]: unsupported T; write a FuzzableXXX helper"
            return List[Self.T]()

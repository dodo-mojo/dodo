"""Pure-Mojo fuzzing and property-based testing library.

Zero external dependencies. No libFuzzer, no C ABI, no compiler flags.
Write a harness, call ``fuzz()``.

## What is fuzzing?

Fuzzing automatically generates large numbers of random or semi-random inputs
and feeds them to a function, looking for crashes and assertion failures.
A fuzz target is a function that accepts bytes and exercises the code under
test. If it panics or violates an assertion, the triggering input is saved to
disk and added to the regression suite.

## What is property-based testing?

Property-based testing lets you describe an invariant that must hold across all
inputs (for example, "encoding then decoding any value returns the original")
and the library generates hundreds or thousands of random inputs to falsify
it. When a counterexample is found, the input is automatically minimized to the
simplest case that still triggers the failure.

## Three levels of API

### Level 1: Raw byte fuzzing

```mojo
from mozz import fuzz, FuzzConfig

def target(data: List[UInt8]) raises:
    _ = MyParser.parse(data)  # raises = valid rejection; panic = crash saved to disk

def main() raises:
    fuzz(target, FuzzConfig(max_runs=100_000, seed=42, verbose=True))
```

Output::

    [mozz] crashes: 0 | runs: 100000 | corpus: 14 | rejects: 6183 | 100%

    [mozz] ── final report ──────────────────────────────
    [mozz]   seed:           42
    [mozz]   runs:           100000
    [mozz]   ok:             93817
    [mozz]   rejections:     6183
    [mozz]   corpus:         14 seeds
    [mozz]   crashes (hits): 0
    [mozz]   crashes (uniq): 0
    [mozz] ─────────────────────────────────────────────

### Level 2: Typed property tests

``Gen[T]`` is the parametric generator; use it instead of naming a specific
``FuzzableXXX`` struct.  Compile-time dispatch via ``comptime if``.

```mojo
from mozz import forall, Gen, Xoshiro256

def gen_u16(mut rng: Xoshiro256) -> UInt16:
    return Gen[UInt16].generate(rng)

def minimize_u16(v: UInt16) -> List[UInt16]:
    return Gen[UInt16].minimize(v)

def no_overflow(v: UInt16) raises -> Bool:
    return Int(v) + 1 > Int(v)

def main() raises:
    forall[UInt16](no_overflow, gen_u16, minimize_u16, trials=5_000, seed=42)
```

``Gen[T]`` supports: ``Bool``, ``UInt8``, ``UInt16``, ``UInt32``, ``UInt64``,
``Int``, ``String``.  For ``List[UInt8]`` use ``FuzzableBytes`` directly.
For custom types write a ``FuzzableMyType`` companion struct.

### Level 3: Raw byte property tests

```mojo
from mozz import forall_bytes

def safe_roundtrip(data: List[UInt8]) raises -> Bool:
    try:
        return MyCodec.encode(MyCodec.decode(data)) == data
    except:
        return True  # rejections are fine

def main() raises:
    forall_bytes(safe_roundtrip, max_len=512, trials=50_000, seed=1)
```

## API reference

### ``fuzz()``

```mojo
comptime FuzzTarget = def(List[UInt8]) raises thin -> None

def fuzz(
    target: FuzzTarget,
    config: FuzzConfig = FuzzConfig(),
    seeds:  List[List[UInt8]] = List[List[UInt8]](),
) raises
```

Runs the mutation loop.  Raises if any crashes are detected (summary in the
error message).  Seeds are merged into the in-memory corpus before the run.

### ``FuzzConfig``

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| ``max_runs`` | ``Int`` | ``100_000`` | Number of mutation iterations |
| ``max_input_len`` | ``Int`` | ``65_540`` | Maximum mutated input size (bytes) |
| ``seed`` | ``UInt64`` | ``0`` | PRNG seed (0 = entropy from heap address) |
| ``corpus_dir`` | ``String`` | ``""`` | Load/save persistent corpus; empty = in-memory only |
| ``crash_dir`` | ``String`` | ``".mozz_crashes"`` | Directory for saved crash inputs |
| ``verbose`` | ``Bool`` | ``True`` | Print progress lines and final report to stdout |
| ``report_file`` | ``String`` | ``""`` | Also write the final report to this file |
| ``timeout_ms`` | ``Int`` | ``0`` | Per-iteration timeout (reserved; not enforced) |

### ``forall[T]()``

```mojo
def forall[T: ImplicitlyCopyable & Deinitable](
    prop:        def(T) raises -> Bool,
    gen:         def(mut Xoshiro256) -> T,
    minimize_fn: def(T) thin -> List[T],
    trials:      Int    = 1_000,
    seed:        UInt64 = 0,
) raises
```

Runs ``trials`` property checks.  On failure, calls ``minimize_fn``
iteratively to find the simplest counterexample, then raises with the
minimized value and step count in the error message.

### ``forall_bytes()``

```mojo
def forall_bytes(
    prop:    def(List[UInt8]) raises -> Bool,
    max_len: Int    = 1_024,
    trials:  Int    = 1_000,
    seed:    UInt64 = 0,
) raises
```

Like ``forall[T]`` but generates uniform random byte sequences.  No
``Fuzzable`` implementation required.  Built-in ddmin on failure.

### ``minimize_bytes()``

```mojo
def minimize_bytes(
    input:    List[UInt8],
    is_crash: def(List[UInt8]) raises thin -> Bool,
) -> List[UInt8]
```

Standalone delta-debugger.  Reduces ``input`` to the smallest byte sequence
that still passes ``is_crash``.  ``is_crash`` returning ``True`` or raising
both count as "crash still present".

### ``Fuzzable`` trait

```mojo
trait Fuzzable(Copyable, Movable):
    @staticmethod
    def generate(mut rng: Xoshiro256) -> Self: ...

    @staticmethod
    def minimize(value: Self) -> List[Self]:
        return List[Self]()  # default: no minimization
```

Implement on a companion struct to make a custom type work with ``forall()``.
Built-in structs: ``FuzzableBool``, ``FuzzableUInt8``, ``FuzzableUInt16``,
``FuzzableUInt32``, ``FuzzableUInt64``, ``FuzzableInt``, ``FuzzableString``,
``FuzzableBytes``.

### ``Gen[T]``: parametric dispatch

```mojo
struct Gen[T: ImplicitlyCopyable]:
    @staticmethod def generate(mut rng: Xoshiro256) -> T
    @staticmethod def minimize(value: T)             -> List[T]
```

Uses ``comptime if T == UInt8:`` compile-time dispatch.  Supported: ``Bool``,
``UInt8``, ``UInt16``, ``UInt32``, ``UInt64``, ``Int``, ``String``.
Unsupported types fail at compile time with a ``constrained`` error.

### Custom type example

```mojo
from mozz import forall, Xoshiro256

struct Color(ImplicitlyCopyable):
    var r: UInt8; var g: UInt8; var b: UInt8

struct FuzzableColor:
    @staticmethod
    def generate(mut rng: Xoshiro256) -> Color:
        return Color(rng.next_byte(), rng.next_byte(), rng.next_byte())

    @staticmethod
    def minimize(c: Color) -> List[Color]:
        var out = List[Color]()
        if c.r > 0: out.append(Color(c.r // 2, c.g, c.b))
        if c.g > 0: out.append(Color(c.r, c.g // 2, c.b))
        if c.b > 0: out.append(Color(c.r, c.g, c.b // 2))
        return out^

def gen_color(mut rng: Xoshiro256) -> Color:
    return FuzzableColor.generate(rng)

def minimize_color(c: Color) -> List[Color]:
    return FuzzableColor.minimize(c)

def prop(c: Color) raises -> Bool:
    var inv = Color(255 - c.r, 255 - c.g, 255 - c.b)
    return inv.r != c.r or inv.g != c.g or inv.b != c.b

def main() raises:
    forall[Color](prop, gen_color, minimize_color, trials=5_000)
```

### Crash replay

```mojo
from mozz import Corpus, minimize_bytes

def is_crash(data: List[UInt8]) raises -> Bool:
    try:
        my_target(data)
        return False
    except e:
        return String(e).find("panic") >= 0

def main() raises:
    var paths = Corpus.list_crashes(".mozz_crashes")
    var input = Corpus.load_crash(paths[0])
    var minimal = minimize_bytes(input, is_crash)
    print(len(minimal), "bytes (was", len(input), ")")
```

### Mutators

| Mutator | Weight | Description |
|---------|--------|-------------|
| ``BitFlip`` | 30 | Flip 1–4 random bits |
| ``ByteSubstitution`` | 25 | Replace 1–4 bytes (30% boundary bias) |
| ``ByteInsertion`` | 15 | Insert 1–8 random bytes |
| ``ByteDeletion`` | 10 | Remove 1–8 bytes |
| ``BlockDuplication`` | 10 | Duplicate a 1–32 byte block |
| ``Splice`` | 5 | Splice bytes from another corpus entry |
| ``BoundaryInt`` | 5 | Inject boundary values (0x00, 0x7F, 0x80, 0xFF) |

Use ``default_mutator()`` for the standard weighted ``MutatorChain``.

### ``Xoshiro256`` PRNG

```mojo
var rng = Xoshiro256(seed=42)   # seed=0 → entropy from heap address
rng.next_u64()                  # UInt64
rng.next_u32()                  # UInt32
rng.next_byte()                 # UInt8 in [0, 255]
rng.next_below(n)               # UInt64 in [0, n), rejection-sampled
rng.next_bool()                 # Bool
rng.fill(buf)                   # fill List[UInt8] with random bytes
```
"""

from .rng import Xoshiro256
from .mutator import (
    MutatorChain,
    MutatorId,
    BitFlip,
    ByteSubstitution,
    ByteInsertion,
    ByteDeletion,
    BlockDuplication,
    Splice,
    BoundaryInt,
    default_mutator,
)
from .corpus import Corpus
from .arbitrary import (
    Fuzzable,
    FuzzableBool,
    FuzzableUInt8,
    FuzzableUInt16,
    FuzzableUInt32,
    FuzzableUInt64,
    FuzzableInt,
    FuzzableString,
    FuzzableBytes,
    Gen,
)
from .minimize import minimize_bytes
from .property import forall, forall_bytes
from .runner import FuzzConfig, FuzzTarget, fuzz

"""Corpus management for fuzzing.

Manages the set of seed inputs fed to the mutators.  Deduplication is
performed via FNV-1a 64-bit hashing so duplicate inputs are never stored
twice.  When the corpus exceeds ``MAX_CORPUS_SIZE`` seeds the oldest
entry is evicted (FIFO order).

Example:
    ```mojo
    var corpus = Corpus.default()
    var seed_bytes: List[UInt8] = [0x01, 0x02, 0x03]
    corpus.add(seed_bytes)
    var seed = corpus.pick(rng)   # Span[UInt8, _] borrow
    print(corpus.size())
    ```
"""

from std.os import listdir, makedirs
from std.os.path import isdir

from .rng import Xoshiro256

comptime MAX_CORPUS_SIZE: Int = 10_000


def _fnv1a64(data: Span[UInt8, _]) -> UInt64:
    """FNV-1a 64-bit hash of ``data``.

    Args:
        data: Bytes to hash.

    Returns:
        64-bit FNV-1a hash value.
    """
    var h: UInt64 = 0xCBF29CE484222325
    for b in data:
        h ^= UInt64(b)
        h *= 0x100000001B3
    return h


struct Corpus(Movable):
    """A deduplicated, bounded set of fuzzing seed inputs.

    Seeds are stored as ``List[UInt8]``.  At most ``MAX_CORPUS_SIZE`` seeds
    are kept; inserting beyond the limit evicts the oldest entry (index 0).

    Fields:
        _seeds:  Ordered list of seed byte buffers.
        _hashes: FNV-1a 64-bit hash of each seed for O(n) dedup.
    """

    var _seeds: List[List[UInt8]]
    var _hashes: List[UInt64]

    def __init__(out self, seeds: List[List[UInt8]]):
        """Create a corpus pre-populated with ``seeds``.

        Duplicate seeds (by content hash) are silently dropped.

        Args:
            seeds: Initial seed list.
        """
        self._seeds = List[List[UInt8]]()
        self._hashes = List[UInt64]()
        for i in range(len(seeds)):
            self._insert(seeds[i].copy())

    @staticmethod
    def default() -> Corpus:
        """Return a corpus with the four minimal default seeds.

        Default seeds: ``[]``, ``[0x00]``, ``[0xFF]``, ``[0x00, 0x00]``.

        Returns:
            A ``Corpus`` with four entries.
        """
        var seeds = List[List[UInt8]]()
        seeds.append(List[UInt8]())
        var s1: List[UInt8] = [0x00]
        seeds.append(s1^)
        var s2: List[UInt8] = [0xFF]
        seeds.append(s2^)
        var s3: List[UInt8] = [0x00, 0x00]
        seeds.append(s3^)
        return Corpus(seeds)

    def _insert(mut self, data: List[UInt8]):
        """Insert ``data`` if not already present; evict oldest if at capacity.

        Args:
            data: Seed to insert.
        """
        var h = _fnv1a64(Span[UInt8, _](data))
        # Dedup check
        for i in range(len(self._hashes)):
            if self._hashes[i] == h:
                return
        # Evict oldest if at capacity
        if len(self._seeds) >= MAX_CORPUS_SIZE:
            _ = self._seeds.pop(0)
            _ = self._hashes.pop(0)
        self._seeds.append(data.copy())
        self._hashes.append(h)

    def add(mut self, input: List[UInt8]):
        """Add ``input`` to the corpus (deduplication applied).

        Args:
            input: The bytes to add.
        """
        self._insert(input)

    def pick(self, mut rng: Xoshiro256) -> List[UInt8]:
        """Return a randomly selected seed (uniform over the corpus).

        Biases slightly toward recently added seeds (last 20%) with 40%
        probability when the corpus has more than 10 entries.

        Args:
            rng: PRNG state (advanced in-place).

        Returns:
            A copy of the selected seed bytes.
        """
        var n = len(self._seeds)
        if n == 0:
            return List[UInt8]()
        var idx: Int
        if n > 10 and rng.next_below(10) < 4:
            var recent_start = n - max(1, n // 5)
            idx = recent_start + Int(rng.next_below(UInt64(n - recent_start)))
        else:
            idx = Int(rng.next_below(UInt64(n)))
        return self._seeds[idx].copy()

    def size(self) -> Int:
        """Return the current number of seeds in the corpus.

        Returns:
            Seed count.
        """
        return len(self._seeds)

    def get(self, i: Int) -> List[UInt8]:
        """Return a copy of the seed at index ``i``.

        Args:
            i: Zero-based seed index; must be in ``[0, size())``.

        Returns:
            A copy of the seed bytes at position ``i``.
        """
        return self._seeds[i].copy()

    @staticmethod
    def load(dir: String) raises -> Corpus:
        """Load all ``*.bin`` files from ``dir`` as seeds.

        Files are read in name order.  Invalid or empty files are
        skipped silently.

        Args:
            dir: Path to the directory containing ``.bin`` seed files.

        Returns:
            A new ``Corpus`` populated with the loaded seeds.

        Raises:
            Error: If ``dir`` cannot be opened or listed.
        """
        var seeds = List[List[UInt8]]()
        var listing = _list_bin_files(dir)
        for i in range(len(listing)):
            try:
                var data = _read_file(listing[i])
                if len(data) > 0:
                    seeds.append(data^)
            except:
                pass
        return Corpus(seeds)

    @staticmethod
    def list_crashes(crash_dir: String) raises -> List[String]:
        """Return sorted paths of all crash inputs in ``crash_dir``.

        Args:
            crash_dir: Directory written by ``fuzz()``'s ``crash_dir`` option.

        Returns:
            List of file paths (e.g. ``".mozz_crashes/crash_0001.bin"``),
            sorted lexicographically (which matches numeric order given the
            zero-padded names).

        Raises:
            Error: If the directory cannot be listed.
        """
        return _list_bin_files(crash_dir)

    @staticmethod
    def load_crash(path: String) raises -> List[UInt8]:
        """Read a single crash input from ``path``.

        Convenience wrapper around file I/O for use in replay harnesses.

        Args:
            path: Path to a ``crash_NNNN.bin`` file produced by ``fuzz()``.

        Returns:
            Raw bytes of the crashing input.

        Raises:
            Error: If the file cannot be opened or read.
        """
        return _read_file(path)

    def save(self, dir: String) raises:
        """Save all corpus seeds to ``dir`` as ``seed_NNNN.bin`` files.

        Existing files are not overwritten (new files get the next
        available index).

        Args:
            dir: Destination directory (created if absent).

        Raises:
            Error: If the directory cannot be created or a file cannot be
                   written.
        """
        _mkdir(dir)
        for i in range(len(self._seeds)):
            var path = dir + "/seed_" + _zero_pad(i, 4) + ".bin"
            _write_file(path, self._seeds[i].copy())


# ── File I/O helpers ──────────────────────────────────────────────────────────


def _zero_pad(n: Int, width: Int) -> String:
    """Return ``n`` formatted as a zero-padded decimal string of ``width`` digits.

    Args:
        n:     Non-negative integer.
        width: Minimum digit count.

    Returns:
        Zero-padded string representation.
    """
    var s = String(n)
    while s.byte_length() < width:
        s = "0" + s
    return s


def _mkdir(path: String) raises:
    """Create ``path`` directory (and parents) if it does not exist.

    Args:
        path: Directory path to create.

    Raises:
        Error: If the directory cannot be created.
    """
    makedirs(path, exist_ok=True)


def _read_file(path: String) raises -> List[UInt8]:
    """Read the entire contents of a binary file.

    Args:
        path: File path.

    Returns:
        File contents as ``List[UInt8]``.

    Raises:
        Error: If the file cannot be opened or read.
    """
    with open(path, "r") as f:
        return f.read_bytes()


def _write_file(path: String, data: List[UInt8]) raises:
    """Write ``data`` bytes to a binary file (creates or truncates).

    Args:
        path: Destination file path.
        data: Bytes to write.

    Raises:
        Error: If the file cannot be opened or written.
    """
    with open(path, "w") as f:
        _ = f.write_bytes(data)


def _list_bin_files(dir: String) raises -> List[String]:
    """Return the sorted paths of the ``*.bin`` files in ``dir``.

    Returns an empty list if the directory does not exist.

    Args:
        dir: Directory to search.

    Returns:
        Paths of the form ``dir/name.bin``, sorted by name.

    Raises:
        Error: If the directory exists but cannot be listed.
    """
    var paths = List[String]()
    if not isdir(dir):
        return paths^
    var names = listdir(dir)
    sort(names)
    for name in names:
        if name.endswith(".bin"):
            paths.append(dir + "/" + name)
    return paths^

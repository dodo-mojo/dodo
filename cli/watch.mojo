"""Notice when a project's `.mojo` files change, cheaply enough to ask
every 200 ms.

A `Watcher` remembers every `.mojo` file under the root with its change
time and size, and every folder with its listing. `changed` lists the
folders first: a file added, removed or renamed (editors often save by
renaming a new file over the old one) changes a listing, and only then
is the tree walked again. Otherwise it reads the time and size of each
file it knows.

Listings, not folder change times, because a change in the same tick of
the file system's clock as the last look leaves the time as it was. The
size is read for the same reason: an edit in that tick that changes the
size is still seen.
"""

from std.os import listdir, stat

from .files import ProjectTree, listing_of


struct Watcher(Movable):
    var root: String
    var files: List[String]
    var file_times: List[Int]
    var file_sizes: List[Int]
    var dirs: List[String]
    var dir_listings: List[String]

    def __init__(out self, root: String) raises:
        """Raises: Error: If `root` cannot be listed."""
        self.root = root
        self.files = List[String]()
        self.file_times = List[Int]()
        self.file_sizes = List[Int]()
        self.dirs = List[String]()
        self.dir_listings = List[String]()
        self._walk()

    def changed(mut self) raises -> Bool:
        """Whether a `.mojo` file was added, removed or changed since the
        watcher was made or last asked.

        Raises:
            Error: If the root folder can no longer be listed.
        """
        if self._a_folder_changed():
            var old_files = self.files.copy()
            var old_times = self.file_times.copy()
            var old_sizes = self.file_sizes.copy()
            self._walk()
            if old_files != self.files:
                return True
            return old_times != self.file_times or old_sizes != self.file_sizes

        var any_changed = False
        for i in range(len(self.files)):
            var now = _stamp(self.files[i])
            if now[0] != self.file_times[i] or now[1] != self.file_sizes[i]:
                self.file_times[i] = now[0]
                self.file_sizes[i] = now[1]
                any_changed = True
        return any_changed

    def _a_folder_changed(self) -> Bool:
        for i in range(len(self.dirs)):
            var names: List[String]
            try:
                names = listdir(self.dirs[i])
            except:
                return True
            if listing_of(names) != self.dir_listings[i]:
                return True
        return False

    def _walk(mut self) raises:
        var tree = ProjectTree(self.root)
        self.dirs = tree.dirs.copy()
        self.dir_listings = tree.dir_listings.copy()
        self.files = tree.files.copy()
        self.file_times = List[Int]()
        self.file_sizes = List[Int]()
        for path in self.files:
            var now = _stamp(path)
            self.file_times.append(now[0])
            self.file_sizes.append(now[1])


def _stamp(path: String) -> Tuple[Int, Int]:
    """`path`'s change time in ns and size in bytes, or (0, -1) when it is
    gone."""
    try:
        var info = stat(path)
        return (info.st_mtimespec.as_nanoseconds(), info.st_size)
    except:
        return (0, -1)

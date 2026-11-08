"""Notice when a project's `.mojo` files change, cheaply enough to ask
every 200 ms.

A `Watcher` remembers every `.mojo` file and folder under the root, each
with its change time. `changed` looks at the folders first: adding,
removing or renaming a file (editors often save by renaming a new file
over the old one) changes its folder's time, and only then is the tree
walked again. Otherwise it reads the time of each file it knows.
"""

from .files import ProjectTree, time_or_zero


struct Watcher(Movable):
    var root: String
    var files: List[String]
    var file_times: List[Int]
    var dirs: List[String]
    var dir_times: List[Int]

    def __init__(out self, root: String) raises:
        """Raises: Error: If `root` cannot be listed."""
        self.root = root
        self.files = List[String]()
        self.file_times = List[Int]()
        self.dirs = List[String]()
        self.dir_times = List[Int]()
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
            self._walk()
            if old_files != self.files:
                return True
            return old_times != self.file_times

        var any_changed = False
        for i in range(len(self.files)):
            var now = time_or_zero(self.files[i])
            if now != self.file_times[i]:
                self.file_times[i] = now
                any_changed = True
        return any_changed

    def _a_folder_changed(self) -> Bool:
        for i in range(len(self.dirs)):
            if time_or_zero(self.dirs[i]) != self.dir_times[i]:
                return True
        return False

    def _walk(mut self) raises:
        var tree = ProjectTree(self.root)
        self.dirs = tree.dirs.copy()
        self.dir_times = tree.dir_times.copy()
        self.files = tree.files.copy()
        self.file_times = List[Int]()
        for path in self.files:
            self.file_times.append(time_or_zero(path))

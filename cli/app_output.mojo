"""Copying what the app writes to its files onto dodo's own output.

`dodo dev` gives the app files for stdout and stderr (so `dodo logs` can
read them) and copies each file's new bytes to dodo's stdout or stderr as
they arrive.
"""

from std.ffi import c_int, c_size_t, external_call

comptime _MAX_WAITING_BYTES = 65536
"""A line longer than this is copied without waiting for its end."""


def write_fd(fd: Int, data: Span[UInt8, _]):
    """Write all of `data` to file descriptor `fd`. Gives up quietly when
    the descriptor is closed, as `print` does."""
    var done = 0
    while done < len(data):
        var wrote = external_call["write", Int](
            c_int(fd),
            data.unsafe_ptr().unsafe_offset(done),
            c_size_t(len(data) - done),
        )
        if wrote <= 0:
            return
        done += wrote


struct OutputCopy(Movable):
    """Follows one file and copies what is added to it to `fd`."""

    var path: String
    var fd: Int
    var offset: Int
    """How much of the file is copied already."""

    def __init__(out self, path: String, fd: Int):
        self.path = path
        self.fd = fd
        self.offset = 0

    def restart(mut self):
        """The file was started again (the app restarted)."""
        self.offset = 0

    def copy_new(mut self, whole: Bool = False):
        """Copy the lines added since the last call. A last line that has
        no newline yet waits for one, so it never reaches the terminal cut
        in two, unless `whole` (the app has stopped)."""
        var added: List[UInt8]
        try:
            with open(self.path, "r") as file:
                _ = file.seek(self.offset)
                added = file.read_bytes()
        except:
            return
        var end = len(added)
        if not whole and len(added) <= _MAX_WAITING_BYTES:
            end = _after_last_newline(added)
        if end == 0:
            return
        write_fd(self.fd, Span(added)[:end])
        self.offset += end


def _after_last_newline(data: List[UInt8]) -> Int:
    """The length of `data` up to and including its last newline, or 0."""
    var i = len(data)
    while i > 0:
        if data[i - 1] == UInt8(ord("\n")):
            return i
        i -= 1
    return 0

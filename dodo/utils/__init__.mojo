"""Cross-cutting utility helpers that don't fit any other layer.

- :mod:`dodo.utils.posix_proc`: thin wrappers over POSIX ``fork`` /
  ``waitpid`` / ``kill`` / ``usleep`` / ``_exit`` / ``getpid``, for
  tests and fork servers.
- :mod:`dodo.utils.process`: start programs and get their exit status
  (``spawn``, ``run``, ``exec_replace``), through ``libdodo_proc.so``.
- :mod:`dodo.utils.signals`: record Ctrl-C, SIGTERM and SIGHUP instead
  of dying, for loops that shut down cleanly.
- :mod:`dodo.utils.dylib`: finds and loads dodo's wrapper libraries.

Future inhabitants belong here when they're (a) low-level enough
that they don't fit a protocol-shaped subpackage like
``dodo.http`` / ``dodo.tls`` and (b) cross-cutting enough that
they're consumed by more than one such subpackage. Anything more
specific should land in the most-specific subpackage that uses it.
"""

from .posix_proc import (
    SIGINT,
    SIGKILL,
    SIGTERM,
    exit,
    fork,
    getpid,
    kill,
    usleep,
    waitpid,
)
from .dylib import find_dodo_lib

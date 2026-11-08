# `dodo.utils`

Cross-cutting utility helpers that don't fit any other layer.

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

## Packages

- [`dodo.utils.ffi`](ffi/index.md)

## Modules

- [`dodo.utils.dylib`](dylib.md): Canonical FFI dylib path resolver shared across :mod:`dodo`.
- [`dodo.utils.posix_proc`](posix_proc.md): POSIX process-control helpers thin-wrapped over ``external_call``.
- [`dodo.utils.process`](process.md): Start programs, wait for them to end, and stop them.
- [`dodo.utils.signals`](signals.md): Notice Ctrl-C, SIGTERM and SIGHUP without being killed by them.

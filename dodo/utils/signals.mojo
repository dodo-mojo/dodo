"""Notice Ctrl-C, SIGTERM and SIGHUP without being killed by them.

After `watch_signals`, those signals no longer end the process. Each one
is recorded, and `take_signal` returns it once. Loops that run anyway (a
server's supervisor, the `dodo dev` watcher) check it on every pass.
Programs this process starts get the default handling back.

```mojo
from dodo.utils.signals import take_signal, watch_signals


def main() raises:
    watch_signals()
    while take_signal() == 0:
        pass  # do one step of work
```
"""

from std.ffi import c_int

from .dylib import dl_sym, pinned_dodo_lib
from .process import error_text


def watch_signals() raises:
    """Record SIGINT, SIGTERM and SIGHUP from now on, instead of dying.

    Raises:
        Error: If the handlers cannot be installed.
    """
    _call("dodo_signals_watch")


def stop_watching_signals() raises:
    """Give SIGINT, SIGTERM and SIGHUP their default handling back.

    Raises:
        Error: If the handlers cannot be reset.
    """
    _call("dodo_signals_stop")


def take_signal() raises -> Int:
    """The last signal recorded since the previous call, or 0 for none."""
    var take = dl_sym[def() thin abi("C") -> c_int](
        pinned_dodo_lib["proc"]()[], "dodo_signals_take"
    )
    return Int(take())


def _call(symbol: StaticString) raises:
    var install = dl_sym[def() thin abi("C") -> c_int](
        pinned_dodo_lib["proc"]()[], symbol
    )
    var failure = Int(install())
    if failure != 0:
        raise Error(symbol, " failed: ", error_text(failure))

# `dodo.utils.signals`

Notice Ctrl-C, SIGTERM and SIGHUP without being killed by them.

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

## Functions

### `watch_signals`

```mojo
def watch_signals() raises
```

Record SIGINT, SIGTERM and SIGHUP from now on, instead of dying.

Raises: Error: If the handlers cannot be installed.

### `stop_watching_signals`

```mojo
def stop_watching_signals() raises
```

Give SIGINT, SIGTERM and SIGHUP their default handling back.

Raises: Error: If the handlers cannot be reset.

### `take_signal`

```mojo
def take_signal() raises -> Int
```

The last signal recorded since the previous call, or 0 for none.

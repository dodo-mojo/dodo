# `std.sys.arg`

Implements functions and variables for interacting with execution and system environment.

## Functions

### `argv`

```mojo
def argv() -> Span[StringSpan[ImmStaticOrigin], ImmStaticOrigin]
```

Gets the list of command line arguments given to the `mojo` CLI.

For example:

```mojo title="app.mojo"
from std.sys import argv

def main() raises:
    args = argv()
    for arg in args:
        print(arg)
```

```sh
mojo app.mojo "Hello world"
```

```output
app.mojo
Hello world
```

Returns: The list of command line arguments provided when mojo was invoked.

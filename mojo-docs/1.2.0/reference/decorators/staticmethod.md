# @staticmethod

*From Modular's Mojo docs (`Mojo/docs/site/reference/decorators/staticmethod.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

You can add the `@staticmethod` decorator on a struct method to declare a static
method.

For example:

```mojo
from std.pathlib import Path

struct MyStruct(Movable):
    var data: List[UInt8]

    def __init__(out self):
        self.data = List[UInt8]()

    @staticmethod
    def load_from_file(file_path: Path) raises -> Self:
        var new_struct = MyStruct()
        new_struct.data = file_path.read_bytes()
        return new_struct ^
```

Unlike an instance method, a static method doesn't take an implicit `self`
argument. It's not attached to a specific instance of a struct, so it can't
access instance data.

For more information see the documentation on
[static methods](../../manual/structs/index.md#static-methods).

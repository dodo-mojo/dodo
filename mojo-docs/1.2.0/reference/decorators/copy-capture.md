# @__copy_capture

*From Modular's Mojo docs (`Mojo/docs/site/reference/decorators/copy-capture.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

**Caution: Deprecated**
The `@__copy_capture` decorator is deprecated and will be removed in a future
release. Use the current [closure](../../manual/functions/closures.md) syntax
with capture lists.

You can add the `@__copy_capture` decorator on a legacy closure to capture
register-passable values by copy. This decorator causes a nested function to
copy the value of the indicated variable into the closure object at the point of
formation instead of capturing that variable by reference. This allows you to
pass the closure as a parameter, but lifetimes aren't guaranteed to be
respected.

```mojo
  def foo(x: Int):
      var z = x

      @__copy_capture(z)
      @__parameter
      def formatter() -> Int:
          return z
      z = 2
      print(formatter())

  def main():
      foo(5)
```

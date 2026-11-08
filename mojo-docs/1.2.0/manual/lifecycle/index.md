# Value lifecycles

*From Modular's Mojo docs (`Mojo/docs/site/manual/lifecycle/index.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

A Mojo value has a beginning and an end. Mojo creates and initializes the
value before you use it, then destroys it when it's no longer needed.

Lifecycle methods define what happens at each stage. Use them to control how
your types initialize their state, transfer values, and release resources.

  - [Creating values](../../manual/lifecycle/life.md): Construct values with generated and custom initializers.
  - [Initialization state](https://mojolang.org/docs/manual/lifecycle/init/): Understand when a value is initialized and ready to use.
  - [Automatic destruction](../../manual/lifecycle/death.md): Let Mojo destroy values automatically after their last use.
  - [Explicit destruction](../../manual/lifecycle/explicit-destroy.md): Require values to be deliberately destroyed in code.

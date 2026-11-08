# Install Mojo

*From Modular's Mojo docs (`Mojo/docs/site/docs_root/install.mdx` at tag `mojo/v1.2.0`, Apache-2.0 with LLVM Exceptions, see `LICENSE.txt`), turned into plain Markdown by dodo.*

Mojo installs exactly like a Python or Conda package on
macOS and Linux (see the [system requirements](requirements.md)).

**uv:**

1. If needed, install `uv`:

   ```sh
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. Install Mojo:

   ```sh
   uv pip install mojo
   ```

   Or create a project and install Mojo:

   ```sh
   uv init hello-world
   cd hello-world
   uv add mojo
   ```

**pixi:**

1. If needed, install `pixi`:

   ```sh
   curl -fsSL https://pixi.sh/install.sh | sh
   ```

2. Create a project and install Mojo:

   ```sh
   pixi init hello-world \
     -c https://conda.modular.com/max/ -c conda-forge
   cd hello-world
   pixi add mojo
   ```

If you instead want the latest nightly build, [switch to the nightly docs](https://mojolang.org/nightly/install/).

## Get the VS Code extension

For syntax highlighting, code completion, and debugging support, install the
Mojo extension from:

- [VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=modular-mojotools.vscode-mojo)
- [Open VSX Registry](https://open-vsx.org/extension/modular-mojotools/vscode-mojo)

## Get Mojo skills

Mojo agent skills keep your AI coding assistants aligned with the latest
language updates and best practices.

Install with:

```sh
npx skills add modular/skills
```

## Get started

  - [Quickstart](https://mojolang.org/manual/quickstart/): Quickly learn the Mojo programming basics with simple code examples
  - [Beginner tutorial](https://mojolang.org/manual/get-started/): Build a deeper understanding of Mojo in this tutorial to build the Game of Life

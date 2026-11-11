"""The files `dodo new` writes. Each template is plain text; `fill` puts
the project's name, dodo's version and the package channel in place of
`__NAME__`, `__DODO_VERSION__` and `__CHANNEL__`."""

from std.os import getenv

from .version import DODO_VERSION

comptime COMMUNITY_CHANNEL = "https://repo.prefix.dev/modular-community"
"""Where the `dodo` package is published."""


@fieldwise_init
struct NewFile(Copyable, Movable):
    var path: String
    """Relative to the project folder."""
    var text: String


def package_channel() -> String:
    """The channel the project gets `dodo` from. `DODO_PACKAGE_CHANNEL`
    swaps it, for a dodo package built locally (`packaging/build_local.sh`).
    """
    var channel = getenv("DODO_PACKAGE_CHANNEL")
    if channel != "":
        return channel
    return COMMUNITY_CHANNEL


def fill(template: String, name: String, channel: String) -> String:
    var text = template.replace("__NAME__", name)
    text = text.replace("__DODO_VERSION__", DODO_VERSION)
    text = text.replace("__CHANNEL__", channel)
    return text^


def project_files(name: String, channel: String) -> List[NewFile]:
    """Every file of a new project, in the order they are written."""
    var files = List[NewFile]()
    files.append(NewFile("pixi.toml", fill(_PIXI_TOML, name, channel)))
    files.append(NewFile("main.mojo", _MAIN_MOJO))
    files.append(NewFile("app.mojo", _APP_MOJO))
    files.append(NewFile("tests/test_app.mojo", _TEST_APP_MOJO))
    files.append(NewFile("AGENTS.md", fill(_AGENTS_MD, name, channel)))
    files.append(NewFile("CLAUDE.md", "@AGENTS.md\n"))
    files.append(NewFile(".mcp.json", _MCP_JSON))
    files.append(NewFile(".gitignore", _GITIGNORE))
    files.append(NewFile(".gitattributes", _GITATTRIBUTES))
    return files^


comptime _PIXI_TOML = """[workspace]
name = "__NAME__"
version = "0.1.0"
channels = [
    "https://conda.modular.com/max",
    "__CHANNEL__",
    "conda-forge",
]
platforms = ["linux-64", "linux-aarch64", "osx-arm64"]

[dependencies]
mojo = ">=1.2.0,<2.0.0"
dodo = "==__DODO_VERSION__"
"""

comptime _MAIN_MOJO = '''"""Start the server: `pixi run dodo dev` (restarts on save) or
`pixi run dodo run`."""

from app import make_app


def main() raises:
    var app = make_app()
    app.serve(port=8000)
'''

comptime _APP_MOJO = '''"""The app's routes and handlers. `main.mojo` serves it; the tests call
it directly."""

from dodo import App, PathParams, Request, Response, ok


@fieldwise_init
struct NamePath(PathParams):
    var name: String


@fieldwise_init
struct Greeting(Movable):
    var message: String


def home(req: Request) raises -> Response:
    return ok("hello from dodo")


def greet(req: Request, path: NamePath) raises -> Greeting:
    return Greeting(String("hello, ", path.name))


def make_app() raises -> App[]:
    var app = App()
    app.get["/"](home)
    app.get["/hello/{name}"](greet)
    return app^
'''

comptime _TEST_APP_MOJO = """from std.testing import TestSuite, assert_equal

from dodo.http import Method, Request

from app import make_app


def get(url: String) -> Request:
    return Request(method=Method.GET, url=url)


def test_home_says_hello() raises:
    var app = make_app()
    var reply = app.serve(get("/"))
    assert_equal(reply.status, 200)
    assert_equal(reply.text(), "hello from dodo")


def test_greet_returns_json() raises:
    var app = make_app()
    var reply = app.serve(get("/hello/ada"))
    assert_equal(reply.status, 200)
    assert_equal(reply.headers.get("Content-Type"), "application/json")
    assert_equal(reply.text(), '{"message":"hello, ada"}')


def test_unknown_path_is_404() raises:
    var app = make_app()
    var reply = app.serve(get("/nope"))
    assert_equal(reply.status, 404)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
"""

comptime _AGENTS_MD = """# __NAME__

A web app on [dodo](https://github.com/dodo-mojo/dodo) __DODO_VERSION__, a web framework for Mojo.

## Read the docs first

Mojo changes fast, and most of what you remember about it is out of date. Check syntax and APIs in the docs for this project's versions, not from memory.

- When `.dodo/docs/` is missing, run `pixi run dodo docs pull`.
- Mojo: `.dodo/docs/mojo-<version>/index.md`. What Mojo 1.x changed: `changes-in-1x.md` in the same folder.
- dodo: `.dodo/docs/dodo-<version>/index.md`.

## Layout

| Path | What |
|---|---|
| `app.mojo` | Routes and handlers. `make_app()` builds the app. |
| `main.mojo` | Serves `make_app()` on port 8000. |
| `tests/` | `test_*.mojo` files. Each is a `TestSuite` program that calls the app directly. |
| `pixi.toml` | Mojo and dodo versions. |

## Commands

| Command | What |
|---|---|
| `pixi run dodo dev` | Run the app and restart it on every save. |
| `pixi run dodo test` | Build and run every test file. |
| `pixi run dodo run` | Build and run the app once. |
| `pixi run dodo routes` | List the routes. |
| `pixi run dodo request GET /path` | Send one request to the app `dodo dev` runs. |
| `pixi run dodo logs` | What `dodo dev` and the app printed, failed builds included. |
| `pixi run dodo docs search "words"` | Search the pulled docs. |
| `pixi run dodo doctor` | Check the toolchain and the project. |

Every command takes `--json` and `--help`.

## MCP

`pixi run dodo mcp` serves the same powers as MCP tools over stdio: `routes_list`, `request_send`, `test_run`, `logs_tail`, `docs_search`, `doctor`. `.mcp.json` sets it up for Claude Code; give other agents the same command.

## Mojo 1.x

- `def` only. `fn` is gone.
- A function that can fail says `raises`.
- `App` as a return type is written `App[]`.
"""

comptime _MCP_JSON = """{
  "mcpServers": {
    "dodo": {
      "command": "pixi",
      "args": ["run", "dodo", "mcp"]
    }
  }
}
"""

comptime _GITIGNORE = """.pixi/
.dodo/
"""

comptime _GITATTRIBUTES = """pixi.lock merge=binary linguist-language=YAML linguist-generated=true
"""

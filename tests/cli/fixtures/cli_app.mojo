"""The app the CLI tests build. `CLI_APP_MODE` picks what it does, so one
build covers every case:

- unset: serve `/` and a blocking `/slow` on `CLI_APP_PORT` (default 18731)
- `hang`: never reach serve()
- `crash`: raise before serve()
- `no_serve`: exit without serving
- `args`: print each argument on its own line, exit with the first one
"""

from std.os import getenv
from std.sys import argv, exit
from std.time import sleep

from dodo import App, Request


def home(req: Request) raises -> String:
    return "hello"


def slow(req: Request) raises -> String:
    sleep(1.0)
    return "slow done"


def main() raises:
    print("cli_app starting")
    var mode = getenv("CLI_APP_MODE")
    if mode == "hang":
        sleep(600.0)
    if mode == "crash":
        raise Error("database is down")
    if mode == "no_serve":
        return
    if mode == "args":
        var words = argv()
        for i in range(1, len(words)):
            print(words[i])
        var code = 0
        if len(words) > 1:
            code = Int(String(words[1]))
        exit(code)
    var app = App()
    app.get["/"](home)
    app.get["/slow"](slow, blocking=True)
    var port = Int(getenv("CLI_APP_PORT", "18731"))
    app.serve(port=UInt16(port), num_workers=2)
    print("cli_app stopped")

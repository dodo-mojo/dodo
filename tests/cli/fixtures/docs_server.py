"""A stand-in for GitHub's raw file server, for the `dodo docs pull` tests.

    python3 docs_server.py FOLDER

Serves FOLDER on a free port of 127.0.0.1 with keep-alive, and prints
`port N` once it listens. Every request is logged to stdout as
`GET /path`. Two file names misbehave on purpose:

- `hang.md` is never answered;
- `broken.md` gets a 500.
"""

import http.server
import posixpath
import sys
import time


class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        print(f"GET {self.path}", flush=True)
        name = posixpath.basename(self.path)
        if name == "hang.md":
            time.sleep(3600)
            return
        if name == "broken.md":
            self.send_error(500, "broken on purpose")
            return
        super().do_GET()

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    folder = sys.argv[1]

    def handler(*args: object, **kwargs: object) -> Handler:
        return Handler(*args, directory=folder, **kwargs)

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    server.daemon_threads = True
    print(f"port {server.server_address[1]}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

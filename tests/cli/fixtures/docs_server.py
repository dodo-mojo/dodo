"""A stand-in for GitHub's raw file server, for the `dodo docs pull` tests.

    python3 docs_server.py FOLDER

Serves FOLDER on a free port of 127.0.0.1 with keep-alive, and prints
`port N` once it listens. Every request is logged to stdout as
`GET /path`. Some file names misbehave on purpose:

- `hang.md` is never answered;
- `broken.md` gets a 500;
- a name starting with `slow_` is answered after a second (a 404 if
  there is no such file).
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
        if name.startswith("slow_"):
            time.sleep(1)
        super().do_GET()

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    folder = sys.argv[1]

    def handler(*args: object, **kwargs: object) -> Handler:
        return Handler(*args, directory=folder, **kwargs)

    # Python queues 5 connections by default; dodo opens 32 at once
    # (FETCH_THREADS), and on macOS the rest are reset.
    http.server.ThreadingHTTPServer.request_queue_size = 128
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    server.daemon_threads = True
    print(f"port {server.server_address[1]}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

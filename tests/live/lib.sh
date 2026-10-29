# Shared helpers for the live checks. Source it from a script in this
# directory; it moves to the repo root.
#
#   LIVE_SANITIZE=address|thread  build the server with that sanitizer
#   LIVE_PORT_BASE=N              first port to use (default 18400)

set -euo pipefail

LIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LIVE_DIR/../.." && pwd)"
cd "$REPO_ROOT"

BUILD_DIR="$REPO_ROOT/build/live"
mkdir -p "$BUILD_DIR"
LIVE_PORT_BASE="${LIVE_PORT_BASE:-18400}"
SERVER_PIDS=()

# The mojo command: pixi's when pixi is on PATH, else a bare mojo.
mojo_cmd() {
    if command -v pixi >/dev/null 2>&1; then
        pixi run mojo "$@"
    else
        mojo "$@"
    fi
}

# Build tests/live/live_server.mojo once per sanitizer setting and print
# the binary's path.
build_server() {
    local name="live_server"
    local flags=()
    if [ -n "${LIVE_SANITIZE:-}" ]; then
        name="live_server_${LIVE_SANITIZE}"
        flags=(--sanitize "$LIVE_SANITIZE")
    fi
    local bin="$BUILD_DIR/$name"
    if [ ! -x "$bin" ] || [ "$LIVE_DIR/live_server.mojo" -nt "$bin" ] \
        || [ -n "$(find dodo -name '*.mojo' -newer "$bin" -print -quit)" ]; then
        echo "building $name" >&2
        mojo_cmd build -I . ${flags[@]+"${flags[@]}"} \
            "$LIVE_DIR/live_server.mojo" -o "$bin" >&2
    fi
    echo "$bin"
}

# start_server <bin> <mode> <port> [workers]: run it in the background,
# logging to $BUILD_DIR/<mode>-<port>.log, and wait until it listens.
start_server() {
    local bin="$1" mode="$2" port="$3" workers="${4:-1}"
    local log="$BUILD_DIR/$mode-$port.log"
    "$bin" "$mode" "$port" "$workers" >"$log" 2>&1 &
    SERVER_PIDS+=("$!")
    local i
    for i in $(seq 1 100); do
        if grep -q "^listening" "$log" 2>/dev/null; then
            return 0
        fi
        if ! kill -0 "$!" 2>/dev/null; then
            echo "server $mode:$port exited at start:" >&2
            cat "$log" >&2
            return 1
        fi
        sleep 0.1
    done
    echo "server $mode:$port did not start" >&2
    return 1
}

# True while every server started here is still running.
servers_alive() {
    local pid
    for pid in ${SERVER_PIDS[@]+"${SERVER_PIDS[@]}"}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 1
        fi
    done
    return 0
}

stop_servers() {
    local pid
    for pid in ${SERVER_PIDS[@]+"${SERVER_PIDS[@]}"}; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    SERVER_PIDS=()
}
trap stop_servers EXIT

# The host a container uses to reach a server on this machine, and the
# docker flags that make that work.
docker_target_host() {
    if [ "$(uname)" = "Darwin" ]; then
        echo "host.docker.internal"
    else
        echo "127.0.0.1"
    fi
}

docker_net_flags() {
    if [ "$(uname)" = "Darwin" ]; then
        echo ""
    else
        echo "--network host"
    fi
}

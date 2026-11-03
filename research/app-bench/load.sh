#!/bin/bash
# Load each endpoint of bench_app and bench_raw with wrk.
# Usage: load.sh BIN_DIR [SECONDS]
BIN_DIR=$1
SECONDS_EACH=${2:-5}
HERE=$(cd "$(dirname "$0")" && pwd)

run() {
    local name=$1
    local url=$2
    local script=$3
    local args=(-t2 -c32 "-d${SECONDS_EACH}s" --latency)
    if [ -n "$script" ]; then
        args+=(-s "$script")
    fi
    local out
    out=$(wrk "${args[@]}" "$url")
    local rps
    rps=$(echo "$out" | awk '/Requests\/sec/ {print $2}')
    local p50
    p50=$(echo "$out" | awk '$1=="50%" {print $2}')
    local p99
    p99=$(echo "$out" | awk '$1=="99%" {print $2}')
    local bad
    bad=$(echo "$out" | awk '/Non-2xx|Socket errors/ {printf "%s ", $0}')
    printf "%-14s %10s rps  p50 %-9s p99 %-9s %s\n" "$name" "$rps" "$p50" "$p99" "$bad"
}

"$BIN_DIR/bench_raw" 18101 2 >/dev/null 2>&1 &
RAW=$!
"$BIN_DIR/bench_app" 18102 2 >/dev/null 2>&1 &
APP=$!
sleep 1

run raw http://127.0.0.1:18101/
run first-route http://127.0.0.1:18102/plain
run last-literal http://127.0.0.1:18102/last
run path http://127.0.0.1:18102/users/42
run two-params http://127.0.0.1:18102/orgs/acme/users/42
run query "http://127.0.0.1:18102/search?q=hello&limit=3"
run json-body http://127.0.0.1:18102/users "$HERE/post.lua"
run not-found http://127.0.0.1:18102/nope

kill $RAW $APP
wait 2>/dev/null

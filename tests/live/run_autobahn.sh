#!/usr/bin/env bash
# The Autobahn WebSocket suite (fuzzingclient) against the live server's
# two echo servers: one thread per connection (ws) and the reactor
# (ws-reactor). Runs every case; the report lands in
# build/live/autobahn/index.html.
#
# Uses a local wstest when installed, else the crossbario image.
# The server does not offer permessage-deflate, so sections 12 and 13
# come back UNIMPLEMENTED, which passes.
#
#   AUTOBAHN_CASES='1.*,2.*'  run only these cases (default: all)

source "$(dirname "$0")/lib.sh"

AUTOBAHN_IMAGE="crossbario/autobahn-testsuite:25.10.1"
WS_PORT=$((LIVE_PORT_BASE + 2))
WS_REACTOR_PORT=$((LIVE_PORT_BASE + 3))
CASES="${AUTOBAHN_CASES:-*}"

bin="$(build_server)"
start_server "$bin" ws "$WS_PORT"
start_server "$bin" ws-reactor "$WS_REACTOR_PORT"

out="$BUILD_DIR/autobahn"
rm -rf "$out"
mkdir -p "$out"

if command -v wstest >/dev/null 2>&1; then
    host="127.0.0.1"
    report_dir="$out"
else
    host="$(docker_target_host)"
    report_dir="/out/autobahn"
fi

cases_json="$(python3 -I -c 'import json, sys
print(json.dumps([c.strip() for c in sys.argv[1].split(",")]))' "$CASES")"

cat >"$out/fuzzingclient.json" <<EOF
{
  "outdir": "$report_dir",
  "servers": [
    {"agent": "dodo-thread", "url": "ws://$host:$WS_PORT"},
    {"agent": "dodo-reactor", "url": "ws://$host:$WS_REACTOR_PORT"}
  ],
  "cases": $cases_json,
  "exclude-cases": [],
  "exclude-agent-cases": {}
}
EOF

if command -v wstest >/dev/null 2>&1; then
    wstest -m fuzzingclient -s "$out/fuzzingclient.json" >"$out/wstest.log" 2>&1
else
    # shellcheck disable=SC2046
    docker run --rm $(docker_net_flags) --platform linux/amd64 \
        -v "$BUILD_DIR:/out" "$AUTOBAHN_IMAGE" \
        wstest -m fuzzingclient -s /out/autobahn/fuzzingclient.json \
        >"$out/wstest.log" 2>&1
fi

if ! servers_alive; then
    echo "FAIL: a server died during the Autobahn run" >&2
    exit 1
fi

python3 -I - "$out/index.json" <<'EOF'
import json
import sys

PASS = {"OK", "NON-STRICT", "INFORMATIONAL", "UNIMPLEMENTED"}
PASS_CLOSE = {"OK", "INFORMATIONAL", "UNIMPLEMENTED"}

with open(sys.argv[1]) as f:
    report = json.load(f)

bad = 0
for agent in sorted(report):
    cases = report[agent]
    counts = {}
    failed = []
    for case_id, result in cases.items():
        behavior = result["behavior"]
        close = result["behaviorClose"]
        counts[behavior] = counts.get(behavior, 0) + 1
        if behavior not in PASS or close not in PASS_CLOSE:
            failed.append((case_id, behavior, close))
    summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    print(f"{agent}: {len(cases)} cases ({summary}), {len(failed)} failed")
    for case_id, behavior, close in sorted(failed):
        print(f"  FAIL {case_id}: {behavior}, close {close}")
    if not cases:
        bad += 1
    bad += len(failed)
sys.exit(1 if bad else 0)
EOF

#!/usr/bin/env bash
# h2spec (RFC 9113 and RFC 7541 conformance) against the live server:
# HTTP/2 over TLS (ALPN h2) and cleartext prior knowledge (h2c).
#
# Uses a local h2spec when installed, else the summerwind/h2spec image.
#
# One h2c case is expected to fail: "3.5 #2, sends invalid connection
# preface". The cleartext port serves HTTP/1.1 and HTTP/2, so bytes that
# are not the HTTP/2 preface are an HTTP/1.1 request, and get a 400. Over
# TLS, where ALPN settles the protocol, the same case passes.

source "$(dirname "$0")/lib.sh"

H2SPEC_IMAGE="summerwind/h2spec:2.6.0"
HTTP_PORT=$((LIVE_PORT_BASE + 0))
HTTPS_PORT=$((LIVE_PORT_BASE + 1))

bin="$(build_server)"
start_server "$bin" http "$HTTP_PORT"
start_server "$bin" https "$HTTPS_PORT"

# run_h2spec <port> <report> [flags...]
run_h2spec() {
    local port="$1" report="$2"
    shift 2
    if command -v h2spec >/dev/null 2>&1; then
        h2spec -h 127.0.0.1 -p "$port" -o 5 -j "$report" "$@" >/dev/null || true
    else
        local name
        name="$(basename "$report")"
        # shellcheck disable=SC2046
        docker run --rm $(docker_net_flags) -v "$BUILD_DIR:/out" \
            --platform linux/amd64 "$H2SPEC_IMAGE" \
            -h "$(docker_target_host)" -p "$port" -o 5 \
            -j "/out/$name" "$@" >/dev/null || true
    fi
}

run_h2spec "$HTTPS_PORT" "$BUILD_DIR/h2spec-tls.xml" -t -k
run_h2spec "$HTTP_PORT" "$BUILD_DIR/h2spec-h2c.xml"

if ! servers_alive; then
    echo "FAIL: a server died during h2spec" >&2
    exit 1
fi

python3 -I - "$BUILD_DIR/h2spec-tls.xml" "$BUILD_DIR/h2spec-h2c.xml" <<'EOF'
import sys
import xml.etree.ElementTree as ET

# (report, testsuite package, test case name) the run may fail.
ALLOWED = {
    ("h2spec-h2c.xml", "http2/3.5", "Sends invalid connection preface"),
}

bad = 0
for path in sys.argv[1:]:
    name = path.rsplit("/", 1)[-1]
    root = ET.parse(path).getroot()
    total = 0
    failed = []
    for suite in root.iter("testsuite"):
        package = suite.get("package", "")
        for case in suite.iter("testcase"):
            total += 1
            if case.find("failure") is None and case.find("error") is None:
                continue
            failed.append((name, package, case.get("classname", "")))
    unexpected = [f for f in failed if f not in ALLOWED]
    print(f"{name}: {total} cases, {len(failed)} failed, "
          f"{len(unexpected)} unexpected")
    for f in unexpected:
        print(f"  FAIL {f[1]}: {f[2]}")
    if total == 0:
        print(f"  FAIL no test cases in {name}")
        bad += 1
    bad += len(unexpected)
sys.exit(1 if bad else 0)
EOF

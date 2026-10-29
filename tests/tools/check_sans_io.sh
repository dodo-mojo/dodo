#!/usr/bin/env bash
# Check that the pure parser files (the sans-I/O surface re-exported by
# dodo.http.proto) import nothing that does I/O: no runtime, io, tcp, uds,
# tls or net. A file that needs I/O leaves this list on purpose.
#
# Usage: pixi run check-sans-io

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

SANS_IO_FILES=(
    "dodo/http/proto/__init__.mojo"
    "dodo/http/cookie.mojo"
    "dodo/http/form.mojo"
    "dodo/http/multipart.mojo"
    "dodo/http/url.mojo"
    "dodo/http/headers.mojo"
    "dodo/http/header_view.mojo"
    "dodo/http/header_phf.mojo"
    "dodo/ws/protocol.mojo"
    "dodo/http/intern.mojo"
    "dodo/http/simd_parsers.mojo"
    "dodo/http/hpack_huffman.mojo"
    "dodo/http/hpack_huffman_simd.mojo"
    "dodo/http/proto/huffman.mojo"
    "dodo/http2/frame.mojo"
    "dodo/http2/hpack.mojo"
    "dodo/http2/state.mojo"
    "dodo/http/proto/h2c_upgrade.mojo"
    "dodo/http/proto/ascii.mojo"
)

FORBIDDEN_PREFIXES=(
    "dodo.runtime"
    "dodo.io"
    "dodo.tcp"
    "dodo.uds"
    "dodo.tls"
    "dodo.net"
)

violations=0

for file in "${SANS_IO_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "check-sans-io: listed file does not exist: $file" >&2
        violations=$((violations + 1))
        continue
    fi
    for prefix in "${FORBIDDEN_PREFIXES[@]}"; do
        # Anchored on from/import so prose in docstrings never matches.
        pattern="^(from|import)[[:space:]]+(${prefix//./\\.})\\b"
        if grep -nE "$pattern" "$file" >/dev/null 2>&1; then
            echo "check-sans-io: $file imports $prefix:" >&2
            grep -nE "$pattern" "$file" >&2
            violations=$((violations + 1))
        fi
    done
done

if [[ $violations -gt 0 ]]; then
    echo "check-sans-io: $violations violation(s)." >&2
    exit 1
fi

echo "check-sans-io: ${#SANS_IO_FILES[@]} files clean."

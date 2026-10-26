#!/usr/bin/env bash
# Check the http <-> http2 layering.
#
# - dodo/http2/** may reach dodo.http only through dodo.http.wire,
#   dodo.http.proto and the two HPACK Huffman modules.
# - dodo/http/** may import dodo.http2 only from the files listed in
#   BRIDGES, which drive Http2Connection or Http2ClientConnection.
#
# Usage: pixi run check-no-http-http2-cycle

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

ALLOWED_HTTP_SUBPATHS=(
    "dodo.http.wire"
    "dodo.http.proto"
    "dodo.http.hpack_huffman"
    "dodo.http.hpack_huffman_simd"
)

BRIDGES=(
    "dodo/http/_h2_conn_handle.mojo"
    "dodo/http/_unified_reactor_impl.mojo"
    "dodo/http/frontend.mojo"
    "dodo/http/proto/__init__.mojo"
    "dodo/http/server.mojo"
    "dodo/http/client.mojo"
    "dodo/http/_client/h2_send.mojo"
    "dodo/http/_client/h2_download.mojo"
)

violations=0

# Pass 1: dodo/http2/** must not import dodo.http outside the allowed paths.
# Inside dodo/http2, the relative `..http` means `dodo.http`.
while IFS= read -r -d '' file; do
    matches="$(grep -nE '^(from|import)[[:space:]]+(dodo\.http|\.\.http)\b' "$file" || true)"
    if [[ -z "$matches" ]]; then
        continue
    fi
    while IFS= read -r line; do
        path="$(echo "$line" | sed -E 's/^[0-9]+:[[:space:]]*(from|import)[[:space:]]+([^[:space:]]+).*/\2/')"
        if [[ "${path:0:2}" == ".." ]]; then
            path="dodo.${path:2}"
        fi
        allowed=0
        for prefix in "${ALLOWED_HTTP_SUBPATHS[@]}"; do
            if [[ "$path" == "$prefix" ]] || [[ "$path" == "$prefix."* ]]; then
                allowed=1
                break
            fi
        done
        if [[ "$allowed" -eq 0 ]]; then
            echo "check-no-http-http2-cycle: $file: forbidden import:" >&2
            echo "  $line" >&2
            violations=$((violations + 1))
        fi
    done <<< "$matches"
done < <(find dodo/http2 -name '*.mojo' -print0)

# Pass 2: dodo/http/** files outside BRIDGES must not import dodo.http2.
# Relative forms (`..http2`, `...http2`) count too.
while IFS= read -r -d '' file; do
    is_bridge=0
    for bridge in "${BRIDGES[@]}"; do
        if [[ "$file" == "$bridge" ]]; then
            is_bridge=1
            break
        fi
    done
    if [[ "$is_bridge" -eq 1 ]]; then
        continue
    fi
    matches="$(grep -nE '^(from|import)[[:space:]]+(dodo\.http2|\.{2,}http2)\b' "$file" || true)"
    if [[ -n "$matches" ]]; then
        echo "check-no-http-http2-cycle: $file imports dodo.http2 but isn't a bridge:" >&2
        echo "$matches" >&2
        violations=$((violations + 1))
    fi
done < <(find dodo/http -name '*.mojo' -print0)

if [[ $violations -gt 0 ]]; then
    echo "check-no-http-http2-cycle: $violations violation(s). Route shared types through dodo.http.wire." >&2
    exit 1
fi

echo "check-no-http-http2-cycle: clean."

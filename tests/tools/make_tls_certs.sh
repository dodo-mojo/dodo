#!/usr/bin/env bash
# Make the self-signed cert and key the TLS tests load from
# build/test-certs/. Does nothing when both already exist.

set -euo pipefail

OUT_DIR="${1:-$(pwd)/build/test-certs}"
CERT="$OUT_DIR/server.pem"
KEY="$OUT_DIR/server.key"

if [ -f "$CERT" ] && [ -f "$KEY" ]; then
    exit 0
fi

mkdir -p "$OUT_DIR"
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$KEY" -out "$CERT" -days 365 \
    -subj "/CN=localhost/O=dodo/OU=tests" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
    >/dev/null 2>&1
echo "made $CERT"

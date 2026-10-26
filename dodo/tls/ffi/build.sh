#!/bin/bash
# Build libdodo_tls.so (the OpenSSL wrapper) into build/ and install it into
# $CONDA_PREFIX/lib, where dodo looks it up at runtime.
#
# Runs as a pixi activation script, so it uses `return`, never `exit`, and
# skips the build when the library is newer than its sources.
#
# Linked with `-z nodelete` on Linux so the library is never unmapped once
# loaded, even if a call site drops its handle early.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../../../build"
TARGET="$BUILD_DIR/libdodo_tls.so"
INSTALLED="$CONDA_PREFIX/lib/libdodo_tls.so"
SOURCE="$SCRIPT_DIR/openssl_wrapper.cpp"
HEADER="$SCRIPT_DIR/openssl_wrapper.h"

if [ -z "$CONDA_PREFIX" ]; then
    echo "dodo: CONDA_PREFIX not set, skipping the TLS wrapper build" >&2
    return 0 2>/dev/null || true
fi

_tls_needs_rebuild() {
    [ ! -f "$TARGET" ] && return 0
    [ ! -f "$INSTALLED" ] && return 0
    [ "$SOURCE" -nt "$TARGET" ] && return 0
    [ "$HEADER" -nt "$TARGET" ] && return 0
    [ "$CONDA_PREFIX/lib/libssl.so" -nt "$TARGET" ] 2>/dev/null && return 0
    [ "$TARGET" -nt "$INSTALLED" ] 2>/dev/null && return 0
    return 1
}

if ! _tls_needs_rebuild; then
    return 0 2>/dev/null || true
fi

if [ ! -f "$CONDA_PREFIX/include/openssl/ssl.h" ]; then
    echo "dodo: openssl/ssl.h not found in $CONDA_PREFIX/include; run 'pixi install'" >&2
    return 1 2>/dev/null || true
fi

mkdir -p "$BUILD_DIR"

if [[ "$(uname)" == "Darwin" ]]; then
    CXX="clang++"
    NODELETE=""
else
    CXX="g++"
    NODELETE="-Wl,-z,nodelete"
fi

if $CXX -O2 -std=c++17 -fPIC -DNDEBUG -shared \
    -o "$TARGET" \
    "$SOURCE" \
    -I"$CONDA_PREFIX/include" \
    -L"$CONDA_PREFIX/lib" \
    -lssl -lcrypto \
    $NODELETE \
    -Wl,-rpath,"$CONDA_PREFIX/lib"; then
    cp "$TARGET" "$INSTALLED"
    echo "dodo: built $INSTALLED"
else
    echo "dodo: libdodo_tls.so failed to build; removed the stale copy" >&2
    rm -f "$TARGET" "$INSTALLED"
    return 1 2>/dev/null || true
fi

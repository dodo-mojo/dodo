#!/bin/bash
# Build the simdjson wrapper into build/ and install it into
# $CONDA_PREFIX/lib, where dodo looks it up at runtime:
#
#   libdodo_simdjson.so   JSON parsing through simdjson (conda-forge)
#
# Runs as a pixi activation script, so it uses `return`, never `exit`, and
# rebuilds the library only when its source is newer. When simdjson is not
# installed the library is skipped and dodo.json parses in pure Mojo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../../../build"
PIN_HEADER="$SCRIPT_DIR/../../utils/ffi/pin_self.h"
SOURCE="$SCRIPT_DIR/simdjson_wrapper.cpp"
TARGET="$BUILD_DIR/libdodo_simdjson.so"

if [ -z "$CONDA_PREFIX" ]; then
    echo "dodo: CONDA_PREFIX not set, skipping the simdjson wrapper build" >&2
    return 0 2>/dev/null || true
fi

if [ ! -f "$CONDA_PREFIX/include/simdjson.h" ]; then
    echo "dodo: simdjson not installed, skipping libdodo_simdjson.so" >&2
    return 0 2>/dev/null || true
fi

if [[ "$(uname)" == "Darwin" ]]; then
    CXX="clang++"
    NODELETE=""  # no such flag on macOS; pin_self.h does the same
else
    CXX="g++"
    NODELETE="-Wl,-z,nodelete"
fi

INSTALLED="$CONDA_PREFIX/lib/libdodo_simdjson.so"
SIMDJSON_LIB="$(ls "$CONDA_PREFIX"/lib/libsimdjson.* 2>/dev/null | head -n 1)"

_needs_rebuild() {
    if [ ! -f "$TARGET" ] || [ ! -f "$INSTALLED" ]; then
        return 0
    fi
    if [ "$SOURCE" -nt "$TARGET" ] || [ "$PIN_HEADER" -nt "$TARGET" ]; then
        return 0
    fi
    if [ -n "$SIMDJSON_LIB" ] && [ "$SIMDJSON_LIB" -nt "$TARGET" ]; then
        return 0
    fi
    if [ "$TARGET" -nt "$INSTALLED" ]; then
        return 0
    fi
    return 1
}

if _needs_rebuild; then
    mkdir -p "$BUILD_DIR"
    if $CXX -O3 -std=c++17 -fPIC -DNDEBUG -shared -o "$TARGET" "$SOURCE" \
        -I"$CONDA_PREFIX/include" -L"$CONDA_PREFIX/lib" -lsimdjson -pthread \
        $NODELETE -Wl,-rpath,"$CONDA_PREFIX/lib"; then
        # Replace the file instead of overwriting it: macOS kills any process
        # that loads a signed library whose file was rewritten in place.
        rm -f "$INSTALLED"
        cp "$TARGET" "$INSTALLED"
        echo "dodo: built $INSTALLED"
    else
        echo "dodo: libdodo_simdjson.so failed to build; removed the stale copy" >&2
        rm -f "$TARGET" "$INSTALLED"
        return 1 2>/dev/null || true
    fi
fi

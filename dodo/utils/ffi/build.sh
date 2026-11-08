#!/bin/bash
# Build the process wrapper into build/ and install it into
# $CONDA_PREFIX/lib, where dodo looks it up at runtime:
#
#   libdodo_proc.so   spawn, wait and kill processes; catch signals
#
# Runs as a pixi activation script, so it uses `return`, never `exit`, and
# rebuilds the library only when its source is newer.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../../../build"
SOURCE="$SCRIPT_DIR/proc_wrapper.c"
PIN_HEADER="$SCRIPT_DIR/pin_self.h"
TARGET="$BUILD_DIR/libdodo_proc.so"

if [ -z "$CONDA_PREFIX" ]; then
    echo "dodo: CONDA_PREFIX not set, skipping the process wrapper build" >&2
    return 0 2>/dev/null || true
fi
INSTALLED="$CONDA_PREFIX/lib/libdodo_proc.so"

# DODO_CC overrides the compiler; the conda package build sets it.
if [[ "$(uname)" == "Darwin" ]]; then
    CC="${DODO_CC:-clang}"
    NODELETE=""  # no such flag on macOS; pin_self.h does the same
else
    CC="${DODO_CC:-gcc}"
    NODELETE="-Wl,-z,nodelete"
fi

mkdir -p "$BUILD_DIR"

_dodo_proc_stale=0
if [ ! -f "$TARGET" ] || [ ! -f "$INSTALLED" ]; then
    _dodo_proc_stale=1
elif [ "$SOURCE" -nt "$TARGET" ] || [ "$PIN_HEADER" -nt "$TARGET" ]; then
    _dodo_proc_stale=1
elif [ "$TARGET" -nt "$INSTALLED" ]; then
    _dodo_proc_stale=1
fi

if [ "$_dodo_proc_stale" -eq 1 ]; then
    if $CC -O2 -Wall -Wextra -fPIC -shared -o "$TARGET" "$SOURCE" $NODELETE; then
        # Replace the file instead of overwriting it: macOS kills any process
        # that loads a signed library whose file was rewritten in place.
        rm -f "$INSTALLED"
        cp "$TARGET" "$INSTALLED"
        echo "dodo: built $INSTALLED"
    else
        echo "dodo: libdodo_proc.so failed to build; removed the stale copy" >&2
        rm -f "$TARGET" "$INSTALLED"
        return 1 2>/dev/null || true
    fi
fi

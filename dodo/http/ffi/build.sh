#!/bin/bash
# Build the HTTP FFI wrappers into build/ and install them into
# $CONDA_PREFIX/lib, where dodo looks them up at runtime:
#
#   libdodo_zlib.so    gzip / deflate (zlib + libdeflate)
#   libdodo_brotli.so  br (skipped when libbrotli isn't installed)
#   libdodo_fs.so      open/read/close for FileServer and UnixListener
#
# Runs as a pixi activation script, so it uses `return`, never `exit`, and
# rebuilds each library only when its source is newer.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../../../build"
PIN_HEADER="$SCRIPT_DIR/../../utils/ffi/pin_self.h"

if [ -z "$CONDA_PREFIX" ]; then
    echo "dodo: CONDA_PREFIX not set, skipping the HTTP wrapper builds" >&2
    return 0 2>/dev/null || true
fi

if [[ "$(uname)" == "Darwin" ]]; then
    CC="clang"
    NODELETE=""  # no such flag on macOS; pin_self.h does the same
else
    CC="gcc"
    NODELETE="-Wl,-z,nodelete"
fi

mkdir -p "$BUILD_DIR"

# _build_lib NAME SOURCE [LINK FLAGS...]
# Builds build/libdodo_NAME.so from SOURCE when it is missing or stale, then
# copies it into $CONDA_PREFIX/lib.
_build_lib() {
    local name="$1"
    local source="$2"
    shift 2
    local target="$BUILD_DIR/libdodo_$name.so"
    local installed="$CONDA_PREFIX/lib/libdodo_$name.so"

    local stale=0
    if [ ! -f "$target" ] || [ ! -f "$installed" ]; then
        stale=1
    elif [ "$source" -nt "$target" ] || [ "$SCRIPT_DIR/scratch_cache.h" -nt "$target" ] || [ "$PIN_HEADER" -nt "$target" ]; then
        stale=1
    elif [ "$target" -nt "$installed" ]; then
        stale=1
    fi
    if [ "$stale" -eq 0 ]; then
        return 0
    fi

    if $CC -O2 -fPIC -shared -o "$target" "$source" \
        -I"$CONDA_PREFIX/include" -L"$CONDA_PREFIX/lib" \
        "$@" $NODELETE -Wl,-rpath,"$CONDA_PREFIX/lib"; then
        # Replace the file instead of overwriting it: macOS kills any process
        # that loads a signed library whose file was rewritten in place.
        rm -f "$installed"
        cp "$target" "$installed"
        echo "dodo: built $installed"
    else
        echo "dodo: libdodo_$name.so failed to build; removed the stale copy" >&2
        rm -f "$target" "$installed"
        return 1
    fi
}

_build_lib zlib "$SCRIPT_DIR/zlib_wrapper.c" -lz -ldeflate -pthread

if [ -f "$CONDA_PREFIX/lib/libbrotlienc.so" ] || [ -f "$CONDA_PREFIX/lib/libbrotlienc.dylib" ]; then
    _build_lib brotli "$SCRIPT_DIR/brotli_wrapper.c" \
        -lbrotlienc -lbrotlidec -lbrotlicommon -pthread
else
    echo "dodo: libbrotli not installed, skipping libdodo_brotli.so" >&2
fi

_build_lib fs "$SCRIPT_DIR/fs_wrapper.c"

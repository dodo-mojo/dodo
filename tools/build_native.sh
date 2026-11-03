#!/bin/bash
# Build every native wrapper library dodo loads at runtime into
# $CONDA_PREFIX/lib. pixi sources this on activation and the conda recipe
# sources it in the package build, so a new wrapper's build script is added
# here and nowhere else.
#
# Sourced, so it uses `return`, never `exit`. Returns 1 when any wrapper
# failed to build.

_DODO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_DODO_NATIVE_STATUS=0

for _dodo_script in \
    dodo/tls/ffi/build.sh \
    dodo/http/ffi/build.sh \
    dodo/json/ffi/build.sh; do
    if ! source "$_DODO_ROOT/$_dodo_script"; then
        _DODO_NATIVE_STATUS=1
    fi
done

return $_DODO_NATIVE_STATUS 2>/dev/null || true

#!/usr/bin/env bash
# Build and run fuzzers.
#
#   bash fuzz/run.sh              build every fuzzer (compile check only)
#   bash fuzz/run.sh http_server  build and run fuzz/fuzz_http_server.mojo
#   bash fuzz/run.sh selftest     run the harness's own tests in fuzz/mozz_tests/
#
# Through pixi:
#   pixi run fuzz-build
#   pixi run fuzz http_server
#   pixi run fuzz-selftest
#
# The fuzzers use the harness vendored in fuzz/mozz/.
#
# Crashes land in .mozz_crashes/<name>/.

set -uo pipefail

BUILD_DIR="build/fuzz"
mkdir -p "$BUILD_DIR"

build_fuzzer() {
  local src="$1"
  local name
  name="$(basename "${src%.mojo}")"
  local out="$BUILD_DIR/$name"
  rm -f "$out"
  if ! mojo build -I . -I fuzz "$src" -o "$out" 2>"$out.log"; then
    echo "BUILD FAILED: $src"
    sed -n '1,20p' "$out.log"
    return 1
  fi
}

run_selftest() {
  for test_file in fuzz/mozz_tests/test_*.mojo; do
    echo "$test_file"
    if ! mojo -I fuzz -I . "$test_file"; then
      echo "SELFTEST FAILED: $test_file"
      return 1
    fi
  done
  echo "all harness tests pass"
}

if [ "${1:-}" = "selftest" ]; then
  run_selftest || exit 1
  exit 0
fi

if [ "$#" -ge 1 ]; then
  src="fuzz/fuzz_$1.mojo"
  if [ ! -f "$src" ]; then
    src="fuzz/$1.mojo"
  fi
  if [ ! -f "$src" ]; then
    echo "no fuzzer named $1" >&2
    exit 1
  fi
  build_fuzzer "$src" || exit 1
  exec "$BUILD_DIR/$(basename "${src%.mojo}")"
fi

failed=()
for src in fuzz/*.mojo; do
  if ! build_fuzzer "$src"; then
    failed+=("$src")
  fi
done

if [ "${#failed[@]}" -ne 0 ]; then
  echo "── ${#failed[@]} fuzzer(s) failed to build ──"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
echo "── all fuzzers build ──"

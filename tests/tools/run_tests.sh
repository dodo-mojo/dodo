#!/usr/bin/env bash
# Build and run every test: one aggregate binary per area (see
# gen_test_aggregates.py), then the tests that need their own process.
# Keeps going after a failure and lists every failed suite at the end.
#
# Env:
#   AGG_JOBS       parallel builds (default: cores, capped at 4; each one is
#                  a full compile of the library and uses several GB)
#   BUILD_DIR      where binaries go (default: build/agg)
#   MOJO_DEFINES   extra flags for every build, e.g. "-D ASSERT=all"

set -uo pipefail

AGG_DIR="tests/_agg"
BUILD_DIR="${BUILD_DIR:-build/agg}"
MOJO_DEFINES="${MOJO_DEFINES:-}"

cores="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
if [ "$cores" -gt 4 ]; then
  cores=4
fi
JOBS="${AGG_JOBS:-$cores}"

# Must match EXCLUDE in gen_test_aggregates.py.
STANDALONE=(
  tests/runtime/test_block_in_pool.mojo
  tests/runtime/test_closure_send_contract.mojo
  tests/runtime/test_handoff.mojo
  tests/runtime/test_scheduler_start_rollback.mojo
  tests/runtime/test_reuseport.mojo
  tests/runtime/stress_scheduler.mojo
  tests/json/test_loads_fallback.mojo
)

echo "── prerequisites ──"
bash tests/tools/make_tls_certs.sh || { echo "ERROR: cert setup failed" >&2; exit 1; }
python3 tests/tools/gen_test_aggregates.py --check || {
  echo "ERROR: aggregates are stale; run: pixi run tests-gen" >&2
  exit 1
}

mkdir -p "$BUILD_DIR"
AGGS=()
for a in "$AGG_DIR"/agg_*.mojo; do
  if [ -f "$a" ]; then
    AGGS+=("$a")
  fi
done
if [ "${#AGGS[@]}" -eq 0 ]; then
  echo "ERROR: no aggregates in $AGG_DIR" >&2
  exit 1
fi

# build_one SRC: compile one aggregate. Each aggregate imports its tests by
# module name relative to its area directory.
build_one() {
  local src="$1"
  local name
  name="$(basename "${src%.mojo}")"
  local out="$BUILD_DIR/$name"
  local area="${name#agg_}"
  local inc="tests/$area"
  if [ "$area" = "_root" ]; then
    inc="tests"
  fi
  # Remove the old binary so a failed build can't run stale code.
  rm -f "$out"
  # shellcheck disable=SC2086
  if ! mojo build $MOJO_DEFINES -I . -I "$inc" "$src" -o "$out" 2>"$out.log"; then
    echo "BUILD FAILED: $src"
    sed -n '1,30p' "$out.log"
    return 1
  fi
}
export -f build_one
export BUILD_DIR MOJO_DEFINES

echo "── building ${#AGGS[@]} aggregates (jobs=$JOBS) ──"
printf '%s\n' "${AGGS[@]}" | xargs -P "$JOBS" -I FF bash -c 'build_one FF'

failed=()
for a in "${AGGS[@]}"; do
  bin="$BUILD_DIR/$(basename "${a%.mojo}")"
  if [ ! -x "$bin" ]; then
    failed+=("$a (build)")
  fi
done

echo "── running aggregates ──"
for a in "${AGGS[@]}"; do
  bin="$BUILD_DIR/$(basename "${a%.mojo}")"
  if [ -x "$bin" ]; then
    if ! "$bin"; then
      failed+=("$a")
    fi
  fi
done

echo "── running ${#STANDALONE[@]} standalone tests ──"
for t in "${STANDALONE[@]}"; do
  if [ ! -f "$t" ]; then
    echo "MISSING: $t"
    failed+=("$t (missing)")
    continue
  fi
  # shellcheck disable=SC2086
  if ! mojo $MOJO_DEFINES -I . "$t"; then
    failed+=("$t")
  fi
done

echo "── checking compile errors ──"
if ! bash tests/tools/check_compile_errors.sh; then
  failed+=("compile errors")
fi

if [ "${#failed[@]}" -ne 0 ]; then
  echo
  echo "── ${#failed[@]} suite(s) failed ──"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
echo "── all suites passed ──"

#!/usr/bin/env bash
# Start the test databases in Docker and run the dodo.db driver tests
# against them. `pixi run tests` stays Docker-free; this is the rest.
#
# Env:
#   DODO_DB_NO_COMPOSE=1   the databases are already up (another host, CI
#                          services); don't start them
#   MOJO_DEFINES           extra flags for every build

set -uo pipefail

COMPOSE="tests/live/db/compose.yaml"
MOJO_DEFINES="${MOJO_DEFINES:-}"

if [ "${DODO_DB_NO_COMPOSE:-}" != "1" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "run_db_tests: docker not found; start $COMPOSE yourself and set DODO_DB_NO_COMPOSE=1" >&2
    exit 1
  fi
  docker compose -f "$COMPOSE" up -d --wait || exit 1
fi

failed=()
for test in tests/live/db/test_*.mojo; do
  echo "== $test"
  if ! mojo $MOJO_DEFINES -I . "$test"; then
    failed+=("$test")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "run_db_tests: ${#failed[@]} failed:" >&2
  printf '  %s\n' "${failed[@]}" >&2
  exit 1
fi
echo "run_db_tests: all passed"

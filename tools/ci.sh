#!/usr/bin/env bash
# Runs on this machine what GitHub's CI ran. There is no CI on GitHub.
#
#   pixi run ci              every step this branch needs, in order
#   pixi run ci tests        only the steps named
#
# Steps: checks, package, tests. `package` builds and tests the conda package,
# and runs on its own only when this branch changes packaging, the native
# wrappers or pixi. Run it on macOS and on Linux (WSL) before merging into dev.
set -euo pipefail
cd "$(dirname "$0")/.."

STEPS=(checks package tests)
# What `package` depends on: a change here means the package must be rebuilt.
PACKAGE_PATHS=(packaging tools/build_native.sh 'dodo/*/ffi' pixi.toml pixi.lock)

say() {
  printf '\n== %s\n' "$*"
}

fail() {
  printf '\nci: %s\n' "$*" >&2
  exit 1
}

# The import and layering checks, and the package precompiles.
step_checks() {
  say "checks"
  pixi run check-sans-io
  pixi run check-no-http-http2-cycle
  pixi run check-package
  python3 tools/test_docs_tools.py
}

step_package() {
  say "package"
  bash packaging/build_local.sh
}

step_tests() {
  say "tests"
  pixi run tests
}

# Does this branch change anything the package is built from?
packageChanged() {
  git fetch -q origin dev
  local base
  base=$(git merge-base origin/dev HEAD)
  if git diff --quiet "$base" -- "${PACKAGE_PATHS[@]}"; then
    return 1
  fi
}

main() {
  local wanted=("$@")
  if [ ${#wanted[@]} -eq 0 ]; then
    wanted=(checks tests)
    if packageChanged; then
      echo "this branch changes the package, so package runs too"
      wanted=(checks package tests)
    fi
  fi
  local step
  for step in "${wanted[@]}"; do
    if [[ ! " ${STEPS[*]} " =~ " $step " ]]; then
      fail "no step called $step (steps: ${STEPS[*]})"
    fi
  done
  for step in "${wanted[@]}"; do
    "step_$step"
  done
  local commit
  commit=$(git rev-parse --short HEAD)
  if [ -n "$(git status --porcelain)" ]; then
    commit="$commit plus uncommitted changes"
  fi
  say "ci passed on $(uname -s) at $commit"
}

main "$@"

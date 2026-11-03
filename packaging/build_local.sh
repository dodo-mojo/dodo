#!/bin/bash
# Build and test the conda package from this checkout instead of the git tag.
# Usage: bash packaging/build_local.sh [OUTPUT_DIR]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$REPO/build/conda}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Same recipe, with the git source swapped for this checkout.
mkdir -p "$WORK/dodo"
cp -R "$REPO/packaging/tests" "$WORK/dodo/tests"
sed -e "s|- git: https://github.com/dodo-mojo/dodo.git|- path: $REPO|" \
    -e "/tag: v\${{ version }}/d" \
    "$REPO/packaging/recipe.yaml" > "$WORK/dodo/recipe.yaml"

# The rattler-build version the modular-community channel uses.
pixi exec --spec "rattler-build>=0.30.0,<0.31" -- rattler-build build \
    --channel https://conda.modular.com/max \
    --channel conda-forge \
    --output-dir "$OUTPUT" \
    --recipe "$WORK/dodo/recipe.yaml"

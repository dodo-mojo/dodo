#!/usr/bin/env bash
# Each tests/compile_fail/*.mojo must fail to build with the message in its
# first line (`# expect: <text>`).

set -uo pipefail

failed=0
for file in tests/compile_fail/*.mojo; do
  expected="$(head -1 "$file" | sed 's/^# expect: //')"
  output="$(pixi run mojo build -I . "$file" -o /dev/null 2>&1)"
  status=$?
  if [ "$status" -eq 0 ]; then
    echo "FAIL $file: built, expected an error"
    failed=1
  elif ! printf '%s' "$output" | grep -qF -- "$expected"; then
    echo "FAIL $file: message not found: $expected"
    failed=1
  else
    echo "ok   $file"
  fi
done
exit "$failed"

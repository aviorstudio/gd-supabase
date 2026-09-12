#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
MANIFEST=${TEST_MANIFEST:-"$SCRIPT_DIR/suite_manifest.txt"}
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-60}
LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

if [ ! -s "$MANIFEST" ]; then
    echo "FAIL: missing or empty suite manifest: $MANIFEST" >&2
    exit 1
fi
mapfile -t tests < <(grep -Ev '^[[:space:]]*(#|$)' "$MANIFEST")
if [ "${#tests[@]}" -eq 0 ]; then
    echo "FAIL: suite manifest has no tests" >&2
    exit 1
fi

failures=0
for relative_test in "${tests[@]}"; do
    test_path="$ROOT_DIR/$relative_test"
    case_name=$(basename "$relative_test" .gd)
    echo "Running $relative_test..."
    if ! "$SCRIPT_DIR/run_godot_case.sh" "$test_path" "$case_name" "$TIMEOUT_SECONDS" "$LOG_DIR/$case_name.log"; then
        failures=$((failures + 1))
    fi
done
if [ "$failures" -ne 0 ]; then
    echo "FAIL: $failures Godot test case(s) failed" >&2
    exit 1
fi
echo "TEST_SUITE_REACHED=${#tests[@]}/${#tests[@]}"

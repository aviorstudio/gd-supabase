#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "usage: run_godot_case.sh TEST_PATH CASE_NAME TIMEOUT_SECONDS LOG_PATH" >&2
    exit 2
fi

TEST_PATH=$1
CASE_NAME=$2
TIMEOUT_SECONDS=$3
LOG_PATH=$4
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GODOT=${GODOT_BIN:-godot}
status=0

if [ ! -f "$TEST_PATH" ]; then
    echo "FAIL: missing test script: $TEST_PATH" | tee "$LOG_PATH" >&2
    exit 1
fi

timeout --foreground "${TIMEOUT_SECONDS}s" "$GODOT" --headless --path "$ROOT_DIR" --script "$TEST_PATH" >"$LOG_PATH" 2>&1 || status=$?
cat "$LOG_PATH"
if [ "$status" -ne 0 ]; then
    echo "FAIL: $CASE_NAME exited $status" >&2
    exit 1
fi
if grep -Eq '(^|[[:space:]])(USER ERROR|SCRIPT ERROR|ERROR):' "$LOG_PATH"; then
    echo "FAIL: $CASE_NAME emitted unexpected Godot errors" >&2
    exit 1
fi
sentinel=$(grep -E "^TEST_REACHED:${CASE_NAME}:[1-9][0-9]*$" "$LOG_PATH" || true)
if [ "$(printf '%s\n' "$sentinel" | grep -c . || true)" -ne 1 ]; then
    echo "FAIL: $CASE_NAME did not emit exactly one reachable assertion sentinel" >&2
    exit 1
fi

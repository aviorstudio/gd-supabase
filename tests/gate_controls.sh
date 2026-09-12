#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUN_CASE="$SCRIPT_DIR/run_godot_case.sh"
FIXTURES="$SCRIPT_DIR/gate/fixtures"
LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

expect_failure() {
    local fixture=$1
    local name=$2
    local timeout_seconds=${3:-10}
    if "$RUN_CASE" "$fixture" "$name" "$timeout_seconds" "$LOG_DIR/$name.log"; then
        echo "FAIL: negative gate control unexpectedly passed: $name" >&2
        exit 1
    fi
    echo "CONTROL_FAILED_AS_EXPECTED:$name"
}

expect_failure "$FIXTURES/error_zero.gd" error_zero
expect_failure "$FIXTURES/assertion_overwrite.gd" assertion_overwrite
expect_failure "$FIXTURES/parse_failure.gd" parse_failure
expect_failure "$FIXTURES/hang.gd" hang 1
expect_failure "$FIXTURES/missing.gd" missing

empty_manifest="$LOG_DIR/empty-manifest.txt"
: > "$empty_manifest"
if TEST_MANIFEST="$empty_manifest" "$SCRIPT_DIR/test.sh"; then
    echo "FAIL: missing-language-suite control unexpectedly passed" >&2
    exit 1
fi
echo "CONTROL_FAILED_AS_EXPECTED:missing_suite"

"$RUN_CASE" "$FIXTURES/pass.gd" pass 10 "$LOG_DIR/pass.log"
echo "CONTROL_RESTORED_PASS:pass"

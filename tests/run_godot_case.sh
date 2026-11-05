#!/usr/bin/env bash
set -euo pipefail
[ "$#" -eq 4 ] || { echo 'Expected program, case, timeout and log' >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "${TOOLS_ROOT:?Pinned cookbook required}/helpers/godot-test.py" --project "$root" --program "$1" --timeout "$3" --sentinel-regex "^TEST_REACHED:$2:([1-9][0-9]*)$" 2>&1 | tee "$4"

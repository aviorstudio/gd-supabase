#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: package_controls.sh ARCHIVE" >&2
    exit 2
fi

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ARCHIVE=$(realpath "$1")
FIXTURE="$ROOT_DIR/dist/package-fixture"
ADDON_DIR="$FIXTURE/addons/@aviorstudio_gd-supabase"
GODOT=${GODOT_BIN:-godot}
LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

python3 "$ROOT_DIR/scripts/package_addon.py" verify "$ARCHIVE"
rm -rf "$FIXTURE"
mkdir -p "$ADDON_DIR"
cp "$ROOT_DIR/tests/package_fixture/"{main.gd,main.tscn,export_presets.cfg} "$FIXTURE/"
cp "$ROOT_DIR/tests/package_fixture/project.disabled.godot" "$FIXTURE/project.godot"
unzip -q "$ARCHIVE" -d "$ADDON_DIR"

run_godot() {
    local name=$1
    shift
    local status=0
    timeout --foreground 60s "$GODOT" "$@" >"$LOG_DIR/$name.log" 2>&1 || status=$?
    cat "$LOG_DIR/$name.log"
    if [ "$status" -ne 0 ] || grep -Eq '(^|[[:space:]])(USER ERROR|SCRIPT ERROR|ERROR):' "$LOG_DIR/$name.log"; then
        echo "FAIL: packaged lifecycle step $name" >&2
        exit 1
    fi
}

run_godot editor-disabled --headless --editor --path "$FIXTURE" --quit-after 2
cp "$ROOT_DIR/tests/package_fixture/project.enabled.godot" "$FIXTURE/project.godot"
run_godot editor-enabled --headless --editor --path "$FIXTURE" --quit-after 2
run_godot editor-restarted --headless --editor --path "$FIXTURE" --quit-after 2
run_godot smoke --headless --path "$FIXTURE" --quit-after 3
grep -Fq 'PACKAGE_SMOKE_REACHED:PASS' "$LOG_DIR/smoke.log"

cp "$ROOT_DIR/tests/package_fixture/project.disabled.godot" "$FIXTURE/project.godot"
run_godot editor-disabled-final --headless --editor --path "$FIXTURE" --quit-after 2
run_godot editor-disabled-restarted --headless --editor --path "$FIXTURE" --quit-after 2
grep -Fq 'preserved_marker="consumer-owned"' "$FIXTURE/project.godot"
if grep -Eq '^\[autoload\]|@aviorstudio_gd-supabase' "$FIXTURE/project.godot"; then
    echo "FAIL: addon-owned editor configuration remained after disable" >&2
    exit 1
fi

(cd "$ADDON_DIR" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$ROOT_DIR/dist/installed-tree.files.sha256"
sha256sum "$ROOT_DIR/dist/installed-tree.files.sha256" | cut -d' ' -f1 > "$ROOT_DIR/dist/installed-tree.sha256"
mkdir -p "$ROOT_DIR/dist/web"
run_godot web-export --headless --path "$FIXTURE" --export-release Web "$ROOT_DIR/dist/web/index.html"
test -s "$ROOT_DIR/dist/web/index.html"
echo "PACKAGE_LIFECYCLE_REACHED:enable-restart-smoke-disable-restart"

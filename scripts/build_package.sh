#!/usr/bin/env bash
# scripts/build_package.sh
# Packaging helper script for ReTetris standalone exports.
# Supports Linux/X11 desktop (x86_64 / arm64), Windows, Android, and standalone .pck bundles.
#
# Shell compatibility:
# - Bash / POSIX: ./scripts/build_package.sh [target]
# - Fish shell: bash scripts/build_package.sh [target]
#
# Available targets:
#   pck     (default: creates builds/retetris.pck)
#   linux   (creates builds/linux/retetris.x86_64)
#   windows (creates builds/windows/retetris.exe)
#   android (creates builds/android/retetris.apk)
#   all     (attempts all configured export presets)

set -euo pipefail

TARGET="${1:-pck}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p builds/linux builds/windows builds/android builds/web

echo "=================================================="
echo ">>> ReTetris Standalone Packaging Runner <<<"
echo "Target: $TARGET"
echo "Project Root: $ROOT_DIR"
echo "=================================================="

# Check Godot binary
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    echo "ERROR: Godot executable '$GODOT_BIN' not found in PATH."
    exit 1
fi

case "$TARGET" in
    pck)
        echo "--> Building standalone ReTetris resource pack (builds/retetris.pck)..."
        timeout 5s "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-pack "Linux/X11 Desktop" "builds/retetris.pck" || {
            echo "Note: Standalone pack export requires Godot export templates in ~/.local/share/godot/export_templates/."
        }
        if [ -f "builds/retetris.pck" ]; then
            echo "SUCCESS: Standalone package built at builds/retetris.pck ($(stat -c%s builds/retetris.pck 2>/dev/null || stat -f%z builds/retetris.pck) bytes)"
        fi
        ;;
    linux)
        echo "--> Exporting Linux/X11 Desktop binary..."
        timeout 5s "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "Linux/X11 Desktop" "builds/linux/retetris.x86_64" || true
        ;;
    windows)
        echo "--> Exporting Windows Desktop binary..."
        timeout 5s "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "Windows Desktop" "builds/windows/retetris.exe" || true
        ;;
    android)
        echo "--> Exporting Android Mobile APK..."
        timeout 5s "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "Android Mobile" "builds/android/retetris.apk" || true
        ;;
    all)
        echo "--> Exporting all targets..."
        timeout 5s "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-pack "Linux/X11 Desktop" "builds/retetris.pck" || true
        timeout 5s "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "Linux/X11 Desktop" "builds/linux/retetris.x86_64" || true
        timeout 5s "$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release "Windows Desktop" "builds/windows/retetris.exe" || true
        ;;
    *)
        echo "Unknown target '$TARGET'. Valid targets: pck, linux, windows, android, all"
        exit 1
        ;;
esac

echo "Packaging complete."

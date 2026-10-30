#!/bin/bash
# Builds "HA Tray.app" into build/ and ad-hoc signs it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="build/HA Tray.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/HATray" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;
codesign --force --deep -s - "$APP"
echo "Built $APP"

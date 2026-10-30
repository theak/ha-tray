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
# A stable local identity keeps Keychain "Always Allow" valid across rebuilds;
# fall back to ad-hoc signing when it isn't installed.
IDENTITY="HA Tray Local"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --deep -s "$IDENTITY" "$APP"
else
    echo "warning: '$IDENTITY' signing identity not found; signing ad-hoc" >&2
    codesign --force --deep -s - "$APP"
fi
echo "Built $APP"

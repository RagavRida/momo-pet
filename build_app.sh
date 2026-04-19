#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "→ Building release binary"
swift build -c release

APP="MomoPet.app"
echo "→ Bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp .build/release/MomoPet "$APP/Contents/MacOS/MomoPet"
cp Info.plist "$APP/Contents/Info.plist"

echo "→ Ad-hoc signing"
codesign --force --deep --sign - "$APP"

echo "→ Done. Open with:"
echo "    open $PWD/$APP"

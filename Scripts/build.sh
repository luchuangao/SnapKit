#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
./Scripts/build-icons.sh
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app="$PWD/dist/SnapKit.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/SnapKit" "$app/Contents/MacOS/SnapKit"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$app/Contents/Resources/"; fi
cp Resources/AppIcon.png "$app/Contents/Resources/"
codesign --force --deep --sign - "$app"
touch "$app"
echo "$app"

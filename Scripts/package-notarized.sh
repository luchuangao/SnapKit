#!/bin/bash
# Preserve the Developer ID signature and stapled ticket while creating downloads.
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:?Usage: Scripts/package-notarized.sh /path/to/notarized/SnapKit.app}"
app="$(cd "$app" && pwd)"
codesign --verify --deep --strict "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
if [ "$app" != "$PWD/dist/SnapKit.app" ]; then ditto "$app" "$PWD/dist/SnapKit.app"; fi
./Scripts/package.sh --skip-build
echo "The DMG and ZIP contain the notarized app and its stapled ticket."

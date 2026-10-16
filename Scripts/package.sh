#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != "--skip-build" ]; then ./Scripts/build.sh; fi
app="$PWD/dist/SnapKit.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
artifact="SnapKit-${version}-macOS-arm64"
source="SnapKit-${version}-source"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/${artifact}.zip"
staging="$(mktemp -d "$PWD/.build/dmg.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/SnapKit.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "SnapKit ${version}" -srcfolder "$staging" -ov -format UDZO "dist/${artifact}.dmg"
zip -q -r "$staging/source.zip" Package.swift README.md README.zh-CN.md .gitignore Sources Tests Scripts Resources Research Branding/Final Docs .github -x 'Research/official-*.png'
mv "$staging/source.zip" "dist/${source}.zip"
shasum -a 256 "dist/${artifact}.dmg" "dist/${artifact}.zip" "dist/${source}.zip" > "dist/SHA256SUMS-${version}.txt"

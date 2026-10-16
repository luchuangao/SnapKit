#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:-$PWD/Docs/Screenshots}"
mkdir -p "$output"
# Quit other SnapKit instances before running this command.
for language in zh-Hans en; do
  for scene in commands general appearance; do
    dist/SnapKit.app/Contents/MacOS/SnapKit --language "$language" --capture-scene "$scene" --capture-directory "$output"
  done
done

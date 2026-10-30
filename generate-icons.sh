#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p build/module-cache
xcrun swiftc -module-cache-path "$PWD/build/module-cache" -framework AppKit Tools/GenerateIcon.swift -o build/generate-icon
build/generate-icon "$PWD"
iconutil -c icns build/AppIcon.iconset -o Assets/AppIcon.icns

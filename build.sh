#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
app='build/Link Router.app'
resources="$app/Contents/Resources"
mkdir -p build/module-cache "$app/Contents/MacOS" "$resources"
arch_name=$(uname -m)
target="${arch_name}-apple-macos13.0"
swift_flags=(-target "$target" -module-cache-path "$PWD/build/module-cache" -framework AppKit -framework Carbon)
xcrun swiftc "${swift_flags[@]}" Sources/Routing.swift Tests/main.swift -o build/routing-tests
build/routing-tests
if [ ! -s Assets/AppIcon.icns ] || [ ! -s Assets/MenuBarIcon.pdf ]; then
    bash generate-icons.sh
fi
xcrun swiftc "${swift_flags[@]}" -framework ServiceManagement -O Sources/Routing.swift Sources/main.swift -o "$app/Contents/MacOS/LinkRouter"
xcrun swiftc "${swift_flags[@]}" Tools/AppControl.swift -o build/app-control
cp Info.plist "$app/Contents/Info.plist"
cp Assets/AppIcon.icns Assets/MenuBarIcon.pdf "$resources/"
source_dir="$resources/Source"
mkdir -p "$source_dir"
for folder in Sources Tests Tools Assets; do
    ditto "$folder" "$source_dir/$folder"
done
cp Info.plist README.md build.sh install.sh generate-icons.sh prepare-integration.sh .gitignore "$source_dir/"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf '%s\n' "Built: $PWD/$app"

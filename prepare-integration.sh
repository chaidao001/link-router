#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
test_app='build/Router Test Sender.app'
mkdir -p "$test_app/Contents/MacOS"
xcrun swiftc -parse-as-library -module-cache-path "$PWD/build/module-cache" -framework AppKit Tests/IntegrationSender.swift -o "$test_app/Contents/MacOS/RouterTestSender"
python3 - <<'PY'
import plistlib
from pathlib import Path
path = Path('build/Router Test Sender.app/Contents/Info.plist')
path.write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'local.linkrouter.test-sender',
    'CFBundleName': 'Router Test Sender',
    'CFBundleExecutable': 'RouterTestSender',
    'CFBundlePackageType': 'APPL',
    'LSUIElement': True,
}))
PY
codesign --force --sign - "$test_app"

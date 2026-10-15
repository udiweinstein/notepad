#!/bin/bash
# Builds Notepad.app. Requires Xcode or the Command Line Tools (xcode-select --install).
#   ./build.sh            build into build/Notepad.app
#   ./build.sh --install  also copy it to /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Notepad.app"
MIN_OS="12.0"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

compile() {  # $1 = arch
  swiftc -O -swift-version 5 -module-name Notepad \
    -target "$1-apple-macos$MIN_OS" \
    Sources/*.swift -o "build/Notepad-$1"
}

echo "▸ Compiling…"
if compile arm64 && compile x86_64; then
  lipo -create -output "$APP/Contents/MacOS/Notepad" build/Notepad-arm64 build/Notepad-x86_64
else
  echo "  (universal build failed – building for this Mac only)"
  ARCH="$(uname -m)"
  compile "$ARCH"
  cp "build/Notepad-$ARCH" "$APP/Contents/MacOS/Notepad"
fi
rm -f build/Notepad-*

cp Info.plist "$APP/Contents/Info.plist"

echo "▸ Drawing icon…"
if swift Tools/make_icon.swift build/AppIcon.iconset >/dev/null 2>&1 \
   && iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"; then
  rm -rf build/AppIcon.iconset
else
  echo "  (icon skipped)"
fi

echo "▸ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/Notepad.app"
  cp -R "$APP" /Applications/
  echo "✓ Installed to /Applications/Notepad.app"
else
  echo "✓ Built $APP"
fi

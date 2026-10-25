#!/bin/bash
# Собирает dist/DisplayToggle.app (universal: arm64 + x86_64), подписывает ad-hoc.
# Параметр — версия (default 1.1.0). --install — ещё и поставить в ~/Applications.
# SIGN_IDENTITY="Developer ID Application" — подписать сертификатом с hardened runtime
# (нужно для нотаризации); без переменной — ad-hoc подпись.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-1.1.0}"
INSTALL=0
[ "${2:-}" = "--install" ] && INSTALL=1

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/DisplayToggle"

APP="dist/DisplayToggle.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DisplayToggle"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.arturruz.DisplayToggle</string>
  <key>CFBundleName</key><string>DisplayToggle</string>
  <key>CFBundleDisplayName</key><string>DisplayToggle</string>
  <key>CFBundleExecutable</key><string>DisplayToggle</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>GPL-3.0</string>
</dict></plist>
PLIST

if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"
lipo -info "$APP/Contents/MacOS/DisplayToggle"
echo "OK: $APP ($VERSION)"

if [ "$INSTALL" -eq 1 ]; then
    mkdir -p ~/Applications
    pkill -x DisplayToggle 2>/dev/null || true
    rm -rf ~/Applications/DisplayToggle.app
    cp -R "$APP" ~/Applications/
    open ~/Applications/DisplayToggle.app
    echo "OK: установлено в ~/Applications и запущено"
fi

#!/bin/bash
# Собирает dist/DisplayToggle-<version>.dmg из готового dist/DisplayToggle.app:
# приложение + ярлык на /Applications + иконка тома. Параметр — версия.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-1.1.0}"
APP_SRC="dist/DisplayToggle.app"
ICNS="assets/AppIcon.icns"
DMG="dist/DisplayToggle-${VERSION}.dmg"
RW_DMG="$(mktemp -u /tmp/displaytoggle_rw.XXXXXX).dmg"
# FinderInfo с флагом kHasCustomIcon (0x0400 в байтах 8-9) — иконка тома без SetFile.
CUSTOM_ICON_FINDERINFO="0000000000000000040000000000000000000000000000000000000000000000"

STAGE=""
MOUNT=""
cleanup() {
    [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
    rm -f "$RW_DMG" 2>/dev/null || true
    [ -n "$STAGE" ] && rm -rf "$STAGE" 2>/dev/null || true
}
trap cleanup EXIT

if [ ! -d "$APP_SRC" ]; then
    echo "Не найден $APP_SRC — сначала: scripts/build_app.sh $VERSION" >&2
    exit 1
fi

STAGE=$(mktemp -d)
cp -R "$APP_SRC" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ICNS" "$STAGE/.VolumeIcon.icns"

hdiutil create -volname DisplayToggle -srcfolder "$STAGE" -ov -format UDRW "$RW_DMG"
# Поля вывода hdiutil attach разделены табами — имя тома может содержать пробел.
MOUNT=$(hdiutil attach -nobrowse "$RW_DMG" | awk -F'\t' '/\/Volumes\//{print $3}')
if [ -z "$MOUNT" ]; then
    echo "ОШИБКА: не удалось смонтировать rw-образ" >&2
    exit 1
fi
xattr -wx com.apple.FinderInfo "$CUSTOM_ICON_FINDERINFO" "$MOUNT"
hdiutil detach "$MOUNT"
MOUNT=""

mkdir -p dist
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG" -ov
hdiutil verify "$DMG"

# Иконка самого файла .dmg (видна до монтирования) — если есть fileicon (brew install fileicon).
if command -v fileicon >/dev/null 2>&1; then
    fileicon set "$DMG" "$ICNS"
else
    echo "fileicon не найден — у файла .dmg будет стандартная иконка" >&2
fi

echo "OK: $DMG"

#!/bin/bash
# Отправляет подписанный .dmg на нотаризацию в Apple, ждёт ответа и «пришивает» тикет.
# Параметр — путь к .dmg. Учётные данные — один из вариантов:
#   NOTARY_PROFILE=<имя>   — профиль из `xcrun notarytool store-credentials` (локально)
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD — Apple ID + пароль приложения (CI)
set -euo pipefail

DMG="${1:?Использование: scripts/notarize.sh dist/DisplayToggle-X.Y.Z.dmg}"

if [ -n "${NOTARY_PROFILE:-}" ]; then
    AUTH=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
    AUTH=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
else
    echo "Нет учётных данных: задай NOTARY_PROFILE или APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD" >&2
    exit 1
fi

RESULT=$(xcrun notarytool submit "$DMG" "${AUTH[@]}" --wait --output-format json)
echo "$RESULT"
ID=$(echo "$RESULT" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
STATUS=$(echo "$RESULT" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')

if [ "$STATUS" != "Accepted" ]; then
    echo "ОШИБКА: нотаризация не пройдена ($STATUS). Лог Apple:" >&2
    xcrun notarytool log "$ID" "${AUTH[@]}" >&2 || true
    exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
echo "OK: $DMG нотаризован"

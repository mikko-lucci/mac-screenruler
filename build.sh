#!/bin/bash
# Builds build/ScreenRuler.app.  Usage: ./build.sh [install]
#   SIGN_ID="Apple Development: ..." ./build.sh   – sign with a specific identity
# By default signs with "ScreenRuler Local Signing" (Scripts/create-signing-cert.sh)
# so the Screen Recording permission survives rebuilds; falls back to ad-hoc.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/ScreenRuler"

APP=build/ScreenRuler.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ScreenRuler"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f Resources/AppIcon.icns ]; then
    TMP=$(mktemp -d)
    swift Scripts/make-icon.swift "$TMP/icon.png"
    mkdir "$TMP/AppIcon.iconset"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
        sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
    rm -rf "$TMP"
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -z "${SIGN_ID:-}" ]; then
    if security find-certificate -c "ScreenRuler Local Signing" >/dev/null 2>&1; then
        SIGN_ID="ScreenRuler Local Signing"
    else
        SIGN_ID="-"
        echo "Varoitus: ad hoc -allekirjoitus, näytön tallennuslupa nollautuu jokaisen käännöksen jälkeen."
        echo "Aja Scripts/create-signing-cert.sh kerran, niin lupa säilyy."
    fi
fi
codesign --force --sign "$SIGN_ID" "$APP"
echo "Valmis: $APP"

if [ "${1:-}" = "install" ]; then
    pkill -x ScreenRuler || true
    rm -rf /Applications/ScreenRuler.app
    cp -R "$APP" /Applications/
    echo "Asennettu: /Applications/ScreenRuler.app"
    open /Applications/ScreenRuler.app
fi

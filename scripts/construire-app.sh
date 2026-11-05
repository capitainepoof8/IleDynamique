#!/bin/zsh
# Compile le paquet Swift (binaire universel Apple Silicon + Intel)
# et l'emballe dans build/IleDynamique.app (signature ad hoc).
# Usage : ./scripts/construire-app.sh [release|debug]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION=${1:-release}
APP=build/IleDynamique.app

ARCHITECTURES=(--arch arm64 --arch x86_64)
swift build -c "$CONFIGURATION" "${ARCHITECTURES[@]}"
BINAIRE="$(swift build -c "$CONFIGURATION" "${ARCHITECTURES[@]}" --show-bin-path)/IleDynamique"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINAIRE" "$APP/Contents/MacOS/IleDynamique"
cp Resources/Info.plist "$APP/Contents/Info.plist"
./scripts/construire-aide-lecture.sh "$APP/Contents/Resources/aide-lecture.dylib"
# Retire les attributs étendus qui peuvent invalider la signature.
xattr -cr "$APP"

codesign --force --options runtime \
  --entitlements Resources/IleDynamique.entitlements \
  --sign - "$APP"

echo "✅ Application prête : $APP"
echo "   Lancer : open $APP"

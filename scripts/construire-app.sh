#!/bin/zsh
# Compile le paquet Swift et l'emballe dans build/IleDynamique.app (signature ad hoc).
# Usage : ./scripts/construire-app.sh [release|debug]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION=${1:-release}
APP=build/IleDynamique.app

swift build -c "$CONFIGURATION"
BINAIRE="$(swift build -c "$CONFIGURATION" --show-bin-path)/IleDynamique"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINAIRE" "$APP/Contents/MacOS/IleDynamique"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Retire les attributs étendus qui peuvent invalider la signature.
xattr -cr "$APP"

codesign --force --options runtime \
  --entitlements Resources/IleDynamique.entitlements \
  --sign - "$APP"

echo "✅ Application prête : $APP"
echo "   Lancer : open $APP"

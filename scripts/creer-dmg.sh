#!/bin/zsh
# Crée build/IleDynamique.dmg : une fenêtre avec l'app et un raccourci vers Applications.
# Usage : ./scripts/creer-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/construire-app.sh release

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG=build/IleDynamique-$VERSION.dmg
DOSSIER=build/dmg

rm -rf "$DOSSIER" "$DMG"
mkdir -p "$DOSSIER"
ditto build/IleDynamique.app "$DOSSIER/IleDynamique.app"
ln -s /Applications "$DOSSIER/Applications"

hdiutil create -volname "Île Dynamique" -srcfolder "$DOSSIER" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DOSSIER"

# Archive zip en complément (ditto conserve la signature).
ditto -c -k --keepParent build/IleDynamique.app "build/IleDynamique-$VERSION.zip"

echo "✅ $DMG"
echo "✅ build/IleDynamique-$VERSION.zip"

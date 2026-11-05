#!/bin/zsh
# Compile l'aide de lecture (bibliothèque universelle, signature ad hoc).
# Usage : ./scripts/construire-aide-lecture.sh <chemin de sortie du .dylib>
set -euo pipefail
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
SORTIE=$1

mkdir -p "$(dirname "$SORTIE")"
clang -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 -O2 -fobjc-arc \
  -dynamiclib -fvisibility=hidden -framework Foundation \
  "$RACINE/Sources/AideLecture/aide-lecture.m" -o "$SORTIE"
codesign --force --sign - "$SORTIE"

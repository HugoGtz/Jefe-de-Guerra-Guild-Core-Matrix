#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(sed -n 's/^## Version: //p' "$ROOT/GuildCoreMatrix.toc" | head -1 | tr -d '\r')"
if [[ -z "$VERSION" ]]; then
  echo "ERROR: Could not read ## Version from GuildCoreMatrix.toc" >&2
  exit 1
fi

OUT="$ROOT/dist"
PKG="$OUT/GuildCoreMatrix"
ZIP="$OUT/GuildCoreMatrix-${VERSION}.zip"

rm -rf "$PKG"
mkdir -p "$PKG/Modules" "$PKG/Locales"

rsync -a "$ROOT/GuildCoreMatrix.toc" "$ROOT/Core.lua" "$PKG/"
rsync -a "$ROOT/Modules/" "$PKG/Modules/"
rsync -a "$ROOT/Locales/" "$PKG/Locales/"

if [[ -d "$ROOT/Media" ]]; then
  mkdir -p "$PKG/Media"
  rsync -a "$ROOT/Media/" "$PKG/Media/"
fi

rm -f "$ZIP"
(
  cd "$OUT"
  zip -rq "GuildCoreMatrix-${VERSION}.zip" GuildCoreMatrix
)

echo "Built $ZIP"

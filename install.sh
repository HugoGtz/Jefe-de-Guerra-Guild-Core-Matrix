#!/bin/bash

set -euo pipefail

ADDON_NAME="GuildCoreMatrix"
SOURCE_PATH="$(cd "$(dirname "$0")" && pwd)/"

if [[ -n "${GCM_WOW_ROOT:-}" ]]; then
    WOW_ROOT="$GCM_WOW_ROOT"
elif [[ -d "/Volumes/os/World of Warcraft/_anniversary_" ]]; then
    WOW_ROOT="/Volumes/os/World of Warcraft/_anniversary_"
elif [[ -d "/Volumes/so/World of Warcraft/_anniversary_" ]]; then
    WOW_ROOT="/Volumes/so/World of Warcraft/_anniversary_"
elif [[ -d "/Volumes/:/World of Warcraft/_anniversary_" ]]; then
    WOW_ROOT="/Volumes/:/World of Warcraft/_anniversary_"
else
    echo "ERROR: No WoW _anniversary_ folder found. Set GCM_WOW_ROOT to the directory that contains Interface and WTF."
    echo "Example: export GCM_WOW_ROOT='/Volumes/os/World of Warcraft/_anniversary_' && bash install.sh"
    exit 1
fi

DEST_PATH="${WOW_ROOT}/Interface/AddOns/${ADDON_NAME}"

if [[ ! -d "${WOW_ROOT}/Interface" ]]; then
    echo "ERROR: Missing ${WOW_ROOT}/Interface"
    exit 1
fi

last="$(basename "$DEST_PATH")"
if [[ "$last" != "$ADDON_NAME" ]]; then
    echo "ERROR: DEST_PATH must end with ${ADDON_NAME}, got: $DEST_PATH"
    exit 1
fi

echo "Installing GuildCoreMatrix to $DEST_PATH"
mkdir -p "$DEST_PATH"

rsync -av --delete \
    --exclude ".git/" \
    --exclude ".gemini/" \
    --exclude ".cursor/" \
    --exclude "AGENTS.md" \
    --exclude "install.sh" \
    "$SOURCE_PATH" "$DEST_PATH"

echo "Done. /reload in-game."

#!/usr/bin/env bash
set -euo pipefail

# Your prefix and game directory
export WINEPREFIX="$HOME/Games/pfx/ascension-pfx"
GAME_EXE="$HOME/Games/ascension_live/Ascension.exe"

# Pin system wine explicitly (avoid GE runners)
WINE_BIN="/usr/bin/wine"
WINESERVER="/usr/bin/wineserver"

# Sanity checks
[[ -x "$WINE_BIN" ]] || { echo "Wine not found at $WINE_BIN"; exit 1; }
[[ -f "$GAME_EXE" ]] || { echo "Ascension.exe not found at $GAME_EXE"; exit 1; }

# Kill any stray wineservers from other builds
"$WINESERVER" -k || true

# Optional: uncomment for Vulkan overlay during testing
# export DXVK_HUD=1

# Launch from the game folder so it finds Data/
cd "$(dirname "$GAME_EXE")"
exec "$WINE_BIN" "$GAME_EXE"


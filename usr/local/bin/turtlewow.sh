#!/usr/bin/env bash
set -euo pipefail

# Your paths (exactly as requested)
export WINEPREFIX="/home/zrgst/Games/pfx/turtlewow-pfx/"
GAME_DIR="/home/zrgst/Games/turtlewow/drive_c/Program Files (x86)/TurtleWoW/"
GAME_EXE="${GAME_DIR}/WoW.exe"   # Turtle-WoW is 32-bit; use Wow.exe, not Wow-64.exe

# Pin system wine; avoid Lutris GE runners entirely
WINE_BIN="/usr/bin/wine"
WINESERVER="/usr/bin/wineserver"

# Sanity checks
[[ -x "$WINE_BIN" ]] || { echo "Wine not found at $WINE_BIN"; exit 1; }
[[ -f "$GAME_EXE" ]] || { echo "Wow.exe not found at: $GAME_EXE"; exit 1; }

# Kill any stray wineserver from a different Wine build
"$WINESERVER" -k || true

# Optional: show DXVK HUD once to verify Vulkan path, then comment it out
export DXVK_HUD=1

# If Turtle HD patch hates async, comment these back off later
export WINEESYNC=1
export WINEFSYNC=1

# If the “memory bridge” style issues appear, this can help:
export STAGING_SHARED_MEMORY=1

# Run from the game folder so it finds Data/
cd "$GAME_DIR"
exec "$WINE_BIN" "$GAME_EXE"


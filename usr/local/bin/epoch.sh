#!/usr/bin/env bash
set -euo pipefail

# Your exact paths
export WINEPREFIX="$HOME/Games/pfx/epoch-pfx64"
GAME_EXE="$HOME/Games/project_epoch/Ascension.exe"

# Pin GE 8-26 (don’t use /usr/bin/wine here)
GE="$HOME/.local/share/lutris/runners/wine/wine-ge-8-26-x86_64"
WINE_BIN="$GE/bin/wine"
WINESERVER="$GE/bin/wineserver"

# Sanity
[[ -x "$WINE_BIN" ]] || { echo "Missing GE wine: $WINE_BIN"; exit 1; }
[[ -f "$GAME_EXE" ]] || { echo "Ascension.exe not found: $GAME_EXE"; exit 1; }

# Make sure only this wineserver is alive
"$WINESERVER" -k || true

# One-time: install DXVK into this prefix if not already there
if [[ ! -f "$WINEPREFIX/drive_c/windows/system32/d3d9.dll" ]]; then
  command -v winetricks >/dev/null && \
    WINEPREFIX="$WINEPREFIX" winetricks -q dxvk || true
fi

# Performance toggles that usually HELP Ascension on GE
export WINEESYNC=1
export WINEFSYNC=1
# Helps those custom “memory bridge” shenanigans behave:
export STAGING_SHARED_MEMORY=1

# First runs: prove DXVK/Vulkan is used; then comment this out
# export DXVK_HUD=1

# Force DX9 path so DXVK hooks, not OpenGL fallback
CFG_DIR="$(dirname "$GAME_EXE")/WTF"
mkdir -p "$CFG_DIR"
grep -q 'SET gxApi "d3d9"' "$CFG_DIR/Config.wtf" 2>/dev/null || \
  printf '%s\n' 'SET gxApi "d3d9"' 'SET gxWindow "1"' >> "$CFG_DIR/Config.wtf"

# Go to game dir so it finds Data/
cd "$(dirname "$GAME_EXE")"
exec "$WINE_BIN" "$GAME_EXE"

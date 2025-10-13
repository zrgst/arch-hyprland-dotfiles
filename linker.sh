#!/usr/bin/env bash
set -euo pipefail
REPO="${REPO:-$HOME/dotfiles}"
MANIFEST="${MANIFEST:-$REPO/.manifest}" # optional file with relative paths
APPLY="${APPLY:-0}"

map_path() {
  rel="$1"
  case "$rel" in
  config/*) printf "%s/.config/%s\n" "$HOME" "${rel#config/}" ;;
  local/*) printf "%s/.local/%s\n" "$HOME" "${rel#local/}" ;;
  usr/local/*) printf "/%s\n" "$rel" ;;
  home/*) printf "%s/%s\n" "$HOME" "${rel#home/}" ;;
  *) printf "%s/.%s\n" "$HOME" "$rel" ;; # e.g. zshrc -> ~/.zshrc
  esac
}

list_files() {
  if [[ -f "$MANIFEST" ]]; then
    sed '/^\s*#/d;/^\s*$/d' "$MANIFEST"
  else
    find "$REPO" -type f -printf '%P\n'
  fi
}

cd "$REPO"

# Preview
while IFS= read -r rel; do
  src="$REPO/$rel"
  dst="$(map_path "$rel")"
  printf "LINK  %s -> %s\n" "$dst" "$src"
done < <(list_files)

# Apply
if [[ "$APPLY" == 1 ]]; then
  while IFS= read -r rel; do
    src="$REPO/$rel"
    dst="$(map_path "$rel")"
    need_sudo=0
    [[ "$dst" == /usr/* ]] && need_sudo=1
    ((need_sudo)) && pre=sudo || pre=

    $pre install -d "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      ts=$(date +%Y%m%d%H%M%S)
      $pre mv -v "$dst" "${dst}.bak.$ts"
    fi
    $pre rm -f "$dst"
    $pre ln -s "$src" "$dst"
  done < <(list_files)
fi

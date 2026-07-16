#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- package manifest -> portage set ---
sudo mkdir -p /etc/portage/sets
sudo ln -sfn "$REPO/desktop" /etc/portage/sets/desktop

# --- packages (noreplace = ставит только недостающее) ---
sudo emerge --noreplace --verbose @desktop

# --- config symlinks: "путь_в_репе:куда" ---
LINKS=(
    # "vim/.vimrc:$HOME/.vimrc"
)

for pair in "${LINKS[@]}"; do
    src="$REPO/${pair%%:*}"
    dst="${pair##*:}"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    echo "link: $dst -> $src"
done

echo "done."

#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- package manifest -> portage set ---
sudo mkdir -p /etc/portage/sets
sudo ln -sfn "$REPO/desktop" /etc/portage/sets/desktop

# --- declared USE flags -> portage config ---
sudo mkdir -p /etc/portage/package.use
sudo ln -sfn "$REPO/package.use/doom" /etc/portage/package.use/doom

# --- declared keywords -> portage config ---
sudo mkdir -p /etc/portage/package.accept_keywords
sudo ln -sfn "$REPO/package.accept_keywords/doom" /etc/portage/package.accept_keywords/doom

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

# --- assets portage cannot ship (never fatal) ---
"$REPO/assets.sh"

echo "done."

#!/bin/bash
set -euo pipefail

SENTINEL="$HOME/.config/mactahoe/.firefox-done"
WALLPAPER_SENTINEL="$HOME/.config/mactahoe/.wallpaper-done"

# Apply the day/night wallpaper pair once per user.
if [[ ! -f "$WALLPAPER_SENTINEL" ]]; then
    gsettings set org.gnome.desktop.background picture-uri \
        'file:///usr/share/backgrounds/MacTahoe/MacTahoe-day.jpeg'
    gsettings set org.gnome.desktop.background picture-uri-dark \
        'file:///usr/share/backgrounds/MacTahoe/MacTahoe-night.jpeg'
    gsettings set org.gnome.desktop.background picture-options 'zoom'

    mkdir -p "$(dirname "$WALLPAPER_SENTINEL")"
    touch "$WALLPAPER_SENTINEL"
fi

[[ -f "$SENTINEL" ]] && exit 0

REPO_DIR="/usr/share/MacTahoe-gtk-theme"

# Require at least one Firefox profile to exist before applying.
# If Firefox hasn't been opened yet this session, exit and retry on next login.
if ! compgen -G "${HOME}/.mozilla/firefox/*.default*" > /dev/null 2>&1; then
    exit 0
fi

cd "$REPO_DIR"
./tweaks.sh -f

mkdir -p "$(dirname "$SENTINEL")"
touch "$SENTINEL"

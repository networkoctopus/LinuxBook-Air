#!/bin/bash
SENTINEL="$HOME/.config/toshy/.image-setup-done"
[[ -f "$SENTINEL" ]] && exit 0
[[ -f "$HOME/.config/toshy/toshy_config.py" ]] && exit 0

SETUP_SCRIPT="/usr/libexec/toshy-first-login-setup.sh"

if command -v ptyxis &>/dev/null; then
    ptyxis -- bash "$SETUP_SCRIPT"
elif command -v kgx &>/dev/null; then
    kgx -- bash "$SETUP_SCRIPT"
elif command -v xterm &>/dev/null; then
    xterm -title "Toshy Setup" -e bash "$SETUP_SCRIPT"
else
    gnome-terminal \
        --app-id org.gnome.Terminal.ToshySetup \
        --title "Toshy First-Time Setup" \
        -- bash "$SETUP_SCRIPT"
fi
#!/bin/bash

set -uo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linuxbook-air"
LOGIN_SEEN="$STATE_DIR/initial-setup-first-login-seen"
DONE_FILE="$STATE_DIR/initial-setup-done"
SKIP_FILE="$STATE_DIR/initial-setup-skipped"
GNOME_SETUP_DONE="${XDG_CONFIG_HOME:-$HOME/.config}/gnome-initial-setup-done"
SETUP_SCRIPT="/usr/libexec/linuxbook-air-post-deploy-setup.sh"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/linuxbook-air/initial-setup.log"

mkdir -p "$STATE_DIR"

[[ -f "$DONE_FILE" || -f "$SKIP_FILE" ]] && exit 0

# A newly-created user has not completed GNOME Initial Setup yet, so silently
# consume that session. Existing users already have GNOME's completion marker
# and should see this dialog on their first login after receiving the image.
if [[ ! -f "$LOGIN_SEEN" && ! -f "$GNOME_SETUP_DONE" ]]; then
    touch "$LOGIN_SEEN"
    exit 0
fi

CHOICE=$(zenity --list \
    --title="LinuxBook-Air Setup" \
    --window-icon="preferences-system" \
    --text="<big><b>Welcome to LinuxBook-Air</b></big>\n\nFinish setting up your Mac-style keyboard shortcuts and restore the standard GNOME applications.\n\nKeyboard remapping is powered by <b>Toshy</b>, created by RedBearAK:\nhttps://github.com/RedBearAK/Toshy" \
    --radiolist \
    --column="" --column="Choose what to do" \
    TRUE "Complete LinuxBook-Air setup now" \
    FALSE "Remind me at my next login" \
    FALSE "Skip this setup permanently" \
    --ok-label="Continue" \
    --cancel-label="Not now" \
    --width=620 --height=360 2>/dev/null) || exit 0

case "$CHOICE" in
    "Remind me at my next login"|"")
        exit 0
        ;;
    "Skip this setup permanently")
        if zenity --question \
            --title="LinuxBook-Air Setup" \
            --window-icon="preferences-system" \
            --text="This will stop checking for Toshy and the default applications on future logins." \
            --ok-label="Skip permanently" --cancel-label="Go back" 2>/dev/null; then
            touch "$SKIP_FILE"
        fi
        exit 0
        ;;
esac

bash "$SETUP_SCRIPT" 2>&1 | zenity --progress \
    --title="LinuxBook-Air Setup" \
    --window-icon="preferences-system" \
    --text="Starting setup…" \
    --percentage=0 \
    --no-cancel \
    --auto-close \
    --width=520 2>/dev/null
SETUP_STATUS=${PIPESTATUS[0]}

if [[ $SETUP_STATUS -eq 0 ]]; then
    zenity --info \
        --title="LinuxBook-Air Setup Complete" \
        --window-icon="preferences-system" \
        --text="Toshy and the default GNOME applications are installed." 2>/dev/null
else
    zenity --error \
        --title="LinuxBook-Air Setup Incomplete" \
        --window-icon="preferences-system" \
        --text="Setup could not finish. It will be offered again next login.\n\nDetails: $LOG_FILE" 2>/dev/null
fi

exit "$SETUP_STATUS"

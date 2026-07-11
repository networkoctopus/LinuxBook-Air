#!/bin/bash
# Install the per-user components selected by the image setup launcher.
# Detailed command output is kept out of the GUI and written to LOG_FILE.

set -uo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linuxbook-air"
DONE_FILE="$STATE_DIR/initial-setup-done"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/linuxbook-air"
LOG_FILE="$LOG_DIR/initial-setup.log"

FLATPAKS=(
    org.gnome.Calculator
    org.gnome.Calendar
    org.gnome.Characters
    org.gnome.Connections
    org.gnome.Contacts
    org.gnome.Evolution
    org.gnome.Extensions
    org.gnome.Firmware
    org.gnome.Logs
    org.gnome.Loupe
    org.gnome.Maps
    org.gnome.NautilusPreviewer
    org.gnome.Papers
    org.gnome.Snapshot
    org.gnome.TextEditor
    org.gnome.Weather
    org.gnome.baobab
    org.gnome.clocks
    org.gnome.font-viewer
)

mkdir -p "$STATE_DIR" "$LOG_DIR"
: > "$LOG_FILE"

progress() {
    printf '%s\n' "$1"
    printf '# %s\n' "$2"
}

fail() {
    printf 'ERROR: %s\n' "$1" >> "$LOG_FILE"
    progress 100 "$1"
    exit 1
}

progress 5 "Checking internet access…"
if ! curl --connect-timeout 8 --max-time 15 --silent --show-error --fail \
    --head https://github.com/ >> "$LOG_FILE" 2>&1; then
    fail "No internet connection. Setup will be offered again next login."
fi

if [[ ! -f "$HOME/.config/toshy/toshy_config.py" ]]; then
    progress 15 "Downloading Toshy…"
    TOSHY_TMP=$(mktemp -d)
    trap 'rm -rf "$TOSHY_TMP"' EXIT

    if ! git clone --quiet --depth=1 https://github.com/RedBearAK/Toshy.git \
        "$TOSHY_TMP/toshy" >> "$LOG_FILE" 2>&1; then
        fail "Toshy could not be downloaded. Setup will retry next login."
    fi

    progress 35 "Installing Toshy keyboard shortcuts…"
    cd "$TOSHY_TMP/toshy" || fail "Could not open the Toshy installer directory."

    # Toshy's prompts used here expect the affirmative/default response. Keep its
    # verbose build output in the log rather than displaying a terminal window.
    yes "y" | SESSION_TYPE=wayland python3 ./setup_toshy.py install \
        --override-distro silverblue \
        --skip-native >> "$LOG_FILE" 2>&1
    TOSHY_STATUS=${PIPESTATUS[1]}
    [[ $TOSHY_STATUS -eq 0 ]] || \
        fail "Toshy installation failed. See $LOG_FILE"
else
    progress 55 "Toshy is already installed."
fi

progress 65 "Checking the default applications…"
mapfile -t INSTALLED_APPS < <(flatpak list --app --columns=application 2>> "$LOG_FILE")
MISSING_APPS=()
for app in "${FLATPAKS[@]}"; do
    if ! printf '%s\n' "${INSTALLED_APPS[@]}" | grep -Fxq "$app"; then
        MISSING_APPS+=("$app")
    fi
done

if (( ${#MISSING_APPS[@]} )); then
    progress 75 "Restoring ${#MISSING_APPS[@]} default GNOME applications from Flathub…"
    if ! flatpak install --noninteractive --assumeyes flathub \
        "${MISSING_APPS[@]}" >> "$LOG_FILE" 2>&1; then
        fail "Some default applications could not be installed. See $LOG_FILE"
    fi
else
    progress 90 "All default applications are already installed."
fi

touch "$DONE_FILE"
progress 100 "Setup complete. Toshy and the default applications are ready."

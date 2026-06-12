#!/bin/bash
set -ouex pipefail

### Clone MacTahoe GTK theme
# Keep the repo so tweaks.sh can find Firefox CSS source files at first-login
REPO_DIR="/usr/share/MacTahoe-gtk-theme"
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$REPO_DIR"

### Install default GTK theme system-wide.
# install.sh redirects its own stderr to /tmp/MacTahoe.lock/error_log.txt via
# `exec 2>` — errors are invisible in the build log without this trap.
mkdir -p /usr/share/themes
MACTAHOE_LOCK_LOG="/tmp/MacTahoe.lock/error_log.txt"
trap 'echo "=== MacTahoe install.sh error log ==="; cat "$MACTAHOE_LOCK_LOG" 2>/dev/null || echo "(empty)"; echo "===================================="' ERR
cd "$REPO_DIR"
./install.sh -d /usr/share/themes --silent-mode
trap - ERR

### Install Firefox first-login setup (user-profile-specific, runs silently at graphical session)
install -Dm755 /ctx/mactahoe/mactahoe-firefox-setup.sh \
    /usr/libexec/mactahoe-firefox-setup.sh

install -Dm644 /ctx/mactahoe/mactahoe-firefox-setup.service \
    /usr/lib/systemd/user/mactahoe-firefox-setup.service

mkdir -p /usr/lib/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/mactahoe-firefox-setup.service \
       /usr/lib/systemd/user/graphical-session.target.wants/mactahoe-firefox-setup.service

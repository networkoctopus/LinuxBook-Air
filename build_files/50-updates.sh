#!/bin/bash
set -ouex pipefail

### ── uupd (ublue automatic updates) ──
dnf5 -y copr enable ublue-os/packages
dnf5 install -y uupd
dnf5 -y copr disable ublue-os/packages
systemctl enable uupd.timer
echo "ublue automatic updates enabled"

### ── Disable rpm-ostree automatic updates ──
# uupd handles updates; rpm-ostreed-automatic would conflict
sed -i 's/^AutomaticUpdatePolicy=.*/AutomaticUpdatePolicy=none/' /etc/rpm-ostreed.conf
systemctl disable rpm-ostreed-automatic.timer
echo "rpm-ostree automatic updates disabled"

### ── Flatpak remotes ──
# Add Flathub and remove the Fedora Flatpak remote
flatpak remote-add --system --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo
systemctl disable flatpak-add-fedora-repos.service

### ── GNOME Software / PackageKit ──
# Prevent gnome-software from trying to update packages and conflicting
# with bootc's deployment process
rm -f /usr/lib64/gnome-software/plugins-*/libgs_plugin_dnf5.so
systemctl mask packagekit
echo "gnome-software dnf5 plugin removed"

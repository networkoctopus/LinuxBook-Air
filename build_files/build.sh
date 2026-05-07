#!/bin/bash
set -ouex pipefail

### Install packages

# Enable RPMFusion free and nonfree repos
# (not pre-enabled on vanilla Fedora Silverblue unlike Bluefin)
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Install FaceTime HD camera driver (MacBook)
# facetimehd-kmod is a plain pre-built kmod RPM, not an akmod,
# so it installs cleanly as root without triggering any build scriptlets
#dnf5 -y copr enable mulderje/facetimehd-kmod
#dnf5 install -y facetimehd-kmod
#dnf5 -y copr disable mulderje/facetimehd-kmod

# this installs a package from fedora repos
dnf5 install -y tmux

# Install Toshy native dependencies
dnf5 install -y \
    cairo-devel \
    cairo-gobject-devel \
    dbus \
    dbus-devel \
    evtest \
    gcc \
    git \
    gobject-introspection-devel \
    libappindicator-gtk3 \
    libinput-utils \
    libjpeg-turbo-devel \
    libnotify \
    libxkbcommon-devel \
    python3-dbus \
    python3-devel \
    python3-pip \
    python3-tkinter \
    systemd-devel \
    wayland-devel \
    xorg-x11-server-utils \
    zenity

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
systemctl enable podman.socket

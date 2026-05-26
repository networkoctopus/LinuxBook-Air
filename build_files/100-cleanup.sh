#!/bin/bash
set -ouex pipefail

### ── Disable leftover third-party repos ──
for repo in negativo17-fedora-multimedia fedora-cisco-openh264; do
    if [[ -f "/etc/yum.repos.d/${repo}.repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/${repo}.repo"
    fi
done

# Disable any remaining COPR repos
for i in /etc/yum.repos.d/_copr:*.repo; do
    [[ -f "$i" ]] && sed -i 's@enabled=1@enabled=0@g' "$i"
done

# Disable ublue-os akmods COPR if present
if [[ -f "/etc/yum.repos.d/_copr_ublue-os-akmods.repo" ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo
fi

# Disable RPM Fusion repos
for i in /etc/yum.repos.d/rpmfusion-*.repo; do
    [[ -f "$i" ]] && sed -i 's@enabled=1@enabled=0@g' "$i"
done

# Disable fedora-coreos-pool if present
if [[ -f /etc/yum.repos.d/fedora-coreos-pool.repo ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-coreos-pool.repo
fi

### ── DNF cleanup ──
dnf5 autoremove -y
rm -rf \
    /run/dnf \
    /var/cache/libdnf5

truncate -s 0 /var/log/dnf5.log

### ── General cache / tmp cleanup ──
rm -rf \
    /var/cache/* \
    /var/lib/dnf/repos/* \
    /var/lib/flatpak/repo/* \
    /run/dnf/* \
    /tmp/* \
    /var/tmp/*

rm -f \
    /var/cache/ldconfig/aux-cache \
    /var/lib/dnf/system-repo.lock \
    /var/lib/flatpak/.changed

### ── Log truncation ──
find /var/log -type f -exec truncate -s 0 {} \;

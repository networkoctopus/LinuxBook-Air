#!/usr/bin/bash
set -eoux pipefail

systemctl mask \
    gssproxy.service \
    nfs-client.target \
    remote-fs.target \
    rpc-statd-notify.service \
    var-lib-nfs-rpc_pipefs.mount \
    NetworkManager-wait-online.service \
    sssd-kcm.service \
    sssd-kcm.socket \
    pcscd.socket \
    ModemManager.service \
    systemd-homed.service \
    lvm2-monitor.service \
    lvm-devices-import.service \
    lvm-devices-import.path \
    smartd.service \
    fwupd.service \
    plymouth-quit-wait.service \
    fedora-atomic-desktop-appstream-cache-refresh.service
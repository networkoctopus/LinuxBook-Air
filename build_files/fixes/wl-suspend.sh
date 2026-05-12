#!/bin/bash
IFACE="wlp3s0"

case "$1" in
    pre)
        # Bring interface down cleanly before S3
        ip link set "$IFACE" down 2>/dev/null || true
        ;;
    post)
        # Restart NetworkManager wifi to force firmware re-init
        nmcli radio wifi off 2>/dev/null || true
        sleep 2
        nmcli radio wifi on 2>/dev/null || true
        ;;
esac

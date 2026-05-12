#!/bin/bash
BACKLIGHT=/sys/class/backlight/intel_backlight
case "$1" in
    pre)
        cat "$BACKLIGHT/brightness" > /tmp/backlight-save 2>/dev/null || true
        ;;
    post)
        start=$(date +%s%3N)
        deadline=$((start + 3000))
        until [ -f /tmp/backlight-save ] && \
            cat /tmp/backlight-save > "$BACKLIGHT/brightness" 2>/dev/null; do
            sleep 0.05
            [ $(date +%s%3N) -ge $deadline ] && break
        done
        end=$(date +%s%3N)
        echo "$((end - start))ms wait for backlight" >> /etc/backlight-resume.log
        ;;
esac
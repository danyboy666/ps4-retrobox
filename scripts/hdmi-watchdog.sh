#!/bin/bash
# HDMI recovery watchdog
# When TV power cycles: connector goes disconnected→connected
# Kill ES so hdmi-init can force modetest as root, then ES auto-restarts
PREV_STATUS=""
while true; do
    STATUS=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null)
    if [ "$PREV_STATUS" = "connected" ] && [ "$STATUS" = "connected" ]; then
        # TV was power-cycled while showing "connected" — force re-init
        modetest -s HDMI-A-1:1920x1080 >/dev/null 2>&1
    elif [ "$PREV_STATUS" = "disconnected" ] && [ "$STATUS" = "connected" ]; then
        # TV just reconnected — restart ES to re-init display
        systemctl restart es-session 2>/dev/null
    fi
    PREV_STATUS="$STATUS"
    sleep 2
done

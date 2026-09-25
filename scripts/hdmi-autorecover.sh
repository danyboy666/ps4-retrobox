#!/bin/bash
# hdmi-autorecover.sh — Smart HDMI recovery daemon
# Detects TV power-cycle via HDMI audio ELD (EDID-Like Data)
# ELD = 524 bytes when TV is ON, 0 bytes when TV is OFF
# Only triggers recovery on TV power-ON (ELD goes 0→nonzero)
# No periodic restarts — only acts when needed.

ELD_FILE="/proc/asound/card0/eld#0.0"
PREV_ELD=""

while true; do
    sleep 3

    # Read ELD size
    ELD_SIZE=$(cat "$ELD_FILE" 2>/dev/null | wc -c)

    if [ "$ELD_SIZE" = "0" ] && [ "$PREV_ELD" != "0" ]; then
        # TV just powered OFF (ELD went to 0) — do nothing, wait for power-on
        :
    elif [ "$ELD_SIZE" != "0" ] && [ "$PREV_ELD" = "0" ]; then
        # TV just powered ON (ELD went from 0 to nonzero) — trigger recovery
        /usr/local/bin/hdmi-recover.sh >/dev/null 2>&1
    fi

    PREV_ELD="$ELD_SIZE"
done

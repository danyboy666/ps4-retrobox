#!/bin/bash
# hdmi-autorecover.sh — Runs hdmi-recover periodically to maintain HDMI signal
# The PS4 kernel's amdgpu driver can't auto-recover after TV power-cycle.
# This daemon forces a DPMS Off→On cycle every 120 seconds to keep the link alive.
# During recovery, screen blanks for ~10 seconds then comes back.

while true; do
    sleep 300
    if systemctl is-active es-session >/dev/null 2>&1; then
        /usr/local/bin/hdmi-recover.sh >/dev/null 2>&1
    fi
done

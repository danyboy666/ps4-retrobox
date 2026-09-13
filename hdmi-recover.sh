#!/bin/bash
# hdmi-recover.sh — PS4 HDMI recovery
# The PS4 kernel's amdgpu driver has broken HDMI hotplug re-detection.
# DPMS is read-only, connector properties are locked down.
# The ONLY reliable recovery is a physical cable replug.
# This script does everything possible from software:
# 1. Stops ES (frees DRM master)
# 2. Cycles force=on (triggers re-probe on next hotplug)
# 3. Clears CRTC (stops scanout)
# 4. Waits for PHY to power down
# 5. Re-sets mode (forces fresh signal)
# 6. Restarts ES
# If this doesn't work, unplug and replug the HDMI cable.

echo "=== PS4 HDMI Recovery ==="
echo "Stopping display..."
systemctl stop es-session 2>/dev/null
killall -9 emulationstation 2>/dev/null
sleep 2

echo "Setting force=on..."
echo on > /sys/kernel/debug/dri/0/HDMI-A-1/force 2>/dev/null
sleep 1

echo "Clearing CRTC (PHY power down)..."
/usr/local/bin/hdmi-force 2>&1

echo "Waiting 5 seconds..."
sleep 5

echo "Setting mode 1920x1080..."
/usr/bin/modetest -s HDMI-A-1:1920x1080 2>/dev/null
sleep 2

echo "Starting display..."
systemctl start es-session 2>/dev/null

echo ""
echo "If you still have no signal, you MUST unplug and replug the HDMI cable."
echo "This is a kernel-level limitation on PS4 Linux (amdgpu driver)."
echo "The kernel cannot re-negotiate the HDMI link from userspace."

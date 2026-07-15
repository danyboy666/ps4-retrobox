#!/bin/bash
# PS4 RetroBox - Rest Mode
# Puts the PS4 into suspend/rest mode

echo "=== PS4 RetroBox - Rest Mode ==="
echo ""
echo "The PS4 will enter rest mode in 3 seconds."
echo "Press Ctrl+C to cancel."
echo ""
sleep 3
echo "Entering rest mode..."
sudo systemctl suspend

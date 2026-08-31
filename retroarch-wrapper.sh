#!/bin/bash
# PS4 RetroBox RetroArch wrapper
# - Shows launching.png via fbi (ROOT, full-screen)
# - KMS retry loop
# - HDMI recovery on exit (NO es-session restart)

trap "" HUP
mkdir -p /tmp/runtime-PS4 && chmod 700 /tmp/runtime-PS4

export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/amdgpu_shim.so
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
export XDG_RUNTIME_DIR=/run/user/1000
export MESA_NO_ERROR=1
export XKB_CONFIG_ROOT=/usr/share/X11/xkb
export vblank_mode=2
export __GL_SYNC_TO_VBLANK=1

ROM_PATH="$*"
SYS_DIR=$(echo "$ROM_PATH" | grep -oE "/ROMS/[^/ ]+" | head -1 | sed "s|/ROMS/||")
LAUNCH_IMG="/home/PS4/.emulationstation/downloaded_images/$SYS_DIR/launching.png"
if [ -f "$LAUNCH_IMG" ]; then
    sudo fbi -T 7 -d /dev/fb0 -a -t 4 -noverbose -1 "$LAUNCH_IMG" 2>/dev/null &
    FBI_PID=$!
    sleep 3
    sudo kill $FBI_PID 2>/dev/null
    sleep 1
fi

MAX_RETRIES=5
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    /usr/bin/retroarch --verbose --appendconfig=/home/PS4/.config/retroarch/retroarch-ps4.cfg "$@" > /tmp/retroarch.log 2>&1
    RC=$?
    if grep -q "KMS.*Error when switching mode" /tmp/retroarch.log 2>/dev/null; then
        RETRY=$((RETRY+1))
        echo "PS4" | sudo -S killall -9 retroarch 2>/dev/null
        sleep 5
    else
        break
    fi
done

sleep 1
echo "PS4" | sudo -S killall -9 retroarch 2>/dev/null
sleep 1
echo "PS4" | sudo -S modetest -s HDMI-A-1:1920x1080 2>/dev/null
exit $RC

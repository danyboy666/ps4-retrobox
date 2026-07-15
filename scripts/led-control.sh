#!/bin/bash
# PS4 RetroBox - DS4 LED Controller
# Controls DualShock 4 LED color via USB HID
# Usage: led-control.sh --color red|green|blue|purple|cyan|yellow|white|off

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

usage() {
    echo "Usage: led-control.sh --color <color>"
    echo ""
    echo "Colors:"
    echo "  red      Red LED"
    echo "  green    Green LED"
    echo "  blue     Blue LED (default)"
    echo "  purple   Purple LED"
    echo "  cyan     Cyan LED"
    echo "  yellow   Yellow LED"
    echo "  white    White LED"
    echo "  off      Turn off LED"
    echo ""
    echo "Examples:"
    echo "  led-control.sh --color red"
    echo "  led-control.sh --color off"
}

get_color() {
    case "$1" in
        red)    echo "255 0 0" ;;
        green)  echo "0 255 0" ;;
        blue)   echo "0 0 255" ;;
        purple) echo "255 0 255" ;;
        cyan)   echo "0 255 255" ;;
        yellow) echo "255 255 0" ;;
        white)  echo "255 255 255" ;;
        off)    echo "0 0 0" ;;
        *)      echo ""; return 1 ;;
    esac
}

set_led() {
    local r="$1" g="$2" b="$3"
    local brightness=255
    if [ "$r" = "0" ] && [ "$g" = "0" ] && [ "$b" = "0" ]; then
        brightness=0
    fi
    # DS4 LED report: [report_id=0x05, brightness, r, g, b]
    python3 -c "
import struct, os
# Find DS4 hidraw device
for i in range(4):
    try:
        with open(f'/sys/class/hidraw/hidraw{i}/device/uevent') as f:
            if '054C' in f.read():
                dev = f'/dev/hidraw{i}'
                # LED report: [0x05, brightness, red, green, blue, 0, 0, 0]
                report = bytes([0x05, $brightness, $r, $g, $b, 0, 0, 0])
                with open(dev, 'wb') as d:
                    d.write(report)
                print(f'LED set on {dev}: R=$r G=$g B=$b')
                exit(0)
    except:
        pass
print('DS4 not found')
exit(1)
"
}

# Parse arguments
COLOR="blue"
while [ $# -gt 0 ]; do
    case "$1" in
        --color) COLOR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

RGB=$(get_color "$COLOR")
if [ -z "$RGB" ]; then
    echo -e "${RED}Unknown color: $COLOR${NC}"
    usage
    exit 1
fi

set_led $RGB

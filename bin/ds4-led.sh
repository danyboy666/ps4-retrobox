#!/bin/sh
# DS4 Lightbar LED Controller for PS4 RetroBox
# Reads ~/.emulationstation/ds4_led.cfg and applies color/pattern

ES_DIR="$HOME/.emulationstation"
CONFIG="$ES_DIR/ds4_led.cfg"

# Default: purple, solid
R=128; G=0; B=128
PATTERN="solid"

# Parse config if it exists
if [ -f "$CONFIG" ]; then
    COLOR=$(grep -o 'value="[^"]*"' "$CONFIG" | head -1 | sed 's/value="//;s/"//')
    PATTERN=$(grep -o 'value="[^"]*"' "$CONFIG" | tail -1 | sed 's/value="//;s/"//')
    case "$COLOR" in
        red)     R=255; G=0;   B=0   ;;
        green)   R=0;   G=255; B=0   ;;
        blue)    R=0;   G=0;   B=255 ;;
        orange)  R=255; G=165; B=0   ;;
        cyan)    R=0;   G=255; B=255 ;;
        magenta) R=255; G=0;   B=255 ;;
        yellow)  R=255; G=255; B=0   ;;
        white)   R=255; G=255; B=255 ;;
        off)     R=0;   G=0;   B=0   ;;
        purple)  R=128; G=0;   B=128 ;;
    esac
fi

# Find DS4 LED devices (auto-detect input number)
for led_dir in /sys/class/leds/input*; do
    [ -d "$led_dir" ] || continue
    name=$(basename "$led_dir")
    # Skip non-LED entries
    case "$name" in *:*) ;; *) continue ;; esac

    # Set trigger to none first
    echo "none" > "$led_dir/trigger" 2>/dev/null

    # Apply color
    case "$name" in
        *:red)   echo $R > "$led_dir/brightness" ;;
        *:green) echo $G > "$led_dir/brightness" ;;
        *:blue)  echo $B > "$led_dir/brightness" ;;
    esac

    # Apply pattern
    case "$PATTERN" in
        breathing)
            echo "timer" > "$led_dir/trigger" 2>/dev/null
            echo 1500 > "$led_dir/delay_on" 2>/dev/null
            echo 1500 > "$led_dir/delay_off" 2>/dev/null
            ;;
        fast_breathing)
            echo "timer" > "$led_dir/trigger" 2>/dev/null
            echo 500 > "$led_dir/delay_on" 2>/dev/null
            echo 500 > "$led_dir/delay_off" 2>/dev/null
            ;;
        pulse)
            echo "timer" > "$led_dir/trigger" 2>/dev/null
            echo 200 > "$led_dir/delay_on" 2>/dev/null
            echo 1800 > "$led_dir/delay_off" 2>/dev/null
            ;;
        solid|*)
            # Already set to "none" trigger with brightness
            ;;
    esac
done

# Reset to blue when ES exits (called with "reset" argument)
if [ "$1" = "reset" ]; then
    for led_dir in /sys/class/leds/input*; do
        [ -d "$led_dir" ] || continue
        name=$(basename "$led_dir")
        echo "none" > "$led_dir/trigger" 2>/dev/null
        case "$name" in
            *:red)   echo 0 > "$led_dir/brightness" ;;
            *:green) echo 0 > "$led_dir/brightness" ;;
            *:blue)  echo 255 > "$led_dir/brightness" ;;
        esac
    done
fi

#!/usr/bin/env bash
# RetroArch configscript for PS4 RetroBox
# Reads es_input.cfg and generates retroarch.cfg with correct hotkey mappings
# Based on RetroPie's configscripts/retroarch.sh

CONFIG_DIR="/home/PS4/.config/retroarch"
INPUT_CFG="/home/PS4/.emulationstation/es_input.cfg"
RETROARCH_CFG="$CONFIG_DIR/retroarch.cfg"

if [ ! -f "$INPUT_CFG" ]; then
    echo "ERROR: $INPUT_CFG not found"
    exit 1
fi

mkdir -p "$CONFIG_DIR"

echo "=== Generating RetroArch config from ES input ==="

# Parse es_input.cfg to extract button mappings
# ES uses SDL keycodes and evdev codes
# Format: <input name="up" type="button" id="11" value="1" ... />

# Create temp config
TMPFILE=$(mktemp)

cat > "$TMPFILE" << 'BASECFG'
video_fullscreen = "true"
video_driver = "gl"
video_context_driver = "kms"
audio_driver = "sdl2"
input_driver = "udev"
input_autodetect_enable = "false"
libretro_directory = "/usr/lib/x86_64-linux-gnu/libretro"
screenshot_directory = "/home/PS4/screenshots"
savefile_directory = "/home/PS4/saves"
savestate_directory = "/home/PS4/saves"
system_directory = "/home/PS4/BIOS"
menu_driver = "xmb"
BASECFG

# Function to extract button mapping from es_input.cfg for joystick
# Usage: get_joypad_input "inputName" "deviceName"
get_joypad_input() {
    local input_name="$1"
    local device_name="$2"
    # Find the inputConfig for this device, then find the input with this name
    # For joystick inputs: type="button" id="N" or type="hat" or type="axis"
    python3 -c "
import xml.etree.ElementTree as ET
import sys

tree = ET.parse('$INPUT_CFG')
root = tree.getroot()

for ic in root.findall('inputConfig'):
    dev = ic.get('deviceName', '')
    devtype = ic.get('type', '')
    if devtype != 'joystick':
        continue
    if '$device_name' not in dev and dev not in '$device_name':
        continue
    for inp in ic.findall('input'):
        if inp.get('name') == '$input_name':
            print(f\"{inp.get('type')} {inp.get('id')} {inp.get('value')}\")
            sys.exit(0)
print('NOTFOUND')
sys.exit(0)
" 2>/dev/null
}

# Get the first joystick device name
DEVICE_NAME=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('$INPUT_CFG')
root = tree.getroot()
for ic in root.findall('inputConfig'):
    if ic.get('type') == 'joystick':
        print(ic.get('deviceName', ''))
        break
" 2>/dev/null)

if [ -z "$DEVICE_NAME" ]; then
    echo "WARNING: No joystick found in es_input.cfg"
    echo "Using keyboard-only config"
else
    echo "Found joystick: $DEVICE_NAME"
fi

# Map each ES input to RetroArch config
map_input() {
    local es_name="$1"
    local retroarch_keys="$2"  # space-separated list of retroarch config keys
    
    local result=$(get_joypad_input "$es_name" "$DEVICE_NAME")
    if [ "$result" = "NOTFOUND" ] || [ -z "$result" ]; then
        return
    fi
    
    local type=$(echo "$result" | cut -d' ' -f1)
    local id=$(echo "$result" | cut -d' ' -f2)
    local value=$(echo "$result" | cut -d' ' -f3)
    
    local retro_value=""
    case "$type" in
        button)
            retro_value="$id"
            ;;
        hat)
            declare -A hat_map=([1]="up" [2]="right" [4]="down" [8]="left")
            if [ -n "${hat_map[$value]}" ]; then
                retro_value="h$id${hat_map[$value]}"
            fi
            ;;
        axis)
            if [ "$value" = "1" ]; then
                retro_value="+$id"
            else
                retro_value="-$id"
            fi
            ;;
    esac
    
    if [ -z "$retro_value" ]; then
        return
    fi
    
    for key in $retroarch_keys; do
        echo "${key} = \"${retro_value}\"" >> "$TMPFILE"
    done
}

# Map D-pad
map_input "up" "input_player1_up"
map_input "down" "input_player1_down"
map_input "left" "input_player1_left"
map_input "right" "input_player1_right"

# Map face buttons
map_input "a" "input_player1_a"
map_input "b" "input_player1_b"
map_input "x" "input_player1_x"
map_input "y" "input_player1_y"

# Map shoulders/triggers
map_input "LeftShoulder" "input_player1_l"
map_input "RightShoulder" "input_player1_r"
map_input "LeftTrigger" "input_player1_l2"
map_input "RightTrigger" "input_player1_r2"

# Map thumb sticks
map_input "LeftThumb" "input_player1_l3"
map_input "RightThumb" "input_player1_r3"

# Map start/select
map_input "Start" "input_player1_start"
map_input "Select" "input_player1_select"

# Map analog sticks
map_input "LeftAnalogUp" "input_player1_l_y_minus"
map_input "LeftAnalogDown" "input_player1_l_y_plus"
map_input "LeftAnalogLeft" "input_player1_l_x_minus"
map_input "LeftAnalogRight" "input_player1_l_x_plus"
map_input "RightAnalogUp" "input_player1_r_y_minus"
map_input "RightAnalogDown" "input_player1_r_y_plus"
map_input "RightAnalogLeft" "input_player1_r_x_minus"
map_input "RightAnalogRight" "input_player1_r_x_plus"

# Map hotkey enable (use Select as default hotkey if not configured)
map_input "HotKeyEnable" "input_enable_hotkey"

# If no HotKeyEnable button was mapped, use Select as hotkey
if ! grep -q "input_enable_hotkey" "$TMPFILE"; then
    SELECT_VAL=$(grep "input_player1_select" "$TMPFILE" | head -1 | sed 's/.*= *"//;s/".*//')
    if [ -n "$SELECT_VAL" ]; then
        echo "input_enable_hotkey = \"$SELECT_VAL\"" >> "$TMPFILE"
    fi
fi

# Add hotkey functions (when hotkey is held + button pressed)
# X = Menu Toggle, Start = Exit
grep "input_player1_x" "$TMPFILE" | sed 's/input_player1_x/input_menu_toggle/' >> "$TMPFILE"
grep "input_player1_start" "$TMPFILE" | sed 's/input_player1_start/input_exit_emulator/' >> "$TMPFILE"
grep "input_player1_left" "$TMPFILE" | sed 's/input_player1_left/input_state_slot_decrease/' >> "$TMPFILE"
grep "input_player1_right" "$TMPFILE" | sed 's/input_player1_right/input_state_slot_increase/' >> "$TMPFILE"
grep "input_player1_l\b" "$TMPFILE" | sed 's/input_player1_l /input_load_state /' >> "$TMPFILE"
grep "input_player1_r\b" "$TMPFILE" | sed 's/input_player1_r /input_save_state /' >> "$TMPFILE"

# Add left stick as D-pad fallback
grep "input_player1_l_y_minus" "$TMPFILE" | sed 's/input_player1_l_y_minus/input_player1_up/' >> "$TMPFILE"
grep "input_player1_l_y_plus" "$TMPFILE" | sed 's/input_player1_l_y_plus/input_player1_down/' >> "$TMPFILE"
grep "input_player1_l_x_minus" "$TMPFILE" | sed 's/input_player1_l_x_minus/input_player1_left/' >> "$TMPFILE"
grep "input_player1_l_x_plus" "$TMPFILE" | sed 's/input_player1_l_x_plus/input_player1_right/' >> "$TMPFILE"

# Disable autodetect (we set everything explicitly)
echo 'input_autodetect_enable = "false"' >> "$TMPFILE"

# Copy to final location
cp "$TMPFILE" "$RETROARCH_CFG"
rm -f "$TMPFILE"

echo "Generated $RETROARCH_CFG"
echo "Hotkey: Hold Select + X = Menu, Hold Select + Start = Exit"

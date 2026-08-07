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
video_fullscreen_x = "1920"
video_fullscreen_y = "1080"
video_driver = "gl"
video_shared_context = "true"
video_font_enable = "true"
video_font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
video_font_size = "32.000000"
audio_driver = "pulse"
input_driver = "udev"
input_autodetect_enable = "false"
input_device = "Sony Interactive Entertainment Wireless Controller"
libretro_directory = "/usr/lib/x86_64-linux-gnu/libretro"
screenshot_directory = "/home/PS4/screenshots"
savefile_directory = "/home/PS4/saves"
savestate_directory = "/home/PS4/saves"
system_directory = "/home/PS4/BIOS"
menu_driver = "xmb"
all_users_control_menu = "true"
menu_unified_controls = "true"
config_save_on_exit = "false"
menu_show_load_content = "false"
menu_show_load_content_animation = "false"
input_menu_toggle_gamepad_combo = "2"
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
    local retro_value_hat=""
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
        case "$type" in
            button|hat)
                echo "${key}_btn = \"${retro_value}\"" >> "$TMPFILE"
                ;;
            axis)
                echo "${key}_axis = \"${retro_value}\"" >> "$TMPFILE"
                ;;
        esac
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

# Map shoulders/triggers (ES uses lowercase names)
map_input "leftshoulder" "input_player1_l"
map_input "rightshoulder" "input_player1_r"
map_input "lefttrigger" "input_player1_l2"
map_input "righttrigger" "input_player1_r2"

# Map thumb sticks
map_input "leftthumb" "input_player1_l3"
map_input "rightthumb" "input_player1_r3"

# Map start/select
map_input "start" "input_player1_start"
map_input "select" "input_player1_select"

# Map analog sticks
map_input "leftanalogup" "input_player1_l_y_minus"
map_input "leftanalogdown" "input_player1_l_y_plus"
map_input "leftanalogleft" "input_player1_l_x_minus"
map_input "leftanalogright" "input_player1_l_x_plus"
map_input "rightanalogup" "input_player1_r_y_minus"
map_input "rightanalogdown" "input_player1_r_y_plus"
map_input "rightanalogleft" "input_player1_r_x_minus"
map_input "rightanalogright" "input_player1_r_x_plus"

# Global RetroPad bindings (used by menu navigation)
map_input "up" "input_up"
map_input "down" "input_down"
map_input "left" "input_left"
map_input "right" "input_right"
map_input "a" "input_a"
map_input "b" "input_b"
map_input "x" "input_x"
map_input "y" "input_y"
map_input "start" "input_start"
map_input "select" "input_select"
map_input "leftshoulder" "input_l"
map_input "rightshoulder" "input_r"
map_input "leftthumb" "input_l3"
map_input "rightthumb" "input_r3"

# Map hotkey enable (use Select as default hotkey if not configured)
map_input "hotkeyenable" "input_enable_hotkey"

# If no HotKeyEnable button was mapped, use Select as hotkey
if ! grep -q "input_enable_hotkey" "$TMPFILE"; then
    SELECT_VAL=$(grep "input_player1_select" "$TMPFILE" | head -1 | sed 's/.*= *"//;s/".*//')
    if [ -n "$SELECT_VAL" ]; then
        echo "input_enable_hotkey = \"$SELECT_VAL\"" >> "$TMPFILE"
    fi
fi

# Add hotkey functions (when hotkey is held + button pressed)
# X = Menu Toggle, Start = Exit
grep "input_player1_x_btn" "$TMPFILE" | sed 's/input_player1_x_btn/input_menu_toggle_btn/' >> "$TMPFILE"
grep "input_player1_start_btn" "$TMPFILE" | sed 's/input_player1_start_btn/input_exit_emulator_btn/' >> "$TMPFILE"
grep "input_player1_left_btn" "$TMPFILE" | sed 's/input_player1_left_btn/input_state_slot_decrease_btn/' >> "$TMPFILE"
grep "input_player1_right_btn" "$TMPFILE" | sed 's/input_player1_right_btn/input_state_slot_increase_btn/' >> "$TMPFILE"
grep "input_player1_l_btn" "$TMPFILE" | sed 's/input_player1_l_btn/input_load_state_btn/' >> "$TMPFILE"
grep "input_player1_r_btn" "$TMPFILE" | sed 's/input_player1_r_btn/input_save_state_btn/' >> "$TMPFILE"

# Add left stick as D-pad fallback
grep "input_player1_l_y_minus_axis" "$TMPFILE" | sed 's/input_player1_l_y_minus_axis/input_player1_up_btn/' >> "$TMPFILE"
grep "input_player1_l_y_plus_axis" "$TMPFILE" | sed 's/input_player1_l_y_plus_axis/input_player1_down_btn/' >> "$TMPFILE"
grep "input_player1_l_x_minus_axis" "$TMPFILE" | sed 's/input_player1_l_x_minus_axis/input_player1_left_btn/' >> "$TMPFILE"
grep "input_player1_l_x_plus_axis" "$TMPFILE" | sed 's/input_player1_l_x_plus_axis/input_player1_right_btn/' >> "$TMPFILE"

# Disable autodetect (we set everything explicitly)
echo 'input_autodetect_enable = "false"' >> "$TMPFILE"

# PS4 OVERRIDE: D-pad is HAT hardware (ABS_HAT0X/Y)
# ES records D-pad as type="button" but hardware sends HAT events
sed -i '/^input_player1_up_btn/d; /^input_player1_down_btn/d; /^input_player1_left_btn/d; /^input_player1_right_btn/d; /^input_up_btn/d; /^input_down_btn/d; /^input_left_btn/d; /^input_right_btn/d' "$TMPFILE"
cat >> "$TMPFILE" << 'HAT'
input_player1_up_btn = "h0up"
input_player1_down_btn = "h0down"
input_player1_left_btn = "h0left"
input_player1_right_btn = "h0right"
input_up_btn = "h0up"
input_down_btn = "h0down"
input_left_btn = "h0left"
input_right_btn = "h0right"
HAT

# PS4 OVERRIDE: Force PS button (BTN_MODE=12) as hotkey
# ES Configure Input has a bug where it records PS button as BTN_Z(5) instead of BTN_MODE(12)
# Evtest proves BTN_MODE fires at code 316 = button 12 in sequential index
sed -i '/^input_enable_hotkey/d' "$TMPFILE"
echo 'input_enable_hotkey_btn = "12"' >> "$TMPFILE"

# PS4 OVERRIDE: Add keyboard bindings (Escape/F1 work when getty is disabled)
cat >> "$TMPFILE" << 'KBDBIND'
input_menu_toggle = "f1"
input_exit_emulator = "escape"
input_save_state = "f2"
input_load_state = "f4"
input_screenshot = "f8"
input_up = "up"
input_down = "down"
input_left = "left"
input_right = "right"
input_a = "return"
input_b = "escape"
input_start = "space"
input_select = "tab"
input_l = "pageup"
input_r = "pagedown"
KBDBIND

# PS4 OVERRIDE: Add analog axis bindings
sed -i '/^input_player1_l2_axis/d; /^input_player1_r2_axis/d; /^input_player1_l_x/d; /^input_player1_l_y/d; /^input_player1_r_x/d; /^input_player1_r_y/d' "$TMPFILE"
cat >> "$TMPFILE" << 'AXIS'
input_player1_l2_axis = "-4"
input_player1_r2_axis = "+5"
input_l2_axis = "-4"
input_r2_axis = "+5"
input_player1_l_x_plus_axis = "+0"
input_player1_l_x_minus_axis = "-0"
input_player1_l_y_plus_axis = "+1"
input_player1_l_y_minus_axis = "-1"
input_player1_r_x_plus_axis = "+3"
input_player1_r_x_minus_axis = "-3"
input_player1_r_y_plus_axis = "+4"
input_player1_r_y_minus_axis = "-4"
input_l_x_plus_axis = "+0"
input_l_x_minus_axis = "-0"
input_l_y_plus_axis = "+1"
input_l_y_minus_axis = "-1"
input_r_x_plus_axis = "+3"
input_r_x_minus_axis = "-3"
input_r_y_plus_axis = "+4"
input_r_y_minus_axis = "-4"
AXIS

# Copy to final location
cp "$TMPFILE" "$RETROARCH_CFG"
rm -f "$TMPFILE"

echo "Generated $RETROARCH_CFG"
echo "Hotkey: Hold Select + X = Menu, Hold Select + Start = Exit"

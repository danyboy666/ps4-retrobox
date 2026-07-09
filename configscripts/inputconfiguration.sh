#!/bin/bash
# Input Configuration Script for PS4 RetroBox
# Reads es_input.cfg and generates matching RetroArch config
# Called automatically after ES saves input configuration

INPUT_CFG="/home/PS4/.emulationstation/es_input.cfg"
RETROARCH_CFG="/home/PS4/.config/retroarch/retroarch.cfg"
RETROARCH_PS4_CFG="/home/PS4/.config/retroarch/retroarch-ps4.cfg"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$INPUT_CFG" ]; then
    echo "ERROR: $INPUT_CFG not found"
    exit 1
fi

# Source the retroarch configscript functions
source "$SCRIPT_DIR/retroarch.sh"

# Parse es_input.cfg using python
python3 << 'PYEOF'
import xml.etree.ElementTree as ET
import os
import subprocess

input_cfg = os.environ.get("INPUT_CFG", "/home/PS4/.emulationstation/es_input.cfg")
config_dir = "/home/PS4/.config/retroarch"
temp_cfg = "/tmp/retroarch_temp.cfg"
retroarch_cfg = os.path.join(config_dir, "retroarch.cfg")

tree = ET.parse(input_cfg)
root = tree.getroot()

# Build button mapping from es_input.cfg
mapping = {}
for inputConfig in root.findall("inputConfig"):
    device_type = inputConfig.get("type", "")
    if device_type != "joystick":
        continue
    device_name = inputConfig.get("deviceName", "")
    if "PS4" not in device_name and "Wireless" not in device_name and "Sony" not in device_name:
        continue
    
    print(f"Found controller: {device_name}")
    
    for inp in inputConfig.findall("input"):
        name = inp.get("name")
        inp_type = inp.get("type")
        inp_id = inp.get("id")
        inp_value = inp.get("value")
        mapping[name] = (inp_type, inp_id, inp_value)

# Generate RetroArch config
config_lines = []
config_lines.append('input_driver = "udev"')
config_lines.append(f'input_device = "{device_name}"')
config_lines.append('input_autodetect_enable = "true"')
config_lines.append('menu_driver = "xmb"')
config_lines.append('all_users_control_menu = "true"')
config_lines.append('menu_unified_controls = "true"')

# Map ES inputs to RetroArch global bindings (for XMB menu navigation)
def get_retroarch_value(inp_type, inp_id, inp_value):
    if inp_type == "button":
        return inp_id
    elif inp_type == "axis":
        if int(inp_value) > 0:
            return f"+{inp_id}"
        else:
            return f"-{inp_id}"
    elif inp_type == "hat":
        hat_map = {"1": "up", "2": "right", "4": "down", "8": "left"}
        return f"h{inp_id}{hat_map.get(inp_value, '')}"
    return inp_id

# Global RetroPad bindings (XMB menu uses these)
global_map = {
    "up": "input_up_btn",
    "down": "input_down_btn",
    "left": "input_left_btn",
    "right": "input_right_btn",
    "a": "input_a_btn",
    "b": "input_b_btn",
    "x": "input_x_btn",
    "y": "input_y_btn",
    "start": "input_start_btn",
    "select": "input_select_btn",
    "leftshoulder": "input_l_btn",
    "rightshoulder": "input_r_btn",
    "lefttrigger": "input_l2_axis",
    "righttrigger": "input_r2_axis",
    "leftthumb": "input_l3_btn",
    "rightthumb": "input_r3_btn",
    "leftanalogleft": "input_l_x_minus_axis",
    "leftanalogright": "input_l_x_plus_axis",
    "leftanalogup": "input_l_y_minus_axis",
    "leftanalogdown": "input_l_y_plus_axis",
    "rightanalogleft": "input_r_x_minus_axis",
    "rightanalogright": "input_r_x_plus_axis",
    "rightanalogup": "input_r_y_minus_axis",
    "rightanalogdown": "input_r_y_plus_axis",
}

# Player1 bindings
player1_map = {
    "up": "input_player1_up_btn",
    "down": "input_player1_down_btn",
    "left": "input_player1_left_btn",
    "right": "input_player1_right_btn",
    "a": "input_player1_a_btn",
    "b": "input_player1_b_btn",
    "x": "input_player1_x_btn",
    "y": "input_player1_y_btn",
    "start": "input_player1_start_btn",
    "select": "input_player1_select_btn",
    "leftshoulder": "input_player1_l_btn",
    "rightshoulder": "input_player1_r_btn",
    "lefttrigger": "input_player1_l2_axis",
    "righttrigger": "input_player1_r2_axis",
    "leftthumb": "input_player1_l3_btn",
    "rightthumb": "input_player1_r3_btn",
    "leftanalogleft": "input_player1_l_x_minus_axis",
    "leftanalogright": "input_player1_l_x_plus_axis",
    "leftanalogup": "input_player1_l_y_minus_axis",
    "leftanalogdown": "input_player1_l_y_plus_axis",
    "rightanalogleft": "input_player1_r_x_minus_axis",
    "rightanalogright": "input_player1_r_x_plus_axis",
    "rightanalogup": "input_player1_r_y_minus_axis",
    "rightanalogdown": "input_player1_r_y_plus_axis",
}

# Hotkey = PS button (guide)
hotkey_btn = mapping.get("hotkeyenable", ("button", "5", "1"))
hotkey_val = get_retroarch_value(hotkey_btn[0], hotkey_btn[1], hotkey_btn[2])

# Menu toggle = X button (direct, no hotkey needed - RetroPie style)
x_btn = mapping.get("x", ("button", "3", "1"))
menu_toggle_val = get_retroarch_value(x_btn[0], x_btn[1], x_btn[2])

# Exit = Start button (direct - RetroPie style)
start_btn = mapping.get("start", ("button", "6", "1"))
exit_val = get_retroarch_value(start_btn[0], start_btn[1], start_btn[2])

# Save/Load = R/L
r_btn = mapping.get("rightshoulder", ("button", "10", "1"))
l_btn = mapping.get("leftshoulder", ("button", "9", "1"))
save_val = get_retroarch_value(r_btn[0], r_btn[1], r_btn[2])
load_val = get_retroarch_value(l_btn[0], l_btn[1], l_btn[2])

# Screenshot = Y
y_btn = mapping.get("y", ("button", "2", "1"))
screenshot_val = get_retroarch_value(y_btn[0], y_btn[1], y_btn[2])

# Fast forward = R2
r2 = mapping.get("righttrigger", ("axis", "4", "1"))
ff_val = get_retroarch_value(r2[0], r2[1], r2[2])

# Rewind = L2
l2 = mapping.get("lefttrigger", ("axis", "4", "1"))
rewind_val = get_retroarch_value(l2[0], l2[1], l2[2])

# Reset = B
b_btn = mapping.get("b", ("button", "0", "1"))
reset_val = get_retroarch_value(b_btn[0], b_btn[1], b_btn[2])

# State slots = D-pad left/right
left_btn = mapping.get("left", ("button", "13", "1"))
right_btn = mapping.get("right", ("button", "14", "1"))
slot_dec_val = get_retroarch_value(left_btn[0], left_btn[1], left_btn[2])
slot_inc_val = get_retroarch_value(right_btn[0], right_btn[1], right_btn[2])

# Write global bindings
config_lines.append(f'input_up_btn = "{get_retroarch_value(*mapping.get("up", ("button", "11", "1")))}"')
config_lines.append(f'input_down_btn = "{get_retroarch_value(*mapping.get("down", ("button", "12", "1")))}"')
config_lines.append(f'input_left_btn = "{get_retroarch_value(*mapping.get("left", ("button", "13", "1")))}"')
config_lines.append(f'input_right_btn = "{get_retroarch_value(*mapping.get("right", ("button", "14", "1")))}"')
config_lines.append(f'input_a_btn = "{get_retroarch_value(*mapping.get("a", ("button", "1", "1")))}"')
config_lines.append(f'input_b_btn = "{get_retroarch_value(*mapping.get("b", ("button", "0", "1")))}"')
config_lines.append(f'input_x_btn = "{get_retroarch_value(*mapping.get("x", ("button", "3", "1")))}"')
config_lines.append(f'input_y_btn = "{get_retroarch_value(*mapping.get("y", ("button", "2", "1")))}"')
config_lines.append(f'input_start_btn = "{exit_val}"')
config_lines.append(f'input_select_btn = "{get_retroarch_value(*mapping.get("select", ("button", "4", "1")))}"')
config_lines.append(f'input_l_btn = "{save_val}"')
config_lines.append(f'input_r_btn = "{load_val}"')
config_lines.append(f'input_l2_axis = "{get_retroarch_value(*mapping.get("lefttrigger", ("axis", "4", "1")))}"')
config_lines.append(f'input_r2_axis = "{get_retroarch_value(*mapping.get("righttrigger", ("axis", "4", "1")))}"')
config_lines.append(f'input_l3_btn = "{get_retroarch_value(*mapping.get("leftthumb", ("button", "7", "1")))}"')
config_lines.append(f'input_r3_btn = "{get_retroarch_value(*mapping.get("rightthumb", ("button", "8", "1")))}"')

# Write player1 bindings
for es_name, ra_name in player1_map.items():
    if es_name in mapping:
        config_lines.append(f'{ra_name} = "{get_retroarch_value(*mapping[es_name])}"')

# Hotkey settings
config_lines.append(f'input_enable_hotkey_btn = "{hotkey_val}"')
config_lines.append(f'input_menu_toggle_btn = "{menu_toggle_val}"')
config_lines.append(f'input_exit_emulator_btn = "{exit_val}"')
config_lines.append(f'input_save_state_btn = "{save_val}"')
config_lines.append(f'input_load_state_btn = "{load_val}"')
config_lines.append(f'input_screenshot_btn = "{screenshot_val}"')
config_lines.append(f'input_hold_fast_forward_btn = "{ff_val}"')
config_lines.append(f'input_rewind_btn = "{rewind_val}"')
config_lines.append(f'input_reset_btn = "{reset_val}"')
config_lines.append(f'input_state_slot_decrease_btn = "{slot_dec_val}"')
config_lines.append(f'input_state_slot_increase_btn = "{slot_inc_val}"')
config_lines.append(f'input_menu_toggle_gamepad_combo = "2"')

# Write to temp file
with open(temp_cfg, 'w') as f:
    f.write('\n'.join(config_lines) + '\n')

print(f"Generated RetroArch config with {len(config_lines)} lines")
print(f"Hotkey: PS button (btn {hotkey_val})")
print(f"Menu: X button (btn {menu_toggle_val})")
print(f"Exit: Start (btn {exit_val})")
PYEOF

echo "DONE"

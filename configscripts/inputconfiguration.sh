#!/bin/bash
# Input Configuration Script for PS4 RetroBox
# Reads es_input.cfg and generates matching RetroArch config
# Based on Batocera's libretroControllers.py approach

INPUT_CFG="/home/PS4/.emulationstation/es_input.cfg"
CONFIG_DIR="/home/PS4/.config/retroarch"
RETROARCH_CFG="$CONFIG_DIR/retroarch.cfg"
JOYPAD_DIR="$CONFIG_DIR/all/retroarch-joypads"

if [ ! -f "$INPUT_CFG" ]; then
    echo "ERROR: $INPUT_CFG not found"
    exit 1
fi

mkdir -p "$JOYPAD_DIR"

# Parse es_input.cfg and generate RetroArch config (Batocera logic)
python3 << 'PYEOF'
import xml.etree.ElementTree as ET
import os, re

INPUT_CFG = os.environ.get("INPUT_CFG", "/home/PS4/.emulationstation/es_input.cfg")
CONFIG_DIR = os.environ.get("CONFIG_DIR", "/home/PS4/.config/retroarch")
RETROARCH_CFG = os.path.join(CONFIG_DIR, "retroarch.cfg")
JOYPAD_DIR = os.path.join(CONFIG_DIR, "all", "retroarch-joypads")

RA_KEYS = {
    "up": ["input_up"],
    "down": ["input_down"],
    "left": ["input_left"],
    "right": ["input_right"],
    "a": ["input_a"],
    "b": ["input_b"],
    "x": ["input_x"],
    "y": ["input_y"],
    "leftshoulder": ["input_l"],
    "rightshoulder": ["input_r"],
    "lefttrigger": ["input_l2"],
    "righttrigger": ["input_r2"],
    "leftthumb": ["input_l3"],
    "rightthumb": ["input_r3"],
    "start": ["input_start"],
    "select": ["input_select"],
    "hotkeyenable": ["input_enable_hotkey"],
    "leftanalogleft": ["input_l_x_minus"],
    "leftanalogright": ["input_l_x_plus"],
    "leftanalogup": ["input_l_y_minus"],
    "leftanalogdown": ["input_l_y_plus"],
    "rightanalogleft": ["input_r_x_minus"],
    "rightanalogright": ["input_r_x_plus"],
    "rightanalogup": ["input_r_y_minus"],
    "rightanalogdown": ["input_r_y_plus"],
}
HAT_MAP = {"1": "up", "2": "right", "4": "down", "8": "left"}

tree = ET.parse(INPUT_CFG)
root = tree.getroot()

for inputConfig in root.findall("inputConfig"):
    device_type = inputConfig.get("type", "")
    if device_type != "joystick":
        continue
    device_name = inputConfig.get("deviceName", "")
    if "PS4" not in device_name and "Wireless" not in device_name and "Sony" not in device_name:
        continue

    print(f"Configuring: {device_name}")

    if os.path.exists(RETROARCH_CFG):
        with open(RETROARCH_CFG, 'r') as f:
            lines = f.readlines()
        config_lines = [l for l in lines if not l.startswith("input_")]
    else:
        config_lines = []

    config_lines.append(f'input_driver = "udev"\n')
    config_lines.append(f'input_device = "{device_name}"\n')
    config_lines.append(f'input_autodetect_enable = "true"\n')

    for inp in inputConfig.findall("input"):
        es_name = inp.get("name")
        inp_type = inp.get("type")
        inp_id = inp.get("id")
        inp_value = inp.get("value")

        keys = RA_KEYS.get(es_name, [])
        if not keys:
            continue

        if inp_type == "button":
            for k in keys:
                config_lines.append(f'{k}_btn = "{inp_id}"\n')
        elif inp_type == "hat":
            hat_dir = HAT_MAP.get(inp_value, "")
            if hat_dir:
                for k in keys:
                    config_lines.append(f'{k}_btn = "h{inp_id}{hat_dir}"\n')
        elif inp_type == "axis":
            val = f"+{inp_id}" if int(inp_value) > 0 else f"-{inp_id}"
            for k in keys:
                config_lines.append(f'{k}_axis = "{val}"\n')

    safe_name = re.sub(r'[:<>?"/\\|*]', '', device_name)
    safe_name = re.sub(r'\s+', '_', safe_name)
    joypad_file = os.path.join(JOYPAD_DIR, f"{safe_name}.cfg")
    with open(joypad_file, 'w') as f:
        f.writelines(config_lines)
    print(f"Wrote {len(config_lines)} lines to {joypad_file}")

PYEOF

echo "DONE"

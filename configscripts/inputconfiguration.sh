#!/bin/bash
# Input Configuration Script for PS4 RetroBox
# Reads es_input.cfg and generates matching RetroArch config
# Based on RetroPie's configscripts/retroarch.sh approach

INPUT_CFG="/home/PS4/.emulationstation/es_input.cfg"
CONFIG_DIR="/home/PS4/.config/retroarch"
RETROARCH_CFG="$CONFIG_DIR/retroarch.cfg"
JOYPAD_DIR="$CONFIG_DIR/all/retroarch-joypads"

if [ ! -f "$INPUT_CFG" ]; then
    echo "ERROR: $INPUT_CFG not found"
    exit 1
fi

mkdir -p "$JOYPAD_DIR"

# Parse es_input.cfg and generate RetroArch config
python3 << 'PYEOF'
import xml.etree.ElementTree as ET
import os

input_cfg = os.environ.get("INPUT_CFG", "/home/PS4/.emulationstation/es_input.cfg")
config_dir = os.environ.get("CONFIG_DIR", "/home/PS4/.config/retroarch")
retroarch_cfg = os.path.join(config_dir, "retroarch.cfg")
joypad_dir = os.path.join(config_dir, "all", "retroarch-joypads")

tree = ET.parse(input_cfg)
root = tree.getroot()

for inputConfig in root.findall("inputConfig"):
    device_type = inputConfig.get("type", "")
    if device_type != "joystick":
        continue
    device_name = inputConfig.get("deviceName", "")
    device_guid = inputConfig.get("deviceGUID", "")
    if "PS4" not in device_name and "Wireless" not in device_name and "Sony" not in device_name:
        continue

    print(f"Configuring: {device_name}")

    # Read the current retroarch.cfg to preserve non-input settings
    with open(retroarch_cfg, 'r') as f:
        lines = f.readlines()

    # Keep only non-input lines
    config_lines = []
    for line in lines:
        if not line.startswith("input_"):
            config_lines.append(line)

    # Add device info
    config_lines.append(f'input_driver = "udev"\n')
    config_lines.append(f'input_device = "{device_name}"\n')
    config_lines.append(f'input_autodetect_enable = "true"\n')

    # Map each ES input to RetroArch config
    for inp in inputConfig.findall("input"):
        es_name = inp.get("name")
        inp_type = inp.get("type")
        inp_id = inp.get("id")
        inp_value = inp.get("value")

        if inp_type == "hat":
            hat_map = {"1": "up", "2": "right", "4": "down", "8": "left"}
            hat_dir = hat_map.get(inp_value, "")
            if hat_dir:
                config_lines.append(f'input_{es_name} = "h{inp_id}{hat_dir}"\n')
                config_lines.append(f'input_{es_name}_btn = "h{inp_id}{hat_dir}"\n')
        elif inp_type == "axis":
            val = f"+{inp_id}" if int(inp_value) > 0 else f"-{inp_id}"
            config_lines.append(f'input_{es_name} = "{val}"\n')
            config_lines.append(f'input_{es_name}_axis = "{val}"\n')
        elif inp_type == "button":
            config_lines.append(f'input_{es_name} = "{inp_id}"\n')
            config_lines.append(f'input_{es_name}_btn = "{inp_id}"\n')

    # Write to retroarch-joypads directory (RetroPie style)
    safe_name = "".join(c for c in device_name if c.isalnum() or c in " -_").strip()
    joypad_file = os.path.join(joypad_dir, f"{safe_name}.cfg")
    with open(joypad_file, 'w') as f:
        f.writelines(config_lines)
    print(f"Wrote {len(config_lines)} lines to {joypad_file}")

PYEOF

echo "DONE"

#!/usr/bin/env bash
# RetroArch configscript for PS4 RetroBox
# Reads es_input.cfg and generates retroarch.cfg using Batocera logic
# Reference: /tmp/batocera-extract/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroControllers.py

CONFIG_DIR="/home/PS4/.config/retroarch"
RETROARCH_CFG="$CONFIG_DIR/retroarch.cfg"
JOYPAD_DIR="$CONFIG_DIR/all/retroarch-joypads"
INPUT_CFG="/home/PS4/.emulationstation/es_input.cfg"

mkdir -p "$CONFIG_DIR"
mkdir -p "$JOYPAD_DIR"
echo "=== Generating RetroArch config from es_input.cfg (Batocera logic) ==="

# Preserve non-input settings, replace input section
cat > "$RETROARCH_CFG" << 'HEADER'
# === Video ===
video_fullscreen = "true"
video_fullscreen_x = "1920"
video_fullscreen_y = "1080"
video_driver = "gl"
video_shared_context = "true"
video_font_enable = "true"
video_font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
video_font_size = "32.000000"

# === Audio ===
audio_driver = "alsa"
audio_device = "plughw:0,3"
audio_sync = "true"
audio_latency = "64"

# === Input driver ===
input_driver = "udev"
input_autodetect_enable = "true"
input_device = "PS4 DS4 Bridge Joystick"
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

# === D-pad (HAT hardware on PS4 — ABS_HAT0X/Y) ===
input_player1_up_btn = "h0up"
input_player1_down_btn = "h0down"
input_player1_left_btn = "h0left"
input_player1_right_btn = "h0right"
input_up_btn = "h0up"
input_down_btn = "h0down"
input_left_btn = "h0left"
input_right_btn = "h0right"
HEADER

# Parse es_input.cfg with python (Batocera-style mapping)
python3 << 'PYEOF'
import xml.etree.ElementTree as ET
import os

INPUT_CFG = "/home/PS4/.emulationstation/es_input.cfg"
RETROARCH_CFG = "/home/PS4/.config/retroarch/retroarch.cfg"
JOYPAD_DIR = "/home/PS4/.config/retroarch/all/retroarch-joypads"

# ES input name → RA player1 input key (Batocera retroarchbtns)
RA_BTNS = {
    "a": "input_player1_a",
    "b": "input_player1_b",
    "x": "input_player1_x",
    "y": "input_player1_y",
    "start": "input_player1_start",
    "select": "input_player1_select",
    "leftshoulder": "input_player1_l",
    "rightshoulder": "input_player1_r",
    "leftthumb": "input_player1_l3",
    "rightthumb": "input_player1_r3",
}

# ES axis name → RA player1 axis key
RA_AXES = {
    "lefttrigger": "input_player1_l2",
    "righttrigger": "input_player1_r2",
    "leftanalogleft": "input_player1_l_x_minus",
    "leftanalogright": "input_player1_l_x_plus",
    "leftanalogup": "input_player1_l_y_minus",
    "leftanalogdown": "input_player1_l_y_plus",
    "rightanalogleft": "input_player1_r_x_minus",
    "rightanalogright": "input_player1_r_x_plus",
    "rightanalogup": "input_player1_r_y_minus",
    "rightanalogdown": "input_player1_r_y_plus",
}

# ES input name → RA special action key (Batocera retroarchspecials)
RA_SPECIALS = {
    "start": "input_exit_emulator",
    "b": "input_menu_toggle",
    "y": "input_save_state",
    "x": "input_load_state",
    "a": "input_reset",
    "up": "input_state_slot_increase",
    "left": "input_rewind",
    "right": "input_hold_fast_forward",
    "lefttrigger": "input_shader_prev",
    "righttrigger": "input_shader_next",
}

HAT_MAP = {"1": "up", "2": "right", "4": "down", "8": "left"}

tree = ET.parse(INPUT_CFG)
root = tree.getroot()

with open(RETROARCH_CFG, "a") as cfg:
    hotkey_id = None
    joystick_inputs = []
    for inputConfig in root.findall("inputConfig"):
        if inputConfig.get("type") != "joystick":
            continue
        device_name = inputConfig.get("deviceName", "")
        if "PS4" not in device_name and "Wireless" not in device_name and "Sony" not in device_name:
            continue

        cfg.write(f'# Controller: {device_name}\n')
        cfg.write(f'input_player1_joypad_index = "1"\n')
        cfg.write(f'input_player1_analog_dpad_mode = "1"\n')

        for inp in inputConfig.findall("input"):
            name = inp.get("name")
            typ = inp.get("type")
            idx = inp.get("id")
            val = inp.get("value")

            if name == "hotkeyenable":
                hotkey_id = idx
                continue

            if typ == "button":
                if name in RA_BTNS:
                    cfg.write(f'{RA_BTNS[name]}_btn = "{idx}"\n')
                if name in RA_SPECIALS:
                    cfg.write(f'{RA_SPECIALS[name]}_btn = "{idx}"\n')
            elif typ == "axis":
                sign = "+" if int(val) > 0 else "-"
                axis_val = f"{sign}{idx}"
                if name in RA_AXES:
                    cfg.write(f'{RA_AXES[name]}_axis = "{axis_val}"\n')
                if name in RA_SPECIALS:
                    cfg.write(f'{RA_SPECIALS[name]}_axis = "{axis_val}"\n')
            elif typ == "hat":
                if val in HAT_MAP:
                    hat_str = f"h{idx}{HAT_MAP[val]}"
                    if name in RA_BTNS:
                        cfg.write(f'{RA_BTNS[name]}_btn = "{hat_str}"\n')

        if hotkey_id is not None:
            cfg.write(f'input_enable_hotkey_btn = "{hotkey_id}"\n')

    # Per-device joypad file (RetroPie autoconfig layout)
    safe_name = "".join(c for c in device_name if c.isalnum() or c in " -_").strip()
    joypad_path = os.path.join(JOYPAD_DIR, f"{safe_name}.cfg")
    with open(joypad_path, "w") as jp:
        jp.write(f'input_driver = "udev"\n')
        jp.write(f'input_device = "Sony Interactive Entertainment Wireless Controller"\n')
        jp.write(f'input_autodetect_enable = "true"\n')

print("retroarch.cfg generated from es_input.cfg (Batocera logic)")
print(f"Hotkey button: {hotkey_id}")
PYEOF

echo "Generated $RETROARCH_CFG"
echo "Joypad files in $JOYPAD_DIR"

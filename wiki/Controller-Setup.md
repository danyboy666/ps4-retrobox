# Controller Setup

## DualShock 4 (DS4)

The DS4 uses the **hid-generic** driver via `usbhid.quirks` in bootargs.txt. This prevents `hid_playstation` from crashing the xhci_aeolia USB controller.

**Connection:** USB wired only (Bluetooth not supported on CUH-1000/1100). Use a good cable — bad cables cause disconnects.

### DS4 Button Mapping (verified on PS4 hardware)

| DS4 Button | js0 Button | ES | RetroArch |
|------------|-----------|-----|-----------|
| D-Pad | Hat switch | Navigate | D-Pad |
| Left Stick | Axes 0,1 | Navigate | Left Analog |
| Cross | btn 1 | Confirm | A |
| Circle | btn 0 | Back | B |
| Triangle | btn 2 | Info | X |
| Square | btn 3 | Details | Y |
| L1 | btn 4 | Page Up | L1 |
| R1 | btn 5 | Page Down | R1 |
| L2 | axis 2 | — | L2 |
| R2 | axis 5 | — | R2 |
| Start | btn 9 | — | Start |
| Select | btn 8 | — | Select |
| L3 Click | btn 10 | — | L3 |
| R3 Click | btn 11 | — | R3 |
| PS Button | btn 12 | — | Guide/Hotkey |

### RetroArch Hotkey Combo

| Combo | Action |
|-------|--------|
| **Hold Select + Cross** | Open RetroArch Menu |
| **Hold Select + Start** | Exit Game |
| **Hold Select + L1** | Load State |
| **Hold Select + R1** | Save State |
| **Hold Select + Left** | Decrease State Slot |
| **Hold Select + Right** | Increase State Slot |
| **Hold Select + Triangle** | Screenshot |
| **Hold Select + Square** | Fast Forward |

Hold **Select**, then press the second button. Select must be held the entire time.

### RetroArch Configuration

RetroArch uses a configscript that reads ES input and generates RetroArch config:

```bash
ssh PS4@<PS4-IP>   # Password: PS4
/usr/local/bin/retroarch-configscript.sh
```

### Multi-Controller Support

437 official RetroArch autoconfig profiles at `/usr/share/retroarch/assets/autoconfig/udev/`. Any RetroArch-compatible controller auto-detects. For unmapped controllers, use ES → Configure Input → run configscript.

## DS4 Lightbar LED

Customize the DS4 lightbar color via SSH:

```bash
ssh PS4@<PS4-IP>
nano ~/.emulationstation/ds4_led.cfg
```

```xml
<?xml version="1.0"?>
<config>
  <string name="Color" value="purple" />
  <string name="Pattern" value="solid" />
</config>
```

**Colors:** `purple`, `red`, `green`, `blue`, `orange`, `cyan`, `magenta`, `yellow`, `white`, `off`

**Patterns:** `solid`, `breathing`, `fast_breathing`, `pulse`, `off`

Script: `/usr/local/bin/ds4-led.sh` — reads config on ES startup.

## CLI Access

### SSH (recommended)
```bash
ssh PS4@<PS4-IP>  # Password: PS4
```

### Virtual Terminal (USB keyboard)
1. **Ctrl+Alt+F2** → tty2 login
2. Type `exit`, then **Ctrl+Alt+F1** → back to ES

### Kill ES (returns to shell)
```bash
killall emulationstation
```
Restart: `emulationstation &`

### Useful Commands
```bash
uname -a                    # Kernel version
free -h                     # RAM usage
df -h /                     # Disk usage
ip a                        # IP addresses
sudo shutdown -h now        # Shutdown
sudo reboot                 # Restart
dmesg | tail                # Kernel messages
```

## Supported Systems

| System | Core | BIOS Required |
|--------|------|---------------|
| Super Nintendo | bsnes-mercury-balanced | No |
| NES | Nestopia | No |
| Nintendo 64 | mupen64plus | No |
| Game Boy Advance | mGBA | Optional (gba_bios.bin) |
| Game Boy | Gambatte | No |
| Game Boy Color | Gambatte | No |
| Sega Mega Drive | Genesis Plus GX | No |
| PlayStation | Mednafen PSX | Yes (SCPH1001.bin) |
| TurboGrafx-16 | Mednafen PCE Fast | No |
| TurboGrafx-CD | Mednafen PCE Fast | Yes (syscard3.pce) |
| Arcade | FinalBurn Neo | No |
| Neo Geo | FinalBurn Neo | No |
| Atari 2600 | Stella | No |
| Atari 5200 | atari800 | No |
| Atari 7800 | ProSystem | No |
| Sega Master System | Genesis Plus GX | No |
| Sega Game Gear | Genesis Plus GX | No |

## ROM Directories

```
ROMS/
├── snes/  nes/  n64/  gba/  gb/  gbc/
├── megadrive/  psx/  tg16/  tgcd/
├── arcade/  neogeo/
├── atari2600/  atari5200/  atari7800/
├── mastersystem/  gamegear/
```

BIOS: `/home/PS4/BIOS/`
Saves: `/home/PS4/saves/`
Screenshots: `/home/PS4/screenshots/`

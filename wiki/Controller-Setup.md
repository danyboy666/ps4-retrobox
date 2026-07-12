# Controller Setup

## DualShock 4 (Wired USB)

DS4 connected via USB is the primary controller.

### Button Mapping

| DS4 Button | Button ID | ES Action | RetroArch |
|-----------|-----------|-----------|-----------|
| Cross (X) | 1 | Confirm | A |
| Circle | 0 | Back | B |
| Square | 3 | | X |
| Triangle | 2 | | Y |
| L1 | 4 | Page Up | L |
| R1 | 5 | Page Down | R |
| L2 (axis) | 4 | | L2 (analog) |
| R2 (axis) | 4 | | R2 (analog) |
| Select | 4 | Select | Select |
| Start | 6 | Start | Start |
| L3 (axis) | 5 | | L3 |
| R3 (axis) | 5 | | R3 |
| **PS (Guide)** | **5** | | **Hotkey Enable** |
| D-Pad | h0up/down/left/right | Navigation | D-Pad |
| Left Stick | +0/-0/+1/-1 | Navigation | Left Stick |
| Right Stick | +3/-3/+4/-4 | | Right Stick |

## Hotkey System

The **PS button (Guide)** is the hotkey modifier. Hold it + press a button for combos:

| Combo | Action |
|-------|--------|
| PS + X | Open RetroArch menu |
| PS + Start | Exit emulator |
| PS + R1 | Save state |
| PS + L1 | Load state |
| PS + Y | Screenshot |
| PS + R2 | Fast forward |
| PS + L2 | Rewind |
| PS + A | Reset |
| PS + D-Pad Left | State slot - |
| PS + D-Pad Right | State slot + |

**No hotkey = direct button press** (Start = Start, X = X, etc.)

## Reconfiguring Controller Mapping

Users can reconfigure at any time:

### From EmulationStation
1. Press **Start** → Controller Settings → Configure Input
2. Map each button when prompted
3. Press **A** to save — ES will auto-generate RetroArch config

### From command line
```bash
# Edit ES button mapping
nano /home/PS4/.emulationstation/es_input.cfg

# Edit RetroArch hotkey/button config
nano /home/PS4/.config/retroarch/retroarch.cfg

# Edit RetroArch appendconfig (overrides retroarch.cfg for RetroArch)
nano /home/PS4/.config/retroarch/retroarch-ps4.cfg
```

### Config file hierarchy
1. **es_input.cfg** — ES button mapping (input configuration menu saves here)
2. **retroarch.cfg** — Main RetroArch config (base button mapping + hotkey settings)
3. **retroarch-ps4.cfg** — Appendconfig loaded on top of retroarch.cfg (for RetroArch-specific overrides)

## Other Controllers

Other USB controllers may work but are untested. The DS4 wired USB is the only confirmed controller.

> **⚠ Do NOT load `hid-sony` kernel module** — it crashes the PS4's USB controller (xhci_aeolia).

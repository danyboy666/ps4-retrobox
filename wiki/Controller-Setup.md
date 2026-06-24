# Controller Setup

## DualShock 4 (Wired USB)

DS4 connected via USB is the primary controller. Button mapping:

| DS4 Button | Button ID | ES Action | RetroArch |
|-----------|-----------|-----------|-----------|
| Cross (X) | 1 | Confirm | A |
| Circle | 0 | Back | B |
| Square | 2 | | X |
| Triangle | 3 | | Y |
| L1 | 4 | Page Up | L |
| R1 | 5 | Page Down | R |
| L2 | +6 | | L2 (analog) |
| R2 | +7 | | R2 (analog) |
| Select | 8 | | Hotkey Enable |
| Start | 9 | | Start |
| L3 | 10 | | L3 |
| R3 | 11 | | R3 |
| PS | 12 | | Guide |
| D-Pad | h0up/down/left/right | Navigation | D-Pad |
| Left Stick | +0/-0/+1/-1 | Navigation | Left Stick |
| Right Stick | +3/-3/+4/-4 | | Right Stick |

## Hotkeys

| Combo | Action |
|-------|--------|
| Select + Cross | Open RetroArch Menu |
| Start (alone) | Start game |
| Select (alone) | Select |

## Customizing Buttons

Edit the ES input config:

```bash
nano /home/PS4/.emulationstation/es_input.cfg
```

Edit the RetroArch appendconfig:

```bash
nano /home/PS4/.config/retroarch/retroarch-ps4.cfg
```

## Other Controllers

Other USB controllers may work but are untested. The DS4 wired USB is the only confirmed controller.

> **⚠ Do NOT load `hid-sony` kernel module** — it crashes the PS4's USB controller (xhci_aeolia).

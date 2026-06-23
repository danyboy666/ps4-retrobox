# Troubleshooting

## Display Issues

| Problem | Fix |
|---------|-----|
| Black screen on boot | Check `bootargs.txt` has `video=HDMI-A-0:1920x1080@60`. Try different TV/monitor. Ensure PS4 video settings: 1080p, HDR OFF, Deep Color OFF, HDCP OFF |
| Garbled GUI / white screen | Remove `drm.edid_firmware=edid/1920x1080.bin` from bootargs.txt (causes garbled display). Check PS4 video settings. |
| No signal after SSH changes | Restart ES: `sudo systemctl restart es-session.service` |
| ES sluggish | Software GL rendering at 1080p. PS4 kernel lacks amdgpu firmware for hardware GL. |

## Input Issues

| Problem | Fix |
|---------|-----|
| DS4 not detected | Check USB cable (bad cables cause disconnects). Try different USB port. |
| DS4 buttons wrong in RetroArch | Run configscript: `/usr/local/bin/retroarch-configscript.sh` |
| Keyboard not working in RetroArch | Should work via udev autodetect. Try re-plugging keyboard. |
| Start exits game | Hold Select + Start to exit. Just pressing Start should not exit. |
| Can't exit RetroArch menu | Press Select + Cross to open menu. Select + Start to exit. |

## Network Issues

| Problem | Fix |
|---------|-----|
| SSH refused | Ensure Ethernet cable connected. Try `ping <PS4-IP>`. |
| No IP address | Check Ethernet cable is connected to router. Run `ip a` on PS4. |
| WiFi not working | WiFi not supported on CUH-1000/1100 (Aeolia v1). Use Ethernet. |
| Samba mount fails | Check PC IP, firewall, share name. Run `sudo setup-samba.sh --setup`. |

## Installation Issues

| Problem | Fix |
|---------|-----|
| Install fails | Verify all 4 FTP files at correct paths. Check `/ps4hdd/system/boot/install.log`. Try 1GB payload. |
| `.img` already exists | Run `sudo rm /ps4hdd/home/arch.img` then `exec install-HDD.sh` |
| Black screen after install | Check `bootargs.txt` exists at `/data/linux/boot/bootargs.txt`. Try different TV. |
| PS4 freezes during jailbreak | Hold power button 7-10s to force shutdown. Try again. |

## Sound Issues

| Problem | Fix |
|---------|-----|
| No audio in RetroArch | PulseAudio configured. Check `pactl list sinks short`. Audio driver may need investigation. |
| ALSA errors | Non-fatal. PulseAudio handles audio. |

## Other Issues

| Problem | Fix |
|---------|-----|
| DS4 LED stays on after exit | Known bug. Reset manually via `/sys/class/leds/` |
| BIOS not found | Copy BIOS files to `/home/PS4/BIOS/` via SCP |
| ROMs not showing in ES | Check `ls /home/PS4/ROMS/`. Restart ES. |
| Plymouth not showing | Known issue. Boot splash not rendering on PS4 kernel. |

## Payload Sizes

| Payload | Use When | VRAM |
|---------|----------|------|
| `payload-960-1gb.elf` | Initial install only | 1GB |
| `payload-960-2gb.elf` | Daily gaming (recommended) | 2GB |
| `payload-960-3gb.elf` | More GPU RAM | 3GB |
| `payload-960-4gb.elf` | Maximum GPU RAM | 4GB |

## Supported PS4 Models

| Model | Southbridge | Kernel | Status |
|-------|-------------|--------|--------|
| Fat CUH-1000/1100 | Aeolia | bzImage_no-built-in-fw_Clang_fullLTO | Tested |
| Fat CUH-1200 / Slim CUH-2000 | Belize | bzImage_no-built-in-fw_Clang_fullLTO | Not tested |
| Pro CUH-7000 | Baikal | bzImage_Baikal_5.4.247 | Not tested |

## Building from Source

```bash
sudo apt-get install debootstrap qemu-user-static git cmake build-essential
sudo ./build.sh /mnt/ps4root
```

Build script bootstraps Ubuntu 24.04, installs packages, compiles EmulationStation, builds RetroArch with DRM support, packages as `arch.tar.xz`.

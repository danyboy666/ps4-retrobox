# PS4 RetroBox

> **DISCLAIMER**: Assembled by AI assistant (OpenCode). Use at your own risk. Author assumes no responsibility for console damage.

> **v1.3 — WORK IN PROGRESS**  
> Not a stable release. Sound, controller mapping, Plymouth, and many features need testing/fixes. See [Known Issues](#known-issues).

## What It Does

Turns a jailbroken PS4 into a retro gaming machine running **EmulationStation** + **RetroArch** on **Ubuntu 24.04**, installed directly on the PS4's internal HDD. No USB drive needed after setup.

## What Works (v1.3, CUH-1000/1100 Aeolia)

- [x] Jailbreak + payload → Linux boot → EmulationStation
- [x] ES at 1080p with hardware GL (radeonsi + amdgpu_shim.so)
- [x] 17 retro systems with 12 libretro cores
- [x] RetroArch 1.22.2 — ROMs launch and run
- [x] DS4 wired USB — buttons work in ES
- [x] SSH access (port 22)
- [x] Install: 3GB base + optional expansion

## Known Issues (v1.3)

- [ ] Sound not working (PulseAudio configured, ALSA errors)
- [ ] DS4 button mapping wrong in RetroArch
- [ ] No controller/keyboard in RetroArch settings menu
- [ ] RetroArch menu shows old rgui instead of xmb
- [ ] Plymouth boot splash not rendering
- [ ] UFS ROMs folder permissions untested
- [ ] Other controllers untested
- [ ] ES Configure Input not validated
- [ ] FTP disabled by default
- [ ] Network helpers untested
- [ ] ES sluggishness (software GL, needs kernel amdgpu firmware)

## Quick Start

### First Time Install
1. Download [v1.3 ZIP](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.3)
2. Rename kernel to `bzImage`, FTP 4 files to PS4 (port 2121)
3. Jailbreak → GoldHEN → BinLoader → send **1GB payload**
4. Install runs automatically → choose 3GB or expand

### Daily Use
1. Jailbreak → GoldHEN → BinLoader → send **2GB payload**
2. Linux boots → EmulationStation → play!

See [Installation Guide](wiki/Installation-Guide.md) for full details.

## Requirements

- PS4 Fat CUH-1000/1100 (Aeolia) — only tested model
> **⚠ Firmware: Only tested on 9.60.** Other FW versions may work but are unverified.
- Firmware 5.05–13.02 (any jailbreak-compatible)
- Ethernet cable required (WiFi not supported on CUH-1000/1100)
- Windows PC on same network (for initial FTP)

## Quick Links

- [Installation Guide](wiki/Installation-Guide.md) — Full setup walkthrough
- [Controller Setup](wiki/Controller-Setup.md) — DS4 mapping, hotkeys, RetroArch config
- [Troubleshooting](wiki/Troubleshooting.md) — Common issues and fixes
- [Network & File Transfer](wiki/Network-File-Transfer.md) — SSH, SCP, Samba, FTP, USB
- [Build from Source](wiki/Troubleshooting.md#building-from-source) — Rebuild rootfs

## Project Structure

| Repo | Description |
|------|-------------|
| [ps4-retrobox](https://github.com/danyboy666/ps4-retrobox) | Main repo — build scripts, initramfs, configs, releases |
| [EmulationStation](https://github.com/danyboy666/EmulationStation) | PS4 fork — 25-button input, configscripts |
| [RetroArch](https://github.com/danyboy666/RetroArch) | PS4 patches — KMS context, DRM modesetting |

## Roadmap

| Version | Focus |
|---------|-------|
| v1.3 | Current WIP — radeonsi+shim, 24.04, RetroArch 1.22.2 |
| v1.4 | Fix sound, DS4 RetroArch mapping, RetroArch menu, Plymouth |
| v1.5 | UFS ROM permissions, all controllers, ES input validation |
| v1.6 | Network helpers, FTP, full install flow validation |
| v1.7 | Performance (needs kernel amdgpu firmware) |
| v2.0 | Stable release candidate |

## Credits

- [Piotr Karbowski](https://bitbucket.org/piotrkarbowski/better-initramfs) — better-initramfs
- [feeRnt](https://github.com/feeRnt/ps4-linux-initramfs) — PS4 initramfs adaptation
- [Aloshi](https://github.com/Aloshi/EmulationStation) — EmulationStation
- [RetroPie](https://github.com/RetroPie/EmulationStation) — 25-button input, configscripts
- [libretro](https://www.libretro.com) — RetroArch and libretro cores
- [feeRnt](https://github.com/feeRnt/ps4-linux-12xx) — PS4 Linux kernel
- [ArabPixel](https://github.com/ArabPixel) + [rmuxnet](https://github.com/rmuxnet) — PS4 Linux loader

## License

This project combines open-source software. See individual licenses for each component.

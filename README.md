# PS4 RetroBox

> **DISCLAIMER**: Assembled by AI assistant (OpenCode). Use at your own risk. Author assumes no responsibility for console damage.

> **v1.3 — WORK IN PROGRESS**  
> Not a stable release. Sound, Plymouth, and some features need testing. See [Known Issues](#known-issues).

## What It Does

Turns a jailbroken PS4 into a retro gaming machine running **EmulationStation** + **RetroArch** on **Ubuntu 24.04**, installed directly on the PS4's internal HDD. No USB drive needed after setup.

## What Works (v1.3, CUH-1000/1100 Aeolia)

- [x] Jailbreak + payload → Linux boot → EmulationStation
- [x] ES at 1080p with hardware GL (radeonsi + amdgpu_shim.so)
- [x] **39 retro systems** with **27 libretro cores**
- [x] RetroArch 1.22.2 — ROMs launch and run
- [x] DS4 wired USB — buttons work in ES and RetroArch
- [x] Launching images before games start (ffmpeg + framebuffer)
- [x] SSH access (port 22)
- [x] Install: 3GB base + optional expansion

## Supported Systems

| System | Core | Extensions |
|--------|------|-----------|
| **Nintendo** | | |
| Super Nintendo (snes) | snes9x | .sfc .smc .zip |
| Super Famicom (sfc) | snes9x | .sfc .smc .zip |
| Nintendo Entertainment System (nes) | nestopia | .nes .zip |
| Famicom (famicom) | nestopia | .nes .zip |
| Famicom Disk System (fds) | mesen | .fds .zip |
| Nintendo 64 (n64) | mupen64plus | .n64 .z64 .v64 .zip |
| Game Boy (gb) | gambatte | .gb .zip |
| Game Boy Color (gbc) | gambatte | .gbc .zip |
| Game Boy Advance (gba) | mgba | .gba .zip |
| Virtual Boy (virtualboy) | mednafen_vb | .vb .zip |
| **Sega** | | |
| Mega Drive (megadrive) | genesis_plus_gx | .md .bin .gen .smd .zip |
| Genesis (genesis) | genesis_plus_gx | .md .bin .gen .smd .zip |
| Sega CD / Mega CD (segacd) | genesis_plus_gx | .bin .cue .iso .chd .zip |
| Mega CD (mega-cd) | genesis_plus_gx | .bin .cue .iso .chd .zip |
| Sega 32X (sega32x) | picodrive | .32x .bin .smd .zip |
| Master System (mastersystem) | genesis_plus_gx | .sms .bin .gen .zip |
| Game Gear (gamegear) | genesis_plus_gx | .gg .bin .zip |
| SG-1000 (sg-1000) | gearsystem | .sg .bin .zip |
| **Sony** | | |
| PlayStation (psx) | mednafen_psx | .bin .cue .iso .pbp .chd .m3u .zip |
| PlayStation Portable (psp) | ppsspp | .iso .cso .pbp .zip |
| **NEC** | | |
| TurboGrafx-16 (tg16) | mednafen_pce_fast | .pce .cue .zip |
| TurboGrafx-CD (tgcd) | mednafen_pce_fast | .chd .cue .iso .m3u |
| SuperGrafx (supergrafx) | mednafen_supergrafx | .pce .sg .zip |
| **Atari** | | |
| Atari 2600 (atari2600) | stella | .a26 .bin .rom .zip |
| Atari 5200 (atari5200) | atari800 | .a52 .bin .xfd .atari .zip |
| Atari 7800 (atari7800) | prosystem | .a78 .bin .zip |
| Atari Jaguar (atarijaguar) | virtualjaguar | .j64 .jag .zip |
| Atari Lynx (atarilynx) | mednafen_lynx | .lnx .zip |
| **SNK** | | |
| Neo Geo (neogeo) | fbneo | .zip |
| Neo Geo Pocket (ngp) | mednafen_ngp | .ngp .zip |
| Neo Geo Pocket Color (ngpc) | mednafen_ngp | .ngc .zip |
| **Bandai** | | |
| WonderSwan (wonderswan) | mednafen_wswan | .ws .wsc .zip |
| WonderSwan Color (wonderswancolor) | mednafen_wswan | .wsc .zip |
| **Arcade** | | |
| Arcade (arcade) | fbneo | .zip |
| MAME (mame-libretro) | mame2003_plus | .zip |
| **Others** | | |
| ColecoVision (colecovision) | gearcoleco | .col .bin .zip |
| Fairchild Channel F (channelf) | freechaf | .chf .bin .zip |
| Game and Watch (gameandwatch) | gw | .gw .zip |
| GCE Vectrex (vectrex) | vecx | .vec .zip |

## Known Issues (v1.3)

- [ ] Sound not working (PulseAudio configured, ALSA errors)
- [ ] Plymouth boot splash not rendering (amdgpu DRM limitation)
- [ ] Other controllers untested
- [ ] Network helpers untested
- [ ] FTP disabled by default

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
- [Supported Systems](wiki/Systems.md) — Full list of 39 systems with cores and ROM formats
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
| v1.3 | Current WIP — radeonsi+shim, 24.04, RetroArch 1.22.2, 39 systems, launching images |
| v1.4 | Fix sound, Plymouth, other controllers |
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
- [ehettervik](https://github.com/ehettervik/es-runcommand-splash) — Launching images
- [feeRnt](https://github.com/feeRnt/ps4-linux-12xx) — PS4 Linux kernel
- [ArabPixel](https://github.com/ArabPixel) + [rmuxnet](https://github.com/rmuxnet) — PS4 Linux loader

## License

This project combines open-source software. See individual licenses for each component.

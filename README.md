# PS4 RetroBox

> **DISCLAIMER**: Assembled by AI assistant (OpenCode). Use at your own risk. Author assumes no responsibility for console damage.

> **v1.4 — PARTIALLY WORKING**  
> Most systems have NOT been tested yet. N64 does not launch. See [Known Issues](#known-issues).

## What It Does

Turns a jailbroken PS4 into a retro gaming machine running **EmulationStation** + **RetroArch** on **Ubuntu 24.04**, installed directly on the PS4's internal HDD. No USB drive needed after setup.

## What Works (v1.4, CUH-1000/1100 Aeolia)

- [x] Jailbreak + payload → Linux boot → EmulationStation
- [x] ES at 1080p with hardware GL (radeonsi + amdgpu_shim.so)
- [x] **39 retro systems** with **27 libretro cores**
- [x] RetroArch 1.22.2 — multiple ROMs confirmed working
- [x] Audio via PulseAudio → HDMI output
- [x] DS4 wired USB — buttons work in ES
- [x] Launching images before games start (Python PIL + fb0)
- [x] SSH access (port 22)
- [x] Install: 3GB base + optional expansion
- [x] Open-source Neo Geo BIOS included (ngdevkit nullbios)
- [x] UFS permissions — .img deletable from FTP via HEN
- [x] HDMI signal recovery after TV close/reopen

## Supported Systems

| System | Core | BIOS | Status |
|--------|------|------|--------|
| **Nintendo** | | | |
| Super Nintendo (snes) | snes9x | No | ✓ Working |
| Super Famicom (sfc) | snes9x | No | Untested |
| NES (nes) | nestopia | No | ✓ Working |
| Famicom (famicom) | nestopia | No | Untested |
| Famicom Disk System (fds) | mesen | No | Untested |
| Nintendo 64 (n64) | mupen64plus | No | ✗ Not working |
| Game Boy (gb) | gambatte | No | ✓ Working |
| Game Boy Color (gbc) | gambatte | No | ✓ Working |
| Game Boy Advance (gba) | mgba | No | ✓ Working |
| Virtual Boy (virtualboy) | mednafen_vb | No | Untested |
| **Sega** | | | |
| Mega Drive (megadrive) | genesis_plus_gx | No | ✓ Working |
| Genesis (genesis) | genesis_plus_gx | No | ✓ Working |
| Master System (mastersystem) | genesis_plus_gx | No | ✓ Working |
| Game Gear (gamegear) | genesis_plus_gx | No | ✓ Working |
| SG-1000 (sg-1000) | gearsystem | No | Untested |
| Sega 32X (sega32x) | picodrive | Yes | Untested |
| Sega CD (segacd) | genesis_plus_gx | Optional | Untested |
| Mega CD (mega-cd) | genesis_plus_gx | Optional | Untested |
| **Sony** | | | |
| PlayStation (psx) | mednafen_psx | Yes | ✓ Working |
| PlayStation Portable (psp) | ppsspp | Yes | Untested |
| **NEC** | | | |
| TurboGrafx-16 (tg16) | mednafen_pce_fast | No | ✓ Working |
| TurboGrafx-CD (tgcd) | mednafen_pce_fast | Yes | Untested |
| SuperGrafx (supergrafx) | mednafen_supergrafx | No | Untested |
| **Atari** | | | |
| Atari 2600 (atari2600) | stella | No | ✓ Working |
| Atari 5200 (atari5200) | atari800 | Yes | ✓ Working |
| Atari 7800 (atari7800) | prosystem | No | ✓ Working |
| Atari Jaguar (atarijaguar) | virtualjaguar | No | Untested |
| Atari Lynx (atarilynx) | mednafen_lynx | No | Untested |
| **SNK** | | | |
| Neo Geo (neogeo) | fbneo | Included | ✓ Working |
| Neo Geo Pocket (ngp) | mednafen_ngp | No | Untested |
| Neo Geo Pocket Color (ngpc) | mednafen_ngp | No | Untested |
| **Bandai** | | | |
| WonderSwan (wonderswan) | mednafen_wswan | No | Untested |
| WonderSwan Color (wonderswancolor) | mednafen_wswan | No | Untested |
| **Arcade** | | | |
| Arcade (arcade) | fbneo | Depends | ✓ Working (needs BIOS for most games) |
| MAME (mame-libretro) | mame2003_plus | Depends | Untested |
| **Others** | | | |
| ColecoVision (colecovision) | gearcoleco | No | Untested |
| Fairchild Channel F (channelf) | freechaf | No | Untested |
| Game & Watch (gameandwatch) | gw | No | Untested |
| GCE Vectrex (vectrex) | vecx | No | Untested |

## Known Issues (v1.4)

- [ ] N64 does not launch (mupen64plus core crashes)
- [ ] Most systems NOT tested yet — all emus need testing
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
| v1.3 | Stable — radeonsi+shim, 24.04, RetroArch 1.22.2, launching images, audio via HDMI |
| v1.4 | **Current** — 39 systems, 27 cores, Neo Geo BIOS, PIL launching images, HDMI recovery, UFS permissions |
| v1.5 | Fix N64, test all helper scripts, Plymouth boot splash |
| v1.6 | Fix carbon theme, add more themes, controller hotkey/menu navigation |
| v1.7 | Other controllers, network helpers, FTP |
| v1.8 | Full install flow validation, performance (kernel amdgpu firmware) |
| v1.9 | Stable release candidate |
| v2.0 | PS4 PKG app — auto-detect southbridge, select payload, user choice: new install vs boot existing .img |

## Build From Source

### Pre-built (recommended)

Download the [latest release](https://github.com/danyboy666/ps4-retrobox/releases) — no build needed. FTP to PS4 and boot.

### Full Build (Linux PC)

Requirements:
- x86_64 Linux PC (Ubuntu/Debian)
- `sudo` access
- Internet connection
- ~5GB free disk space
- ~15-30 minutes

```bash
git clone https://github.com/danyboy666/ps4-retrobox.git
cd ps4-retrobox
sudo ./build.sh
```

Output files in `community-files/`:

| File | Description |
|------|-------------|
| `arch.tar.xz` | Ubuntu rootfs with RetroArch, ES, cores |
| `initramfs.cpio.gz` | Boot initramfs |
| `bzImage_*` | Linux kernel |
| `payload-960-*.elf` | PS4 payloads |

### Architecture

```
PS4 payload → initramfs → Ubuntu 24.04 rootfs
                                    │
                          ┌─────────┴─────────┐
                          │  EmulationStation   │
                          │  (SDL2 framebuffer) │
                          └─────────┬─────────┘
                                    │ launch game
                          ┌─────────┴─────────┐
                          │   retroarch-wrapper │
                          │  (stops ES, shows   │
                          │   launching image,   │
                          │   runs RetroArch)    │
                          └─────────┬─────────┘
                                    │
                          ┌─────────┴─────────┐
                          │     RetroArch       │
                          │  (GL + KMS context) │
                          │  amdgpu_shim.so     │
                          │  → radeonsi GPU     │
                          └───────────────────┘
```

The `amdgpu_shim.so` library intercepts `amdgpu_query_info(ACCEL_WORKING)` to return success, tricking Mesa into using the radeonsi driver despite the PS4's kernel not reporting GPU acceleration as ready.

## Credits

- [Piotr Karbowski](https://bitbucket.org/piotrkarbowski/better-initramfs) — better-initramfs
- [feeRnt](https://github.com/feeRnt/ps4-linux-initramfs) — PS4 initramfs adaptation
- [Aloshi](https://github.com/Aloshi/EmulationStation) — EmulationStation
- [RetroPie](https://github.com/RetroPie/EmulationStation) — 25-button input, configscripts
- [libretro](https://www.libretro.com) — RetroArch and libretro cores
- [ehettervik](https://github.com/ehettervik/es-runcommand-splash) — Launching images
- [feeRnt](https://github.com/feeRnt/ps4-linux-12xx) — PS4 Linux kernel
- [ArabPixel](https://github.com/ArabPixel) + [rmuxnet](https://github.com/rmuxnet) — PS4 Linux loader
- [dciabrin](https://github.com/dciabrin/ngdevkit) — ngdevkit nullbios (open-source Neo Geo BIOS)
- [Abdess](https://github.com/Abdess/retrobios) — retrobios (BIOS files reference)

## License

This project combines open-source software. See individual licenses for each component.

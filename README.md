# PS4 RetroBox

> **DISCLAIMER**: Assembled by AI assistant (OpenCode). Use at your own risk. Author assumes no responsibility for console damage.

> **v1.3 — PARTIALLY WORKING**  
> This is a partial release. Most systems have NOT been tested yet. N64 does not launch. See [Known Issues](#known-issues).

## What It Does

Turns a jailbroken PS4 into a retro gaming machine running **EmulationStation** + **RetroArch** on **Ubuntu 24.04**, installed directly on the PS4's internal HDD. No USB drive needed after setup.

## What Works (v1.3, CUH-1000/1100 Aeolia)

- [x] Jailbreak + payload → Linux boot → EmulationStation
- [x] ES at 1080p with hardware GL (radeonsi + amdgpu_shim.so)
- [x] **39 retro systems** with **27 libretro cores**
- [x] RetroArch 1.22.2 — some ROMs confirmed working
- [x] Audio via PulseAudio → HDMI output
- [x] DS4 wired USB — buttons work in ES
- [x] Launching images before games start (ffmpeg + framebuffer)
- [x] SSH access (port 22)
- [x] Install: 3GB base + optional expansion
- [ ] **Not all systems tested** — NES confirmed, N64 broken

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

- [ ] **N64 does not launch** (mupen64plus core crashes)
- [ ] Most systems **NOT tested yet** — all emus need testing
- [ ] Plymouth boot splash not rendering (amdgpu DRM limitation)
- [ ] Controller hotkey/menu navigation needs verification
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
| v1.3 | Current — radeonsi+shim, 24.04, RetroArch 1.22.2, 39 systems, launching images, audio via HDMI |
| v1.4 | Fix N64, test all systems, Plymouth, other controllers |
| v1.5 | UFS ROM permissions, all controllers, ES input validation |
| v1.6 | Network helpers, FTP, full install flow validation |
| v1.7 | Performance (needs kernel amdgpu firmware) |
| v2.0 | Stable release candidate |

## Build From Source

### Quick Build (pre-built rootfs)

Download the [v1.3 ZIP](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.3) — no build needed. Just FTP the files to your PS4 and boot.

### Full Build (from scratch)

Requirements:
- Ubuntu/Debian host with `sudo` access
- Internet connection
- ~5GB free disk space
- ~30-60 minutes

```bash
git clone https://github.com/danyboy666/ps4-retrobox.git
cd ps4-retrobox
sudo ./build.sh
```

This will:
1. Bootstrap Ubuntu 24.04 rootfs (~1.8GB)
2. Build RetroArch 1.22.2 from source with DRM/KMS support
3. Build EmulationStation from the PS4 fork
4. Compile the amdgpu_shim.so (intercepts ACCEL_WORKING for radeonsi)
5. Download 27 libretro cores from the buildbot
6. Install 39 system configs, launching images, carbon theme
7. Package as `community-files/arch.tar.xz`
8. Rebuild initramfs from source tree

Output files in `community-files/`:
| File | Size | Description |
|------|------|-------------|
| `arch.tar.xz` | ~250MB | Ubuntu rootfs with RetroArch, ES, cores, configs |
| `initramfs.cpio.gz` | ~8MB | Boot initramfs with Plymouth splash |
| `bzImage_*` | ~9-18MB | Linux kernel (provided, not built by build.sh) |
| `payload-960-*.elf` | ~300KB each | PS4 payloads for 1GB-4GB RAM models |

### Build vs Pre-built — Pros & Cons

| | Pre-built (ZIP) | Full Build |
|---|---|---|
| **Time** | ~10 min setup | ~1-2 hours |
| **Disk space** | Just download | ~5GB free |
| **Customization** | Fixed config | Change anything |
| **Latest code** | Last release | Always up to date |
| **Difficulty** | Easy | Moderate (needs Linux) |
| **Root access** | Not needed | Required |
| **Internet** | Only for download | Required (large downloads) |

### Updating a Running PS4

If you already have PS4 RetroBox installed and want to update without reflashing:

1. SSH into PS4: `ssh PS4@<IP>` (password: `PS4`)
2. Copy updated files via SCP/SFTP
3. Key files to update:
   - `/usr/local/bin/retroarch-wrapper.sh` — game launcher
   - `/home/PS4/.config/retroarch/retroarch.cfg` — main RetroArch config
   - `/home/PS4/.config/retroarch/retroarch-ps4.cfg` — DS4 bindings + hotkeys
   - `/home/PS4/.emulationstation/es_systems.cfg` — system definitions
   - `/usr/lib/x86_64-linux-gnu/libretro/*.so` — cores
4. Restart ES: `sudo systemctl restart es-session.service`

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

## License

This project combines open-source software. See individual licenses for each component.

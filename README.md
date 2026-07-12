# PS4 RetroBox

> **v1.7-stable**
> First stable release with all boot, theme, and build fixes resolved. 31 libretro cores, 44 systems, 66 bundled homebrew ROMs, Plymouth boot splash, PS4 RetroBox carousel theme.

## What It Does

Turns a jailbroken PS4 into a retro gaming machine running **EmulationStation** + **RetroArch** on **Ubuntu 24.04**, installed directly on the PS4's internal HDD. No USB drive needed after setup.

## What Works (v1.7-stable, CUH-1000/1100 Aeolia)

- [x] Jailbreak + payload → Linux boot → EmulationStation
- [x] ES at 1080p with hardware GL (radeonsi + amdgpu_shim.so)
- [x] **44 retro systems** with **31 libretro cores**
- [x] **66 bundled homebrew ROMs** — playable out of the box
- [x] RetroArch 1.22.2 with full DS4 controller mapping
- [x] Audio via PulseAudio → HDMI output
- [x] DS4 wired USB — buttons work in ES and RetroArch
- [x] Plymouth es-logo boot splash
- [x] PS4 RetroBox carousel theme with system logos
- [x] SSH access (port 22)
- [x] Install: 3GB base + optional expansion
- [x] Open-source Neo Geo BIOS included (ngdevkit nullbios)
- [x] DS4 hotkey combo: Select+Cross for RetroArch menu
- [x] OSD notifications enabled (game-loaded overlay disabled)
- [x] RetroArch appendconfig with full DS4 button mapping
- [x] Beetle PSX + Mupen64Plus-Next optimized core options
- [x] Keyboard navigation in RetroArch XMB

## Supported Systems

| System | Core | BIOS | Status |
|--------|------|------|--------|
| **Nintendo** | | | |
| Super Nintendo (snes) | snes9x | No | ✓ Working |
| Super Famicom (sfc) | snes9x | No | Untested |
| NES (nes) | nestopia | No | ✓ Working |
| Famicom (famicom) | nestopia | No | Untested |
| Famicom Disk System (fds) | mesen | No | Untested |
| Nintendo 64 (n64) | mupen64plus_next | No | ✓ Working (Angrylion, Vulkan planned) |
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

## Known Issues (v1.5.2-dev)

- [ ] **RetroArch XMB menu navigation** — keyboard works when DS4 unplugged, DS4 d-pad doesn't navigate XMB ([#2](https://github.com/danyboy666/ps4-retrobox/issues/2))
- [ ] **PSX performance** — Beetle PSX dynarec (Lightrec JIT) works but Dynasty Warriors crashes at gameplay start. Other games need testing. Interpreter fallback available but slow.
- [ ] **N64 performance** — GLideN64 runs but slow due to eth0 interrupt storm (ksoftirqd/1 at 60-90% CPU)
- [ ] **eth0 interrupt storm** — ~3,600 spurious interrupts/sec all on CPU1. Kernel IRQ round-robin fix distributes xhci interrupts but eth0 is pinned by Aeolia hardware. Workaround: `isolcpus=1` in bootargs reserves CPU1 for kernel.
- [ ] **HDMI signal recovery** — TV power cycle or cable replug loses signal. Manual recovery via `sudo hdmi-recover` required (uses xrandr to force EDID re-read). Auto-recovery not possible without kernel driver changes.
- [ ] N64 GLideN64 font rendering — glColorMask fix deployed, inverted colors may persist
- [ ] Most systems NOT tested yet — all emus need testing
- [ ] Plymouth boot splash not rendering (amdgpu DRM limitation)
- [ ] Other controllers untested
- [ ] Network helpers untested
- [ ] FTP disabled by default

## Quick Start

### First Time Install
1. Download [v1.7-stable ZIP](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.7-stable)
2. Extract `arch.tar.xz`, `initramfs.cpio.gz`, `bzImage`
3. FTP to PS4 via FileZilla (port 2121):
   - `bzImage` → `/data/linux/boot/bzImage`
   - `initramfs.cpio.gz` → `/data/linux/boot/initramfs.cpio.gz`
   - `arch.tar.xz` → `/user/system/boot/arch.tar.xz`
4. Jailbreak → GoldHEN → BinLoader → send **1GB payload**
5. Install runs automatically → choose 3GB or expand

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
| [EmulationStation](https://github.com/danyboy666/EmulationStation) | PS4 fork — 25-button input, scraper API key UI, TheGamesDB v1 + ScreenScraper |
| [RetroArch](https://github.com/libretro/RetroArch) | v1.22.2 with PS4 patches — GL stale error fix, KMS modeset non-fatal, FBO blit fix, glColorMask font fix |
| [ps4-linux-12xx](https://github.com/danyboy666/ps4-linux-12xx) | PS4 Linux kernel 6.15.4 — IRQ round-robin, WiFi MT6632 fixes, Clang+FullLTO |

## Roadmap

| Version | Focus |
|---------|-------|
| v1.3 | Stable — radeonsi+shim, 24.04, RetroArch 1.22.2, launching images, audio via HDMI |
| v1.4 | 39 systems, 27 cores, scrapers with API key UI, Neo Geo BIOS, HDMI recovery, N64 FBO blit fix |
| v1.5 | Kernel IRQ fix, PSX dynarec, RetroArch font fix, keyboard navigation, sysctl tuning |
| **v1.5.2-dev** | **Current** — PSX Lightrec JIT working, IRQ round-robin kernel, HDMI xrandr recovery, keyboard nav, font fix |
| v1.6 | Fix RetroArch XMB navigation with DS4, N64 GLideN64 font colors, eth0 interrupt mitigation |
| **v1.7-stable** | **Current** — All boot/theme/build fixes, Plymouth splash, PS4 RetroBox carousel, 31 cores, 66 homebrew ROMs, DS4 hotkey combo, OSD notifications |
| v1.8 | Fix HDMI auto-recovery (kernel driver patch), controller hotkey/menu navigation |
| v1.9 | Other controllers, network helpers, FTP |
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

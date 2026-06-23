# PS4 RetroBox

> **DISCLAIMER**: This project was assembled by an AI assistant (OpenCode). The author is testing this method on real hardware to verify it is valid and safe. Use at your own risk. Always ensure you have a way to recover your PS4 if something goes wrong. The author assumes no responsibility for any damage to your console.

> **⚠ PROJECT STATUS — v1.3 WORK IN PROGRESS**  
> Core boot flow works. ES runs with hardware GL (radeonsi). RetroArch launches games. Controller, sound, Plymouth, and many features need further testing and fixes. This is NOT a stable release.

## What Works (v1.3, tested on CUH-1000/1100 Aeolia)

- [x] Jailbreak + payload delivery (PSFree-Enhanced, GoldHEN BinLoader)
- [x] Payload loads kernel + initramfs from internal HDD
- [x] Initramfs decrypts PS4 HDD partition (auto-detect)
- [x] UFS2 mount + write verification
- [x] Network — Ethernet + DHCP, SSH (port 22)
- [x] Install flow: 3GB base + optional expansion
- [x] Ubuntu 24.04 LTS (upgraded from 22.04 in v1.3)
- [x] ES runs at 1080p with hardware GL via radeonsi + amdgpu_shim.so
- [x] 17 retro systems (snes, nes, n64, gba, gb, gbc, megadrive, psx, tg16, arcade, neogeo, atari2600, atari5200, atari7800, mastersystem, gamegear)
- [x] RetroArch 1.22.2 with GL+KMS video driver
- [x] DS4 wired USB detected and buttons work in ES
- [x] ROMs launch in RetroArch (NES, SNES confirmed)
- [x] 12 libretro cores installed

## Known Bugs / Not Working (v1.3)

- [ ] **Sound not working** — PulseAudio configured but ALSA errors persist. Audio driver needs investigation
- [ ] **DS4 button mapping wrong in RetroArch** — Controller works in ES but RetroArch autoconfig doesn't map buttons correctly. L2/R2 axis mapping needs fixing
- [ ] **No controller input in RetroArch settings menu** — Controller not recognized inside RA settings
- [ ] **No keyboard input in RetroArch settings menu** — Keyboard not detected by RA's udev driver
- [ ] **RetroArch interface shows old rgui** — Menu driver not switching to xmb consistently
- [ ] **Plymouth boot splash not working** — Service runs but no visual splash during boot
- [ ] **UFS ROMs folder permissions untested** — Create/add/delete ROMs on /ps4hdd/ROMS/ not validated
- [ ] **Other controllers untested** — Only DS4 tested. Xbox/Switch/other USB controllers need validation
- [ ] **ES Configure Input not tested** — 25-button input config needs real-hardware validation
- [ ] **FTP disabled by default** — Only SSH enabled. FTP settings/script need validation
- [ ] **Samba/NFS helper scripts untested** — setup-samba.sh, network mounts need testing
- [ ] **DS4 LED reset not called on ES exit**
- [ ] **No signal can occur** — Display sometimes drops when making runtime changes via SSH
- [ ] **ES sluggishness** — Software GL rendering at 1080p on PS4 CPU. Hardware GL via radeonsi attempted but DRM modesetting broken on PS4 kernel

## Roadmap

1. **v1.3 (current)** — Ubuntu 24.04, RetroArch 1.22.2, radeonsi+shim for hardware GL, 25-button ES input, configscript for RetroArch
2. **v1.4** — Fix sound, fix DS4 RetroArch mapping, fix RetroArch menu, fix Plymouth
3. **v1.5** — Fix UFS ROM permissions, test all controllers, validate ES input config
4. **v1.6** — Fix network helpers, enable FTP, validate full install flow
5. **v1.7** — Performance optimization, fix ES sluggishness (needs kernel amdgpu firmware)
6. **v2.0** — Stable release candidate
18. **Performance testing** — Different PS4 models (Fat/Slim/Pro)
19. **Clean up README** — Remove unverified claims, add accurate troubleshooting

---

## What This Project Does

PS4 RetroBox turns your jailbroken PS4 into a retro gaming machine running **EmulationStation** + **RetroArch**. It installs a minimal **Ubuntu 22.04** server environment directly onto the PS4's internal HDD — no USB drive needed after setup, no external hardware required.

### How It Works

The PS4's internal HDD is encrypted and uses a UFS2 filesystem. This project works *within* those constraints:

1. **Payload** — A small program (kexec) loads a Linux kernel and initramfs from `/data/linux/boot/` on the PS4's internal HDD
2. **Initramfs** — Decrypts the PS4 HDD partition and mounts it
3. **`.img` file** — A single ext4 filesystem image (like a virtual disk) stored at `/ps4hdd/home/arch.img` on the PS4's encrypted UFS partition
4. **Loop-mount** — The `.img` file is loop-mounted as the root filesystem
5. **`switch_root`** — The system hands off to Ubuntu, which boots into EmulationStation

```
Payload (kexec) → Kernel + Initramfs → Decrypt PS4 HDD
  → Find .img on existing partition → Loop-mount .img
  → switch_root → Ubuntu boots → EmulationStation launches

ROMs can be stored in .img (default) or on UFS (/ps4hdd/ROMS/).
BIOS is stored in .img at /home/PS4/BIOS/.
```

### Why This Is Safe

This is the safest way to run Linux on a PS4 because **we never touch the HDD partition table or modify OrbisOS in any way.**

- **No repartitioning** — The PS4's HDD partition layout is completely untouched. We don't resize, move, or create any new partitions.
- **No firmware modification** — OrbisOS, the PS4 BIOS, and all system firmware remain exactly as Sony left them.
- **No OrbisOS changes** — The `.img` file is stored as a regular file inside an existing OrbisOS partition (`/user/home/`). OrbisOS treats it like any other file — it doesn't know it's a Linux rootfs.
- **No permanent changes** — The Linux installation is a single `.img` file. Delete it via FTP, and your PS4 is fully back to stock OrbisOS with zero traces of Linux.
- **Virtually no risk of bricking** — The only "change" is adding a file. Even if the `.img` is corrupt or missing, the PS4 simply boots normally into OrbisOS. There is no way for this to brick your console.

The only risky part is the jailbreak itself (exploiting the PS4 browser), which is unrelated to this project.

### What Gets Installed

| Component | Description |
|-----------|-------------|
| **Ubuntu 22.04** | Minimal server rootfs (no desktop environment) |
| **EmulationStation** | Retro gaming frontend — shows your ROMs in a TV-friendly interface |
| **RetroArch** | Emulator backend — runs the actual games via libretro cores |
| **16 systems** | SNES, NES, N64, GBA, Game Boy, Game Boy Color, Sega Mega Drive, PlayStation, TurboGrafx-16, TurboGrafx-CD, Arcade, Neo Geo, Atari 2600, Atari 7800, Sega Master System, Sega Game Gear |
| **SSH server** | Remote access from your PC (user: `PS4`, password: `PS4`) |
| **Network support** | Wired LAN for ROM transfer via NFS, Samba, SCP, or FTP |

### Key Facts

- **Internal HDD only** — the `.img` file lives on the PS4's own encrypted HDD
- **No USB drive needed** after initial setup — everything is self-contained
- **Reversible** — delete the `.img` file via FTP to fully restore OrbisOS
- **Ethernet required** — WiFi is not supported on CUH-1000/1100 models
- **ROM storage** — ROMs stored in `.img` (default) or on UFS. BIOS, saves, screenshots always in `.img`

## Features

- **EmulationStation** frontend (compiled from source)
- **RetroArch** with 16 libretro cores pre-installed
- **Internal HDD install** — runs from `.img` file on PS4's encrypted HDD (3GB minimal, or 16-50GB with expansion)
- **ROM storage options** — ROMs in `.img` (default) or on UFS. Samba toggle from ES carousel
- **No USB drive needed** after initial setup — all boot files on internal HDD
- **Auto-detect partition** — works with CUH-1000/1100 (partition 13) and CUH-1200+ (partition 27)
- **Multi-southbridge** — supports Aeolia, Belize, and Baikal with appropriate kernel selection
- **Firmware-agnostic** — works on FW 5.05 through 13.02 (payload auto-detects FW at runtime)
- **SSH server** enabled (user: `PS4`, password: `PS4`)
- **Auto-boot** into EmulationStation on tty1
- **Samba client** for loading ROMs from your PC over the network (toggle from ES carousel)
- **NFS client** for mounting ROMs from your PC's NFS share
- **Plymouth boot splash** — ES logo splash screen during boot
- **FTP server** on port 2121 (pure-ftpd) for quick file transfer
- **Safe & reversible** — delete the `.img` file via FTP to uninstall

## Controller Setup

### DualShock 4 (DS4)

The DS4 uses the **hid-generic** driver (not `hid_playstation`) via `usbhid.quirks` in bootargs.txt. This prevents the `hid_playstation` driver from crashing the xhci_aeolia USB controller.

| Property | Value |
|----------|-------|
| **Driver** | `hid-generic` (via `usbhid.quirks=0x054c:0x05c4:0x400000`) |
| **Connection** | USB wired (use a good cable — bad cables cause disconnects) |
| **Auto-detection** | 437 official RetroArch autoconfig profiles included |

**DS4 Button Mapping (verified on PS4 hardware):**

| DS4 Button | js0 Button | ES Action | RetroArch |
|------------|-----------|-----------|-----------|
| D-Pad | Hat switch | Navigate | D-Pad |
| Left Stick | Axes 0,1 | Navigate | Left Analog (also maps as D-Pad) |
| Cross (X) | btn 1 | Confirm (A) | A |
| Circle | btn 0 | Back (B) | B |
| Triangle | btn 2 | Info | X |
| Square | btn 3 | Details | Y |
| L1 | btn 4 | Page Up | L1 |
| R1 | btn 5 | Page Down | R1 |
| L2 | axis 2 | Left Trigger | L2 |
| R2 | axis 5 | Right Trigger | R2 |
| Start | btn 9 | Menu | Start |
| Select | btn 8 | Select | Select |
| L3 Click | btn 10 | — | L3 |
| R3 Click | btn 11 | — | R3 |
| PS Button | btn 12 | — | Guide/Hotkey |

### RetroArch Hotkey Combo

RetroArch uses a **hotkey modifier** system (like RetroPie):

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
| **Hold Select + R3** | Pause |

**How it works:** Hold the **Select** button, then press the second button. Select must be held down for the entire combo.

### RetroArch Configuration

RetroArch uses a **configscript** (`/usr/local/bin/retroarch-configscript.sh`) that reads the ES input configuration and generates the RetroArch config with correct button mappings and hotkey settings.

After configuring input in ES (or reconfiguring), run the configscript to update RetroArch:

```bash
ssh PS4@<PS4-IP>   # Password: PS4
/usr/local/bin/retroarch-configscript.sh
```

The configscript:
1. Reads `~/.emulationstation/es_input.cfg`
2. Maps ES button names → RetroArch config
3. Sets up hotkey: Select as modifier, X for menu, Start for exit
4. Maps left stick as D-pad fallback
5. Writes `~/.config/retroarch/retroarch.cfg`

### Multi-Controller Support

437 official RetroArch autoconfig profiles are installed at `/usr/share/retroarch/assets/autoconfig/udev/`. Any controller supported by RetroArch will auto-detect. For controllers not in the autoconfig database, use "Configure Input" in ES to map buttons, then run the configscript.

## DS4 Lightbar LED Controller

The DS4 controller's lightbar changes color when EmulationStation boots. Customize it by editing the config file.

### Configuration

Edit `~/.emulationstation/ds4_led.cfg` via SSH:

```bash
ssh PS4@<PS4-IP>   # Password: PS4
nano ~/.emulationstation/ds4_led.cfg
```

```xml
<?xml version="1.0"?>
<config>
  <string name="Color" value="purple" />
  <string name="Pattern" value="solid" />
</config>
```

**Colors:** `purple` (default), `red`, `green`, `blue`, `orange`, `cyan`, `magenta`, `yellow`, `white`, `off`

**Patterns:**

| Pattern | Effect |
|---------|--------|
| `solid` | Constant light (default) |
| `breathing` | Slow fade in/out (1.5s cycle) |
| `fast_breathing` | Quick fade in/out (0.5s cycle) |
| `pulse` | Quick flash, slow fade (2s cycle) |
| `off` | Lightbar off |

**LED behavior:** The DS4 LED script is called on EmulationStation startup. The reset-on-exit feature is not yet implemented (known bug — lightbar stays in custom color after quitting ES).

### How It Works

- `/usr/local/bin/ds4-led.sh` — LED controller script
- Reads `~/.emulationstation/ds4_led.cfg` on ES startup
- Auto-detects DS4 LED devices via `/sys/class/leds/input*`
- Uses Linux kernel LED subsystem (timer trigger for breathing effects)

## CLI Access — Dropping to Command Line

You can access a Linux command line without killing EmulationStation.

### Method 1: SSH from PC (recommended)

```bash
ssh PS4@<PS4-IP>
# Password: PS4
```

### Method 2: Virtual terminal on PS4

If you have a USB keyboard connected:

1. Press **Ctrl+Alt+F2** to switch to tty2 (command line)
2. Log in as `PS4` (password: `PS4`)
3. When done, type `exit` and press **Ctrl+Alt+F1** to return to EmulationStation

### Method 3: Kill EmulationStation (returns to tty1 shell)

```bash
# From SSH or tty2
killall emulationstation
```

EmulationStation exits and you get a shell prompt on tty1. To restart:

```bash
startx
```

### Useful CLI Commands

```bash
# Check system info
uname -a                    # Kernel version
free -h                     # RAM usage
df -h                       # Disk usage

# Check network
ip a                        # IP addresses
ping -c 3 google.com        # Test internet

# Restart EmulationStation
startx                      # Or: emulationstation &

# Shutdown
sudo shutdown -h now        # Safe shutdown
sudo reboot                 # Restart PS4

# Check logs
dmesg                       # Kernel messages
cat /var/log/syslog | tail  # System log
```

## Helper Scripts & File Locations

### System Scripts

| Path | Purpose |
|------|---------|
| `/usr/local/bin/ds4-led.sh` | DS4 lightbar LED controller |
| `/usr/local/bin/setup-samba.sh` | Samba share setup & toggle (edit PC_IP/SHARE first, then `--setup`/`--toggle`/`--restore`) |
| `ps4-dhcp-fallback.service` | Systemd service — auto-DHCP on any non-loopback interface |
| `ps4-usb-reprobe.service` | Systemd service — re-enumerates USB devices at boot |

### Configuration Files

| Path | Purpose |
|------|---------|
| `~/.emulationstation/es_systems.cfg` | System definitions (ROM paths, emulators) |
| `~/.emulationstation/es_settings.cfg` | ES settings (theme, resolution, VSync) |
| `~/.emulationstation/es_input.cfg` | Controller/keyboard mappings |
| `~/.emulationstation/ds4_led.cfg` | DS4 LED color/pattern config |
| `~/.xinitrc` | X11 startup (ES launch, LED, DPMS) |
| `/etc/X11/xorg.conf` | X11 display/input config |
| `/etc/NetworkManager/system-connections/Wired connection.nmconn` | Network config |
| `/data/linux/boot/bootargs.txt` | Kernel boot parameters |

### ROM Directories

ROMs can be stored in two locations:
- **In .img** (`/home/PS4/ROMS/`) — default, self-contained, easier backup
- **On UFS** (`/ps4hdd/ROMS/`) — larger capacity, persists across reinstalls

**ROM directory structure** (same for both storage modes):

```
ROMS/
├── snes/
├── nes/
├── n64/
├── gba/
├── gb/
├── gbc/
├── megadrive/
├── psx/
├── tg16/
├── tgcd/
├── arcade/
├── neogeo/
├── atari2600/
├── atari7800/
├── mastersystem/
└── gamegear/
```

**BIOS files** are stored in `.img` at `/home/PS4/BIOS/`.

**Saves and screenshots** are stored in `.img` at `/home/PS4/saves/` and `/home/PS4/screenshots/`.

### Libretro Cores

Installed at `/usr/lib/x86_64-linux-gnu/libretro/`:

| Core | System |
|------|--------|
| `bsnes_mercury_balanced_libretro.so` | SNES |
| `nestopia_libretro.so` | NES |
| `mupen64plus_libretro.so` | N64 |
| `mgba_libretro.so` | GBA |
| `gambatte_libretro.so` | Game Boy, Game Boy Color |
| `genesis_plus_gx_libretro.so` | Mega Drive, Master System, Game Gear |
| `mednafen_psx_libretro.so` | PlayStation |
| `mednafen_pce_fast_libretro.so` | TurboGrafx-16, TurboGrafx-CD |
| `fbneo_libretro.so` | Arcade, Neo Geo |
| `stella_libretro.so` | Atari 2600 |
| `prosystem_libretro.so` | Atari 7800 |

## Supported Systems

| System | Core | BIOS Required |
|--------|------|---------------|
| Super Nintendo | bsnes-mercury-balanced | No |
| Nintendo Entertainment System | Nestopia | No |
| Nintendo 64 | mupen64plus | No |
| Game Boy Advance | mGBA | Optional (gba_bios.bin) |
| Game Boy | Gambatte | No |
| Game Boy Color | Gambatte | No |
| Sega Mega Drive | Genesis Plus GX | No |
| Sony PlayStation | Mednafen PSX | Yes (SCPH1001.bin) |
| TurboGrafx-16 | Mednafen PCE Fast | No |
| TurboGrafx-CD | Mednafen PCE Fast | Yes (syscard3.pce) |
| Arcade | FinalBurn Neo | No |
| Neo Geo | FinalBurn Neo | No |
| Atari 2600 | Stella | No |
| Atari 7800 | ProSystem | No |
| Sega Master System | Genesis Plus GX | No |
| Sega Game Gear | Genesis Plus GX | No |

## Requirements

- Firmware **9.60** (exploitable via PSFree-Enhanced or karo218.ir) — works on **any jailbreak-compatible FW** (5.05–13.02)
- **PS4 Fat CUH-1000/1100** (Aeolia southbridge) — **only tested model**. Other models may work but are unverified.
- Windows PC on the **same network** as PS4
- **Ethernet cable required** — connect PS4 to your router/switch before booting
- WiFi is **not supported** on CUH-1000/1100 (Aeolia v1 southbridge)
- **No USB drive required** — everything is transferred via FTP

### Kernel by PS4 Model

**The initramfs, rootfs, and payload are identical across all models.** Only the kernel (`bzImage`) changes based on your PS4's southbridge.

| PS4 Model | Southbridge | Kernel | Tested? |
|-----------|-------------|--------|---------|
| **Fat CUH-1000/1100** | Aeolia | `bzImage_no-built-in-fw_Clang_fullLTO` | ✅ Tested |
| **Fat CUH-1200 / Slim CUH-2000** | Belize | `bzImage_no-built-in-fw_Clang_fullLTO` | ❌ Not tested |
| **Pro CUH-7000** | Baikal | `bzImage_Baikal_5.4.247` | ❌ Not tested |

> **⚠ TESTING LIMITATION:** This build has only been tested on a PS4 Fat CUH-1000/1100 (Aeolia southbridge) with `bzImage_no-built-in-fw_Clang_fullLTO`. The Baikal kernel (`bzImage_Baikal_5.4.247`) for PS4 Pro and the Belize southbridge (CUH-1200/Slim) have **not** been tested on real hardware. They may work but are unverified. Feedback from other PS4 model users is welcome.

**To identify your model:** Check the label on the back of your PS4. The model number starts with `CUH-` followed by 4 digits.

**Aeolia vs Belize:** Both use the same kernel binary (`bzImage` 6.15.4 from feeRnt). The kernel auto-detects which southbridge is present at boot.

**Baikal (PS4 Pro):** Requires a different kernel. Use `bzImage_Baikal_5.4.247` instead. Rename it to `bzImage` before FTP upload.

> **Source:** Kernels by [feeRnt](https://github.com/feeRnt/ps4-linux-12xx/releases) (6.15.4-crashnt-4.7 for Aeolia/Belize, 5.4.247-neocine-1.1 for Baikal). Payload by [ps4-linux-loader](https://github.com/ps4-linux/ps4-linux-loader) v24b (firmware-agnostic, FW 5.05–13.02).

## Quick Start

### First Time Install (one-time setup)
1. **Download** — grab `ps4-retrobox-v1.2.zip` from [Releases](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.2)
2. **Extract** the zip on your PC
3. **Choose kernel** — rename the correct kernel to `bzImage`:
   - **Aeolia/Belize** (Fat CUH-1000/1100/1200, Slim CUH-2000): rename `bzImage_no-built-in-fw_Clang_fullLTO` → `bzImage`
   - **Baikal** (Pro CUH-7000): rename `bzImage_Baikal_5.4.247` → `bzImage`
4. **FTP** 4 files to your PS4 (see Phase 3 below)
5. **Jailbreak** → GoldHEN → Enable BinLoader → send **1GB payload** (see note below)
6. **Wait for install** — the installer runs automatically. It creates a 3GB `.img`, extracts rootfs, then asks if you want to expand (16/32/50GB) or keep 3GB.
7. **Done** — Linux boots automatically into EmulationStation

> **Why use the 1GB payload for install?** The VRAM payload size determines how much RAM is reserved for the GPU. A 1GB payload reserves only 1GB for GPU, leaving ~3GB for CPU/system — this is critical because tar extraction of the rootfs is memory-intensive. A 2GB+ payload would leave less system RAM and could cause the install to fail or be very slow. For daily gaming after install, use the 2GB payload (more GPU RAM = better game performance).

### Daily Use — Method 1: Netcat (PC required)
1. **Jailbreak** → GoldHEN → Enable BinLoader
2. **Send 2GB payload from PC:** `netcat -w 5 <PS4-IP> 9020 < payload-960-2gb.elf`
3. **Linux boots** → EmulationStation launches → play!

### Daily Use — Method 2: Payload Loader (No PC needed)
1. **Jailbreak** → GoldHEN
2. **Go to GoldHEN menu** → **Payload Loader**
3. **Select** the 2GB payload ELF from `/data/payloads/`
4. **Linux boots** → EmulationStation launches → play!

**To set up Payload Loader (one-time):**
1. Download [Payload Loader PKG](https://pkg-zone.com/download/ps4/FLTZ00001/latest)
2. Install via GoldHEN → Package Installer
3. FTP `payload-960-2gb.elf` to `/data/payloads/` on your PS4

**That's it.** Just jailbreak → launch payload → play.

## Detailed Installation

### Phase 1: Prepare Windows PC (Samba Share)

Create a shared folder on your Windows PC:

```
C:\PS4_ROMs\
├── snes\
├── nes\
├── n64\
├── gba\
├── gb\
├── gbc\
├── megadrive\
├── psx\
├── tg16\
├── tgcd\
├── arcade\
├── neogeo\
├── atari2600\
├── atari5200\
├── atari7800\
├── mastersystem\
└── gamegear\
```

Share the folder:
1. Right-click `C:\PS4_ROMs` → Properties → Sharing → Share
2. Add user `Everyone` with Read access
3. Note your PC's IP address (run `ipconfig`)

### Phase 2: PS4 Preparation

> **This step is critical.** Incorrect video settings are the #1 cause of black screens and garbled display when booting Linux.

#### Video Settings (Required)

Go to **Settings** → **Sound and Screen** → **Video Output Settings**:

| Setting | Value | Why |
|---------|-------|-----|
| **Resolution** | **1080p** (not Automatic, not 4K) | Linux display driver initializes at 1080p. Automatic may select 4K → garbled/black screen |
| **HDR Range** | **OFF** | HDR confuses the Linux DRM driver |
| **Deep Color Output** | **OFF** | Deep Color causes mode negotiation failures |
| **RGB Range** | **Full** | Ensures correct color output on TVs |

#### System Settings (Required)

Go to **Settings** → **System**:

| Setting | Value | Why |
|---------|-------|-----|
| **Enable HDCP** | **OFF** | HDCP blocks third-party OS output. Must be disabled. |
| **Enable HDMI Device Link** | **OFF** | HDMI Device Link causes unexpected power state changes during boot |

#### Network & Exploit Services

Before booting Linux, ensure these are running in GoldHEN:

- **Enable BinLoader Server** — needed to receive the Linux payload
- **Enable FTP Server** — needed to upload files (or for SSH access later)

#### Physical Setup

- Connect **Ethernet cable** from PS4 to your router (WiFi not supported on CUH-1000/1100)
- Connect **USB keyboard** (optional — only needed if you want to interact during install)

### Phase 3: FTP Files to Internal HDD

From your PC, FTP these 4 files to the PS4:

| Local File | Rename To | FTP Path | Size |
|------------|-----------|----------|------|
| `bzImage_no-built-in-fw_Clang_fullLTO` (Aeolia/Belize) **or** `bzImage_Baikal_5.4.247` (Pro) | **`bzImage`** | `/data/linux/boot/bzImage` | ~18MB |
| `initramfs.cpio.gz` | (keep name) | `/data/linux/boot/initramfs.cpio.gz` | ~6MB |
| `bootargs.txt` | (keep name) | `/data/linux/boot/bootargs.txt` | <1KB |
| `arch.tar.xz` | (keep name) | `/user/system/boot/arch.tar.xz` | ~492MB |

**Important:** You MUST rename the kernel file to just `bzImage` before uploading. The payload only looks for a file named `bzImage`.

Use FileZilla or any FTP client:
- Host: `<PS4-IP>`
- Port: `2121`
- Username/Password: (leave empty)

### What is bootargs.txt?

`bootargs.txt` contains kernel boot parameters that fix common issues like black screen, garbled display, and DS4 controller compatibility. It is loaded automatically by the payload.

```
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0 drm.debug=0 usbhid.quirks=0x054c:0x05c4:0x400000,0x054c:0x09cc:0x400000 usbcore.autosuspend=-1 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8 console=tty0 video=HDMI-A-0:1920x1080@60
```

| Parameter | Purpose |
|-----------|---------|
| `panic=0` | Reboot immediately on kernel panic |
| `clocksource=tsc` | Force TSC clocksource |
| `consoleblank=0` | Disable console screen blanking |
| `net.ifnames=0` | Use legacy interface names (`eth0` instead of `enp3s0`) |
| `radeon.dpm=0` | Disable Radeon power management (prevents crashes) |
| `amdgpu.dpm=0` | Disable AMDGPU power management (prevents crashes) |
| `usbhid.quirks=0x054c:0x05c4:0x400000` | Prevents `hid_playstation` from claiming DS4 (DS4 vendor:product `054c:05c4`). Forces `hid-generic` driver instead. |
| `usbhid.quirks=0x054c:0x09cc:0x400000` | Same quirk for DS4 v2 (`054c:09cc`) |
| `usbcore.autosuspend=-1` | Disable USB autosuspend (keeps DS4 connection alive) |
| `video=HDMI-A-0:1920x1080@60` | Force 1080p60 output on HDMI connector |

> **Note:** Do NOT add `drm.edid_firmware=edid/1920x1080.bin` — the EDID firmware file does not exist in the rootfs and causes garbled display when referenced.

### Phase 4: Install to Internal HDD

#### Step 1: Jailbreak

> **⚠ The jailbreak can freeze the console even after a success message.** If the screen goes black or the console becomes unresponsive, **hold the power button for 7-10 seconds** to force shutdown. This is normal — try again. This is NOT a jailbreak guide. See [PSFree-Enhanced](https://arabpixel.github.io/PSFree-Enhanced) for instructions.

**Option A: PSFree-Enhanced (Recommended)**
1. Open **PS4 Browser**
2. Go to `arabpixel.github.io/PSFree-Enhanced`
3. Wait for caching to reach 100% (checkmark appears at top left)
4. Press **Options** on controller → choose **Refresh Page**
5. Select **GoldHEN** → press **Start**
6. Wait for GoldHEN notification

First time requires internet. After caching, works offline from browser cache.

**Option B: Karo218.ir**
1. Open **PS4 Browser**
2. Go to `karo218.ir`
3. Click **G2All** → wait for jailbreak to complete

**Option C: DNS Method (no URL typing)**
1. **Settings** → **Network** → **Set Up Internet Connection**
2. Set **Primary DNS** to `62.210.38.117`
3. Open **User Guide** from PS4 Settings → redirects to exploit host
4. Jailbreak from there

#### Step 2: Enable BinLoader

1. Go to **GoldHEN** menu
2. Select **Enable BinLoader Server**
3. You'll see "BinLoader Server: Listening on port 9020"

#### Step 3: Send the Payload

There are several ways to send the payload from your PC to the PS4:

**Method 1: Netcat (Windows/Mac/Linux)**
```bash
netcat -w 5 <PS4-IP> 9020 < payload-960-2gb.elf
```

**Method 2: GoldHEN BinLoader (from PS4 browser)**
1. On PS4 browser, go to `karo218.ir`
2. Click **G2All** → wait for jailbreak
3. Go to **GoldHEN** → **Enable BinLoader Server**
4. From PC, use a payload sender app or netcat to send the `.elf` file to port 9020

**Method 3: Windows payload sender apps**
- Use any PS4 payload sender application (e.g., PS4 Payload Sender, BinLoader)
- Enter PS4 IP and port 9020
- Select `payload-960-2gb.elf`
- Click Send

**Method 4: Direct USB (if supported by exploit host)**
- Some exploit hosts support loading payloads from USB
- Copy the `.elf` file to root of USB drive
- The exploit host may auto-detect it

**Recommended for first install:** Use Method 1 (netcat) — it's the most reliable.

#### Step 4: Rescueshell

After the payload is sent, the PS4 screen shows white text on black background — this is the **rescueshell**. It's a minimal Linux command prompt.

You'll see something like:
```
Welcome to rescue shell!
# _
```

Connect a USB keyboard to the PS4 to type commands.

#### Step 5: Run HDD Install

In the rescueshell, type:
```bash
exec install-HDD.sh
```

**Note:** A USB keyboard is optional during installation. You can plug one in to interact, or simply let the script run by itself — no input is required.

The script will:
1. Auto-detect the PS4 HDD partition and decrypt it
2. Auto-detect `arch.tar.xz` on the internal HDD
3. Create a 3GB `.img` file on the internal HDD
4. Format it as ext4
5. Extract the rootfs into it
6. Create ROM directories on UFS (`/ps4hdd/ROMS/`) if UFS storage was chosen
7. Ask: **"Keep 3GB or expand?"**
   - **[1] Keep 3GB** — boot now (fastest)
   - **[2] Expand** — choose size (16/32/50GB or custom), expansion happens immediately
8. Boot into Linux automatically

**If an `.img` file already exists** — the script will refuse to run and tell you to delete it first. This prevents accidentally overwriting your existing install. To reinstall:
```bash
rm /ps4hdd/home/arch.img
exec install-HDD.sh
```

**If it fails:** Try again with 1GB payload for initial install. Ensure all 4 files were uploaded via FTP to the correct paths.

#### Step 6: First Boot

After extraction completes, init automatically boots into Linux:
1. Ubuntu boots from the `.img` file on internal HDD
2. tty1 auto-logs in as `PS4` user
3. EmulationStation launches automatically
4. You'll see the EmulationStation menu

**If you get a black screen:** Try connecting a different monitor/TV, or check `bootargs.txt` is at `/data/linux/boot/bootargs.txt`.

### Phase 5: Configure Samba (Optional)

If you want to load ROMs from a Windows PC instead of the PS4's internal storage:

**1. Edit the Samba helper script:**

```bash
ssh PS4@<PS4-IP>   # Password: PS4
sudo nano /usr/local/bin/setup-samba.sh
```

Change the values at the top of the file:

```bash
PC_IP="192.168.1.100"        # <-- Your Windows PC IP
SHARE="PS4_ROMs"             # <-- Your share name
```

**2. Run setup once:**

```bash
sudo setup-samba.sh --setup
```

This adds the Samba share to `/etc/fstab` and mounts it.

**3. Toggle between UFS and Samba from EmulationStation:**

- In ES, navigate to **"Network ROMs"** system
- Select it to toggle between UFS and Samba ROMs
- ES restarts automatically with the selected ROM source

**4. Restore UFS ROMs (if needed):**

```bash
sudo setup-samba.sh --restore
```

**Samba share structure** — your Windows share must have these exact folder names:

```
PS4_ROMs/
├── snes/  nes/  n64/  gba/  gb/  gbc/
├── megadrive/  psx/  tg16/  tgcd/
├── arcade/  neogeo/
├── atari2600/  atari5200/  atari7800/
├── mastersystem/  gamegear/
```

Copy BIOS files to `.img`:

```bash
scp BIOS/*.bin PS4@<PS4-IP>:/home/PS4/BIOS/
```

### Phase 6: Daily Use — How to Play

Once Linux is installed on the internal HDD, **you never run `install-HDD.sh` again.** The `.img` stays on your PS4 permanently.

**Every time you want to play:**

#### Step 1: Jailbreak Your PS4

> **⚠ The jailbreak can freeze the console even after a success message.** If the screen goes black or the console becomes unresponsive, **hold the power button for 7-10 seconds** to force shutdown. This is normal — try again. This is NOT a jailbreak guide. See [PSFree-Enhanced](https://arabpixel.github.io/PSFree-Enhanced) for instructions.

**Option A: PSFree-Enhanced (Recommended)**
1. Open **PS4 Browser**
2. Go to `arabpixel.github.io/PSFree-Enhanced`
3. Wait for caching to reach 100%
4. Press **Options** → **Refresh Page**
5. Select **GoldHEN** → press **Start**

**Option B: Karo218.ir**
1. Open **PS4 Browser**
2. Go to `karo218.ir`
3. Click **G2All** → wait for jailbreak

**Option C: DNS Method**
1. **Settings** → **Network** → **Set Up Internet Connection**
2. Set **Primary DNS** to `62.210.38.117`
3. Open **User Guide** → redirects to exploit host

#### Step 2: Launch the Linux Payload

Pick one of two methods:

**Method 1: Netcat (from PC)** — requires PC on same network
1. Go to **GoldHEN** → **Enable BinLoader Server**
2. From your PC, run:
```bash
netcat -w 5 <PS4-IP> 9020 < payload-960-2gb.elf
```

**Method 2: Payload Loader (no PC needed)** — fully standalone
1. Go to **GoldHEN** menu → **Payload Loader**
2. Browse to `/data/payloads/payload-960-2gb.elf`
3. Select it to load

> **One-time setup for Method 2:** Download [Payload Loader PKG](https://pkg-zone.com/download/ps4/FLTZ00001/latest), install via GoldHEN → Package Installer, then FTP `payload-960-2gb.elf` to `/data/payloads/` on your PS4.

#### Step 3: Play!

The payload boots Linux automatically:
1. Loads kernel + initramfs from internal HDD
2. Decrypts the PS4 HDD and finds your `.img` file
3. Ubuntu boots from the `.img`
4. EmulationStation launches automatically
5. **Play!**

#### Step 4: Shutdown

When done gaming:
- Press **PS button** → Power → Turn Off PS4
- Or type `sudo shutdown -h now` in a terminal (if you have SSH access)

#### Adding ROMs

**Method 1: SCP/SFTP**
Copy ROMs from your PC over SSH:
```bash
# To .img (default)
scp -r /path/to/roms/* PS4@<PS4-IP>:/home/PS4/ROMS/snes/
# Password: PS4

# Or to UFS (if using UFS storage)
scp -r /path/to/roms/* PS4@<PS4-IP>:/ps4hdd/ROMS/snes/
```

**Method 2: Samba share**
See "Phase 5: Configure Samba" above. Use the "Network ROMs" system in ES to toggle between UFS and Samba.

**Method 3: USB drive**
Copy ROMs to a USB drive, then mount and copy:
```bash
sudo mount /dev/sdb1 /mnt
cp -r /mnt/ROMs/* /home/PS4/ROMS/
sudo umount /mnt
```

**Method 3: UFS Direct**
Copy BIOS files to `.img`:
```bash
scp BIOS/SCPH1001.bin PS4@<PS4-IP>:/home/PS4/BIOS/
```

ROMs appear in EmulationStation automatically. If not, press Start → Quit → restart ES.

#### Payload Summary

| Payload | Use When | VRAM | Netcat | Payload Loader |
|---------|----------|------|--------|----------------|
| `payload-960-1gb.elf` | **Initial install only** — leaves max RAM for extraction | 1GB | ✅ | ✅ |
| `payload-960-2gb.elf` | **Daily gaming (recommended)** — balanced GPU/system RAM | 2GB | ✅ | ✅ |
| `payload-960-3gb.elf` | Optional — more GPU RAM for demanding games | 3GB | ✅ | ✅ |
| `payload-960-4gb.elf` | Optional — maximum GPU RAM | 4GB | ✅ | ✅ |

**Note:** VRAM payload = GPU reserved RAM. PS4 Fat has 4GB total. A 1GB payload leaves ~3GB for system (best for install). A 2GB payload leaves ~2GB for system (good for daily use). 3GB/4GB may cause instability due to limited system RAM.

## Recovery — How to Undo Everything

Because Linux lives as a single `.img` file, removing it fully restores your PS4:

1. **FTP** into your PS4 (or SSH if Linux is running)
2. **Delete** `/ps4hdd/home/arch.img` — this is the entire Linux installation
3. **Delete** `/data/linux/boot/bzImage` and `/data/linux/boot/initramfs.cpio.gz` — the kernel and initramfs

Your PS4 is now completely back to stock OrbisOS. No partition changes, no firmware modifications, no traces of Linux.

> **Note:** ROMs on UFS (`/ps4hdd/ROMS/`) persist after `.img` deletion. They are separate from the Linux installation. Delete them manually if you want a complete cleanup.

**If Linux won't boot:** The PS4 simply boots into OrbisOS normally. There is no way for this project to brick your console.

## BIOS Files

Required BIOS files (place in `C:\PS4_ROMs\BIOS\` or copy to `/home/PS4/BIOS/`):

| System | File(s) | Size |
|--------|---------|------|
| PS1 | SCPH1001.bin | 512KB |
| PS2 | SCPH10000.bin | 4MB |
| TurboGrafx-16 | syscard3.pce | 24KB |
| GBA (optional) | gba_bios.bin | 16KB |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Black screen | Use `bootargs.txt` params, try TV instead of monitor |
| Garbled GUI / white screen | Was caused by missing EDID firmware in bootargs.txt. Fixed by removing `drm.edid_firmware=edid/1920x1080.bin`. Also check PS4 video settings: 1080p, HDR OFF, Deep Color OFF, HDCP OFF. |
| No WiFi | WiFi not supported on CUH-1000/1100. Use Ethernet cable. |
| No Bluetooth | Use USB BT dongle |
| SSH refused | Ensure Ethernet cable connected, try `ping <PS4-IP>` |
| No IP address | Ensure Ethernet cable is connected to router. Run `ip a` on PS4 to check. |
| Samba mount fails | Check PC IP, firewall, share name, credentials |
| BIOS not found | Verify files in `/home/PS4/BIOS/` |
| ROMs not showing | Check `ls /home/PS4/ROMS/`, restart EmulationStation |
| HDD install fails | Verify all 4 files at correct FTP paths. Check `/ps4hdd/system/boot/install.log` via SSH. Try 1GB payload for initial install. |
| `mount -o ro /newroot failed` | Ensure `arch.tar.xz` is at `/user/system/boot/` via FTP |

## Building from Source

To rebuild the rootfs from scratch:

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install debootstrap qemu-user-static tar xz-utils dosfstools parted e2fsprogs git cmake build-essential

# Build rootfs
sudo ./build.sh /mnt/ps4root
```

The build script:
1. Bootstraps Ubuntu 22.04 minimal via debootstrap
2. Installs system packages, Bluetooth, Samba, NFS, GPU drivers
3. Installs RetroArch + libretro cores
4. Compiles EmulationStation from source
5. Configures auto-boot, SSH, user accounts
6. Packages as `arch.tar.xz`
7. Downloads feeRnt initramfs

## Credits

### Initramfs (derivative chain)

The init and functions.sh are derived from better-initramfs, modified in stages:

1. **[Piotr Karbowski](https://bitbucket.org/piotrkarbowski/better-initramfs)** — better-initramfs (BSD-3-Clause license, 2010-2018). Original initramfs framework: all core functions (einfo/ewarn/rescueshell/run/run_hooks/emount/eumount/moveDev/cleanup/boot_newroot), mount system, storage layer detection, hook system. ~60% of init and ~95% of functions.sh are unmodified from this project.
2. **[feeRnt](https://github.com/feeRnt/ps4-linux-initramfs)** — PS4 adaptation of better-initramfs. Added PS4 HDD decryption (cryptsetup + AES-XTS), UFS2 mount, Aeolia/Belize/Baikal southbridge detection, boot menu, partition manager.
3. **[danyboy666](https://github.com/danyboy666/ps4-retrobox)** — PS4 RetroBox modifications. Auto-detect boot, .img file management, filesystem expansion, installer (install-HDD.sh), ROM/BIOS bind mounts, non-interactive boot flow.

### Kernels

- [feeRnt](https://github.com/feeRnt/ps4-linux-12xx) — PS4 Linux kernel 6.15.4-crashnt-4.7 for Aeolia/Belize
- [DFAUS](https://github.com/DFAUS-git/ps4-baikal-5.4.247-kernel) — PS4 Linux kernel 5.4.247 for Baikal (Pro)
- [crashniels](https://github.com/crashniels/linux) — Kernel source with WiFi/BT patches

### Payload & loader

- [ArabPixel](https://github.com/ArabPixel) + [rmuxnet](https://github.com/rmuxnet) — Firmware-agnostic PS4 Linux loader (ps4-linux-loader v24b)
- [Ps3itaTeam](https://github.com/Ps3itaTeam), [Nazky](https://github.com/Nazky), [hippie68](https://github.com/hippie68) — Original PS4 initramfs concepts

### Software

- [Aloshi](https://github.com/Aloshi/EmulationStation) — EmulationStation frontend
- [RetroPie](https://github.com/RetroPie/EmulationStation) — EmulationStation fork with 25-button input config, controller configscripts, and hotkey support. PS4 RetroBox ES fork is based on this.
- [RetroPie](https://github.com/RetroPie/RetroPie-Setup) — RetroArch controller configuration scripts (configscripts/retroarch.sh) adapted for PS4 RetroBox
- [libretro](https://www.libretro.com) — RetroArch and libretro cores
- [raelgc](https://github.com/raelgc/es-logo) — EmulationStation Plymouth boot splash theme (GPL-2.0)

## License

This project combines open-source software. See individual licenses for each component.

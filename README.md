# PS4 RetroBox

> **DISCLAIMER**: This project was assembled by an AI assistant (OpenCode). The author is testing this method on real hardware to verify it is valid and safe. Use at your own risk. Always ensure you have a way to recover your PS4 if something goes wrong. The author assumes no responsibility for any damage to your console.

## What This Project Does

PS4 RetroBox turns your jailbroken PS4 Fat into a retro gaming machine running **EmulationStation** + **RetroArch**. It installs a minimal **Ubuntu 22.04** server environment directly onto the PS4's internal HDD — no USB drive needed after setup, no external hardware required.

### How It Works

The PS4's internal HDD is encrypted and uses a UFS2 filesystem. This project works *within* those constraints:

1. **Payload** — A small program (kexec) loads a Linux kernel and initramfs from `/data/linux/boot/` on the PS4's internal HDD
2. **Initramfs** — Decrypts the PS4 HDD partition and mounts it
3. **`.img` file** — A single ext4 filesystem image (like a virtual disk) stored at `/user/home/arch.img` on the PS4's existing OrbisOS partition
4. **Loop-mount** — The `.img` file is loop-mounted as the root filesystem
5. **`switch_root`** — The system hands off to Ubuntu, which boots into EmulationStation

```
Payload (kexec) → Kernel + Initramfs → Decrypt PS4 HDD
  → Find .img on existing partition → Loop-mount .img
  → switch_root → Ubuntu boots → EmulationStation launches
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
| **15 emulators** | SNES, N64, GBA, Game Boy, Genesis, PlayStation, TurboGrafx-16, Nintendo DS, Arcade, Neo Geo, Atari 2600, Atari 7800, Sega Master System, Game Gear, Commodore 64, PC Engine CD |
| **SSH server** | Remote access from your PC (user: `PS4`, password: `PS4`) |
| **Network support** | Wired LAN for ROM transfer via Samba/SCP |

### Key Facts

- **Internal HDD only** — the `.img` file lives on the PS4's own encrypted HDD
- **No USB drive needed** after initial setup — everything is self-contained
- **Reversible** — delete the `.img` file via FTP to fully restore OrbisOS
- **Ethernet required** — WiFi is not supported on CUH-1000/1100 models

## Features

- **EmulationStation** frontend (compiled from source)
- **RetroArch** with 15+ libretro cores pre-installed
- **Internal HDD install** — runs from 32GB `.img` file on PS4's encrypted HDD
- **No USB drive needed** after initial setup — all boot files on internal HDD
- **Auto-detect partition** — works with CUH-1000/1100 (partition 13) and CUH-1200+ (partition 27)
- **SSH server** enabled (user: `PS4`, password: `PS4`)
- **Auto-boot** into EmulationStation on tty1
- **Samba client** for loading ROMs from your PC over the network
- **Safe & reversible** — delete the `.img` file via FTP to uninstall

## Supported Systems

| System | Core | BIOS Required |
|--------|------|---------------|
| Super Nintendo | bsnes-mercury-balanced | No |
| Nintendo 64 | mupen64plus | No |
| Game Boy Advance | mGBA | Optional (gba_bios.bin) |
| Game Boy / Color | Gambatte | No |
| Sega Genesis | Genesis Plus GX | No |
| Sony PlayStation | Mednafen PSX | Yes (SCPH1001.bin) |
| TurboGrafx-16 | Mednafen PCE Fast | Yes (syscard3.pce) |
| Nintendo DS | DeSmuME | No |
| Arcade | FinalBurn Neo | No |
| Neo Geo | FinalBurn Neo | No |
| Atari 2600 | Stella | No |
| Atari 7800 | ProSystem | No |
| Sega Master System | Genesis Plus GX | No |
| Sega Game Gear | Genesis Plus GX | No |
| Commodore 64 | VICE | No |
| PC Engine CD | Mednafen PCE Fast | Yes (syscard3.pce) |

## Requirements

- Firmware **9.60** (exploitable via PSFree-Enhanced or karo218.ir) — works on **any jailbreak-compatible FW** (5.05–13.02)
- Windows PC on the **same network** as PS4
- **Ethernet cable required** — connect PS4 to your router/switch before booting
- WiFi is **not supported** on CUH-1000/1100 (Aeolia v1 southbridge)
- **No USB drive required** — everything is transferred via FTP

### Kernel by PS4 Model

**The initramfs, rootfs, and payload are identical across all models.** Only the kernel (`bzImage`) changes based on your PS4's southbridge.

| PS4 Model | Southbridge | Kernel | Download |
|-----------|-------------|--------|----------|
| **Fat CUH-1000/1100** | Aeolia | `bzImage` (6.15.4) | Included in release |
| **Fat CUH-1200 / Slim CUH-2000** | Belize | `bzImage` (6.15.4) | Included in release |
| **Pro CUH-7000** | Baikal | `bzImage_Baikal_5.4.247` | Included in release |

**To identify your model:** Check the label on the back of your PS4. The model number starts with `CUH-` followed by 4 digits.

**Aeolia vs Belize:** Both use the same kernel binary (`bzImage` 6.15.4 from feeRnt). The kernel auto-detects which southbridge is present at boot.

**Baikal (PS4 Pro):** Requires a different kernel. Use `bzImage_Baikal_5.4.247` instead. Rename it to `bzImage` before FTP upload.

> **Source:** Kernels by [feeRnt](https://github.com/feeRnt/ps4-linux-12xx/releases) (6.15.4-crashnt-4.7 for Aeolia/Belize, 5.4.247-neocine-1.1 for Baikal). Payload by [ps4-linux-loader](https://github.com/ps4-linux/ps4-linux-loader) v24b (firmware-agnostic, FW 5.05–13.02).

## Quick Start

### First Time Install (one-time setup)
1. **Download** — grab `ps4-retrobox-v1.0.zip` from [Releases](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.0)
2. **Extract** the zip on your PC
3. **Choose kernel** — rename the correct kernel to `bzImage`:
   - **Aeolia/Belize** (Fat CUH-1000/1100/1200, Slim CUH-2000): rename `bzImage_no-built-in-fw_Clang_fullLTO` → `bzImage`
   - **Baikal** (Pro CUH-7000): rename `bzImage_Baikal_5.4.247` → `bzImage`
4. **FTP** 4 files to your PS4 (see Phase 3 below)
5. **Jailbreak** → GoldHEN → Enable BinLoader → send 2GB payload
6. **Run** `exec install-HDD.sh` → type `32` → wait for extraction to finish
7. **Done** — Linux boots automatically into EmulationStation

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
├── SNES\
├── N64\
├── GBA\
├── GameBoy\
├── Genesis\
├── PlayStation\
├── TurboGrafx16\
├── NintendoDS\
├── Arcade\
├── NeoGeo\
├── Atari2600\
├── Atari7800\
├── MasterSystem\
├── GameGear\
├── C64\
├── PCEngineCD\
└── BIOS\
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

`bootargs.txt` contains kernel boot parameters that fix common issues like black screen and garbled display. It is loaded automatically by the payload.

```
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0 drm.debug=0 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8 console=tty0 video=HDMI-A-1:1920x1080@60
```

| Parameter | Purpose |
|-----------|---------|
| `panic=0` | Reboot immediately on kernel panic |
| `clocksource=tsc` | Force TSC clocksource |
| `consoleblank=0` | Disable console screen blanking |
| `net.ifnames=0` | Use legacy interface names (`eth0` instead of `enp3s0`) |
| `radeon.dpm=0` | Disable Radeon power management (prevents crashes) |
| `amdgpu.dpm=0` | Disable AMDGPU power management (prevents crashes) |
| `console=tty0` | Output to virtual console (TV screen) |
| `video=HDMI-A-1:1920x1080@60` | Force 1080p60 output on HDMI connector (bypasses EDID, works with any TV including 4K) |

**Important:** Do NOT use `drm.edid_firmware=edid/1920x1080.bin` — this file doesn't exist in the kernel and causes error messages. Use `video=HDMI-A-1:1920x1080@60` instead.

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
netcat -w 5 <PS4-IP> 9020 < payload-960-1gb.elf
```

**Method 2: GoldHEN BinLoader (from PS4 browser)**
1. On PS4 browser, go to `karo218.ir`
2. Click **G2All** → wait for jailbreak
3. Go to **GoldHEN** → **Enable BinLoader Server**
4. From PC, use a payload sender app or netcat to send the `.elf` file to port 9020

**Method 3: Windows payload sender apps**
- Use any PS4 payload sender application (e.g., PS4 Payload Sender, BinLoader)
- Enter PS4 IP and port 9020
- Select `payload-960-1gb.elf`
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
3. Create a 3GB `.img` file on the internal HDD (minimal — expands on first boot)
4. Format it as ext4
5. Extract the rootfs into it (takes 5-15 minutes)
6. Print "Installation complete!" and init boots into Linux automatically

**If an `.img` file already exists** — the script will refuse to run and tell you to delete it first. This prevents accidentally overwriting your existing install. To reinstall:
```bash
rm /ps4hdd/home/arch.img
exec install-HDD.sh
```

**If it fails:** Try again with 1GB payload. Ensure all 4 files were uploaded via FTP to the correct paths.

#### Step 6: First Boot

After extraction completes, init automatically boots into Linux:
1. Ubuntu boots from the `.img` file on internal HDD
2. tty1 auto-logs in as `PS4` user
3. EmulationStation launches automatically
4. You'll see the EmulationStation menu

**If you get a black screen:** Try connecting a different monitor/TV, or check `bootargs.txt` is at `/data/linux/boot/bootargs.txt`.

### Phase 5: Configure Samba

SSH into PS4 from your PC:

```bash
ssh PS4@<PS4-IP>
# Password: PS4
```

Edit the Samba helper script with your PC's IP and share name:

```bash
sudo nano /usr/local/bin/setup-samba.sh
```

Change the values at the top of the file:

```bash
PC_IP="192.168.1.100"        # <-- Your Windows PC IP
SHARE="PS4_ROMs"             # <-- Your share name
```

Then run it:

```bash
sudo setup-samba.sh
```

Copy BIOS files to local storage:

```bash
cp /mnt/roms/BIOS/* /home/PS4/BIOS/
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

**Method 1: SCP/SFTP (recommended)**
Copy ROMs from your PC over SSH:
```bash
scp -r /path/to/roms/* PS4@<PS4-IP>:/home/PS4/ROMs/SNES/
# Password: PS4
# Other ROM dirs: N64, GBA, GameBoy, Genesis, PlayStation, TurboGrafx16,
#   NintendoDS, Arcade, NeoGeo, Atari2600, Atari7800, MasterSystem, GameGear, C64, PCEngineCD
```

**Method 2: Samba share**
Edit the Samba helper script with your PC's IP:
```bash
ssh PS4@<PS4-IP>   # Password: PS4
sudo nano /usr/local/bin/setup-samba.sh
```
Change `PC_IP` and `SHARE`, then run `sudo setup-samba.sh`.

ROMs appear in EmulationStation after restarting it (press Start → Quit → run `startx`).

#### Payload Summary

| Payload | Use When | RAM to GPU | Netcat | Payload Loader |
|---------|----------|------------|--------|----------------|
| `payload-960-1gb.elf` | First install only | 1GB | ✅ | ✅ |
| `payload-960-2gb.elf` | Daily gaming (recommended) | 2GB | ✅ | ✅ |
| `payload-960-3gb.elf` | Optional — better GPU perf | 3GB | ✅ | ✅ |
| `payload-960-4gb.elf` | Optional — maximum GPU perf | 4GB | ✅ | ✅ |

**Tip:** If Linux fails to boot with 2GB payload, try the 1GB payload first. Some systems may need the lower RAM allocation to boot reliably.

**Note:** Higher VRAM = less RAM for CPU/system. 3GB/4GB may cause instability on PS4 Fat with only 4GB total RAM. **2GB is recommended for daily use.** 3GB and 4GB payloads are optional and provided for testing.

## Recovery — How to Undo Everything

Because Linux lives as a single `.img` file, removing it fully restores your PS4:

1. **FTP** into your PS4 (or SSH if Linux is running)
2. **Delete** `/user/home/arch.img` — this is the entire Linux installation
3. **Delete** `/data/linux/boot/bzImage` and `/data/linux/boot/initramfs.cpio.gz` — the kernel and initramfs

Your PS4 is now completely back to stock OrbisOS. No partition changes, no firmware modifications, no traces of Linux.

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
| No WiFi | WiFi not supported on CUH-1000/1100. Use Ethernet cable. |
| No Bluetooth | Use USB BT dongle |
| SSH refused | Ensure Ethernet cable connected, try `ping <PS4-IP>` |
| No IP address | Ensure Ethernet cable is connected to router. Run `ip a` on PS4 to check. |
| Samba mount fails | Check PC IP, firewall, share name, credentials |
| BIOS not found | Verify files in `/home/PS4/BIOS/` |
| ROMs not showing | Check `ls /home/PS4/ROMs/`, restart EmulationStation |
| HDD install fails | Try 1GB payload, re-download files, check FTP paths |
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

- [feeRnt](https://github.com/feeRnt/ps4-linux-initramfs) — Open-source initramfs with PS4 HDD support
- [feeRnt](https://github.com/feeRnt/ps4-linux-12xx) — PS4 Linux kernel 6.15.4 for Aeolia/Belize
- [crashniels](https://github.com/crashniels/linux) — Kernel source with WiFi/BT patches
- [Aloshi](https://github.com/Aloshi/EmulationStation) — EmulationStation
- [libretro](https://www.libretro.com) — RetroArch and libretro cores
- [ps4boot](https://github.com/ps4boot/ps4-linux-payloads) — PS4 Linux payloads

## License

This project combines open-source software. See individual licenses for each component.

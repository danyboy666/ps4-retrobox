# PS4 RetroBox

> **DISCLAIMER**: This project was assembled by an AI assistant (OpenCode). The author is testing this method on real hardware to verify it is valid and safe. Use at your own risk. Always ensure you have a way to recover your PS4 if something goes wrong. The author assumes no responsibility for any damage to your console.

Turn your jailbroken PS4 into a retro gaming machine with EmulationStation + RetroArch.

Minimal Ubuntu 22.04 server rootfs for PS4 Fat (Aeolia southbridge) installed on internal HDD, with network-loaded ROMs via Samba.

## Features

- **EmulationStation** frontend (compiled from source)
- **RetroArch** with 9 libretro cores pre-installed
- **Internal HDD install** — runs from 32GB `.img` file on PS4's encrypted HDD
- **No USB drive needed** after initial setup — all boot files on internal HDD
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

## Requirements

- PS4 Fat **CUH-1001A** (Aeolia southbridge)
- Firmware **9.60** (exploitable via PSFree-Enhanced or karo218.ir)
- Windows PC on the **same network** as PS4
- Ethernet cable recommended (WiFi works with USB dongle)
- **No USB drive required** — everything is transferred via FTP

## Quick Start

1. **Download** — grab `ps4-retrobox-v1.0.zip` from [Releases](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.0)
2. **Extract** the zip on your PC
3. **Rename** `bzImage_no-built-in-fw_Clang_fullLTO` to `bzImage`
4. **FTP** 4 files to your PS4 (see Phase 3 below)
5. **Boot** — send payload → run `exec install-HDD.sh` → enter `32`
6. **Play** — SSH in, configure Samba, load ROMs

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
└── BIOS\
```

Share the folder:
1. Right-click `C:\PS4_ROMs` → Properties → Sharing → Share
2. Add user `Everyone` with Read access
3. Note your PC's IP address (run `ipconfig`)

### Phase 2: PS4 Preparation

1. **Settings** → Disable **HDCP**
2. **Settings** → **Screen and Video** → Set resolution to **1080p**
3. **Settings** → **System** → Disable **HDMI Device Link**
4. Connect PS4 to network (Ethernet recommended)
5. Enable **FTP** on PS4:
   - GoldHEN → Server Settings → Enable FTP
   - Note the PS4's IP address

### Phase 3: FTP Files to Internal HDD

From your PC, FTP these 4 files to the PS4:

| Local File | Rename To | FTP Path | Size |
|------------|-----------|----------|------|
| `bzImage_no-built-in-fw_Clang_fullLTO` | **`bzImage`** | `/data/linux/boot/bzImage` | ~18MB |
| `initramfs.cpio.gz` | (keep name) | `/data/linux/boot/initramfs.cpio.gz` | ~6MB |
| `bootargs.txt` | (keep name) | `/data/linux/boot/bootargs.txt` | <1KB |
| `arch.tar.xz` | (keep name) | `/user/system/boot/arch.tar.xz` | ~492MB |

**Important:** You MUST rename `bzImage_no-built-in-fw_Clang_fullLTO` to just `bzImage` before uploading. The payload only looks for a file named `bzImage`.

Use FileZilla or any FTP client:
- Host: `<PS4-IP>`
- Port: `2121`
- Username/Password: (leave empty)

### What is bootargs.txt?

`bootargs.txt` contains kernel boot parameters that fix common issues like black screen. It is loaded automatically by the payload. The default contents fix display output and disable power management that can cause crashes:

```
panic=0 clocksource=tsc consoleblank=0 net.ifnames=0 radeon.dpm=0 amdgpu.dpm=0 drm.debug=0 console=uart8250,mmio32,0xd0340000 console=ttyS0,115200n8 console=tty0 drm.edid_firmware=edid/1920x1080.bin
```

**Important:** The kernel file must be renamed to `bzImage` (not the full original name).

### Phase 4: Install to Internal HDD

#### Step 1: Jailbreak

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

The script will:
1. Ask how many GB to allocate to Linux — type `32` and press Enter
2. List available `.tar.*` files on the internal HDD
3. Select the Ubuntu rootfs (usually option 1)
4. Create a 32GB `.img` file on the internal HDD
5. Extract the rootfs into it (takes 5-15 minutes)
6. Automatically reboot into Ubuntu

**If it asks to select a distro:** Choose the one that matches `arch.tar.xz` (your Ubuntu rootfs).

**If it fails:** Try again with 1GB payload. Ensure all 4 files were uploaded via FTP to the correct paths.

#### Step 6: First Boot

After installation completes, the PS4 reboots into Ubuntu:
1. Linux boots from the internal HDD `.img` file
2. tty1 auto-login as `PS4` user
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

### Phase 6: Daily Use

Once Linux is installed on the internal HDD, you don't need to run `install-HDD.sh` again. Every time you want to use Linux:

#### Step 1: Jailbreak

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

#### Step 2: Enable BinLoader

1. Go to **GoldHEN** → **Enable BinLoader Server**

#### Step 3: Send the 2GB Payload

For daily use, send the **2GB payload** for better GPU performance:

```bash
netcat -w 5 <PS4-IP> 9020 < payload-960-2gb.elf
```

The 2GB payload allocates 2GB of PS4 RAM to the GPU, giving better graphics performance than the 1GB payload used for installation.

#### Step 4: Linux Boots

1. The payload loads kernel + initramfs from internal HDD
2. Ubuntu boots from the `.img` file on internal HDD
3. tty1 auto-login as `PS4`
4. EmulationStation launches automatically
5. Play!

#### Step 5: Shutdown

When done gaming:
- Press **PS button** → Power → Turn Off PS4
- Or type `sudo shutdown -h now` in a terminal (if you have SSH access)

#### Adding ROMs

Add new ROMs by copying files to `C:\PS4_ROMs\<System>\` on your Windows PC. They appear in EmulationStation after:
- Restarting EmulationStation (press Start → Quit → restart with `startx`)
- Or rebooting the PS4 Linux

#### Payload Summary

| Payload | Use When | RAM to GPU |
|---------|----------|------------|
| `payload-960-1gb.elf` | First install only | 1GB |
| `payload-960-2gb.elf` | Daily gaming | 2GB |

**Tip:** If Linux fails to boot with 2GB payload, try the 1GB payload first. Some systems may need the lower RAM allocation to boot reliably.

## How It Works

The PS4 Linux boot chain:

```
Exploit (PSFree-Enhanced / karo218.ir) → GoldHEN → Payload (kexec) → Kernel (bzImage)
  → Initramfs (feeRnt) → Decrypt PS4 HDD → Find .img file
  → Loop-mount .img → switch_root → Ubuntu boots
```

- **Payload** loads kernel + initramfs from `/data/linux/boot/` on internal HDD
- **Initramfs** decrypts PS4's encrypted HDD partition, finds `.img` file at `/user/home/`
- **`.img` file** contains the full Ubuntu rootfs (32GB ext4 filesystem image)
- **No USB drive** needed — all files are on the internal HDD

## BIOS Files

Required BIOS files (place in `C:\PS4_ROMs\BIOS\` or copy to `/home/PS4/BIOS/`):

| System | File(s) | Size |
|--------|---------|------|
| PS1 | SCPH1001.bin | 512KB |
| PS2 | SCPH10000.bin | 4MB |
| TurboGrafx-16 | syscard3.pce | 24KB |
| GBA (optional) | gba_bios.bin | 16KB |

## Uninstalling

To remove Linux from your PS4:
1. Enable FTP on PS4
2. Delete `/user/home/arch.img` (or whatever the `.img` file is named)
3. Delete `/data/linux/boot/bzImage` and `/data/linux/boot/initramfs.cpio.gz`

This fully restores your PS4 to OrbisOS with no changes.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Black screen | Use `bootargs.txt` params, try TV instead of monitor |
| No WiFi | Use USB WiFi dongle or Ethernet cable |
| No Bluetooth | Use USB BT dongle |
| SSH refused | Ensure same network, try `ping <PS4-IP>` |
| Samba mount fails | Check PC IP, firewall, share name, credentials |
| BIOS not found | Verify files in `/home/PS4/BIOS/` |
| ROMs not showing | Check `ls /mnt/roms/`, restart EmulationStation |
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

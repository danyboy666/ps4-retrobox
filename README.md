# PS4 RetroBox

Turn your jailbroken PS4 into a retro gaming machine with EmulationStation + RetroArch.

Minimal Ubuntu 22.04 server rootfs designed for PS4 Fat (Aeolia southbridge) with network-loaded ROMs via Samba.

## Features

- **EmulationStation** frontend (compiled from source)
- **RetroArch** with 9 libretro cores pre-installed
- **SSH server** enabled (user: `PS4`, password: `PS4`)
- **Auto-boot** into EmulationStation on tty1
- **Samba client** for loading ROMs from your PC over the network
- **Internal HDD install** (32GB partition) — no USB drive needed after setup
- **Dual payload support** — 1GB for first boot, 2GB for daily use

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
- Firmware **9.60** (exploitable via karo218.ir jailbreak)
- USB 3.0 drive (16GB+) formatted as **FAT32**
- Windows PC on the **same network** as PS4
- Ethernet cable recommended (WiFi works with USB dongle)

## Quick Start

1. **Download binaries** — run `./download-binaries.sh` or grab files from [Releases](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.0)
2. **Copy to USB** — put all 7 files on root of FAT32 USB drive
3. **Boot payload** — send `payload-960-1gb.elf` via BinLoader
4. **Install to HDD** — run `exec install-HDD.sh` in rescueshell, enter `32`
5. **Configure Samba** — SSH in, edit `setup-samba.sh` with your PC's IP, then run it

## Detailed Installation

### Phase 1: Prepare Windows PC (Samba Share)

Create a shared folder on your Windows PC:

```
C:\PS4_ROMs\
├── NES\
├── SNES\
├── N64\
├── GBA\
├── GB\
├── Genesis\
├── PlayStation\
├── PSP\
├── NDS\
├── TurboGrafx16\
└── BIOS\
```

Share the folder:
1. Right-click `C:\PS4_ROMs` → Properties → Sharing → Share
2. Add user `Everyone` with Read access
3. Note your PC's IP address (run `ipconfig`)

### Phase 2: Prepare USB Drive

1. Format USB as **FAT32**
2. Copy all release files to root of USB:

```
USB Root/
├── payload-960-1gb.elf
├── payload-960-2gb.elf
├── bzImage_no-built-in-fw_Clang_fullLTO
├── initramfs.cpio.gz
├── ps4-ubuntu-es.tar.xz
└── bootargs.txt
```

### Phase 3: PS4 Preparation

1. **Settings** → Disable **HDCP**
2. **Settings** → **Screen and Video** → Set resolution to **1080p**
3. **Settings** → **System** → Disable **HDMI Device Link**
4. Connect PS4 to network (Ethernet recommended)

### Phase 4: First Boot (Test from USB)

1. Open **Browser** → go to `karo218.ir`
2. Click **G2All** → wait for jailbreak
3. Go to **GoldHEN** → **Enable BinLoader Server**
4. From PC, send 1GB payload:
   ```bash
   netcat -w 5 <PS4-IP> 9020 < payload-960-1gb.elf
   ```
5. Rescueshell appears (white text on black screen)
6. Test USB boot:
   ```bash
   exec start-psxitarch.sh
   ```
7. Verify EmulationStation loads, then reboot: `reboot`

### Phase 5: Install to Internal HDD

1. Boot again with 1GB payload → rescueshell
2. Insert USB drive with all files
3. Run HDD install:
   ```bash
   exec install-HDD.sh
   ```
4. When prompted, enter partition size: **32** (GB)
5. Wait 5-15 minutes for extraction
6. System auto-reboots into HDD Linux

### Phase 6: Configure Samba

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
- Creates `/mnt/roms` mount point
- Adds auto-mount entry to `/etc/fstab`
- Mounts the Samba share

Copy BIOS files to local storage:

```bash
cp /mnt/roms/BIOS/* /home/PS4/BIOS/
```

### Phase 7: Daily Use

For everyday gaming, use the 2GB payload for better GPU performance:

```bash
netcat -w 5 <PS4-IP> 9020 < payload-960-2gb.elf
```

Linux boots → tty1 auto-login → EmulationStation launches → play!

Add new ROMs by copying files to `C:\PS4_ROMs\<System>\` on your Windows PC. They appear in EmulationStation on next restart.

## BIOS Files

Required BIOS files (place in `C:\PS4_ROMs\BIOS\` or `/home/PS4/BIOS/`):

| System | File(s) | Size |
|--------|---------|------|
| PS1 | SCPH1001.bin | 512KB |
| PS2 | SCPH10000.bin | 4MB |
| TurboGrafx-16 | syscard3.pce | 24KB |
| GBA (optional) | gba_bios.bin | 16KB |

## Partition Layout (32GB)

```
Internal HDD Linux Partition
├── /                     5GB (rootfs + packages)
├── /home/PS4/           26GB
│   ├── BIOS/             100MB (local BIOS)
│   ├── ROMs/saves/       1GB (local saves)
│   └── ROMs/screenshots/ 500MB
└── swap                  1GB
```

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
| HDD install fails | Try 1GB payload, ensure FAT32 USB, re-download files |

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
6. Packages everything as `ps4-ubuntu-es.tar.xz`

## Credits

- [feeRnt](https://github.com/feeRnt/ps4-linux-12xx) — PS4 Linux kernel 6.15.4 for Aeolia/Belize
- [crashniels](https://github.com/crashniels/linux) — Kernel source with WiFi/BT patches
- [noob404](https://ps4linux.com) — Multi-boot initramfs, community resources
- [Aloshi](https://github.com/Aloshi/EmulationStation) — EmulationStation
- [libretro](https://www.libretro.com) — RetroArch and libretro cores
- [ps4boot](https://github.com/ps4boot/ps4-linux-payloads) — PS4 Linux payloads

## License

This project combines open-source software. See individual licenses for each component.

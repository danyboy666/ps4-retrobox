# PS4 RetroBox

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
- Firmware **9.60** (exploitable via karo218.ir jailbreak)
- Windows PC on the **same network** as PS4
- Ethernet cable recommended (WiFi works with USB dongle)
- **No USB drive required** — everything is transferred via FTP

## Quick Start

1. **Download** — grab `ps4-retrobox-v1.0.zip` from [Releases](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.0)
2. **Extract** the zip on your PC
3. **FTP** 3 files to your PS4 (see Phase 3 below)
4. **Boot** — send payload → run `exec install-HDD.sh` → enter `32`
5. **Play** — SSH in, configure Samba, load ROMs

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

From your PC, FTP these 3 files to the PS4:

| File | FTP Path | Size |
|------|----------|------|
| `bzImage_no-built-in-fw_Clang_fullLTO` | `/data/linux/boot/bzImage` | ~18MB |
| `initramfs.cpio.gz` (feeRnt) | `/data/linux/boot/initramfs.cpio.gz` | ~6MB |
| `arch.tar.xz` (Ubuntu rootfs) | `/user/system/boot/arch.tar.xz` | ~492MB |

Use FileZilla or any FTP client:
- Host: `<PS4-IP>`
- Port: `2121`
- Username/Password: (leave empty)

**Important:** The kernel file must be renamed to `bzImage` (not the full original name).

### Phase 4: Install to Internal HDD

1. **Disable FTP** on PS4 (GoldHEN → Server Settings → Disable FTP)
2. Open **Browser** → go to `karo218.ir`
3. Click **G2All** → wait for jailbreak
4. Go to **GoldHEN** → **Enable BinLoader Server**
5. From PC, send 1GB payload:
   ```bash
   netcat -w 5 <PS4-IP> 9020 < payload-960-1gb.elf
   ```
6. Rescueshell appears (white text on black screen)
7. Run HDD install:
   ```bash
   exec install-HDD.sh
   ```
8. When prompted, enter size: **32** (GB)
9. Wait 5-15 minutes for extraction
10. System reboots into Ubuntu

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

For everyday gaming, use the 2GB payload for better GPU performance:

```bash
netcat -w 5 <PS4-IP> 9020 < payload-960-2gb.elf
```

Linux boots → tty1 auto-login → EmulationStation launches → play!

Add new ROMs by copying files to `C:\PS4_ROMs\<System>\` on your Windows PC. They appear in EmulationStation on next restart.

## How It Works

The PS4 Linux boot chain:

```
Exploit (karo218.ir) → GoldHEN → Payload (kexec) → Kernel (bzImage)
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

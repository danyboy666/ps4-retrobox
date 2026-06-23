# Installation Guide

## Quick Start (First Time)

1. Download `ps4-retrobox-v1.3.zip` from [Releases](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.3)
2. Extract on your PC
3. Rename the kernel: `bzImage_no-built-in-fw_Clang_fullLTO` → `bzImage` (for Aeolia/Belize) or `bzImage_Baikal_5.4.247` → `bzImage` (for Pro)
4. FTP 4 files to PS4 (see Phase 3 below)
5. Jailbreak → GoldHEN → Enable BinLoader → send **1GB payload**
6. Wait for install — creates 3GB `.img`, extracts rootfs, asks to expand
7. Done — Linux boots into EmulationStation

**Use the 1GB payload for install** (leaves max RAM for extraction). For daily gaming, use the 2GB payload (better GPU performance).

## Daily Use

### Option A: Netcat (PC required)
1. Jailbreak → GoldHEN → Enable BinLoader
2. From PC: `netcat -w 5 <PS4-IP> 9020 < payload-960-2gb.elf`
3. Linux boots → ES launches → play!

### Option B: Payload Loader (No PC needed)
1. Jailbreak → GoldHEN → Payload Loader
2. Select `/data/payloads/payload-960-2gb.elf`
3. Linux boots → ES launches → play!

**One-time setup for Option B:** Download [Payload Loader PKG](https://pkg-zone.com/download/ps4/FLTZ00001/latest), install via GoldHEN → Package Installer, FTP `payload-960-2gb.elf` to `/data/payloads/`.

## Phase 3: FTP Files to PS4

FTP these 4 files (use FileZilla, port 2121, no auth):

| File | Rename To | FTP Path |
|------|-----------|----------|
| `bzImage_no-built-in-fw_Clang_fullLTO` (Aeolia/Belize) | `bzImage` | `/data/linux/boot/bzImage` |
| `initramfs.cpio.gz` | keep name | `/data/linux/boot/initramfs.cpio.gz` |
| `bootargs.txt` | keep name | `/data/linux/boot/bootargs.txt` |
| `arch.tar.xz` | keep name | `/user/system/boot/arch.tar.xz` |

**You MUST rename the kernel to `bzImage` before uploading.**

## Phase 4: Install to HDD

1. Jailbreak (PSFree-Enhanced or karo218.ir)
2. Enable BinLoader in GoldHEN
3. Send payload from PC: `netcat -w 5 <PS4-IP> 9020 < payload-960-1gb.elf`
4. Rescueshell appears — connect USB keyboard
5. Run: `exec install-HDD.sh`
6. Script auto-detects HDD partition, decrypts, creates 3GB .img, extracts rootfs
7. Choose: keep 3GB or expand (16/32/50GB)
8. Reboot → Linux boots into EmulationStation

## Adding ROMs

**SCP/SFTP:**
```bash
scp -r /path/to/roms/* PS4@<PS4-IP>:/home/PS4/ROMS/snes/
# Password: PS4
```

**USB:** Copy ROMs to USB drive, mount on PS4, copy to ROMS dir.

ROMs appear in ES automatically. If not, press Start → Quit → restart ES.

## BIOS Files

| System | File | Size |
|--------|------|------|
| PS1 | SCPH1001.bin | 512KB |
| TurboGrafx-16 | syscard3.pce | 24KB |
| GBA (optional) | gba_bios.bin | 16KB |

Copy to `/home/PS4/BIOS/` via SCP:
```bash
scp BIOS/*.bin PS4@<PS4-IP>:/home/PS4/BIOS/
```

## Recovery

Delete `.img` to fully restore OrbisOS:
```bash
# Via SSH
sudo rm /ps4hdd/home/arch.img
sudo rm /data/linux/boot/bzImage /data/linux/boot/initramfs.cpio.gz
```

If Linux won't boot, PS4 simply boots OrbisOS normally. No risk of bricking.

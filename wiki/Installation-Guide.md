# Installation Guide

## Prerequisites

- PS4 Fat CUH-1000/1100 (Aeolia) with firmware 9.60 (or 5.05–13.02 jailbreakable)
- Ethernet cable connected
- Windows PC on same network
- [GoldHEN](https://github.com/GoldHEN) installed on PS4

## Files Needed

Download [v1.3 ZIP](https://github.com/danyboy666/ps4-retrobox/releases/tag/v1.3) and extract:

| File | FTP To | Notes |
|------|--------|-------|
| `bzImage_no-built-in-fw_Clang_fullLTO` | `/data/linux/boot/bzImage` | Rename to `bzImage` |
| `initramfs.cpio.gz` | `/data/linux/boot/initramfs.cpio.gz` | |
| `arch.tar.xz` | `/user/system/boot/arch.tar.xz` | |
| `payload-960-*.bin` | `/data/` | Choose matching RAM size |

## First Time Install

1. Boot PS4 into GoldHEN
2. Enable BinLoader in GoldHEN settings
3. FTP the 4 files to PS4 (use WinSCP, port 2121)
4. Send the **1GB payload** matching your PS4's RAM size
5. Linux boots, runs automatic install
6. When prompted, enter install size in GB (default: 32)
7. Reboot after install completes

## Daily Use

1. Jailbreak PS4
2. Open GoldHEN, enable BinLoader
3. Send the **2GB payload** (smaller, skips install)
4. Linux boots → EmulationStation loads

## After Install

### Add ROMs

SSH into PS4:

```bash
ssh PS4@<PS4_IP>
# Password: PS4
```

Copy ROMs to system folders:

```bash
scp game.nes PS4@<PS4_IP>:/home/PS4/ROMS/nes/
```

### Find PS4 IP

Check your router's DHCP list, or scan the network:

```bash
nmap -sn 192.168.1.0/24 | grep -B2 "Sony"
```

### Install systemd Service

After first boot, install the ES autostart service:

```bash
sudo systemctl enable es-session.service
sudo systemctl start es-session.service
```

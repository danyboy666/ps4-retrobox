# Network & File Transfer

## SSH Access

```bash
ssh PS4@<PS4-IP>  # Password: PS4
```

SSH is enabled by default on port 22.

## SCP/SFTP (Recommended for ROMs)

```bash
# Copy ROMs to .img storage
scp -r /path/to/roms/* PS4@<PS4-IP>:/home/PS4/ROMS/snes/

# Copy BIOS files
scp BIOS/*.bin PS4@<PS4-IP>:/home/PS4/BIOS/
```

## FTP

FTP server on port 2121 (pure-ftpd). Currently disabled by default. Enable via:
```bash
sudo systemctl start pure-ftpd
sudo systemctl enable pure-ftpd
```

## Samba Setup

1. Edit the helper script:
```bash
ssh PS4@<PS4-IP>
sudo nano /usr/local/bin/setup-samba.sh
```
Set your PC's IP and share name.

2. Run setup:
```bash
sudo setup-samba.sh --setup
```

3. Toggle ROM source in ES: navigate to "Network ROMs" system.

## NFS Mount

Mount an NFS share from your PC:
```bash
sudo mount -t nfs <PC-IP>:/path/to/roms /ps4hdd/ROMS
```

## USB Drive

```bash
sudo mount /dev/sdb1 /mnt
cp -r /mnt/ROMs/* /home/PS4/ROMS/
sudo umount /mnt
```

## File Locations

| Path | Contents |
|------|----------|
| `/home/PS4/ROMS/` | ROMs (in .img) |
| `/ps4hdd/ROMS/` | ROMs (on UFS) |
| `/home/PS4/BIOS/` | BIOS files |
| `/home/PS4/saves/` | Save files |
| `/home/PS4/screenshots/` | Screenshots |
| `/ps4hdd/home/arch.img` | Linux rootfs image |
| `/data/linux/boot/` | Kernel + initramfs |

# Network & File Transfer

## SSH

SSH is enabled by default on port 22.

```bash
ssh PS4@<PS4_IP>
# Password: PS4
```

## SCP (Copy Files)

```bash
# Copy a file
scp game.nes PS4@<PS4_IP>:/home/PS4/ROMS/nes/

# Copy a directory
scp -r roms/* PS4@<PS4_IP>:/home/PS4/ROMS/snes/

# Download from PS4
scp PS4@<PS4_IP>:/home/PS4/saves/save.srm ./
```

## SFTP

Use WinSCP (Windows) or FileZilla (any OS):

- Host: `<PS4_IP>`
- Port: 22
- User: `PS4`
- Password: `PS4`
- Protocol: SFTP

## Samba

Share PS4 ROMs on the network:

1. Edit the setup script:

```bash
sudo nano /usr/local/bin/setup-samba.sh
```

Set your PC's IP and share name.

2. Run setup:

```bash
sudo setup-samba.sh --setup
```

3. Access from Windows:

```
\\<PS4_IP>\PS4_ROMs
```

## FTP

FTP is disabled by default for security. To enable:

```bash
sudo systemctl enable vsftpd
sudo systemctl start vsftpd
```

## USB

Copy files to a USB drive and mount:

```bash
sudo mount /dev/sda1 /mnt
cp /mnt/ROMS/* /home/PS4/ROMS/nes/
sudo umount /mnt
```

#!/bin/sh
. /functions.sh

clear

# PS4 RetroBox installer
# Based on better-initramfs by Piotr Karbowski (BSD-3-Clause)
# PS4 initramfs by feeRnt — https://github.com/feeRnt/ps4-linux-initramfs

echo '                   ~.                   '
echo '            Ya...___|__..ab.     .   .  '
echo '             Y88b  \88b  \88b   (     ) '
echo '              Y88b  :88b  :88b   `.oo'\''  '
echo '              :888  |888  |888  ( (`-'\''  '
echo '     .---.    d88P  ;88P  ;88P   `.`.   '
echo '    / .-._)  d8P-"""|"""'\''-Y8P      `.`. '
echo '   ( (`._) .-.  .-. |.-.  .-.  .-.   ) )'
echo '    \ `---( O )( O )( O )( O )( O )-'\'' / '
echo '     `.    `-'\''  `-'\''  `-'\''  `-'\''  `-'\''  .'\''  '
echo '       `---------------------------'\''    '
echo '##  ##     ##     ######   ##  ##   ##  ##   ##  ##   ######'
echo '### ##    ####        ##   ## ##    ##  ##   ##  ##     ##'
echo '######   ##  ##      ##    ####     ##  ##   ##  ##     ##'
echo '######   ######     ##     ###       ####     ####      ##'
echo '## ###   ##  ##    ##      ####       ##       ##       ##'
echo '##  ##   ##  ##   ##       ## ##      ##       ##       ##'
echo '##  ##   ##  ##   ######   ##  ##     ##       ##       ##'
echo
echo '             Was that ship really necessary? Well, it looks cool at least - feeRnt'
echo ""
echo "=== PS4 RetroBox Installer ==="
echo ""

# Interrupt window — press any key to drop to rescueshell
echo "Press any key in 5 seconds to drop to rescue shell..."
echo "Otherwise, install will begin automatically."
echo ""
_interrupt=5
while [ "$_interrupt" -gt 0 ]; do
	printf "\r  Starting in %ds... " "$_interrupt"
	_key=""
	read -t 1 _key 2>/dev/null
	if [ -n "$_key" ]; then
		echo ""
		echo "Interrupted. Dropping to rescue shell."
		rescueshell
	fi
	_interrupt=$((_interrupt - 1))
done
echo ""
echo "Starting install..."
echo ""
echo "========================================"
echo "  NOTE: A USB keyboard is optional."
echo "  You can plug one in now if you want"
echo "  to interact with the script. Otherwise"
echo "  just let it run — no input required."
echo "========================================"
echo ""

# Auto-detect partition encryption scheme
if [ ! -e /dev/mapper/ps4hdd ]; then
	echo "Setting up cryptsetup..."
	if cryptsetup -d /key/eap_hdd_key.bin --cipher=aes-xts-plain64 -s 256 --offset=0 create ps4hdd /dev/sd?27 2>/dev/null; then
		echo "Using partition 27"
	elif cryptsetup -d /key/eap_hdd_key.bin --cipher=aes-xts-plain64 -s 256 --offset=0 create ps4hdd /dev/sd?13 2>/dev/null; then
		echo "Using partition 13"
	else
		echo "Trying partition 27 with --skip (for models needing ivoffset)..."
		cryptsetup -d /key/eap_hdd_key.bin --cipher=aes-xts-plain64 -s 256 --offset=0 --skip=111669149696 create ps4hdd /dev/sd?27
	fi
else
	echo "cryptsetup already done, skipping."
fi

# Mount if not already mounted
if ! mountpoint -q /ps4hdd 2>/dev/null; then
	mkdir -p /ps4hdd
	mount -t ufs -o ufstype=ufs2 /dev/mapper/ps4hdd /ps4hdd
else
	echo "/ps4hdd already mounted, skipping."
fi

# Verify UFS is writable
if ! touch /ps4hdd/.write_test 2>/dev/null; then
	echo "ERROR: UFS mounted read-only. Cannot install."
	echo "Try rebooting and running install-HDD.sh again."
	rescueshell
fi
rm -f /ps4hdd/.write_test
echo "UFS mounted and writable."

sleep 2
clear

# Auto-detect the .tar.* file
_install_OS="$(ls /ps4hdd/system/boot/*.tar.* 2>/dev/null | head -1)"
if [ -z "$_install_OS" ]; then
	echo "ERROR: No .tar.* found in /ps4hdd/system/boot/"
	echo "Upload arch.tar.xz via FTP first."
	rescueshell
fi
_install_OS="$(basename "$_install_OS")"
echo "Auto-detected OS: $_install_OS"

_install_OS_img="$(echo "$_install_OS" | sed -n 's/.tar.*/.img/p')"
echo "Target image: $_install_OS_img"

# Ask for target size with menu and countdown
echo ""
echo "Select target size for Linux installation:"
echo "  [1] Keep 3GB minimal — boot now (default)"
echo "  [2] 16 GB"
echo "  [3] 32 GB"
echo "  [4] 50 GB"
echo "  [5] Custom size"
echo ""
echo "Default: 3GB in 15 seconds..."
_COUNTDOWN=15
_TARGET_SIZE=""
while [ "$_COUNTDOWN" -gt 0 ] && [ -z "$_TARGET_SIZE" ]; do
	printf "\r  Choice [1-5]: %2ds " "$_COUNTDOWN"
	_CHOICE=""
	read -t 1 _CHOICE 2>/dev/null
	case "$_CHOICE" in
		1) _TARGET_SIZE=3 ;;
		2) _TARGET_SIZE=16 ;;
		3) _TARGET_SIZE=32 ;;
		4) _TARGET_SIZE=50 ;;
		5)
			echo ""
			echo -n "  Enter size in GB: "
			read _TARGET_SIZE
			# Validate input is a number
			case "$_TARGET_SIZE" in
				""|[!0-9]*)
					echo "  Invalid input. Using 3GB minimal."
					_TARGET_SIZE=3
					;;
			esac
			# Sanity check
			if [ "$_TARGET_SIZE" -lt 3 ] 2>/dev/null; then
				echo "  Too small (need at least 3GB). Using 3GB minimal."
				_TARGET_SIZE=3
			fi
			if [ "$_TARGET_SIZE" -gt 500 ] 2>/dev/null; then
				echo "  That's huge! Using 3GB minimal."
				_TARGET_SIZE=3
			fi
			break
			;;
	esac
	_COUNTDOWN=$((_COUNTDOWN - 1))
done
if [ -z "$_TARGET_SIZE" ]; then
	_TARGET_SIZE=3
	echo ""
	echo "  Auto-selected: 3GB minimal"
fi

# Only write .target_size if user chose expansion (not minimal)
if [ "$_TARGET_SIZE" -gt 3 ] 2>/dev/null; then
	echo ""
	echo "Target size: ${_TARGET_SIZE}GB"
	echo "$_TARGET_SIZE" > /ps4hdd/home/.target_size
	echo ""
	echo "  Image will be expanded to ${_TARGET_SIZE}GB on next boot."
else
	_TARGET_SIZE=3
	rm -f /ps4hdd/home/.target_size
	echo ""
	echo "  Booting 3GB minimal image."
fi
echo ""

# === Storage choice: .img or UFS ===
echo ""
echo "Where do you want to store ROMs?"
echo "  [1] Internal .img (default) — self-contained, easier backup"
echo "  [2] UFS (PS4HDD) — larger capacity, persists across reinstalls"
echo ""
echo "Default: 1 in 15 seconds..."
_STORAGE_COUNTDOWN=15
_STORAGE_CHOICE=""
while [ "$_STORAGE_COUNTDOWN" -gt 0 ] && [ -z "$_STORAGE_CHOICE" ]; do
    printf "\r  Choice [1-2]: %2ds " "$_STORAGE_COUNTDOWN"
    _SC=""
    read -t 1 _SC 2>/dev/null
    case "$_SC" in
        1) _STORAGE_CHOICE="img" ;;
        2) _STORAGE_CHOICE="ufs" ;;
    esac
    _STORAGE_COUNTDOWN=$((_STORAGE_COUNTDOWN - 1))
done
if [ -z "$_STORAGE_CHOICE" ]; then
    _STORAGE_CHOICE="img"
    echo ""
    echo "  Auto-selected: Internal .img"
fi
echo ""

# Show PS4 RetroBox art + ROM transfer instructions (visible during dd/extraction)
clear
cat << 'PS4ART'

 .--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--. 
/ .. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \
\ \/\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ \/ /
 \/ /`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'\/ / 
 / /\                                                                                                / /\ 
/ /\ \                                                                                              / /\ \
\ \/ /                                                                                              \ \/ /
 \/ /                                                                                                \/ / 
 / /\       ███████████   █████████  █████ █████                                                     / /\ 
/ /\ \     ░░███░░░░░███ ███░░░░░███░░███ ░░███                                                     / /\ \
\ \/ /      ░███    ░███░███    ░░░  ░███  ░███ █                                                   \ \/ /
 \/ /       ░██████████ ░░█████████  ░███████████                                                    \/ / 
 / /\       ░███░░░░░░   ░░░░░░░░███ ░░░░░░░███░█                                                    / /\ 
/ /\ \      ░███         ███    ░███       ░███░                                                    / /\ \
\ \/ /      █████       ░░█████████        █████                                                    \ \/ /
 \/ /      ░░░░░         ░░░░░░░░░        ░░░░░                                                      \/ / 
 / /\                                                                                                / /\ 
/ /\ \                                                                                              / /\ \
\ \/ /                                                                                              \ \/ /
 \/ /       ███████████             █████                       █████                                \/ / 
 / /\      ░░███░░░░░███           ░░███                       ░░███                                 / /\ 
/ /\ \      ░███    ░███   ██████  ███████   ████████   ██████  ░███████   ██████  █████ █████      / /\ \
\ \/ /      ░██████████   ███░░███░░░███░   ░░███░░███ ███░░███ ░███░░███ ███░░███░░███ ░░███       \ \/ /
 \/ /       ░███░░░░░███ ░███████   ░███     ░███ ░░░ ░███ ░███ ░███ ░███░███ ░███ ░░░█████░         \/ / 
 / /\       ░███    ░███ ░███░░░    ░███ ███ ░███     ░███ ░███ ░███ ░███░███ ░███  ███░░░███        / /\ 
/ /\ \      █████   █████░░██████   ░░█████  █████    ░░██████  ████████ ░░██████  █████ █████      / /\ \
\ \/ /     ░░░░░   ░░░░░  ░░░░░░     ░░░░░  ░░░░░      ░░░░░░  ░░░░░░░░   ░░░░░░  ░░░░░ ░░░░░       \ \/ /
 \/ /                                                                                                \/ / 
 / /\                                                                                                / /\ 
/ /\ \                                                                                              / /\ \
\ \/ /                                                                                              \ \/ /
 \/ /                                                                                                \/ / 
 / /\.--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--./ /\ 
/ /\ \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \/\ \
\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `' /
 `--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--' 

PS4ART
echo ""
echo "=========================================="
echo "  Installation in progress!"
echo "=========================================="
echo ""
echo "  After install, transfer ROMs via:"
echo ""
echo "  SCP/SSH:"
echo "    scp *.sfc PS4@<PS4_IP>:/home/PS4/ROMS/snes/"
echo ""
echo "  FTP:"
echo "    Connect with any FTP client to PS4@<PS4_IP>"
echo "    Navigate to /home/PS4/ROMS/"
echo ""
echo "  USB: Plug USB drive, copy files to:"
echo "    /home/PS4/ROMS/<system>/"
echo "    /home/PS4/BIOS/"
echo ""
echo "  Samba (network share):"
echo "    1. Edit: sudo nano /usr/local/bin/setup-samba.sh"
echo "    2. Set your PC IP and share name, save"
echo "    3. Run: sudo setup-samba.sh --setup"
echo "    4. From PC browse: \\\\PS4_IP\\PS4_ROMs"
echo ""
echo "  ROM folders: snes, nes, n64, gba, gb, gbc,"
echo "    megadrive, psx, tg16, tgcd, arcade, neogeo,"
echo "    atari2600, atari5200, atari7800, mastersystem, gamegear"
echo "=========================================="
echo ""

# Create 3GB .img (rootfs ~2.3GB uncompressed + ext4 overhead + headroom)
_TOTAL_MB=3072
_IMG_FILE="/ps4hdd/home/$_install_OS_img"

echo ""
echo "=== Creating 3GB .img ==="

# Try sparse creation first (truncate, instant)
rm -f "$_IMG_FILE" 2>/dev/null
truncate -s "${_TOTAL_MB}M" "$_IMG_FILE" 2>/dev/null

# Verify sparse file actually got created with real size
_ACTUAL_SIZE=$(stat -c %s "$_IMG_FILE" 2>/dev/null || echo 0)
if [ "$_ACTUAL_SIZE" -gt 1048576 ]; then
	echo "  Sparse image created (instant)."
	_SPARSE=1
else
	# UFS doesn't support sparse files, use real dd (slow)
	echo "  UFS does not support sparse files."
	echo "  Writing 3GB of zeros (this is slow)..."
	rm -f "$_IMG_FILE" 2>/dev/null
	_SPARSE=0
	_START=$(date +%s)
	dd if=/dev/zero of="$_IMG_FILE" bs=1M count=$_TOTAL_MB 2>/dev/null &
	_DD_PID=$!
	sleep 3
	while kill -0 $_DD_PID 2>/dev/null; do
		_DONE_KB=$(du -k "$_IMG_FILE" 2>/dev/null | awk '{print $1}')
		_DONE_MB=$((_DONE_KB / 1024))
		_PCT=$((_DONE_MB * 100 / _TOTAL_MB))
		_ELAPSED=$(($(date +%s) - _START))
		if [ "$_ELAPSED" -gt 0 ] && [ "$_DONE_MB" -gt 0 ]; then
			_SPEED=$((_DONE_MB / _ELAPSED))
			if [ "$_SPEED" -gt 0 ]; then
				_REMAIN=$(( (_TOTAL_MB - _DONE_MB) / _SPEED / 60 ))
				echo -ne "\r  Writing: ${_DONE_MB}MB / ${_TOTAL_MB}MB (${_PCT}%) | ~${_REMAIN} min  "
			fi
		fi
		sleep 5
	done
	wait $_DD_PID
	echo ""
	echo "  Image file created."
fi

# Verify .img is large enough for ext4
_ACTUAL_SIZE=$(stat -c %s "$_IMG_FILE" 2>/dev/null || echo 0)
if [ "$_ACTUAL_SIZE" -lt 10485760 ]; then
	echo "ERROR: .img file is too small ($((_ACTUAL_SIZE / 1048576))MB). Need at least 10MB."
	echo "Something went wrong with image creation."
	rescueshell
fi

# Format as ext4
echo ""
echo "Formatting ext4..."
[ ! -e /dev/loop5 ] && mknod /dev/loop5 b 7 5
losetup /dev/loop5 "$_IMG_FILE"

if ! /bin/mke2fs -t ext4 /dev/loop5; then
	echo "ERROR: mke2fs failed."
	losetup -d /dev/loop5 2>/dev/null
	rescueshell
fi
echo "  ext4 formatted."

# Mount and extract
mkdir -p /newroot
if ! mount -t ext4 /dev/loop5 /newroot; then
	echo "ERROR: mount failed."
	losetup -d /dev/loop5 2>/dev/null
	rescueshell
fi

echo ""
echo "Extracting rootfs..."
cd /newroot

# Background progress tracker (polls every 10 seconds, no overhead on tar)
(
    while true; do
        _DONE=$(du -sb /newroot 2>/dev/null | awk '{print $1}')
        _DONE_MB=$((_DONE / 1048576))
        echo -ne "\r  Extracting: ~${_DONE_MB}MB extracted  "
        sleep 10
    done
) &
_PROG_PID=$!

# Extract at full speed (--no-same-owner: all files become root, chown fixes home later)
tar xf "/ps4hdd/system/boot/$_install_OS" --no-same-owner
_TAR_EXIT=$?

# Kill progress tracker
kill $_PROG_PID 2>/dev/null
wait $_PROG_PID 2>/dev/null
echo ""

# Verify extraction succeeded before continuing
if [ "$_TAR_EXIT" -ne 0 ] || [ ! -e /newroot/sbin/init ]; then
    echo "ERROR: Rootfs extraction failed or incomplete."
    echo "  tar exit code: $_TAR_EXIT"
    [ -e /newroot/sbin/init ] && echo "  /sbin/init: found" || echo "  /sbin/init: MISSING"
    echo "  The .img was kept. Reboot to retry or choose delete."
    losetup -d /dev/loop5 2>/dev/null
    rescueshell
fi
echo "Extraction verified: /sbin/init found."

# Fix ownership — busybox tar may not resolve uid/gid correctly
echo "Fixing file ownership..."
chown -R 1000:1000 /newroot/home/PS4

# Fix setuid bits — busybox tar/cpio strips them
echo "Restoring setuid bits..."
chmod u+s /newroot/usr/bin/sudo
chmod u+s /newroot/usr/bin/su
chmod u+s /newroot/usr/bin/passwd
chmod u+s /newroot/usr/bin/pkexec

# Copy ROMs to UFS if user chose that option (BEFORE umount — /newroot must be mounted)
echo ""
if [ "$_STORAGE_CHOICE" = "ufs" ]; then
    echo "UFS storage selected. Copying ROMs to UFS..."
    for sys in snes nes n64 gba gb gbc megadrive psx tg16 tgcd arcade neogeo atari2600 atari5200 atari7800 mastersystem gamegear; do
        mkdir -p "/ps4hdd/ROMS/$sys"
    done
    cp -r /newroot/home/PS4/ROMS/* /ps4hdd/ROMS/
    echo "Fixing UFS ROM ownership..."
    chown -R 1000:1000 /ps4hdd/ROMS
    # Clean up empty ROM dirs inside .img (they're on UFS now)
    rm -rf /newroot/home/PS4/ROMS
    mkdir -p /newroot/home/PS4/ROMS
    echo "Done! ROMs copied to UFS with correct ownership."
    echo "  UFS: /ps4hdd/ROMS/"
else
    echo "ROMs stored in .img (default)."
    echo "  .img: /home/PS4/ROMS/"
fi

# Sync and unmount cleanly (no 2>/dev/null — we need to know if this fails)
echo ""
echo "Syncing..."
sync
sleep 2
echo "Unmounting /newroot..."
if ! umount /newroot; then
    echo "WARNING: umount /newroot failed. Retrying with lazy unmount..."
    umount -l /newroot
    sleep 2
fi
if ! losetup -d /dev/loop5; then
    echo "WARNING: losetup -d /dev/loop5 failed."
fi

if [ "$_STORAGE_CHOICE" = "ufs" ]; then
    echo ""
    echo "To switch between UFS and Samba later:"
    echo "  Use 'Network' system in EmulationStation, or"
    echo "  Run: sudo setup-samba.sh --toggle"
else
    echo ""
    echo "To switch to UFS storage later:"
    echo "  1. Run: sudo setup-ufs-storage"
    echo "  2. Or manually copy ROMs to /ps4hdd/ROMS/"
fi

echo
echo "=== Install complete! ==="
echo ""
echo "PS4 RetroBox by danyboy666 — https://github.com/danyboy666/ps4-retrobox"
echo "Initramfs based on better-initramfs by Piotr Karbowski (BSD-3-Clause)"
echo "  https://bitbucket.org/piotrkarbowski/better-initramfs"
echo "PS4 initramfs by feeRnt — https://github.com/feeRnt/ps4-linux-initramfs"

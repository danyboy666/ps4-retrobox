clear

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
echo
echo

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

# Check for existing .img and validate
if [ -f "/ps4hdd/home/$_install_OS_img" ]; then
	# Verify ext4 magic number (0xEF53 at offset 0x438)
	_MAGIC="$(dd if="/ps4hdd/home/$_install_OS_img" bs=1 skip=1080 count=2 2>/dev/null | hexdump -e '1/2 "%04x"')"
	if [ "$_MAGIC" = "53ef" ]; then
		echo "Valid .img already exists with correct ext4 filesystem."
		echo "To reinstall, delete /ps4hdd/home/$_install_OS_img first."
		exit 0
	else
		echo "Existing .img has invalid ext4 magic ($_MAGIC). It is corrupt."
		rm -f "/ps4hdd/home/$_install_OS_img"
		echo "Deleted corrupt .img."
	fi
fi

# Ask for final target size (stored for expansion after first boot)
echo ""
echo "How large should the final image be after expansion?"
echo "Rootfs needs ~2.5GB. Common sizes: 16, 32, 50."
read -p "Final size in GB (default=32): " _TARGET_SIZE
_TARGET_SIZE="${_TARGET_SIZE:-32}"
echo "$_TARGET_SIZE" > /ps4hdd/home/.target_size
echo "Will expand to ${_TARGET_SIZE}GB after first boot."

# Create minimal 3GB .img (enough for rootfs + ext4 overhead)
_PARTSIZE=3
_TOTAL_MB=$((_PARTSIZE * 1024))
_IMG_FILE="/ps4hdd/home/$_install_OS_img"

echo ""
echo "=== Creating minimal ${_PARTSIZE}GB .img ==="

# Try sparse creation first (truncate, instant)
rm -f "$_IMG_FILE" 2>/dev/null
truncate -s "${_PARTSIZE}G" "$_IMG_FILE" 2>/dev/null

# Verify sparse file actually got created with real size
_ACTUAL_SIZE=$(stat -c %s "$_IMG_FILE" 2>/dev/null || echo 0)
if [ "$_ACTUAL_SIZE" -gt 1048576 ]; then
	echo "  Sparse image created (instant)."
	_SPARSE=1
else
	# UFS doesn't support sparse files, use real dd (slow)
	echo "  UFS does not support sparse files."
	echo "  Writing ${_PARTSIZE}GB of zeros (this is slow)..."
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

if ! mke2fs -j /dev/loop5; then
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

# Extract at full speed (no per-file overhead)
tar xf "/ps4hdd/system/boot/$_install_OS"

# Kill progress tracker
kill $_PROG_PID 2>/dev/null
wait $_PROG_PID 2>/dev/null
echo ""
echo "Extraction complete!"

echo "Syncing..."
sync

umount /newroot 2>/dev/null
losetup -d /dev/loop5 2>/dev/null

echo
echo "=== Install complete! ==="
echo ""
echo "The system will now boot into Linux automatically."
echo "On first boot, storage will auto-expand to ${_TARGET_SIZE}GB."
echo
echo "Script created by https://github.com/Nazky and https://github.com/feeRnt"

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
_PARTSIZE2="$(echo "($_PARTSIZE*1024*1024*1024/4096)/1" | bc)"

echo ""
echo "=== Creating minimal ${_PARTSIZE}GB .img ==="
truncate -s "${_PARTSIZE}G" "/ps4hdd/home/$_install_OS_img" 2>/dev/null
if [ $? -eq 0 ] && [ -f "/ps4hdd/home/$_install_OS_img" ]; then
	echo "  Sparse image created (instant)."
else
	echo "  truncate failed, falling back to dd (slow)..."
	rm -f "/ps4hdd/home/$_install_OS_img" 2>/dev/null
	_START=$(date +%s)
	dd if=/dev/zero of="/ps4hdd/home/$_install_OS_img" bs=4096 seek="$_PARTSIZE2" 2>/dev/null &
	_DD_PID=$!
	sleep 3
	while kill -0 $_DD_PID 2>/dev/null; do
		_DONE_KB=$(du -k "/ps4hdd/home/$_install_OS_img" 2>/dev/null | awk '{print $1}')
		_DONE_MB=$((_DONE_KB / 1024))
		_PCT=$((_DONE_MB * 100 / _TOTAL_MB))
		_ELAPSED=$(($(date +%s) - _START))
		if [ "$_ELAPSED" -gt 0 ] && [ "$_DONE_MB" -gt 0 ]; then
			_SPEED=$((_DONE_MB / _ELAPSED))
			if [ "$_SPEED" -gt 0 ]; then
				_REMAIN=$(( (_TOTAL_MB - _DONE_MB) / _SPEED / 60 ))
				echo -ne "\r  Creating image: ${_DONE_MB}MB / ${_TOTAL_MB}MB (${_PCT}%) | ~${_REMAIN} min  "
			fi
		fi
		sleep 5
	done
	wait $_DD_PID
	echo ""
	echo "  Image file created via dd."
fi
echo ""

[ ! -e /dev/loop5 ] && mknod /dev/loop5 b 7 5
losetup /dev/loop5 "/ps4hdd/home/$_install_OS_img"

echo "Formatting ext4..."
mkfs.ext4 /dev/loop5
echo "  ext4 formatted."
echo ""

mkdir -p /newroot
mount /dev/loop5 /newroot

echo "Extracting rootfs (this takes ~20-30 minutes)..."
cd /newroot
_IMG_TOTAL_MB=$(($(blockdev --getsize64 /dev/loop5 2>/dev/null || echo 3221225472) / 1048576))
tar -xvf "/ps4hdd/system/boot/$_install_OS" | while read -r _file; do
	_DONE=$(du -sb /newroot 2>/dev/null | awk '{print $1}')
	_DONE_MB=$((_DONE / 1048576))
	if [ "$_IMG_TOTAL_MB" -gt 0 ]; then
		_PCT=$((_DONE_MB * 100 / _IMG_TOTAL_MB))
		[ "$_PCT" -gt 100 ] && _PCT=100
	else
		_PCT=0
	fi
	echo -ne "\r  Extracting: ~${_DONE_MB}MB extracted (${_PCT}%)  "
done
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

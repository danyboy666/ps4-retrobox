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

echo ""
echo "=== Phase 1: Create minimal .img for initial install ==="
echo "You can expand the image to full size after first boot."
echo ""
read -p 'Initial image size in GB (default=4): ' partsize
partsize="${partsize:-4}"
TOTAL_MB=$((partsize * 1024))
partsize2="$(echo "($partsize*1024*1024*1024/4096)/1" | bc)"

echo ""
echo "Creating sparse ${partsize}GB .img file..."
_START=$(date +%s)
dd if=/dev/zero of="/ps4hdd/home/$_install_OS_img" bs=4096 seek="$partsize2" 2>&1 &
_DD_PID=$!
sleep 2
while kill -0 $_DD_PID 2>/dev/null; do
	_DONE_BYTES=$(stat -c %s "/ps4hdd/home/$_install_OS_img" 2>/dev/null || echo 0)
	_DONE_MB=$((_DONE_BYTES / 1048576))
	_PCT=$((_DONE_MB * 100 / TOTAL_MB))
	_ELAPSED=$(($(date +%s) - _START))
	if [ "$_ELAPSED" -gt 0 ] && [ "$_DONE_MB" -gt 0 ]; then
		_SPEED=$((_DONE_MB / _ELAPSED))
		if [ "$_SPEED" -gt 0 ]; then
			_REMAIN=$(( (TOTAL_MB - _DONE_MB) / _SPEED / 60 ))
			echo -ne "\r  Writing: ${_DONE_MB}MB / ${TOTAL_MB}MB (${_PCT}%) | ~${_REMAIN} min remaining  "
		fi
	fi
	sleep 5
done
wait $_DD_PID
echo ""
echo "  Image file created."
echo ""

[ ! -e /dev/loop5 ] && mknod /dev/loop5 b 7 5
losetup /dev/loop5 "/ps4hdd/home/$_install_OS_img"

echo "Formatting ext4..."
_START=$(date +%s)
mkfs.ext4 /dev/loop5 2>&1 &
_MKFS_PID=$!
sleep 2
while kill -0 $_MKFS_PID 2>/dev/null; do
	_DONE_BYTES=$(blockdev --getsize64 /dev/loop5 2>/dev/null || echo 0)
	_DONE_MB=$((_DONE_BYTES / 1048576))
	_ELAPSED=$(($(date +%s) - _START))
	if [ "$_ELAPSED" -gt 0 ] && [ "$_DONE_MB" -gt 0 ]; then
		echo -ne "\r  Formatting: ${_DONE_MB}MB written (${_ELAPSED}s elapsed)  "
	fi
	sleep 3
done
wait $_MKFS_PID
echo ""
echo "  ext4 formatted."
echo ""

mkdir -p /newroot
mount /dev/loop5 /newroot

echo "Extracting rootfs (this takes 5-15 minutes)..."
cd /newroot
tar -xvf "/ps4hdd/system/boot/$_install_OS"
echo ""
echo "Extraction complete!"

echo "Installing storage expansion script..."
mkdir -p /newroot/usr/local/bin
cp /bin/setup-storage.sh /newroot/usr/local/bin/setup-storage.sh
chmod +x /newroot/usr/local/bin/setup-storage.sh

echo "Setting up first-boot auto-expansion..."
mkdir -p /newroot/etc/systemd/system
cat > /newroot/etc/systemd/system/ps4-retrobox-expand.service << 'UNIT'
[Unit]
Description=PS4 RetroBox - Expand storage on first boot
After=local-fs.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-storage.sh
ExecStartPost=/bin/systemctl disable ps4-retrobox-expand.service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

ln -sf /etc/systemd/system/ps4-retrobox-expand.service /newroot/etc/systemd/system/multi-user.target.wants/ps4-retrobox-expand.service 2>/dev/null || true

echo "Syncing..."
sync

umount /newroot 2>/dev/null
losetup -d /dev/loop5 2>/dev/null

echo
echo "=== Phase 1 complete! ==="
echo ""
echo "The system will now boot into Linux automatically."
echo "After first boot, run 'sudo setup-storage.sh' to expand the"
echo "image to full size."
echo
echo "Script created by https://github.com/Nazky and https://github.com/feeRnt"

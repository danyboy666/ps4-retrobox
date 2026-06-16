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
	mount -t ufs -o rw,ufstype=ufs2 /dev/mapper/ps4hdd /ps4hdd
else
	echo "/ps4hdd already mounted, skipping."
fi

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

# Check for existing .img files
_old_imgs="$(ls /ps4hdd/home/*.img 2>/dev/null)"
if [ -n "$_old_imgs" ]; then
	echo "WARNING: Existing .img file(s) found:"
	ls -lh /ps4hdd/home/*.img
	echo ""
	echo "These may be corrupt (0 bytes from failed attempts)."
	read -p "Delete all and reinstall? (y/N): " _del
	if [ "$_del" = "y" ] || [ "$_del" = "Y" ]; then
		rm -f /ps4hdd/home/*.img
		echo "Old images deleted."
	else
		echo "Keeping existing image."
	fi
fi

# Only proceed if no valid .img exists
if [ -f "/ps4hdd/home/$_install_OS_img" ]; then
	_img_size=$(stat -c %s "/ps4hdd/home/$_install_OS_img" 2>/dev/null || echo 0)
	if [ "$_img_size" -gt 1073741824 ]; then
		echo "Valid .img already exists ($(($_img_size / 1048576))MB). Skipping creation."
		echo "To reinstall, delete the existing .img first."
	else
		echo "Existing .img is too small ($(($_img_size / 1048576))MB) — likely corrupt."
		rm -f "/ps4hdd/home/$_install_OS_img"
		echo "Deleted corrupt .img."
	fi
fi

if [ ! -f "/ps4hdd/home/$_install_OS_img" ]; then
	read -p 'Image size in GB (default=8): ' partsize
	partsize="${partsize:-8}"
	TOTAL_MB=$((partsize * 1024))
	TOTAL_BYTES=$((partsize * 1073741824))

	# Detect USB drive for fast image creation
	_USB_DEV=""
	_USB_MNT="/mnt/usb"
	for _dev in /dev/sd?1; do
		# Skip PS4 HDD partitions (sd?27, sd?13 are mapper, but raw devices might show)
		_case_name="$(_dev | sed 's|/dev/||')"
		case "$_case_name" in
			sd?27|sd?13) continue ;;
		esac
		if [ -b "$_dev" ]; then
			echo "Found USB device: $_dev"
			_USB_DEV="$_dev"
			break
		fi
	done

	if [ -n "$_USB_DEV" ]; then
		# === FAST PATH: Create image on USB, then copy to UFS ===
		echo ""
		echo "=== USB STAGING MODE ==="
		echo "Creating .img on USB (fast) then transferring to PS4 HDD."
		echo ""

		mkdir -p "$_USB_MNT"
		if ! mount -t vfat "$_USB_DEV" "$_USB_MNT" 2>/dev/null; then
			if ! mount -t ext4 "$_USB_DEV" "$_USB_MNT" 2>/dev/null; then
				echo "WARNING: Could not mount USB $_USB_DEV. Trying exfat..."
				if ! mount -t exfat "$_USB_DEV" "$_USB_MNT" 2>/dev/null; then
					echo "ERROR: Could not mount USB drive. Format as FAT32 or ext4."
					echo "Falling back to direct UFS creation (slow)..."
					_USB_DEV=""
				fi
			fi
		fi
	fi

	if [ -n "$_USB_DEV" ]; then
		# Check USB free space
		_USB_AVAIL=$(df "$_USB_MNT" 2>/dev/null | tail -1 | awk '{print $4}')
		_USB_AVAIL_MB=$(($_USB_AVAIL / 1024))
		echo "USB free space: ${_USB_AVAIL_MB}MB"
		if [ "$_USB_AVAIL_MB" -lt "$TOTAL_MB" ]; then
			echo "ERROR: Not enough space on USB (need ${TOTAL_MB}MB, have ${_USB_AVAIL_MB}MB)"
			echo "Free up space or use a larger USB drive."
			echo "Falling back to direct UFS creation (slow)..."
			_USB_DEV=""
		fi
	fi

	if [ -n "$_USB_DEV" ]; then
		# --- Phase 1: Create .img on USB (fast) ---
		echo ""
		echo "Phase 1/2: Creating ${partsize}GB .img on USB..."

		# Remove old partial images on USB
		rm -f "$_USB_MNT"/*.img 2>/dev/null

		echo "Writing zeros to USB..."
		START=$(date +%s)
		dd if=/dev/zero of="$_USB_MNT/$_install_OS_img" bs=1M count=$TOTAL_MB 2>&1 &
		_DD_PID=$!
		sleep 2
		while kill -0 $_DD_PID 2>/dev/null; do
			DONE_BYTES=$(stat -c %s "$_USB_MNT/$_install_OS_img" 2>/dev/null || echo 0)
			DONE_MB=$((DONE_BYTES / 1048576))
			PCT=$((DONE_MB * 100 / TOTAL_MB))
			ELAPSED=$(($(date +%s) - START))
			if [ "$ELAPSED" -gt 0 ] && [ "$DONE_MB" -gt 0 ]; then
				SPEED=$((DONE_MB / ELAPSED))
				if [ "$SPEED" -gt 0 ]; then
					REMAIN=$(( (TOTAL_MB - DONE_MB) / SPEED / 60 ))
					echo -ne "\r  Writing: ${DONE_MB}MB / ${TOTAL_MB}MB (${PCT}%) | ~${REMAIN} min remaining  "
				fi
			fi
			sleep 3
		done
		wait $_DD_PID
		echo ""
		echo "  Image file created on USB."

		echo "  Formatting ext4 on USB..."
		mkfs.ext4 -F "$_USB_MNT/$_install_OS_img"

		echo "  Mounting image on USB..."
		[ ! -e /dev/loop5 ] && mknod /dev/loop5 b 7 5
		losetup /dev/loop5 "$_USB_MNT/$_install_OS_img"
		mkdir -p /newroot
		mount /dev/loop5 /newroot

		echo "  Extracting rootfs (this takes 5-15 minutes)..."
		cd /newroot
		tar -xvf "/ps4hdd/system/boot/$_install_OS"
		echo "  Extraction complete!"

		echo "  Syncing to USB..."
		sync
		umount /newroot
		losetup -d /dev/loop5

		echo ""
		echo "Phase 1 complete! .img created on USB."
		echo ""

		# --- Phase 2: Transfer .img from USB to UFS (slow but reliable) ---
		echo "Phase 2/2: Transferring .img to PS4 HDD (this is the slow part)..."
		echo "  USB → UFS via direct file copy."
		echo ""

		START=$(date +%s)
		dd if="$_USB_MNT/$_install_OS_img" of="/ps4hdd/home/$_install_OS_img" bs=1M 2>&1 &
		_DD_PID=$!
		sleep 2
		while kill -0 $_DD_PID 2>/dev/null; do
			DONE_BYTES=$(stat -c %s "/ps4hdd/home/$_install_OS_img" 2>/dev/null || echo 0)
			DONE_MB=$((DONE_BYTES / 1048576))
			PCT=$((DONE_MB * 100 / TOTAL_MB))
			ELAPSED=$(($(date +%s) - START))
			if [ "$ELAPSED" -gt 0 ] && [ "$DONE_MB" -gt 0 ]; then
				SPEED=$((DONE_MB / ELAPSED))
				if [ "$SPEED" -gt 0 ]; then
					REMAIN=$(( (TOTAL_MB - DONE_MB) / SPEED / 60 ))
					echo -ne "\r  Transferring: ${DONE_MB}MB / ${TOTAL_MB}MB (${PCT}%) | ~${REMAIN} min remaining  "
				fi
			fi
			sleep 5
		done
		wait $_DD_PID
		echo ""

		# Verify transfer
		sync
		_USB_SIZE=$(stat -c %s "$_USB_MNT/$_install_OS_img" 2>/dev/null || echo 0)
		_UFS_SIZE=$(stat -c %s "/ps4hdd/home/$_install_OS_img" 2>/dev/null || echo 0)
		echo "  USB size: $_USB_SIZE bytes"
		echo "  UFS size: $_UFS_SIZE bytes"
		if [ "$_USB_SIZE" = "$_UFS_SIZE" ]; then
			echo "  Transfer verified: sizes match!"
		else
			echo "  WARNING: Size mismatch! Transfer may be incomplete."
			echo "  You may need to retry the installation."
		fi

		# Cleanup USB
		rm -f "$_USB_MNT"/$_install_OS_img 2>/dev/null
		umount "$_USB_MNT" 2>/dev/null
		echo ""
		echo "USB cleaned up. You can remove the USB drive."

	else
		# === SLOW PATH: Direct UFS creation (no USB) ===
		echo ""
		echo "No USB drive detected. Creating .img directly on PS4 HDD (slow)..."
		echo "Insert a USB drive next time for 10x faster setup!"
		echo ""

		echo "Writing ${partsize}GB .img directly to UFS..."
		[ ! -e /dev/loop5 ] && mknod /dev/loop5 b 7 5
		touch "/ps4hdd/home/$_install_OS_img"
		losetup /dev/loop5 "/ps4hdd/home/$_install_OS_img"
		START=$(date +%s)
		dd if=/dev/zero of=/dev/loop5 bs=1M count=$TOTAL_MB 2>&1 &
		_DD_PID=$!
		sleep 2
		while kill -0 $_DD_PID 2>/dev/null; do
			DONE_BYTES=$(stat -c %s "/ps4hdd/home/$_install_OS_img" 2>/dev/null || echo 0)
			DONE_MB=$((DONE_BYTES / 1048576))
			PCT=$((DONE_MB * 100 / TOTAL_MB))
			ELAPSED=$(($(date +%s) - START))
			if [ "$ELAPSED" -gt 0 ] && [ "$DONE_MB" -gt 0 ]; then
				SPEED=$((DONE_MB / ELAPSED))
				if [ "$SPEED" -gt 0 ]; then
					REMAIN=$(( (TOTAL_MB - DONE_MB) / SPEED / 60 ))
					echo -ne "\r  Writing: ${DONE_MB}MB / ${TOTAL_MB}MB (${PCT}%) | ~${REMAIN} min remaining  "
				fi
			fi
			sleep 5
		done
		wait $_DD_PID
		echo ""
		echo "  Image file created."

		echo "  Formatting ext4..."
		mkfs.ext4 -F /dev/loop5

		mount /dev/loop5 /newroot

		echo "  Extracting rootfs (this takes 5-15 minutes)..."
		cd /newroot
		tar -xvf "/ps4hdd/system/boot/$_install_OS"
		echo "  Extraction complete!"
	fi
fi

umount /newroot 2>/dev/null
losetup -d /dev/loop5 2>/dev/null

echo
echo "Script created by https://github.com/Nazky and https://github.com/feeRnt"
echo

echo "Installation complete!"
echo "The system will now boot into Linux automatically."

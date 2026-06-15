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

# Check for ANY existing .img files
_old_imgs="$(ls /ps4hdd/home/*.img 2>/dev/null)"
if [ -n "$_old_imgs" ]; then
	echo "WARNING: Existing .img file(s) found:"
	ls -lh /ps4hdd/home/*.img
	echo ""
	read -p "Delete and reinstall? (y/N): " _del
	if [ "$_del" = "y" ] || [ "$_del" = "Y" ]; then
		rm -f /ps4hdd/home/*.img
		echo "Old images deleted."
	else
		echo "Keeping existing image."
	fi
fi

if [ ! -f "/ps4hdd/home/$_install_OS_img" ]; then
	read -p 'Linux disk image file size in GB (recommended >=32, default=32): ' partsize
	partsize="${partsize:-32}"

	echo "Creating ${partsize}GB .img file..."
	truncate -s "${partsize}G" "/ps4hdd/home/$_install_OS_img"
	echo "Image file created."
	sleep 2
	losetup /dev/loop5 "/ps4hdd/home/$_install_OS_img"

	echo "Formatting ext4..."
	mkfs.ext4 -F /dev/loop5

	mount /dev/loop5 /newroot

	echo "Extracting rootfs into .img (this takes 5-15 minutes)..."
	cd /newroot
	tar -xvf "/ps4hdd/system/boot/$_install_OS"
	echo "Extraction complete!"
fi

echo
echo "Script created by https://github.com/Nazky and https://github.com/feeRnt"
echo

echo "Installation complete! Rebooting in 5 seconds..."
echo "After reboot, the payload will boot directly into Linux."
sleep 5
reboot

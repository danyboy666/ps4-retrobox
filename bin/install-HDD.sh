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

read -p 'Linux disk image file size in GB (recommended >=50, default=50): ' partsize
partsize="${partsize:-50}"

partsize2="$(echo "($partsize*1024*1024*1024/4096)/1" | bc)"

echo "Creating sparse ${partsize}GB .img file..."
dd if=/dev/zero of="/ps4hdd/home/$_install_OS_img" bs=4096 seek="$partsize2"
sleep 2

[ ! -e /dev/loop5 ] && mknod /dev/loop5 b 7 5
losetup /dev/loop5 "/ps4hdd/home/$_install_OS_img"

echo "Formatting ext4..."
mkfs.ext4 /dev/loop5

mkdir -p /newroot
mount /dev/loop5 /newroot

echo "Extracting rootfs into .img (this takes 5-15 minutes)..."
cd /newroot
tar -xvf "/ps4hdd/system/boot/$_install_OS"
echo "Extraction complete!"

echo "Syncing..."
sync
umount /newroot 2>/dev/null
losetup -d /dev/loop5 2>/dev/null

echo
echo "Script created by https://github.com/Nazky and https://github.com/feeRnt"
echo

echo "Installation complete!"
echo "The system will now boot into Linux automatically."

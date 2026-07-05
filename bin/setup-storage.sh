#!/bin/bash
# setup-storage.sh - One-time expansion of .img after initial install
# Run automatically on first boot, or manually: sudo setup-storage.sh

set -e

_IMG_NAME="arch.img"
_IMG_PATH="/ps4hdd/home/$_IMG_NAME"
_TARGET_SIZE_FILE="/ps4hdd/home/.target_size"
_DEFAULT_SIZE=32

echo ""
echo "=== PS4 RetroBox Storage Expansion ==="
echo ""

# Check if already expanded
if [ -f /var/lib/ps4-retrobox-expanded ]; then
	echo "Storage already expanded. Skipping."
	echo "To re-expand, delete /var/lib/ps4-retrobox-expanded and reboot."
	exit 0
fi

# Check if .img exists
if [ ! -f "$_IMG_PATH" ]; then
	echo "ERROR: $_IMG_PATH not found."
	echo "Make sure the initial install completed successfully."
	exit 1
fi

# Get current size
_CURRENT_BYTES=$(stat -c %s "$_IMG_PATH" 2>/dev/null || echo 0)
_CURRENT_GB=$((_CURRENT_BYTES / 1073741824))
echo "Current image size: ${_CURRENT_GB}GB"

# Read target size from config file (set during install)
if [ -f "$_TARGET_SIZE_FILE" ]; then
	_TARGET_GB=$(cat "$_TARGET_SIZE_FILE")
	echo "Target size: ${_TARGET_GB}GB (set during install)"
else
	echo "No target size configured. Using default: ${_DEFAULT_SIZE}GB"
	_TARGET_GB="$_DEFAULT_SIZE"
fi

if [ "$_TARGET_GB" -le "$_CURRENT_GB" ]; then
	echo "Target size must be larger than current size (${_CURRENT_GB}GB)."
	echo "Nothing to expand."
	exit 0
fi

echo ""
echo "Expanding .img from ${_CURRENT_GB}GB to ${_TARGET_GB}GB..."

# Mount UFS if not mounted
if ! mountpoint -q /ps4hdd 2>/dev/null; then
	mkdir -p /ps4hdd
	mount -t ufs -o ufstype=ufs2 /dev/mapper/ps4hdd /ps4hdd
fi

# Expand the .img file using truncate (instant for sparse)
_TARGET_BYTES=$((_TARGET_GB * 1073741824))
_TARGET_BLOCKS=$((_TARGET_BYTES / 4096))
dd if=/dev/zero of="$_IMG_PATH" bs=4096 seek="$_TARGET_BLOCKS" count=0 2>/dev/null
echo "  .img file expanded."

# Set up loop device
[ ! -e /dev/loop5 ] && mknod /dev/loop5 b 7 5
losetup /dev/loop5 "$_IMG_PATH"

# Expand ext4 filesystem
echo "  Expanding ext4 filesystem..."
resize2fs /dev/loop5
echo "  ext4 expanded."

# Cleanup
sync
losetup -d /dev/loop5 2>/dev/null

# Clean up target size file
rm -f "$_TARGET_SIZE_FILE"

# Mark as expanded
mkdir -p /var/lib
echo "expanded $(date)" > /var/lib/ps4-retrobox-expanded

echo ""
echo "=== Expansion complete! ==="
echo "Image is now ${_TARGET_GB}GB."
echo "Reboot to apply changes."

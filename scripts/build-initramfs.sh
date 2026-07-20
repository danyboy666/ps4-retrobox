#!/bin/bash
# build-initramfs.sh — Build initramfs.cpio.gz from known-good source tree
# This script creates the initramfs from the project's boot utility directories.
# It does NOT scan the entire project tree — only the directories that belong in the initramfs.
# This prevents accidental inclusion of .git, build artifacts, secrets, etc.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SCRIPT_DIR/community-files/initramfs.cpio.gz"
TMPDIR=$(mktemp -d)

echo "=== Building initramfs from source ==="
echo "Source: $SCRIPT_DIR"
echo "Output: $OUT"

# Create initramfs directory structure
mkdir -p "$TMPDIR"

# Copy boot utility directories — these are the ONLY directories that belong in initramfs
cp -a "$SCRIPT_DIR/bin" "$TMPDIR/"
cp -a "$SCRIPT_DIR/lib" "$TMPDIR/"
cp -a "$SCRIPT_DIR/etc" "$TMPDIR/"
cp -a "$SCRIPT_DIR/sbin" "$TMPDIR/"
cp -a "$SCRIPT_DIR/key" "$TMPDIR/"
cp -a "$SCRIPT_DIR/dev" "$TMPDIR/"
cp -a "$SCRIPT_DIR/usr" "$TMPDIR/"

# Copy init and VERSION from project root
cp "$SCRIPT_DIR/init" "$TMPDIR/init"
chmod +x "$TMPDIR/init"
cp "$SCRIPT_DIR/VERSION" "$TMPDIR/VERSION"

# Copy scripts directory (contains helper scripts)
cp -a "$SCRIPT_DIR/scripts" "$TMPDIR/"

# Copy configscripts directory (retroarch config generation)
cp -a "$SCRIPT_DIR/configscripts" "$TMPDIR/"

# Create functions.sh symlink at root (init sources /functions.sh)
ln -sf bin/functions.sh "$TMPDIR/functions.sh"

# Build cpio archive
echo "Packing initramfs..."
cd "$TMPDIR"
find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip > "$OUT"

# Cleanup
rm -rf "$TMPDIR"

echo "Done: $(du -h "$OUT" | cut -f1)"
echo "Files: $(zcat "$OUT" | cpio -t 2>/dev/null | wc -l)"

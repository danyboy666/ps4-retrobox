#!/bin/bash
set -e

OUTPUT_DIR="${1:-.}"
REPO="danyboy666/ps4-retrobox"
TAG="v1.0"

mkdir -p "$OUTPUT_DIR"

echo "=== PS4 RetroBox Binary Downloader ==="
echo "Downloading release $TAG from $REPO ..."
echo ""

# Download the zip file
gh release download "$TAG" -R "$REPO" -D "$OUTPUT_DIR" \
  -p "ps4-retrobox-${TAG}.zip" 2>/dev/null || {
    echo "Zip not found, downloading individual files..."
    gh release download "$TAG" -R "$REPO" -D "$OUTPUT_DIR" \
      -p "arch.tar.xz" \
      -p "bzImage_no-built-in-fw_Clang_fullLTO" \
      -p "initramfs.cpio.gz" \
      -p "payload-960-1gb.elf" \
      -p "payload-960-1gb.bin" \
      -p "payload-960-2gb.elf" \
      -p "payload-960-2gb.bin"
}

echo ""
echo "=== Download complete ==="
echo "Files saved to: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"

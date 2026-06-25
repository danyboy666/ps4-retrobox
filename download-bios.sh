#!/bin/bash
# PS4 RetroBox - BIOS Downloader
# Downloads BIOS files from Abdess/retrobios (MIT License)
# https://github.com/Abdess/retrobios

BIOS_DIR="/home/PS4/.config/retroarch/system"
REPO_BASE="https://raw.githubusercontent.com/Abdess/retrobios/main/bios"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[OK]${NC} $1"; }
skip()  { echo -e "${YELLOW}[SKIP]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }

download_file() {
    local url="$1"
    local dest="$2"
    local desc="$3"
    if [ -f "$dest" ]; then
        skip "$desc (already exists)"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
        info "$desc"
    elif wget -qO "$dest" "$url" 2>/dev/null; then
        info "$desc"
    else
        error "$desc"
        rm -f "$dest"
        return 1
    fi
}

echo "============================================"
echo "  PS4 RetroBox - BIOS File Downloader"
echo "  Source: Abdess/retrobios (MIT License)"
echo "============================================"
echo ""
echo "Downloading BIOS files needed for PS4 RetroBox systems..."
echo ""

echo "--- PlayStation (mednafen_psx) ---"
download_file "$REPO_BASE/Sony/PlayStation/scph5500.bin" "$BIOS_DIR/scph5500.bin" "PlayStation BIOS (Japan)"
download_file "$REPO_BASE/Sony/PlayStation/scph5501.bin" "$BIOS_DIR/scph5501.bin" "PlayStation BIOS (US)"
download_file "$REPO_BASE/Sony/PlayStation/scph5502.bin" "$BIOS_DIR/scph5502.bin" "PlayStation BIOS (Europe)"

echo ""
echo "--- Sega 32X (picodrive) ---"
download_file "$REPO_BASE/Sega/32X/32X_M_BIOS.BIN" "$BIOS_DIR/32X_M_BIOS.BIN" "32X Main BIOS"
download_file "$REPO_BASE/Sega/32X/32X_S_BIOS.BIN" "$BIOS_DIR/32X_S_BIOS.BIN" "32X Slave BIOS"
download_file "$REPO_BASE/Sega/32X/32X_G_BIOS.BIN" "$BIOS_DIR/32X_G_BIOS.BIN" "32X Game BIOS"

echo ""
echo "--- Atari 5200 (atari800) ---"
download_file "$REPO_BASE/Atari/5200/5200.rom" "$BIOS_DIR/5200.rom" "Atari 5200 BIOS"

echo ""
echo "--- TurboGrafx-CD (mednafen_pce_fast) ---"
download_file "$REPO_BASE/NEC/PC%20Engine%20CD/PCECD_3.0-(J).pce" "$BIOS_DIR/syscard3.pce" "TurboGrafx-CD System Card v3.0"

echo ""
echo "--- Neo Geo (fbneo) ---"
if [ -f "$BIOS_DIR/neogeo.zip" ]; then
    skip "Neo Geo BIOS (ngdevkit nullbios already installed)"
else
    download_file "$REPO_BASE/SNK/Neo%20Geo/neogeo.zip" "$BIOS_DIR/neogeo.zip" "Neo Geo BIOS"
fi

echo ""
echo "============================================"
echo "  BIOS files: $BIOS_DIR"
echo "============================================"
echo ""
ls -lh "$BIOS_DIR"/*.{bin,rom,pce,zip} 2>/dev/null
echo ""
echo "Restart RetroArch to use the new BIOS files."

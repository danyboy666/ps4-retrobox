#!/bin/sh
. /functions.sh

clear

# PS4 RetroBox installer
# Based on better-initramfs by feeRnt (https://github.com/feeRnt)

cat << 'ART'


 .--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--. 
/ .. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \
\ \/\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ \/ /
 \/ /`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'\/ / 
 / /\                                                                                                / /\ 
/ /\ \                                                                                              / /\ \
\ \/ /                                                                                              \ \/ /
 \/ /                                                                                                \/ / 
 / /\       ███████████   █████████  █████ █████                                                     / /\ 
/ /\ \     ░░███░░░░░███ ███░░░░░███░░███ ░░███                                                     / /\ \
\ \/ /      ░███    ░███░███    ░░░  ░███  ░███ █                                                   \ \/ /
 \/ /       ░██████████ ░░█████████  ░███████████                                                    \/ / 
 / /\       ░███░░░░░░   ░░░░░░░░███ ░░░░░░░███░█                                                    / /\ 
/ /\ \      ░███         ███    ░███       ░███░                                                    / /\ \
\ \/ /      █████       ░░█████████        █████                                                    \ \/ /
 \/ /      ░░░░░         ░░░░░░░░░        ░░░░░                                                      \/ / 
 / /\                                                                                                / /\ 
/ /\ \                                                                                              / /\ \
\ \/ /                                                                                              \ \/ /
 \/ /       ███████████             █████                       █████                                \/ / 
 / /\      ░░███░░░░░███           ░░███                       ░░███                                 / /\ 
/ /\ \      ░███    ░███   ██████  ███████   ████████   ██████  ░███████   ██████  █████ █████      / /\ \
\ \/ /      ░██████████   ███░░███░░░███░   ░░███░░███ ███░░███ ░███░░███ ███░░███░░███ ░░███       \ \/ /
 \/ /       ░███░░░░░███ ░███████   ░███     ░███ ░░░ ░███ ░███ ░███ ░███░███ ░███ ░░░█████░         \/ / 
 / /\       ░███    ░███ ░███░░░    ░███ ███ ░███     ░███ ░███ ░███ ░███░███ ░███  ███░░░███        / /\ 
/ /\ \      █████   █████░░██████   ░░█████  █████    ░░██████  ████████ ░░██████  █████ █████      / /\ \
\ \/ /     ░░░░░   ░░░░░  ░░░░░░     ░░░░░  ░░░░░      ░░░░░░  ░░░░░░░░   ░░░░░░  ░░░░░ ░░░░░       \ \/ /
 \/ /                                                                                                \/ / 
 / /\                                                                                                / /\ 
/ /\ \                                                                                              / /\ \
\ \/ /                                                                                              \ \/ /
 \/ /                                                                                                \/ / 
 / /\.--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--..--./ /\ 
/ /\ \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \.. \/\ \
\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `'\ `' /
 `--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--'`--' 

                                                                                                     
                                                                                                     
                       @@                                                    @@                      
                 #=-=======-=#                                          #=-=======-=*                
               @=-::::::::::::==++==+----------------------------=+=====--::::::::::-=@              
              #-:::--=--=-:::::=----=-----------------------------=-----::::-==----:::-#             
             +-:==:::-=--::-=---:---=----------------------------==--::=:=-::--+-=-:-=:-+            
            +-=-:::-=====::::-==----=-----------------------------=:---+-:::-==-+-=::::=-+           
           #=--::::=-:::=-:::::--::-=-----------------------------=::-=::::::====+-:::::-=*          
           +--::-::-=---=:::-:::--:-=----------------------------==::-:----:::---::::-----+          
          %-=-=-:--------=---==---:-=-----------------------------=:--=+==+=:::::::-==-=+=-%         
          =:==+-::--=::---:::-==--:-=----------------------------==:---+::==:::::::-+-:-==-=         
         *-:=::=-==--=---====-::--::==---------------------------=-:---=--=-::::::::==+=-=-:*        
         =::--:::::--:::=-::::::========----------------------========-::::::------:::::--::=        
        +-:::--::::=-:::=-:::::+=-:---:--+=::::--------::::-+=-:---::-+-::::-==+=-=::::--:::-+       
        =-::::-=::::-----::::+=:==-----+=:-=-::-======-:::==:-+-----=+--+-:::==-===:::=-::::-=       
       *-::::::::=----=----=+--+----::---*:-=-::------:::==:+=---::---+--+=----==---=-:::::::-*      
       +-::::::::::::::::::-=:==--:::::---=:=-::-====-:::+-==--:::::---+:-=::::::::::::::::::-=      
       +:::::::::::::::::::=-:==--:::::--==:==::-=##+-::-=-==---::::--==:-=-::::::::::::::::::=      
       =:::::::::::::::::::-=--==-------==--=-:::-==-::::=-:==-------==---=:::::::::::::::::::=+     
      %-:::::::::::::::::::--=-:=-=======:--=-:::::::::::=--:-========-:-=-:::::::::::::::::::-*     
      *:::::::::::::::::::::---=-:-==--:-=---::::::::::::---=--:-==-:--=--:::::::::::::::::::::+     
      =::::::::::::::::::::::-+=----------+################*=----------+=::::::::::::::::::::::=     
      =:::::::::::::::::::::=*  #+=+++=+#                    %+=+++=+#  *=:::::::::::::::::::::-     
     %:::::::::::::::::::::-+                                            +-:::::::::::::::::::::%    
     *:::::::::::::::::::::=                                              =:::::::::::::::::::::*    
     *::::::::::::::::::::-%                                              @-::::::::::::::::::::*    
     =--:::::::::::::::::-#                                                #-:::::::::::::::::--=    
     =::--:::::::::::::::+                                                  +:::::::::::::::--::=    
     *:::::----::::::::-=+                                                   +-::::::::----:::::*    
      +-:::::::::::-:::-+                                                    +-:::-:::::::::::-+     
       +-:::::::::::::-+                                                      +=:::::::::::::-+      
         +=-:::::::-=+                                                          +=-:::::::-=+        
             +##*                                                                    *##+            
                                                                                                     
                                                                                                     

ART
echo "PS4 RetroBox by danyboy666 — https://github.com/danyboy666/ps4-retrobox"
echo "Based on better-initramfs by Piotr Karbowski"
echo "  https://github.com/fff7d1bc/better-initramfs"
echo "PS4 initramfs by feeRnt"
echo "  https://github.com/feeRnt/ps4-linux-initramfs"
echo "Kernels by feeRnt, DFAUS, crashniels"
echo "  https://github.com/feeRnt/ps4-linux-12xx"
echo "Payload by ArabPixel & rmuxnet"
echo "  https://github.com/ps4-linux/ps4-linux-loader"
echo ""
sleep 3

# Interrupt window — press any key to drop to rescueshell
echo "Press any key in 5 seconds to drop to rescue shell..."
echo "Otherwise, install will begin automatically."
echo ""
_interrupt=5
while [ "$_interrupt" -gt 0 ]; do
	printf "\r  Starting in %ds... " "$_interrupt"
	_key=""
	read -t 1 _key 2>/dev/null
	if [ -n "$_key" ]; then
		echo ""
		echo "Interrupted. Dropping to rescue shell."
		rescueshell
	fi
	_interrupt=$((_interrupt - 1))
done
echo ""
echo "Starting install..."
echo ""
echo "========================================"
echo "  NOTE: A USB keyboard is optional."
echo "  You can plug one in now if you want"
echo "  to interact with the script. Otherwise"
echo "  just let it run — no input required."
echo "========================================"
echo ""

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

sleep 2
clear

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

# Ask for target size with menu and countdown
echo ""
echo "Select target size for Linux installation:"
echo "  [1] Keep 3GB minimal — boot now (default)"
echo "  [2] 16 GB"
echo "  [3] 32 GB"
echo "  [4] 50 GB"
echo "  [5] Custom size"
echo ""
echo "Default: 3GB in 15 seconds..."
_COUNTDOWN=15
_TARGET_SIZE=""
while [ "$_COUNTDOWN" -gt 0 ] && [ -z "$_TARGET_SIZE" ]; do
	printf "\r  Choice [1-5]: %2ds " "$_COUNTDOWN"
	_CHOICE=""
	read -t 1 _CHOICE 2>/dev/null
	case "$_CHOICE" in
		1) _TARGET_SIZE=3 ;;
		2) _TARGET_SIZE=16 ;;
		3) _TARGET_SIZE=32 ;;
		4) _TARGET_SIZE=50 ;;
		5)
			echo ""
			echo -n "  Enter size in GB: "
			read _TARGET_SIZE
			# Validate input is a number
			case "$_TARGET_SIZE" in
				""|[!0-9]*)
					echo "  Invalid input. Using 3GB minimal."
					_TARGET_SIZE=3
					;;
			esac
			# Sanity check
			if [ "$_TARGET_SIZE" -lt 3 ] 2>/dev/null; then
				echo "  Too small (need at least 3GB). Using 3GB minimal."
				_TARGET_SIZE=3
			fi
			if [ "$_TARGET_SIZE" -gt 500 ] 2>/dev/null; then
				echo "  That's huge! Using 3GB minimal."
				_TARGET_SIZE=3
			fi
			break
			;;
	esac
	_COUNTDOWN=$((_COUNTDOWN - 1))
done
if [ -z "$_TARGET_SIZE" ]; then
	_TARGET_SIZE=3
	echo ""
	echo "  Auto-selected: 3GB minimal"
fi

# Only write .target_size if user chose expansion (not minimal)
if [ "$_TARGET_SIZE" -gt 3 ] 2>/dev/null; then
	echo ""
	echo "Target size: ${_TARGET_SIZE}GB"
	echo "$_TARGET_SIZE" > /ps4hdd/home/.target_size
	echo ""
	echo "  Image will be expanded to ${_TARGET_SIZE}GB on next boot."
else
	_TARGET_SIZE=3
	rm -f /ps4hdd/home/.target_size
	echo ""
	echo "  Booting 3GB minimal image."
fi
echo ""

# Create 3GB .img (rootfs ~2.3GB uncompressed + ext4 overhead + headroom)
_TOTAL_MB=3072
_IMG_FILE="/ps4hdd/home/$_install_OS_img"

echo ""
echo "=== Creating 3GB .img ==="

# Try sparse creation first (truncate, instant)
rm -f "$_IMG_FILE" 2>/dev/null
truncate -s "${_TOTAL_MB}M" "$_IMG_FILE" 2>/dev/null

# Verify sparse file actually got created with real size
_ACTUAL_SIZE=$(stat -c %s "$_IMG_FILE" 2>/dev/null || echo 0)
if [ "$_ACTUAL_SIZE" -gt 1048576 ]; then
	echo "  Sparse image created (instant)."
	_SPARSE=1
else
	# UFS doesn't support sparse files, use real dd (slow)
	echo "  UFS does not support sparse files."
	echo "  Writing 3GB of zeros (this is slow)..."
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

# Create ROM and BIOS directories on UFS (optional storage)
echo ""
echo "Creating storage directories on UFS..."
mkdir -p /ps4hdd/ROMs/snes /ps4hdd/ROMs/n64 /ps4hdd/ROMs/gba /ps4hdd/ROMs/gameboy /ps4hdd/ROMs/genesis /ps4hdd/ROMs/psx /ps4hdd/ROMs/tg16 /ps4hdd/ROMs/nds /ps4hdd/ROMs/arcade /ps4hdd/ROMs/neogeo /ps4hdd/ROMs/atari2600 /ps4hdd/ROMs/atari7800 /ps4hdd/ROMs/sms /ps4hdd/ROMs/gg /ps4hdd/ROMs/c64 /ps4hdd/ROMs/pcecd /ps4hdd/ROMs/bios /ps4hdd/ROMs/saves /ps4hdd/ROMs/screenshots
mkdir -p /ps4hdd/BIOS
echo "  ROMs: /ps4hdd/ROMs/"
echo "  BIOS: /ps4hdd/BIOS/"

echo
echo "=== Install complete! ==="
echo ""
echo "  ROMs: /ps4hdd/ROMs/"
echo "  BIOS: /ps4hdd/BIOS/"
echo ""
echo "PS4 RetroBox by danyboy666 — https://github.com/danyboy666/ps4-retrobox"
echo "Initramfs based on better-initramfs by Piotr Karbowski (BSD-3-Clause)"
echo "  https://bitbucket.org/piotrkarbowski/better-initramfs"
echo "PS4 initramfs by feeRnt — https://github.com/feeRnt/ps4-linux-initramfs"

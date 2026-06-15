#!/bin/bash
set -e

ROOTFS="/mnt/ps4root"
REPO="danyboy666/ps4-retrobox"
FEEINT_INITRAMFS_TAG="v1.0"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

ROOTFS="${1:-/mnt/ps4root}"

run_chroot() {
    chroot "$ROOTFS" /bin/bash -c "$1"
}

# === Create rootfs directory ===
mkdir -p "$ROOTFS"

# === Bootstrap Ubuntu 22.04 ===
echo "=== Bootstrapping Ubuntu 22.04 ==="
debootstrap --arch=amd64 jammy "$ROOTFS" http://archive.ubuntu.com/ubuntu

# === Mount pseudo-filesystems ===
echo "=== Mounting pseudo-filesystems ==="
for fs in proc sys dev dev/pts run tmp; do
    mount --bind "/$fs" "$ROOTFS/$fs" 2>/dev/null || true
done

# === Configure apt sources ===
echo "=== Configuring apt sources ==="
cat > "$ROOTFS/etc/apt/sources.list" << 'SOURCES'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
SOURCES

cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

# === Set hostname ===
echo "ps4-retrobox" > "$ROOTFS/etc/hostname"
echo "127.0.0.1 localhost ps4-retrobox" > "$ROOTFS/etc/hosts"

# === Set timezone ===
ln -sf /usr/share/zoneinfo/America/New_York "$ROOTFS/etc/localtime"
echo "America/New_York" > "$ROOTFS/etc/timezone"

# === Set locale ===
echo "en_US.UTF-8 UTF-8" > "$ROOTFS/etc/locale.gen"

# === Install all packages ===
echo "=== Installing packages ==="
run_chroot "apt-get update"
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    systemd systemd-sysv init kmod udev locales \
    sudo bash-completion \
    network-manager wpasupplicant \
    openssh-server \
    vim nano htop curl wget git \
    pulseaudio alsa-utils \
    ntfs-3g exfat-fuse exfatprogs \
    usbutils pciutils net-tools iputils-ping \
    dbus console-setup keyboard-configuration"

run_chroot "locale-gen en_US.UTF-8"
run_chroot "update-locale LANG=en_US.UTF-8"

# === Install Bluetooth ===
echo "=== Installing Bluetooth ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bluez bluez-tools pulseaudio-module-bluetooth"

# === Install Samba + NFS ===
echo "=== Installing Samba + NFS ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    samba samba-common-bin nfs-kernel-server nfs-common"

# === Install CIFS utils ===
echo "=== Installing CIFS utils ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y cifs-utils"

# === Install GPU + X11 ===
echo "=== Installing Graphics stack ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    mesa-vulkan-drivers libdrm-amdgpu1 libgl1-mesa-dri libgl1-mesa-glx \
    libglu1-mesa libegl1-mesa xserver-xorg-video-amdgpu \
    xinit xterm x11-xserver-utils xserver-xorg-input-libinput"

# === Install EmulationStation build deps ===
echo "=== Installing EmulationStation build deps ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libsdl2-dev libboost-system-dev libboost-filesystem-dev \
    libboost-date-time-dev libboost-locale-dev libfreeimage-dev \
    libfreetype6-dev libeigen3-dev libcurl4-openssl-dev \
    libasound2-dev libgl1-mesa-dev build-essential cmake"

# === Install RetroArch + cores ===
echo "=== Installing RetroArch + cores ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    retroarch retroarch-assets libretro-core-info \
    libretro-beetle-pce-fast libretro-beetle-psx \
    libretro-bsnes-mercury-balanced libretro-desmume \
    libretro-gambatte libretro-genesisplusgx \
    libretro-mgba libretro-mupen64plus libretro-snes9x"

# === Install extras ===
echo "=== Installing extras ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    joystick jstest-gtk evtest ffmpeg netpbm"

# === Compile EmulationStation ===
echo "=== Compiling EmulationStation ==="
run_chroot "cd /tmp && git clone https://github.com/Aloshi/EmulationStation.git ES-build"

# Patch round() conflict
run_chroot "cd /tmp/ES-build && \
    sed -i '/^float round(float num);$/d' es-core/src/Util.h && \
    grep -q '#include <cmath>' es-core/src/Util.h || sed -i '/#pragma once/a #include <cmath>' es-core/src/Util.h && \
    sed -i '/^float round(float num)\$/,/^}$/d' es-core/src/Util.cpp && \
    find es-core/src/ es-app/src/ -name '*.cpp' -o -name '*.h' | xargs perl -i -pe 's/(?<!std::)(?<![a-zA-Z_])round\(/std::round(/g' && \
    sed -i '1a #include <stack>' es-app/src/views/gamelist/ISimpleGameListView.h && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-w -DCMAKE_CXX_FLAGS='-w' && \
    make -j\$(nproc) && make install"

# === Create user ===
echo "=== Creating user PS4 ==="
run_chroot "useradd -m -s /bin/bash -G sudo,video,input,plugdev PS4"
run_chroot "echo 'PS4:PS4' | chpasswd"
run_chroot "echo 'root:root' | chpasswd"
run_chroot "echo 'PS4 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/PS4"
run_chroot "chmod 440 /etc/sudoers.d/PS4"

# === Configure SSH ===
echo "=== Configuring SSH ==="
run_chroot "systemctl enable ssh.service"

cat > "$ROOTFS/etc/systemd/system/regenerate-ssh-keys.service" << 'EOF'
[Unit]
Description=Regenerate SSH host keys on first boot
After=sysinit.target
Before=ssh.service
ConditionPathExistsGlob=!/etc/ssh/ssh_host_*

[Service]
Type=oneshot
ExecStart=/usr/sbin/sshd-keygen
ExecStart=/bin/systemctl enable --now ssh.service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

run_chroot "systemctl enable regenerate-ssh-keys.service"

# === Configure autostart ===
echo "=== Configuring autostart ==="
mkdir -p "$ROOTFS/etc/systemd/system/getty@tty1.service.d"
cat > "$ROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin PS4 %I $TERM
EOF

cat > "$ROOTFS/home/PS4/.xinitrc" << 'EOF'
#!/bin/bash
xset -dpms
xset s off
xset s noblank
exec emulationstation
EOF
chmod +x "$ROOTFS/home/PS4/.xinitrc"

cat > "$ROOTFS/home/PS4/.bash_profile" << 'EOF'
if [ -z "$DISPLAY" ] && [ $(tty) = /dev/tty1 ]; then
    startx
fi
EOF
chmod +x "$ROOTFS/home/PS4/.bash_profile"

# === Create directories ===
echo "=== Creating directories ==="
mkdir -p "$ROOTFS/home/PS4/BIOS"
mkdir -p "$ROOTFS/home/PS4/ROMs/saves"
mkdir -p "$ROOTFS/home/PS4/ROMs/screenshots"
mkdir -p "$ROOTFS/mnt/roms"
chown -R 1001:1001 "$ROOTFS/home/PS4"

# === Create Samba setup helper ===
cat > "$ROOTFS/usr/local/bin/setup-samba.sh" << 'SAMBA'
#!/bin/bash
# === EDIT THESE VALUES ===
PC_IP="192.168.1.100"        # Your Windows PC IP address
SHARE="PS4_ROMs"             # Your Samba share name
USER="PS4"                   # Samba username
PASS="PS4"                   # Samba password
# =========================

echo "Mounting //$PC_IP/$SHARE to /mnt/roms ..."
sudo mkdir -p /mnt/roms

if ! grep -q "$SHARE" /etc/fstab; then
    echo "//$PC_IP/$SHARE /mnt/roms cifs user=$USER,password=$PASS,uid=1001,gid=1001,iocharset=utf8,x-systemd.automount,_netdev,nofail 0 0" | sudo tee -a /etc/fstab
    echo "Added to /etc/fstab"
fi

sudo mount -a
echo "Done! ROMs available at /mnt/roms/"
ls /mnt/roms/
SAMBA
chmod +x "$ROOTFS/usr/local/bin/setup-samba.sh"

# === Configure RetroArch ===
cat > "$ROOTFS/home/PS4/.config/retroarch/retroarch.cfg" << 'RETROCFG'
video_fullscreen = "true"
video_driver = "gl"
audio_driver = "alsa"
input_driver = "udev"
libretro_directory = "/usr/lib/x86_64-linux-gnu/libretro"
libretro_info_path = "/usr/share/libretro/info"
content_database_path = "/usr/share/retroarch/assets/retroarch/database/rdb"
cheat_database_path = "/usr/share/retroarch/assets/retroarch/cht"
screenshot_directory = "/home/PS4/ROMs/screenshots"
savefile_directory = "/home/PS4/ROMs/saves"
savestate_directory = "/home/PS4/ROMs/saves"
system_directory = "/home/PS4/BIOS"
joypad_autoconfig_dir = "/usr/share/retroarch/assets/autoconfig"
menu_driver = "ozone"
RETROCFG

# === Configure EmulationStation ===
cat > "$ROOTFS/home/PS4/.emulationstation/es_systems.cfg" << 'ESCFG'
<?xml version="1.0"?>
<systemList>
  <system>
    <name>snes</name>
    <fullname>Super Nintendo</fullname>
    <path>/mnt/roms/SNES</path>
    <extension>.sfc .smc</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/bsnes_mercury_balanced_libretro.so %ROM%</command>
    <platform>snes</platform>
    <theme>snes</theme>
  </system>
  <system>
    <name>n64</name>
    <fullname>Nintendo 64</fullname>
    <path>/mnt/roms/N64</path>
    <extension>.n64 .z64 .v64</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mupen64plus_libretro.so %ROM%</command>
    <platform>n64</platform>
    <theme>n64</theme>
  </system>
  <system>
    <name>gba</name>
    <fullname>Game Boy Advance</fullname>
    <path>/mnt/roms/GBA</path>
    <extension>.gba</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mgba_libretro.so %ROM%</command>
    <platform>gba</platform>
    <theme>gba</theme>
  </system>
  <system>
    <name>gb</name>
    <fullname>Game Boy / Color</fullname>
    <path>/mnt/roms/GameBoy</path>
    <extension>.gb .gbc</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/gambatte_libretro.so %ROM%</command>
    <platform>gb</platform>
    <theme>gb</theme>
  </system>
  <system>
    <name>genesis</name>
    <fullname>Sega Genesis / Mega Drive</fullname>
    <path>/mnt/roms/Genesis</path>
    <extension>.md .bin .gen .smd</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>genesis</platform>
    <theme>genesis</theme>
  </system>
  <system>
    <name>psx</name>
    <fullname>Sony PlayStation</fullname>
    <path>/mnt/roms/PlayStation</path>
    <extension>.bin .cue .iso .pbp .chd</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_psx_libretro.so %ROM%</command>
    <platform>psx</platform>
    <theme>psx</theme>
  </system>
  <system>
    <name>pce</name>
    <fullname>TurboGrafx-16</fullname>
    <path>/mnt/roms/TurboGrafx16</path>
    <extension>.pce .cue</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_pce_fast_libretro.so %ROM%</command>
    <platform>pce</platform>
    <theme>pce</theme>
  </system>
  <system>
    <name>nds</name>
    <fullname>Nintendo DS</fullname>
    <path>/mnt/roms/NintendoDS</path>
    <extension>.nds .zip</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/desmume_libretro.so %ROM%</command>
    <platform>nds</platform>
    <theme>nds</theme>
  </system>
</systemList>
ESCFG

chown -R 1001:1001 "$ROOTFS/home/PS4"

# === Cleanup ===
echo "=== Cleaning up ==="
run_chroot "apt-get autoremove -y && apt-get clean"
run_chroot "rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"

# === Unmount pseudo-filesystems ===
for fs in tmp run dev/pts dev sys proc; do
    umount "$ROOTFS/$fs" 2>/dev/null || true
done

# === Package rootfs as arch.tar.xz ===
echo "=== Packaging rootfs ==="
tar -cJf arch.tar.xz -C "$ROOTFS" \
    --exclude='./proc' --exclude='./sys' --exclude='./run' \
    --exclude='./dev' --exclude='./tmp' .

# === Download feeRnt initramfs ===
echo "=== Downloading feeRnt initramfs ==="
if command -v gh &>/dev/null; then
    gh release download "$FEEINT_INITRAMFS_TAG" -R feeRnt/ps4-linux-initramfs \
        -p "initramfs.cpio.gz" -D . --clobber 2>/dev/null || \
    echo "Warning: Could not download initramfs via gh. Download manually from:"
    echo "  https://github.com/feeRnt/ps4-linux-initramfs/releases/tag/$FEEINT_INITRAMFS_TAG"
else
    echo "Warning: gh CLI not found. Download initramfs manually from:"
    echo "  https://github.com/feeRnt/ps4-linux-initramfs/releases/tag/$FEEINT_INITRAMFS_TAG"
fi

echo ""
echo "=== Build complete! ==="
echo "Files:"
echo "  arch.tar.xz          $(du -h arch.tar.xz | cut -f1)  (Ubuntu rootfs)"
echo "  initramfs.cpio.gz    $(du -h initramfs.cpio.gz 2>/dev/null | cut -f1 || echo 'missing')  (feeRnt initramfs)"
echo "  bzImage*             (kernel - download from community-files or GitHub)"
echo "  payload-960-*.elf    (payloads - download from community-files or GitHub)"
echo ""
echo "FTP these 3 files to your PS4:"
echo "  1. bzImage*           -> /data/linux/boot/bzImage"
echo "  2. initramfs.cpio.gz  -> /data/linux/boot/initramfs.cpio.gz"
echo "  3. arch.tar.xz        -> /user/system/boot/arch.tar.xz"
echo ""
echo "Then boot: send 1GB payload -> exec install-HDD.sh -> enter 32"
echo "After boot: sudo nano /usr/local/bin/setup-samba.sh -> sudo setup-samba.sh"

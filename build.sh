#!/bin/bash
# No set -e — we handle errors explicitly to avoid silent build failures

ROOTFS="/mnt/ps4root"
REPO="danyboy666/ps4-retrobox"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo $0)"
    exit 1
fi

ROOTFS="${1:-/mnt/ps4root}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Master system list — 42 systems
ALL_SYSTEMS="snes nes n64 gba gb gbc megadrive psx tg16 tgcd arcade neogeo atari2600 atari5200 atari7800 mastersystem gamegear famicom fds genesis sfc segacd mega-cd sega32x wonderswan wonderswancolor atarijaguar atarilynx colecovision gameandwatch ngp ngpc psp sg-1000 supergrafx virtualboy channelf mame-libretro vectrex dreamcast ps2 gamecube wii"

run_chroot() {
    chroot "$ROOTFS" /bin/bash -c "$1"
}

# === Create rootfs directory ===
# Clean stale mounts from previous builds
for fs in tmp run dev/pts dev sys proc; do
    umount "$ROOTFS/$fs" 2>/dev/null || true
done
mkdir -p "$ROOTFS"
rm -rf "$ROOTFS"/*

# === Bootstrap Ubuntu 24.04 ===
echo "=== Bootstrapping Ubuntu 24.04 ==="
debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu

# === Mount pseudo-filesystems ===
echo "=== Mounting pseudo-filesystems ==="
for fs in proc sys dev dev/pts run tmp; do
    mount --bind "/$fs" "$ROOTFS/$fs" 2>/dev/null || true
done

# === Configure apt sources ===
echo "=== Configuring apt sources ==="
cat > "$ROOTFS/etc/apt/sources.list" << 'SOURCES'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
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
    dbus console-setup keyboard-configuration \
    xvfb xserver-xorg-core"

run_chroot "locale-gen en_US.UTF-8"
run_chroot "update-locale LANG=en_US.UTF-8"

# === Install Bluetooth ===
echo "=== Installing Bluetooth ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bluez bluez-tools pulseaudio-module-bluetooth"

# === Install Samba + NFS ===
echo "=== Installing Samba + NFS ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    samba samba-common-bin nfs-common nfs-utils rpcbind"

# === Install CIFS utils ===
echo "=== Installing CIFS utils ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y cifs-utils"

# === Install GPU + X11 ===
echo "=== Installing Graphics stack ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    mesa-vulkan-drivers libdrm-amdgpu1 libgl1-mesa-dri libgl1-mesa-glx \
    libglu1-mesa libegl1-mesa xserver-xorg-video-amdgpu \
    xinit xterm x11-xserver-utils xserver-xorg-input-libinput \
    libdrm-tests plymouth plymouth-themes fbi imagemagick"

# === Install EmulationStation build deps ===
echo "=== Installing EmulationStation build deps ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libsdl2-dev libboost-system-dev libboost-filesystem-dev \
    libboost-date-time-dev libboost-locale-dev libfreeimage-dev \
    libfreetype6-dev libeigen3-dev libcurl4-openssl-dev \
    libasound2-dev libgl1-mesa-dev build-essential cmake \
    libpng-dev libjpeg-dev"

# === Install RetroArch build deps ===
echo "=== Installing RetroArch build deps ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libdrm-dev libgbm-dev libegl-dev libgles-dev libudev-dev \
    libasound2-dev libpulse-dev libfreetype-dev libfontconfig-dev \
    libxkbcommon-dev libwayland-dev libx11-xcb-dev libxcb1-dev \
    libxcb-xkb-dev libxkbcommon-x11-dev libxrandr-dev libxinerama-dev \
    libxi-dev libxcursor-dev libxss-dev libssl-dev libsdl2-dev \
    nasm git liblzma-dev"

# === Build RetroArch from source (with DRM video driver) ===
echo "=== Building RetroArch 1.22.2 from source ==="
run_chroot "cd /tmp && rm -rf RetroArch && git clone --depth=1 --branch v1.22.2 https://github.com/libretro/RetroArch.git RetroArch"
run_chroot "cd /tmp/RetroArch && ./configure --enable-plain_drm --enable-kms --enable-egl --enable-sdl2 --enable-alsa --enable-udev --enable-freetype --enable-ssl --enable-opengl --disable-qt --disable-ffmpeg --disable-opengl_core"
run_chroot "cd /tmp/RetroArch && make -j\$(nproc)"
run_chroot "cp /tmp/RetroArch/retroarch /usr/bin/retroarch && chmod +x /usr/bin/retroarch"
run_chroot "rm -rf /tmp/RetroArch"

# === Install libretro core build deps ===
echo "=== Installing libretro core build deps ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    retroarch-assets libretro-core-info" || true
# Remove 330MB noto fonts pulled in as dependency (keep retroarch-assets installed)
run_chroot "rm -rf /usr/share/fonts/truetype/noto" 2>/dev/null || true

# Disable system DS4 autoconfig (PS4 kernel shifts button indices via BTN_C=2/BTN_Z=5)
run_chroot "mv /usr/share/retroarch/assets/autoconfig/udev/'Sony DualShock 4 Controller.cfg' \
    /usr/share/retroarch/assets/autoconfig/udev/'Sony DualShock 4 Controller.cfg.disabled' 2>/dev/null" || true

# === Install fonts for XMB menu ===
echo "=== Installing fonts ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    fonts-dejavu-core fonts-roboto-unhinted" || true
# Install TTF shortcut directory for RA
mkdir -p "$ROOTFS/usr/share/fonts/TTF"
cp "$ROOTFS/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" "$ROOTFS/usr/share/fonts/TTF/" 2>/dev/null
cp "$ROOTFS/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" "$ROOTFS/usr/share/fonts/TTF/" 2>/dev/null
cp "$ROOTFS/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Regular.ttf" "$ROOTFS/usr/share/fonts/TTF/" 2>/dev/null
cp "$ROOTFS/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Bold.ttf" "$ROOTFS/usr/share/fonts/TTF/" 2>/dev/null
# Fix broken font symlinks in libretro assets
ln -sf /usr/share/fonts/TTF/DejaVuSans.ttf "$ROOTFS/usr/share/libretro/assets/pkg/chinese-font.ttf" 2>/dev/null
ln -sf /usr/share/fonts/TTF/DejaVuSans.ttf "$ROOTFS/usr/share/libretro/assets/pkg/korean-fallback-font.ttf" 2>/dev/null
ln -sf /usr/share/fonts/TTF/DejaVuSans.ttf "$ROOTFS/usr/share/libretro/assets/pkg/osd-font.ttf" 2>/dev/null
ln -sf /usr/share/fonts/TTF/DejaVuSans.ttf "$ROOTFS/usr/share/libretro/assets/pkg/fallback-font.ttf" 2>/dev/null
# Set XMB monochrome font.ttf symlink to Roboto
cp "$ROOTFS/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" "$ROOTFS/usr/share/retroarch/assets/xmb/monochrome/font.ttf" 2>/dev/null
echo "Fonts installed"

# === Download missing libretro cores from buildbot ===
echo "=== Downloading missing libretro cores ==="
LIBRETRO_DIR="$ROOTFS/usr/lib/x86_64-linux-gnu/libretro"
mkdir -p "$LIBRETRO_DIR"
BUILDBOT="https://buildbot.libretro.com/nightly/linux/x86_64/latest"
CORES_OK=0
CORES_FAIL=0
for core in atari800 bsnes_mercury_balanced gambatte genesis_plus_gx \
    mednafen_pce_fast mednafen_psx mgba mupen64plus_next \
    parallel_n64 pcsx_rearmed snes9x \
    nestopia fbneo stella prosystem flycast \
    mesen picodrive mednafen_wswan virtualjaguar mednafen_lynx \
    gearcoleco gw mednafen_ngp ppsspp gearsystem \
    mednafen_supergrafx mednafen_vb freechaf mame2003_plus vecx; do
    echo "  Downloading ${core}_libretro.so..."
    if wget -q -O "/tmp/${core}_libretro.so.zip" "$BUILDBOT/${core}_libretro.so.zip" 2>/dev/null; then
        cd "$LIBRETRO_DIR" && unzip -o "/tmp/${core}_libretro.so.zip" 2>/dev/null
        rm -f "/tmp/${core}_libretro.so.zip"
        if [ -f "$LIBRETRO_DIR/${core}_libretro.so" ]; then
            echo "    OK: ${core}_libretro.so"
            CORES_OK=$((CORES_OK + 1))
        else
            echo "    FAILED (extract): ${core}_libretro.so"
            CORES_FAIL=$((CORES_FAIL + 1))
        fi
    else
        echo "    FAILED (download): ${core}_libretro.so"
        CORES_FAIL=$((CORES_FAIL + 1))
    fi
    cd /
done
chmod 644 "$LIBRETRO_DIR"/*.so 2>/dev/null
echo "Libretro cores: $CORES_OK OK, $CORES_FAIL failed"

# === Install standalone emulators ===
echo "=== Installing standalone emulators ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y pcsx2 dolphin-emu 2>/dev/null" || true
# If not in apt, download AppImages
if ! run_chroot "which pcsx2-qt" 2>/dev/null; then
    echo "pcsx2 not in apt, downloading AppImage..."
    wget -q -O /tmp/pcsx2.AppImage "https://github.com/PCSX2/pcsx2/releases/latest/download/pcsx2-Qt-x86_64.AppImage" 2>/dev/null
    if [ -f /tmp/pcsx2.AppImage ]; then
        chmod +x /tmp/pcsx2.AppImage
        cp /tmp/pcsx2.AppImage "$ROOTFS/usr/bin/pcsx2-qt"
        rm -f /tmp/pcsx2.AppImage
    fi
fi
if ! run_chroot "which dolphin-emu-nogui" 2>/dev/null; then
    echo "dolphin not in apt, downloading..."
    wget -q -O /tmp/dolphin.tar.xz "https://dl.dolphin-emu.org/releases/latest/dolphin-x64.tar.xz" 2>/dev/null
    if [ -f /tmp/dolphin.tar.xz ]; then
        tar xJf /tmp/dolphin.tar.xz -C /tmp/ 2>/dev/null
        cp /tmp/dolphin-*/bin/dolphin-emu-nogui "$ROOTFS/usr/bin/" 2>/dev/null
        cp /tmp/dolphin-*/bin/dolphin-emu "$ROOTFS/usr/bin/" 2>/dev/null
        cp -r /tmp/dolphin-*/lib/* "$ROOTFS/usr/lib/" 2>/dev/null
        rm -rf /tmp/dolphin-*
    fi
fi

# === Install extras ===
echo "=== Installing extras ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    joystick jstest-gtk evtest ffmpeg netpbm python3-pil \
    xkb-data"
# Force reinstall xkb-data to ensure symbol files survive rootfs cleanup
run_chroot "apt-get install --reinstall -y xkb-data"
run_chroot "ls /usr/share/X11/xkb/symbols/ | wc -l"

# === USB power management ===
echo "=== Creating USB power udev rules ==="
mkdir -p "$ROOTFS/etc/udev/rules.d"
cat > "$ROOTFS/etc/udev/rules.d/99-ps4-usb-power.rules" << 'UDEV'
# Disable ALL USB autosuspend globally
ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="-1"
ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend_delay_ms}="-1"
# DS4: disable autosuspend, force power on, reduce polling to 16ms
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="09cc", ATTR{power/autosuspend}="-1", ATTR{power/autosuspend_delay_ms}="-1", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="09cc", TEST=="*/ep_*/interval", ATTR*/ep_*/interval="16"
# Handle DS4 reconnections
ACTION=="change", SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="09cc", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"
UDEV

# === Install RetroArch autoconfig profiles ===
echo "=== Installing autoconfig profiles ==="
wget -q -O /tmp/ra_autoconfig.zip "https://buildbot.libretro.com/assets/frontend/autoconfig.zip" 2>/dev/null
if [ -s /tmp/ra_autoconfig.zip ]; then
    mkdir -p "$ROOTFS/usr/share/retroarch/assets/autoconfig/udev"
    cd /tmp && python3 -c "
import zipfile, os
z = zipfile.ZipFile('/tmp/ra_autoconfig.zip')
for n in z.namelist():
    if n.startswith('udev/') and n.endswith('.cfg'):
        name = os.path.basename(n)
        with z.open(n) as src, open('$ROOTFS/usr/share/retroarch/assets/autoconfig/udev/' + name, 'wb') as dst:
            dst.write(src.read())
print(f'Extracted {len([n for n in z.namelist() if n.startswith(\"udev/\") and n.endswith(\".cfg\")])} profiles')
"
    cd -
    rm -f /tmp/ra_autoconfig.zip
    # Remove menu_toggle_btn from DS4 profile so our hotkey settings take effect
    sed -i '/input_menu_toggle_btn/d' "$ROOTFS/usr/share/retroarch/assets/autoconfig/udev/Sony DualShock 4 Controller.cfg" 2>/dev/null
else
    echo "WARNING: autoconfig download failed"
fi

# === Compile amdgpu shim (intercepts ACCEL_WORKING check for PS4) ===
echo "=== Compiling amdgpu shim ==="
cat > /tmp/amdgpu_shim.c << 'SHIMEOF'
#include <stddef.h>
#include <stdint.h>
#include <dlfcn.h>
#define AMDGPU_INFO_ACCEL_WORKING 0x18
typedef int (*orig_t)(void *, uint32_t, uint32_t, void *);
int amdgpu_query_info(void *dev, uint32_t info, uint32_t size, void *value) {
    static orig_t orig = NULL;
    if (!orig) orig = (orig_t)dlsym(RTLD_NEXT, "amdgpu_query_info");
    if (info == AMDGPU_INFO_ACCEL_WORKING) {
        if (value) *(uint32_t *)value = 1;
        return 0;
    }
    if (orig) return orig(dev, info, size, value);
    return -1;
}
SHIMEOF
run_chroot "gcc -shared -fPIC -o /usr/lib/x86_64-linux-gnu/amdgpu_shim.so /tmp/amdgpu_shim.c -ldl"
rm -f /tmp/amdgpu_shim.c

# === fbi (framebuffer imageviewer) already installed via extras ===

# === Build ngdevkit nullbios (open-source Neo Geo BIOS) ===
echo "=== Building Neo Geo BIOS (ngdevkit nullbios) ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y autoconf automake make gcc 2>/dev/null"
run_chroot "mkdir -p /home/PS4/.config/retroarch/system && cd /tmp && rm -rf ngdevkit && git clone --depth 1 https://github.com/dciabrin/ngdevkit.git && cd ngdevkit && autoreconf -iv 2>/dev/null && ./configure --prefix=/usr 2>/dev/null && make -C nullbios 2>/dev/null && cp nullbios/rom/neogeo.zip /home/PS4/.config/retroarch/system/ && cp nullbios/rom/aes.zip /home/PS4/.config/retroarch/system/ && echo 'Neo Geo BIOS installed'"
 run_chroot "rm -rf /tmp/ngdevkit"

# === Download additional BIOS files (Abdess/retrobios, MIT License) ===
echo "=== Downloading additional BIOS files ==="
BIOS_DIR="$ROOTFS/home/PS4/.config/retroarch/system"
BIOS_URL="https://raw.githubusercontent.com/Abdess/retrobios/main/bios"
mkdir -p "$BIOS_DIR"

# PlayStation BIOS
curl -fsSL "$BIOS_URL/Sony/PlayStation/scph5500.bin" -o "$BIOS_DIR/scph5500.bin" 2>/dev/null && echo "  [OK] PlayStation BIOS (Japan)" || echo "  [FAIL] PlayStation BIOS (Japan)"
curl -fsSL "$BIOS_URL/Sony/PlayStation/scph5501.bin" -o "$BIOS_DIR/scph5501.bin" 2>/dev/null && echo "  [OK] PlayStation BIOS (US)" || echo "  [FAIL] PlayStation BIOS (US)"
curl -fsSL "$BIOS_URL/Sony/PlayStation/scph5502.bin" -o "$BIOS_DIR/scph5502.bin" 2>/dev/null && echo "  [OK] PlayStation BIOS (Europe)" || echo "  [FAIL] PlayStation BIOS (Europe)"

# Sega 32X BIOS
curl -fsSL "$BIOS_URL/Sega/32X/32X_M_BIOS.BIN" -o "$BIOS_DIR/32X_M_BIOS.BIN" 2>/dev/null && echo "  [OK] 32X Main BIOS" || echo "  [FAIL] 32X Main BIOS"
curl -fsSL "$BIOS_URL/Sega/32X/32X_S_BIOS.BIN" -o "$BIOS_DIR/32X_S_BIOS.BIN" 2>/dev/null && echo "  [OK] 32X Slave BIOS" || echo "  [FAIL] 32X Slave BIOS"
curl -fsSL "$BIOS_URL/Sega/32X/32X_G_BIOS.BIN" -o "$BIOS_DIR/32X_G_BIOS.BIN" 2>/dev/null && echo "  [OK] 32X Game BIOS" || echo "  [FAIL] 32X Game BIOS"

# Atari 5200 BIOS
curl -fsSL "$BIOS_URL/Atari/5200/5200.rom" -o "$BIOS_DIR/5200.rom" 2>/dev/null && echo "  [OK] Atari 5200 BIOS" || echo "  [FAIL] Atari 5200 BIOS"

# TurboGrafx-CD System Card
curl -fsSL "$BIOS_URL/NEC/PC%20Engine%20CD/PCECD_3.0-(J).pce" -o "$BIOS_DIR/syscard3.pce" 2>/dev/null && echo "  [OK] TurboGrafx-CD System Card v3.0" || echo "  [FAIL] TurboGrafx-CD System Card"

# === Create BIOS README ===
echo "=== Creating BIOS README ==="
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/system"
cat > "$ROOTFS/home/PS4/.config/retroarch/system/BIOS_README.txt" << 'BIOSEOF'
===============================================================================
 SYSTEM BIOS DIRECTORY
===============================================================================
Some systems require BIOS files. This build includes an open-source Neo Geo
BIOS (ngdevkit nullbios) pre-installed as neogeo.zip.

Place additional BIOS files in: /home/PS4/.config/retroarch/system/

Systems requiring BIOS:
- PlayStation: scph5500.bin, scph5501.bin, scph5502.bin
- Sega 32X: 32x_bios_m.bin, 32x_bios_s.bin, 32x_bios_g.bin
- Atari 5200: 5200.rom
- TurboGrafx-CD: syscard3.pce
- PSP: PPSSPP system files

Neo Geo: neogeo.zip is pre-installed (ngdevkit nullbios).
For enhanced features: http://unibios.free.fr/ (personal use only)
MAME BIOS: https://github.com/mamedev/mame
===============================================================================
BIOSEOF

# === Compile EmulationStation (PS4 fork with 25-button input + configscripts) ===
echo "=== Compiling EmulationStation ==="
run_chroot "cd /tmp && rm -rf ES-build && git clone https://github.com/danyboy666/EmulationStation.git ES-build"

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

# Install RetroArch configscript
mkdir -p "$ROOTFS/usr/local/bin"
cp "$SCRIPT_DIR/configscripts/retroarch.sh" "$ROOTFS/usr/local/bin/retroarch-configscript.sh"

# Install inputconfiguration.sh (bridges ES input config to RetroArch)
cp "$SCRIPT_DIR/configscripts/inputconfiguration.sh" "$ROOTFS/usr/local/bin/inputconfiguration.sh"
chmod +x "$ROOTFS/usr/local/bin/inputconfiguration.sh"
chmod +x "$ROOTFS/usr/local/bin/retroarch-configscript.sh"

# === Create user ===
echo "=== Creating user PS4 ==="
run_chroot "useradd -m -s /bin/bash -G sudo,video,input,plugdev,render,audio PS4"
run_chroot "echo 'PS4:PS4' | chpasswd"
run_chroot "echo 'root:root' | chpasswd"
run_chroot "echo 'PS4 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/PS4"
run_chroot "chmod 440 /etc/sudoers.d/PS4"

# === Configure SSH ===
echo "=== Configuring SSH ==="
run_chroot "systemctl enable ssh.service"

# === Configure PulseAudio: default to HDMI output ===
mkdir -p "$ROOTFS/home/PS4/.config/pulse"
cat > "$ROOTFS/home/PS4/.config/pulse/client.conf" << 'PULSECONF'
default-sink = alsa_output.pci-0000_00_01.1.hdmi-stereo
PULSECONF
chown 1000:1000 "$ROOTFS/home/PS4/.config/pulse/client.conf"

# Force password authentication on
mkdir -p "$ROOTFS/etc/ssh/sshd_config.d"
cat > "$ROOTFS/etc/ssh/sshd_config.d/00-ps4retrobox.conf" << 'SSHEOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
SSHEOF

# Fix main sshd_config — include is at top, so these lines AFTER the include
# override the include file. Must fix them directly.
sed -i 's/^KbdInteractiveAuthentication no$/KbdInteractiveAuthentication yes/' "$ROOTFS/etc/ssh/sshd_config"
sed -i 's/^#PermitRootLogin prohibit-password$/PermitRootLogin yes/' "$ROOTFS/etc/ssh/sshd_config"

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

# === xorg.conf (baked in) ===
echo "=== Creating xorg.conf ==="
mkdir -p "$ROOTFS/etc/X11"
cat > "$ROOTFS/etc/X11/xorg.conf" << 'XORGEOF'
Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "DontZoom" "true"
    Option "AllowMouseOpenFail" "true"
EndSection

Section "Device"
    Identifier  "AMDGPU"
    Driver      "amdgpu"
    Option      "DRI" "3"
    Option      "TearFree" "true"
EndSection

Section "Monitor"
    Identifier  "HDMI-A-0"
    Option      "PreferredMode" "1920x1080"
EndSection

Section "Screen"
    Identifier  "Default Screen"
    Device      "AMDGPU"
    Monitor     "HDMI-A-0"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080"
    EndSubSection
EndSection

Section "InputClass"
    Identifier  "DS4 Gamepad"
    MatchProduct "Sony Interactive Entertainment Wireless Controller"
    MatchDevicePath "/dev/input/event*"
    Driver      "libinput"
EndSection

Section "InputClass"
    Identifier  "DS4 Gamepad by USB ID"
    MatchUSBID  "054c:05c4|054c:09cc"
    MatchDevicePath "/dev/input/event*"
    Driver      "libinput"
EndSection

Section "InputClass"
    Identifier  "Keyboard"
    MatchIsKeyboard "on"
    Option      "XkbLayout" "us"
EndSection
XORGEOF

# === xinitrc (baked in) ===
echo "=== Creating .xinitrc ==="
cat > "$ROOTFS/home/PS4/.xinitrc" << 'XINITEOF'
#!/bin/bash

# PS4 RetroBox — xinitrc
# Disables power management, sets 1080p, hides cursor, starts ES

# Kill any lingering ES processes from previous X sessions
killall -9 emulationstation 2>/dev/null
sleep 1

# Disable DPMS and screensaver
xset -dpms
xset s off
xset s noblank

# Force 1080p resolution
xrandr --output HDMI-A-0 --mode 1920x1080 2>/dev/null || \
xrandr --output HDMI-0 --mode 1920x1080 2>/dev/null || true

# Hide mouse cursor
xsetroot -cursor_name none 2>/dev/null || true

# Disable cursor blinking
xsetroot -cursor_name left_ptr 2>/dev/null || true

# Start EmulationStation (software GL + vsync)
sleep 5
exec env LIBGL_ALWAYS_SOFTWARE=1 vblank_mode=2 __GL_SYNC_TO_VBLANK=1 emulationstation
XINITEOF
chmod +x "$ROOTFS/home/PS4/.xinitrc"

cat > "$ROOTFS/home/PS4/.bash_profile" << 'EOF'
# ES launched by es-session.service — .bash_profile does nothing
true
EOF
chmod +x "$ROOTFS/home/PS4/.bash_profile"

# === ES systemd service (SDL2 framebuffer) ===
mkdir -p "$ROOTFS/etc/systemd/system"
cat > "$ROOTFS/etc/systemd/system/es-session.service" << 'SVCEOF'
[Unit]
Description=EmulationStation (SDL2 framebuffer)
After=multi-user.target network-online.target plymouth-quit.service
Wants=network-online.target

[Service]
Type=simple
User=PS4
KillMode=process
Environment=LD_PRELOAD=/usr/lib/x86_64-linux-gnu/amdgpu_shim.so
Environment=MESA_LOADER_DRIVER_OVERRIDE=radeonsi
Environment=XDG_RUNTIME_DIR=/tmp/runtime-PS4
Environment=SDL_AUDIODRIVER=pulse
Environment=LANG=en_US.UTF-8
Environment=vblank_mode=2
Environment=__GL_SYNC_TO_VBLANK=1
Environment=XKB_CONFIG_ROOT=/usr/share/X11/xkb
ExecStartPre=/bin/bash -c "plymouth quit --retain-splash 2>/dev/null || true"
ExecStartPre=/bin/bash -c "killall -9 retroarch retroarch-wrapper.sh 2>/dev/null || true"
ExecStartPre=/bin/bash -c "sleep 1"
ExecStartPre=/bin/bash -c "dd if=/dev/zero of=/dev/fb0 bs=8294400 count=1 2>/dev/null || true"
ExecStartPre=/bin/bash -c "sleep 1"
ExecStartPre=/bin/bash -c "modetest -s HDMI-A-1:1920x1080 2>/dev/null || true"
ExecStartPre=/bin/bash -c "sleep 1"
ExecStart=emulationstation
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF
ln -sf /etc/systemd/system/es-session.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/es-session.service"
ln -sf /etc/systemd/system/ds4-bridge.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/ds4-bridge.service"
ln -sf /etc/systemd/system/hdmi-watchdog.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/hdmi-watchdog.service"

# === Disable getty services (they steal keyboard input from RetroArch) ===
echo "=== Disabling getty services ==="
for tty_num in 1 2 3 4 5 6; do
    run_chroot "systemctl mask getty@tty${tty_num}.service" 2>/dev/null || true
done
run_chroot "systemctl mask serial-getty@ttyS0.service" 2>/dev/null || true

# === Enable lingering for PulseAudio (starts on boot without login) ===
echo "=== Enabling user lingering ==="
run_chroot "loginctl enable-linger PS4" 2>/dev/null || true

# === PulseAudio: force HDMI as default sink ===
echo "=== Configuring PulseAudio HDMI default ==="
mkdir -p "$ROOTFS/home/PS4/.config/pulse"
cat > "$ROOTFS/home/PS4/.config/pulse/default.pa" << 'PAPAEOF'
#!/usr/bin/pulseaudio -nF

.include /etc/pulse/default.pa

# Remove auto-switch so DS4 speaker doesn't steal audio
unload-module module-switch-on-connect

# Set HDMI as default
set-default-sink alsa_output.pci-0000_00_01.1.hdmi-stereo
PAPAEOF
chown -R 1000:1000 "$ROOTFS/home/PS4/.config/pulse"

# === CPU governor performance service ===
cat > "$ROOTFS/etc/systemd/system/cpu-performance.service" << 'CPUEOF'
[Unit]
Description=Set CPU governor to performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $cpu 2>/dev/null; done"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
CPUEOF
ln -sf /etc/systemd/system/cpu-performance.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/cpu-performance.service"

# === PS4 sysctl tuning (ASLR off for Lightrec dynarec, threaded NAPI) ===
cat > "$ROOTFS/etc/systemd/system/sysctl-ps4-tuning.service" << 'SYSCTLEOF'
[Unit]
Description=PS4 sysctl tuning for Lightrec dynarec and performance
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "echo 0 > /proc/sys/kernel/randomize_va_space"
ExecStart=/bin/bash -c "echo 0 > /proc/sys/vm/mmap_min_addr"
ExecStart=/bin/bash -c "echo 1 > /sys/class/net/eth0/threaded"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SYSCTLEOF
ln -sf /etc/systemd/system/sysctl-ps4-tuning.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/sysctl-ps4-tuning.service"

# === TCP/IP tuning for faster SSH/SFTP transfers ===
mkdir -p "$ROOTFS/etc/sysctl.d"
cat > "$ROOTFS/etc/sysctl.d/99-ps4-network.conf" << 'SYSCTLNET'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 1048576 16777216
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.core.netdev_max_backlog = 5000
SYSCTLNET

# === IRQ affinity + ethtool for Aeolia interrupt distribution ===
echo "=== Installing ethtool + irqbalance ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y ethtool irqbalance" 2>/dev/null

cat > "$ROOTFS/etc/systemd/system/fix-irq-affinity.service" << 'IRQEOF'
[Unit]
Description=Set Aeolia IRQ affinity and eth0 coalescing
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -C eth0 rx-usecs 1000 rx-frames 10 2>/dev/null || true
ExecStart=/bin/bash -c "for irq in $(grep Aeolia /proc/interrupts | awk -F: '{print $1}' | tr -d ' '); do echo ff > /proc/irq/$irq/smp_affinity 2>/dev/null; done"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
IRQEOF
ln -sf /etc/systemd/system/fix-irq-affinity.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/fix-irq-affinity.service"

# === Create EmulationStation config files ===
echo "=== Creating EmulationStation configs ==="
mkdir -p "$ROOTFS/home/PS4/.emulationstation"

# es_settings.cfg
cat > "$ROOTFS/home/PS4/.emulationstation/es_settings.cfg" << 'ESCFG'
<?xml version="1.0"?>
<config>
  <string name="AudioDevice" value="Default" />
  <string name="GamelistViewStyle" value="automatic" />
  <string name="Language" value="en" />
  <string name="ThemeSet" value="carbon" />
  <string name="UserTheme" value="" />
  <bool name="DrawFramerate" value="false" />
  <bool name="ShowHelpPrompts" value="true" />
  <bool name="BackgroundJoystickInput" value="true" />
  <bool name="ShowHiddenFiles" value="false" />
  <bool name="ShowMissingGames" value="true" />
  <bool name="MultiThreadedMedia" value="true" />
  <string name="MediaSystemInfo" value="true" />
  <string name="StartupSystem" value="" />
  <string name="ScreenSaverBehavior" value="dim" />
  <bool name="ScreenSaverEnabled" value="false" />
  <string name="VideoDriver" value="default" />
  <string name="Scraper" value="TheGamesDB" />
  <string name="TheGamesDBApiKey" value="" />
  <bool name="ScrapeRatings" value="true" />
  <int name="ScraperResizeWidth" value="400" />
  <int name="ScraperResizeHeight" value="0" />
  <string name="CollectionSystemsAuto" value="lastplayed, favorites" />
  <string name="CollectionSystemsCustom" value="" />
  <string name="SortAllSystems" value="false" />
  <string name="UseCustomCollectionsSystem" value="false" />
  <string name="CollectionShowSystemInfo" value="true" />
  <string name="DoublePressRemovesFromFavs" value="true" />
</config>
ESCFG

# es_input.cfg (keyboard + DS4 joystick) — ORIGINAL PS4 mapping
# a=Circle(1) b=Cross(0) x=Triangle(3) y=BTN_C(2)
# start=L1(6) select=Square(4)
# leftshoulder=R2-digital(9) rightshoulder=Share(10)
# leftthumb=R1(7) rightthumb=L2-digital(8)
# lefttrigger=axis4 righttrigger=axis5
# hotkeyenable=PS(12)
# up=Options(11) down=PS(12) left=L3(13) right=R3(14)
cat > "$ROOTFS/home/PS4/.emulationstation/es_input.cfg" << 'INPUTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<inputList>
  <inputConfig type="keyboard" deviceName="Keyboard" deviceGUID="-1">
    <input name="up" type="key" id="1073741906" value="1" />
    <input name="down" type="key" id="1073741905" value="1" />
    <input name="left" type="key" id="1073741904" value="1" />
    <input name="right" type="key" id="1073741903" value="1" />
    <input name="a" type="key" id="13" value="1" />
    <input name="b" type="key" id="27" value="1" />
    <input name="start" type="key" id="1073741882" value="1" />
    <input name="select" type="key" id="1073741883" value="1" />
    <input name="pageup" type="key" id="1073741899" value="1" />
    <input name="pagedown" type="key" id="1073741902" value="1" />
  </inputConfig>
  <inputConfig type="joystick" deviceName="PS4 Controller" deviceGUID="03008fe54c050000cc09000000016800">
    <input name="a" type="button" id="1" value="1" />
    <input name="b" type="button" id="0" value="1" />
    <input name="down" type="button" id="12" value="1" />
    <input name="hotkeyenable" type="button" id="12" value="1" />
    <input name="left" type="button" id="13" value="1" />
    <input name="leftanalogdown" type="axis" id="1" value="1" />
    <input name="leftanalogleft" type="axis" id="0" value="-1" />
    <input name="leftanalogright" type="axis" id="0" value="1" />
    <input name="leftanalogup" type="axis" id="1" value="-1" />
    <input name="leftshoulder" type="button" id="9" value="1" />
    <input name="leftthumb" type="button" id="7" value="1" />
    <input name="lefttrigger" type="axis" id="4" value="-1" />
    <input name="right" type="button" id="14" value="1" />
    <input name="rightanalogdown" type="axis" id="3" value="1" />
    <input name="rightanalogleft" type="axis" id="2" value="-1" />
    <input name="rightanalogright" type="axis" id="2" value="1" />
    <input name="rightanalogup" type="axis" id="3" value="-1" />
    <input name="rightshoulder" type="button" id="10" value="1" />
    <input name="rightthumb" type="button" id="8" value="1" />
    <input name="righttrigger" type="axis" id="5" value="1" />
    <input name="select" type="button" id="4" value="1" />
    <input name="start" type="button" id="6" value="1" />
    <input name="up" type="button" id="11" value="1" />
    <input name="x" type="button" id="3" value="1" />
    <input name="y" type="button" id="2" value="1" />
  </inputConfig>
</inputList>
INPUTEOF

echo "ES config: es_settings.cfg (ThemeSet=carbon, ShowMissingGames=true)"
echo "ES config: es_input.cfg (keyboard + DS4 joystick)"

# === Generate RetroArch autoconfig from es_input.cfg ===
# Mimics Batocera libretroControllers.py: reads ES input type/id/value,
# writes input_{name}_{type} = "{value}" to joypad file
python3 << 'PYEOF'
import xml.etree.ElementTree as ET, os, re
ROOTFS = os.environ.get("ROOTFS", "/mnt/ps4root")
tree = ET.parse(f"{ROOTFS}/home/PS4/.emulationstation/es_input.cfg")
joypad_dir = f"{ROOTFS}/home/PS4/.config/retroarch/all/retroarch-joypads"
os.makedirs(joypad_dir, exist_ok=True)

# Batocera mapping: ES input name → RetroArch key(s)
RA_KEYS = {
    "up": ["input_up"],
    "down": ["input_down"],
    "left": ["input_left"],
    "right": ["input_right"],
    "a": ["input_a"],
    "b": ["input_b"],
    "x": ["input_x"],
    "y": ["input_y"],
    "leftshoulder": ["input_l"],
    "rightshoulder": ["input_r"],
    "lefttrigger": ["input_l2"],
    "righttrigger": ["input_r2"],
    "leftthumb": ["input_l3"],
    "rightthumb": ["input_r3"],
    "start": ["input_start"],
    "select": ["input_select"],
    "hotkeyenable": ["input_enable_hotkey"],
    "leftanalogleft": ["input_l_x_minus"],
    "leftanalogright": ["input_l_x_plus"],
    "leftanalogup": ["input_l_y_minus"],
    "leftanalogdown": ["input_l_y_plus"],
    "rightanalogleft": ["input_r_x_minus"],
    "rightanalogright": ["input_r_x_plus"],
    "rightanalogup": ["input_r_y_minus"],
    "rightanalogdown": ["input_r_y_plus"],
}
HAT_MAP = {"1": "up", "2": "right", "4": "down", "8": "left"}

for ic in tree.getroot().findall("inputConfig"):
    if ic.get("type") != "joystick": continue
    es_name = ic.get("deviceName")
    if "PS4" not in es_name and "Wireless" not in es_name and "Sony" not in es_name:
        continue
    ra_name = "Sony Interactive Entertainment Wireless Controller"
    lines = [f'input_driver = "udev"', f'input_device = "{ra_name}"',
             f'input_autodetect_enable = "true"']
    for inp in ic.findall("input"):
        n, t, i, v = inp.get("name"), inp.get("type"), inp.get("id"), inp.get("value")
        keys = RA_KEYS.get(n, [])
        if not keys: continue
        if t == "button":
            for k in keys: lines.append(f'{k}_btn = "{i}"')
        elif t == "hat":
            if v in HAT_MAP:
                for k in keys: lines.append(f'{k}_btn = "h{i}{HAT_MAP[v]}"')
        elif t == "axis":
            val = f"+{i}" if int(v) > 0 else f"-{i}"
            for k in keys: lines.append(f'{k}_axis = "{val}"')
    safe = re.sub(r'[:<>?"/\\|*]', '', es_name)
    safe = re.sub(r'\s+', '_', safe)
    with open(f"{joypad_dir}/{safe}.cfg", "w") as f: f.write("\n".join(lines)+"\n")
    print(f"Generated: {joypad_dir}/{safe}.cfg ({len(lines)} lines)")
PYEOF

# === Storage choice ===
echo ""
echo "Where should ROMs be stored?"
echo "  [1] In .img (default) — self-contained, easier backup"
echo "  [2] On UFS — larger capacity, persists across reinstalls"
echo ""
echo "Default: 1"
STORAGE_CHOICE=""
read -t 10 -n 1 STORAGE_CHOICE 2>/dev/null
STORAGE_CHOICE=${STORAGE_CHOICE:-1}
echo ""

if [ "$STORAGE_CHOICE" = "2" ]; then
    ROM_STORAGE="ufs"
    echo "Storage: UFS (ROMs on /ps4hdd/ROMS/)"
else
    ROM_STORAGE="img"
    echo "Storage: .img (ROMs in /home/PS4/ROMS/)"
fi

# === Create directories ===
echo "=== Creating directories ==="
mkdir -p "$ROOTFS/home/PS4/BIOS"
mkdir -p "$ROOTFS/home/PS4/saves"
mkdir -p "$ROOTFS/home/PS4/screenshots"
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/system"

# Create ROM directories in .img (empty fallback for UFS mode, populated for .img mode)
ROMS_DIR="$ROOTFS/home/PS4/ROMS"
for sys in $ALL_SYSTEMS; do
    mkdir -p "$ROMS_DIR/$sys"
done

# Copy homebrew ROMs into .img (source: es_configs import/ROMS/)
# NOTE: tgcd excluded — empty, users can add via FTP/Samba
HOMEBREW_DIR="$SCRIPT_DIR/es_configs import/ROMS"
if [ -d "$HOMEBREW_DIR" ]; then
    echo "Copying homebrew ROMs to .img..."
    for sys in $ALL_SYSTEMS; do
        if [ -d "$HOMEBREW_DIR/$sys" ]; then
            cp -r "$HOMEBREW_DIR/$sys"/* "$ROMS_DIR/$sys/" 2>/dev/null || true
        fi
    done
    echo "Homebrew ROMs copied."
fi

# Remove any commercial ROMs that should not be bundled
rm -f "$ROMS_DIR/n64/Legend of Zelda, The - Ocarina of Time"* 2>/dev/null

# If UFS mode, write flag for install-HDD.sh
if [ "$ROM_STORAGE" = "ufs" ]; then
    echo "ufs" > "$ROOTFS/home/PS4/.rom_storage"
    echo "Flag file written: .rom_storage=ufs"
fi

# Create empty gamelists so ES can parse systems on first boot
echo "=== Creating empty gamelists ==="
GAMEDIR="$ROOTFS/home/PS4/.emulationstation/gamelists"
for sys in $ALL_SYSTEMS; do
    mkdir -p "$GAMEDIR/$sys"
    echo '<?xml version="1.0"?>' > "$GAMEDIR/$sys/gamelist.xml"
    echo '<gameList />' >> "$GAMEDIR/$sys/gamelist.xml"
done
echo "Gamelists: $(find $GAMEDIR -name gamelist.xml | wc -l) empty systems"

# Create .emulationstation folder structure
echo "=== Creating ES folder structure ==="
ES_DIR="$ROOTFS/home/PS4/.emulationstation"
mkdir -p "$ES_DIR/collections"
mkdir -p "$ES_DIR/downloaded_images"
mkdir -p "$ES_DIR/PS4-RetroBox-Save"
mkdir -p "$ES_DIR/system_art"
mkdir -p "$ES_DIR/systems"
mkdir -p "$ES_DIR/configs/all/launching"
for sys in $ALL_SYSTEMS; do
    mkdir -p "$ES_DIR/downloaded_images/$sys"
    mkdir -p "$ES_DIR/configs/$sys/launching"
done
echo "ES folders created"

# Download launching images from ehettervik/es-runcommand-splash
echo "=== Downloading launching images ==="
SPLEASH_DIR="/tmp/es-runcommand-splash-$$"
rm -rf "$SPLEASH_DIR"
git clone --depth 1 https://github.com/ehettervik/es-runcommand-splash.git "$SPLEASH_DIR" 2>&1 || {
    echo "WARNING: git clone failed, trying curl fallback..."
    mkdir -p "$SPLEASH_DIR"
    curl -sL https://github.com/ehettervik/es-runcommand-splash/archive/refs/heads/master.tar.gz | tar xz -C "$SPLEASH_DIR" --strip-components=1 2>/dev/null || true
}
if [ -d "$SPLEASH_DIR" ]; then
    # Map system name to ehettervik folder name (most match 1:1)
    for sys in $ALL_SYSTEMS; do
        src="$sys"
        case "$sys" in
            genesis) src="megadrive" ;;
        esac
        if [ -f "$SPLEASH_DIR/$src/launching.png" ]; then
            cp "$SPLEASH_DIR/$src/launching.png" "$ES_DIR/downloaded_images/$sys/launching.png" 2>/dev/null
        fi
    done
    rm -rf "$SPLEASH_DIR"
fi
# Count how many images were downloaded
IMG_COUNT=$(find "$ES_DIR/downloaded_images" -name "launching.png" | wc -l)
echo "Launching images: $IMG_COUNT downloaded to downloaded_images/"

chown -R 1000:1000 "$ROOTFS/home/PS4"

# === NetworkManager wired connection ===
echo "=== Configuring NetworkManager ==="
mkdir -p "$ROOTFS/etc/NetworkManager/system-connections"
cat > "$ROOTFS/etc/NetworkManager/system-connections/Wired connection 1.nmconnection" << 'NMEOF'
[connection]
id=Wired connection 1
type=ethernet
autoconnect=true

[ipv4]
method=auto
never-default=false

[ipv6]
method=auto

[ethernet]
NMEOF
chmod 600 "$ROOTFS/etc/NetworkManager/system-connections/Wired connection 1.nmconnection"

# Override: force NM to manage ALL interfaces including Ethernet
mkdir -p "$ROOTFS/etc/NetworkManager/conf.d"
cat > "$ROOTFS/etc/NetworkManager/conf.d/10-managed-ethernet.conf" << 'NMOVERRIDE'
[device]
match-device=interface-name:eth*
managed=true
NMOVERRIDE

# Remove Ubuntu's default file that unmanages Ethernet
cat > "$ROOTFS/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf" << 'NMLIB'
[keyfile]
unmanaged-devices=
NMLIB

# === DS4 udev rules ===
mkdir -p "$ROOTFS/etc/udev/rules.d"

# DS4 hidraw permissions + hide MS keyboard joystick from SDL2
cat > "$ROOTFS/etc/udev/rules.d/99-ds4-usbhid.rules" << 'UDEV'
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0660", GROUP="input"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0660", GROUP="input"
SUBSYSTEM=="input", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0745", ENV{ID_INPUT_JOYSTICK}="0"
UDEV

# Fix /dev/tty0 permissions for Xorg (needed for xrandr HDMI recovery)
cat > "$ROOTFS/etc/udev/rules.d/99-tty0-permissions.rules" << 'UDEVTTY'
KERNEL=="tty0", MODE="0666"
UDEVTTY

# === PS4 autoconfig override (corrects button IDs for PS4 BTN_C/BTN_Z kernel) ===
# Standard system autoconfig uses non-shifted indices; PS4 kernel adds BTN_C=2 / BTN_Z=5
# Disable system autoconfig, install user-level PS4-correct override
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/autoconfig"
cat > "$ROOTFS/home/PS4/.config/retroarch/autoconfig/054c09cc.cfg" << 'ACFG'
input_driver = "udev"
input_device = "Sony Interactive Entertainment Wireless Controller"
input_autodetect_enable = "true"
# === ORIGINAL PS4 mapping (Batocera-aligned — derived from es_input.cfg) ===
# PS4 Linux kernel: BTN_C=2, BTN_Z=5 (extras) — shifts standard indices by 2
# a=1(Circle) b=0(Cross) x=3(Triangle) y=2(BTN_C)
# start=6(L1) select=4(Square)
# leftshoulder=9(R2-dig) rightshoulder=10(Share)
# leftthumb=7(R1) rightthumb=8(L2-dig)
# lefttrigger=axis4 righttrigger=axis5
# hotkeyenable=12(PS) — matches es_input.cfg
input_a_btn = "1"
input_b_btn = "0"
input_x_btn = "3"
input_y_btn = "2"
input_start_btn = "6"
input_select_btn = "4"
input_l_btn = "9"
input_r_btn = "10"
input_l3_btn = "7"
input_r3_btn = "8"
input_l2_axis = "-4"
input_r2_axis = "+5"
input_up_btn = "h0up"
input_down_btn = "h0down"
input_left_btn = "h0left"
input_right_btn = "h0right"
input_l_x_plus_axis = "+0"
input_l_x_minus_axis = "-0"
input_l_y_plus_axis = "+1"
input_l_y_minus_axis = "-1"
input_r_x_plus_axis = "+2"
input_r_x_minus_axis = "-2"
input_r_y_plus_axis = "+3"
input_r_y_minus_axis = "-3"
# === Hotkey + combos (matches es_input.cfg) ===
input_enable_hotkey_btn = "12"
input_exit_emulator_btn = "6"
input_menu_toggle_btn = "0"
input_save_state_btn = "2"
input_load_state_btn = "3"
input_reset_btn = "1"
input_a_btn_label = "Circle"
input_b_btn_label = "Cross"
input_x_btn_label = "Triangle"
input_y_btn_label = "BTN_C"
input_start_btn_label = "L1"
input_select_btn_label = "Square"
ACFG
cp "$ROOTFS/home/PS4/.config/retroarch/autoconfig/054c09cc.cfg" \
   "$ROOTFS/home/PS4/.config/retroarch/autoconfig/Sony Interactive Entertainment Wireless Controller.cfg"
chown -R 1000:1000 "$ROOTFS/home/PS4/.config/retroarch/autoconfig"

# === HDMI hotplug watcher ===
echo "=== Installing HDMI watcher ==="
cat > "$ROOTFS/usr/local/bin/hdmi-recover" << 'RECOVEREOF'
#!/bin/bash
echo HDMI recovery: stopping ES...
systemctl stop es-session.service
sleep 1
echo Starting Xorg...
Xorg :0 -config /dev/null -noreset &
X_PID=$!
sleep 2
echo Running xrandr off/on...
DISPLAY=:0 xrandr --output HDMI-A-1 --off 2>/dev/null
sleep 2
DISPLAY=:0 xrandr --output HDMI-A-1 --auto 2>/dev/null
sleep 1
kill $X_PID 2>/dev/null
wait $X_PID 2>/dev/null
dd if=/dev/zero of=/dev/fb0 bs=8294400 count=1 2>/dev/null
modetest -s HDMI-A-1:1920x1080 2>/dev/null
echo Starting ES...
systemctl start es-session.service
echo HDMI recovery complete.
RECOVEREOF
chmod +x "$ROOTFS/usr/local/bin/hdmi-recover"

# === HDMI watcher v3.1 — HPD + link-status detection, escalating recovery ===
cat > "$ROOTFS/usr/local/bin/hdmi-watcher.sh" << 'HDMI_EOF'
#!/bin/bash
LOG=/var/log/hdmi-watcher.log
touch "$LOG"
chmod 666 "$LOG"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG" >/dev/null; }
LAST_STATUS=""
LAST_LINK="Good"
RECOVERY_COOLDOWN=0
RECOVERY_COUNT=0
CONSEC_BAD=0
get_link() {
    modetest -M amdgpu -c 2>/dev/null | awk '/^53 / {found=1; next} found && /link-status/ {found=2; next} found==2 && /value:/ {print $2; exit}'
}
recover_light() {
    log "Light: modetest mode set + chvt"
    modetest -s HDMI-A-1:1920x1080 >> "$LOG" 2>&1
    sleep 1
    chvt 1 >/dev/null 2>&1
    sleep 1
    chvt 7 >/dev/null 2>&1
    sleep 2
}
recover_heavy() {
    log "Heavy: stop ES -> modetest mode set + chvt -> start ES"
    systemctl stop es-session.service >> "$LOG" 2>&1
    sleep 2
    pkill -9 -f /usr/bin/retroarch >> "$LOG" 2>&1
    sleep 1
    modetest -s HDMI-A-1:1920x1080 >> "$LOG" 2>&1
    sleep 1
    chvt 1 >/dev/null 2>&1
    sleep 1
    chvt 7 >/dev/null 2>&1
    sleep 1
    systemctl start es-session.service >> "$LOG" 2>&1
    sleep 3
}
recover_nuclear() {
    log "Nuclear: stop ES -> DPMS cycle -> modetest + chvt -> start ES"
    systemctl stop es-session.service >> "$LOG" 2>&1
    sleep 2
    pkill -9 -f /usr/bin/retroarch >> "$LOG" 2>&1
    sleep 1
    modetest -M amdgpu -w 53:DPMS:3 >> "$LOG" 2>&1
    sleep 3
    modetest -M amdgpu -w 53:DPMS:0 >> "$LOG" 2>&1
    sleep 2
    modetest -s HDMI-A-1:1920x1080 >> "$LOG" 2>&1
    sleep 1
    chvt 1 >/dev/null 2>&1
    sleep 1
    chvt 7 >/dev/null 2>&1
    sleep 1
    systemctl start es-session.service >> "$LOG" 2>&1
    sleep 3
}
do_recovery() {
    RECOVERY_COUNT=$((RECOVERY_COUNT+1))
    log "=== RECOVERY #$RECOVERY_COUNT ==="
    case "$RECOVERY_COUNT" in
        1|2) recover_light ;;
        3|4) recover_heavy ;;
        *)   recover_nuclear ;;
    esac
    if [ $RECOVERY_COUNT -ge 8 ]; then
        log "8 recoveries done — please reboot manually if signal still missing"
        RECOVERY_COUNT=0
    fi
}
log "=== hdmi-watcher v3.1 started ==="
while true; do
    STATUS=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null)
    LINK_VAL=$(get_link)
    [ -z "$LINK_VAL" ] && LINK_VAL="?"
    if [ "$LINK_VAL" = "0" ]; then LINK="Good"
    elif [ "$LINK_VAL" = "1" ]; then LINK="Bad"
    else LINK="Unknown($LINK_VAL)"; fi
    if [ "$LAST_STATUS" = "connected" ] && [ "$STATUS" = "disconnected" ]; then
        log "TV DISCONNECTED (HPD lost)"
    fi
    if [ "$LAST_STATUS" = "disconnected" ] && [ "$STATUS" = "connected" ]; then
        log "TV RECONNECTED (HPD gained) — scheduling recovery"
        RECOVERY_COOLDOWN=2
    fi
    if [ "$LINK" = "Bad" ]; then
        CONSEC_BAD=$((CONSEC_BAD+1))
        if [ $CONSEC_BAD -eq 5 ]; then
            log "link-status Bad for 5 cycles — scheduling recovery"
            RECOVERY_COOLDOWN=2
        fi
    else
        CONSEC_BAD=0
    fi
    if [ $RECOVERY_COOLDOWN -gt 0 ]; then
        RECOVERY_COOLDOWN=$((RECOVERY_COOLDOWN-1))
        if [ $RECOVERY_COOLDOWN -eq 0 ]; then
            do_recovery
        fi
    fi
    LAST_STATUS="$STATUS"
    LAST_LINK="$LINK"
    sleep 3
done
HDMI_EOF
chmod +x "$ROOTFS/usr/local/bin/hdmi-watcher.sh"

cat > "$ROOTFS/etc/systemd/system/hdmi-watcher.service" << 'SVC2EOF'
[Unit]
Description=HDMI Signal Recovery Watcher
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hdmi-watcher.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC2EOF
ln -sf /etc/systemd/system/hdmi-watcher.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/hdmi-watcher.service"
echo "Services: hdmi-watcher enabled"

# === DHCP fallback service ===
cat > "$ROOTFS/etc/systemd/system/ps4-dhcp-fallback.service" << 'DHCPEOF'
[Unit]
Description=Fallback DHCP on any non-loopback interface
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "for iface in /sys/class/net/*/; do iface=$(basename $iface); [ \"$iface\" = \"lo\" ] && continue; nmcli device set $iface managed yes 2>/dev/null || true; done"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
DHCPEOF
ln -sf /etc/systemd/system/ps4-dhcp-fallback.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/ps4-dhcp-fallback.service"

# === Samba ROM share ===
echo "=== Configuring Samba share ==="
mkdir -p "$ROOTFS/etc/samba"
cat > "$ROOTFS/etc/samba/smb.conf" << 'SAMBAEOF'
[global]
   workgroup = WORKGROUP
   server string = PS4 RetroBox

[PS4_ROMs]
   comment = PS4 RetroBox ROMs
   path = /ps4hdd/ROMS
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0664
   directory mask = 0775
   force user = PS4
   force group = PS4
SAMBAEOF

# === NFS client only ===
echo "=== Configuring NFS client ==="
run_chroot "systemctl disable nfs-server.service 2>/dev/null || true"
run_chroot "systemctl mask nfs-server.service 2>/dev/null || true"
cat > "$ROOTFS/etc/exports" << 'NFSEOF'
# NFS client only — mount ROMs from PC via: sudo mount -t nfs <IP>:<share> /home/PS4/ROMS
NFSEOF

# === Create Samba setup helper ===
cat > "$ROOTFS/usr/local/bin/setup-samba.sh" << 'SAMBA'
#!/bin/bash
# === EDIT THESE VALUES ===
PC_IP="192.168.1.100"        # Your Windows PC IP address
SHARE="PS4_ROMs"             # Your Samba share name
USER="PS4"                   # Samba username
PASS="PS4"                   # Samba password
# =========================

ROMS_DIR="/home/PS4/ROMS"
BK_DIR="/home/PS4/ROM_BK"
MOUNT_LINE="//PC_IP/SHARE $ROMS_DIR cifs user=USER,password=PASS,uid=1000,gid=1000,iocharset=utf8,x-systemd.automount,_netdev,nofail 0 0"

usage() {
    echo "Usage: setup-samba.sh [--toggle|--restore|--setup]"
    echo ""
    echo "  --toggle   Switch between UFS and Samba ROMs (default)"
    echo "  --restore  Restore UFS ROMs after Samba"
    echo "  --setup    One-time setup: add fstab entry and mount"
    echo ""
    echo "Before first use, edit this script and set PC_IP and SHARE."
}

setup_fstab() {
    if ! grep -q "$SHARE" /etc/fstab; then
        echo "Adding Samba share to /etc/fstab..."
        echo "//$PC_IP/$SHARE $ROMS_DIR cifs user=$USER,password=$PASS,uid=1000,gid=1000,iocharset=utf8,x-systemd.automount,_netdev,nofail 0 0" | sudo tee -a /etc/fstab
        echo "Added to /etc/fstab"
    else
        echo "Samba share already in /etc/fstab"
    fi
}

toggle_roms() {
    # Detect current mode
    if mount | grep -q "cifs.*$ROMS_DIR"; then
        # Currently Samba → restore UFS or .img
        echo "Currently Samba. Restoring..."
        sudo umount "$ROMS_DIR" 2>/dev/null
        if [ -d "$BK_DIR" ]; then
            sudo mv "$BK_DIR" "$ROMS_DIR"
            sudo mount --bind /ps4hdd/ROMS "$ROMS_DIR"
            echo "Restored UFS ROMs."
        else
            sudo rmdir "$ROMS_DIR" 2>/dev/null || true
            echo "Restored .img ROMs."
        fi
    elif mountpoint -q "$ROMS_DIR" 2>/dev/null; then
        # Currently UFS bind mount → switch to Samba
        echo "Currently UFS. Switching to Samba..."
        sudo umount "$ROMS_DIR" 2>/dev/null
        [ -d "$BK_DIR" ] && sudo rm -rf "$BK_DIR"
        sudo mv "$ROMS_DIR" "$BK_DIR"
        sudo mkdir -p "$ROMS_DIR"
        sudo mount -a
        echo "Samba ROMs active."
    else
        # Currently .img (regular directory) → switch to Samba
        echo "Currently .img. Switching to Samba..."
        sudo mv "$ROMS_DIR" "$BK_DIR" 2>/dev/null || true
        sudo mkdir -p "$ROMS_DIR"
        sudo mount -a
        echo "Samba ROMs active."
    fi
    sudo systemctl restart es-session
}

restore_ufs() {
    echo "Restoring UFS ROMs..."
    sudo umount "$ROMS_DIR" 2>/dev/null
    sudo rm -rf "$ROMS_DIR"
    sudo mv "$BK_DIR" "$ROMS_DIR" 2>/dev/null || true
    sudo mount --bind /ps4hdd/ROMS "$ROMS_DIR"
    sudo chown -R 1000:1000 /ps4hdd/ROMS
    sudo systemctl restart es-session
    echo "UFS ROMs restored."
}

case "${1:-}" in
    --toggle)
        setup_fstab
        toggle_roms
        ;;
    --restore)
        restore_ufs
        ;;
    --setup)
        setup_fstab
        sudo mkdir -p "$ROMS_DIR"
        sudo mount -a
        echo "Done! Samba ROMs mounted."
        ls "$ROMS_DIR/"
        ;;
    *)
        usage
        ;;
esac
SAMBA
chmod +x "$ROOTFS/usr/local/bin/setup-samba.sh"

# === Configure RetroArch via configscript (RetroPie approach) ===
# Runs configscripts/retroarch.sh in chroot to generate retroarch.cfg from es_input.cfg
# This ensures controller mapping matches ES exactly, with hotkey combos derived from ES bindings
mkdir -p "$ROOTFS/home/PS4/.config/retroarch"
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/all/retroarch-joypads"
cp configscripts/retroarch.sh "$ROOTFS/usr/local/bin/retroarch-configscript.sh"
chmod +x "$ROOTFS/usr/local/bin/retroarch-configscript.sh"
chown 1000:1000 "$ROOTFS/usr/local/bin/retroarch-configscript.sh"
# Run configscript in chroot — generates retroarch.cfg from es_input.cfg
# Handles: button mapping, D-pad HAT override, PS button hotkey, keyboard bindings, analog axes
run_chroot "/usr/local/bin/retroarch-configscript.sh"

# === RetroArch appendconfig: audio (ALSA direct) + keyboard fallback bindings ===
cat > "$ROOTFS/home/PS4/.config/retroarch/retroarch-ps4.cfg" << 'APPENDCFG'
# PS4 RetroBox - Audio (ALSA direct, bypasses dying PulseAudio) + keyboard fallback bindings
# Controller bindings — generated by retroarch-configscript.sh from es_input.cfg
audio_driver = "alsa"
audio_device = "plughw:0,3"
audio_sync = "true"
audio_latency = "64"

# Keyboard fallback bindings (NO hotkey required — escape exits immediately)
input_menu_toggle_key = "f1"
input_exit_emulator_key = "escape"
input_save_state_key = "f3"
input_load_state_key = "f4"
input_state_slot_decrease_key = "f5"
input_state_slot_increase_key = "f6"

# Keyboard gameplay fallbacks
input_a_key = "x"
input_b_key = "z"
input_start_key = "enter"
input_select_key = "right_shift"
input_up_key = "up"
input_down_key = "down"
input_left_key = "left"
input_right_key = "right"
input_l_key = "q"
input_r_key = "w"
APPENDCFG

# === Create RetroArch wrapper ===
cat > "$ROOTFS/usr/local/bin/retroarch-wrapper.sh" << 'WRAPPER'
#!/bin/bash
# PS4 RetroBox RetroArch wrapper
# - Shows launching.png via fbi (runs as ROOT for /dev/tty7 access, full-screen -a)
# - KMS retry loop
# - HDMI recovery on exit
# - ALSA audio (no PulseAudio dependency — PA daemon dies between launches)

trap "" HUP
mkdir -p /tmp/runtime-PS4 && chmod 700 /tmp/runtime-PS4

export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/amdgpu_shim.so
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
export XDG_RUNTIME_DIR=/run/user/1000
export MESA_NO_ERROR=1
export XKB_CONFIG_ROOT=/usr/share/X11/xkb
export vblank_mode=2
export __GL_SYNC_TO_VBLANK=1

# Show launching image (ROOT, full-screen with -a)
ROM_PATH="$*"
SYS_DIR=$(echo "$ROM_PATH" | grep -oE '/ROMS/[^/ ]+' | head -1 | sed 's|/ROMS/||')
LAUNCH_IMG="/home/PS4/.emulationstation/downloaded_images/$SYS_DIR/launching.png"
if [ -f "$LAUNCH_IMG" ]; then
    sudo fbi -T 7 -d /dev/fb0 -a -t 4 -noverbose -1 "$LAUNCH_IMG" 2>/dev/null &
    FBI_PID=$!
    sleep 3
    sudo kill $FBI_PID 2>/dev/null
    sleep 1
    sudo dd if=/dev/zero of=/dev/fb0 bs=8294400 count=1 2>/dev/null
fi

# KMS retry loop
MAX_RETRIES=5
RETRY=0
while [ $RETRY -lt $MAX_RETRIES ]; do
    /usr/bin/retroarch --verbose --appendconfig=/home/PS4/.config/retroarch/retroarch-ps4.cfg "$@" > /tmp/retroarch.log 2>&1
    RC=$?
    if grep -q "KMS.*Error when switching mode" /tmp/retroarch.log 2>/dev/null; then
        RETRY=$((RETRY+1))
        echo "PS4" | sudo -S killall -9 retroarch 2>/dev/null
        sleep 5
    else
        break
    fi
done

# HDMI recovery on exit — do NOT restart es-session, ES is already running
sleep 1
echo "PS4" | sudo -S killall -9 retroarch 2>/dev/null
sleep 1
echo "PS4" | sudo -S modetest -s HDMI-A-1:1920x1080 2>/dev/null
exit $RC
WRAPPER
chmod +x "$ROOTFS/usr/local/bin/retroarch-wrapper.sh"

# === Build and install hdmi-recover (DRM DPMS Off→On cycle for HDMI re-sync) ===
echo "=== Building hdmi-recover ==="
gcc -O2 -I/usr/include/libdrm -o "$ROOTFS/usr/local/bin/hdmi-recover" hdmi-recover.c -ldrm 2>/dev/null || echo "WARN: hdmi-recover compile failed"
chmod +x "$ROOTFS/usr/local/bin/hdmi-recover" 2>/dev/null

# === HDMI autorecover daemon (periodic recovery every 5 minutes) ===
cat > "$ROOTFS/usr/local/bin/hdmi-autorecover.sh" << 'HDMIAUTO'
#!/bin/bash
# Smart HDMI recovery: monitors HDMI audio ELD for TV power-cycle detection
# ELD=524 when TV on, ELD=0 when TV off. Triggers recovery on TV power-ON.
ELD_FILE="/proc/asound/card0/eld#0.0"
PREV_ELD=""
while true; do
    sleep 3
    ELD_SIZE=$(cat "$ELD_FILE" 2>/dev/null | wc -c)
    if [ "$ELD_SIZE" != "0" ] && [ "$PREV_ELD" = "0" ]; then
        /usr/local/bin/hdmi-recover.sh >/dev/null 2>&1
    fi
    PREV_ELD="$ELD_SIZE"
done
HDMIAUTO
chmod +x "$ROOTFS/usr/local/bin/hdmi-autorecover.sh"

# === Build and install ds4-bridge (DS4 js0→uinput button bridge) ===
echo "=== Building ds4-bridge ==="
gcc -O2 -o "$ROOTFS/usr/local/bin/ds4-bridge" ds4-bridge.c 2>/dev/null || echo "WARN: ds4-bridge compile failed (host gcc needed)"
chmod +x "$ROOTFS/usr/local/bin/ds4-bridge" 2>/dev/null

# === Build and install hdmi-force (forces HDMI PHY re-init) ===
echo "=== Building hdmi-force ==="
gcc -O2 -I/usr/include/libdrm -o "$ROOTFS/usr/local/bin/hdmi-force" hdmi-force.c -ldrm 2>/dev/null || echo "WARN: hdmi-force compile failed"
chmod +x "$ROOTFS/usr/local/bin/hdmi-force" 2>/dev/null

# === HDMI watchdog + recovery scripts ===
cat > "$ROOTFS/usr/local/bin/hdmi-recover.sh" << 'HDMIRECOVER'
#!/bin/bash
systemctl stop es-session 2>/dev/null
killall -9 emulationstation 2>/dev/null
sleep 2
/usr/local/bin/hdmi-force 2>&1
sleep 2
systemctl start es-session 2>/dev/null
HDMIRECOVER
chmod +x "$ROOTFS/usr/local/bin/hdmi-recover.sh"

cat > "$ROOTFS/usr/local/bin/hdmi-watchdog.sh" << 'HDMIWATCHDOG'
#!/bin/bash
PREV_EDID=""
while true; do
    EDID=$(cat /sys/class/drm/card0-HDMI-A-1/edid 2>/dev/null | wc -c)
    STATUS=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null)
    if [ "$STATUS" = "connected" ] && [ "$EDID" = "0" ] && [ "$PREV_EDID" != "0" ]; then
        /usr/local/bin/hdmi-recover.sh >/dev/null 2>&1
        sleep 15
    fi
    PREV_EDID="$EDID"
    sleep 3
done
HDMIWATCHDOG
chmod +x "$ROOTFS/usr/local/bin/hdmi-watchdog.sh"

mkdir -p "$ROOTFS/etc/systemd/system"
cat > "$ROOTFS/etc/systemd/system/ds4-bridge.service" << 'BRIDGESVC'
[Unit]
Description=DS4 Button Bridge
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ds4-bridge
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
BRIDGESVC

cat > "$ROOTFS/etc/systemd/system/hdmi-watchdog.service" << 'HDMISVC'
[Unit]
Description=HDMI Signal Watchdog
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hdmi-watchdog.sh
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
HDMISVC

# === DS4 bridge autoconfig for RetroArch ===
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/autoconfig"
cp autoconfig.cfg "$ROOTFS/home/PS4/.config/retroarch/autoconfig/PS4 DS4 Bridge Joystick.cfg"

# === Create N64 core options (optimized for PS4 base) ===
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/config/Mupen64Plus-Next"
cat > "$ROOTFS/home/PS4/.config/retroarch/config/Mupen64Plus-Next/Mupen64Plus-Next.opt" << 'N64OPT'
mupen64plus-rdp-plugin = "gliden64"
mupen64plus-rsp-plugin = "hle"
mupen64plus-cpucore = "dynamic_recompiler"
mupen64plus-Framerate = "Original"
mupen64plus-43screensize = "320x240"
mupen64plus-169screensize = "640x360"
mupen64plus-aspect = "4:3"
mupen64plus-EnableFBEmulation = "True"
mupen64plus-EnableCopyColorToRDRAM = "Off"
mupen64plus-EnableCopyDepthToRDRAM = "Off"
mupen64plus-ThreadedRenderer = "True"
N64OPT

# === Create PSX core options (Beetle PSX — dynarec, overclocks, analog calibration) ===
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/config/Beetle PSX"
cat > "$ROOTFS/home/PS4/.config/retroarch/config/Beetle PSX/Beetle PSX.opt" << 'PSXOPT'
beetle_psx_cpu_freq_scale = "110%"
beetle_psx_cpu_dynarec = "execute"
beetle_psx_dynarec_invalidate = "full"
beetle_psx_dynarec_op_cycles = "2"
beetle_psx_dynarec_eventcycles = "128"
beetle_psx_dynarec_spgp_opt = "disabled"
beetle_psx_dynarec_spu_samples = "1"
beetle_psx_cd_access_method = "precache"
beetle_psx_cd_fastload = "4x(native)"
beetle_psx_gte_overclock = "enabled"
beetle_psx_gpu_overclock = "2x(native)"
beetle_psx_dither_mode = "disabled"
beetle_psx_crop_overscan = "smart"
beetle_psx_internal_resolution = "1x(native)"
beetle_psx_aspect_ratio = "corrected"
beetle_psx_region = "ntsc"
beetle_psx_display_internal_fps = "disabled"
beetle_psx_draw_frontend_borders = "disabled"
beetle_psx_enable_og_sce_audio = "disabled"
beetle_psx_analog_calibration = "enabled"
PSXOPT
chmod 444 "$ROOTFS/home/PS4/.config/retroarch/config/Beetle PSX/Beetle PSX.opt"

# === Create DS4 USB polling reduction rule ===
mkdir -p "$ROOTFS/etc/udev/rules.d"
cat > "$ROOTFS/etc/udev/rules.d/99-ps4-usb-poll.rules" << 'UDEVPOLL'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="054c", ATTR{idProduct}=="09cc", TEST=="*/ep_*/interval", ATTR*/ep_*/interval="8"
UDEVPOLL

# === Create DS4 autoconfig profile ===
mkdir -p "$ROOTFS/usr/share/retroarch/assets/autoconfig/udev"
cat > "$ROOTFS/usr/share/retroarch/assets/autoconfig/udev/Wireless_Controller.cfg" << 'DS4CFG'
input_driver = "udev"
input_device = "Sony Interactive Entertainment Wireless Controller"
input_vendor_id = "1356"
input_product_id = "2508"
input_a_btn = "1"
input_b_btn = "0"
input_x_btn = "3"
input_y_btn = "2"
input_start_btn = "6"
input_select_btn = "4"
input_l_btn = "9"
input_r_btn = "10"
input_l2_axis = "-4"
input_r2_axis = "+5"
input_l3_btn = "7"
input_r3_btn = "8"
input_guide_btn = "12"
input_up_btn = "h0up"
input_down_btn = "h0down"
input_left_btn = "h0left"
input_right_btn = "h0right"
input_l_x_plus_axis = "+0"
input_l_x_minus_axis = "-0"
input_l_y_plus_axis = "+1"
input_l_y_minus_axis = "-1"
input_r_x_plus_axis = "+3"
input_r_x_minus_axis = "-3"
input_r_y_plus_axis = "+4"
input_r_y_minus_axis = "-4"
input_enable_hotkey_btn = "12"
input_exit_emulator_btn = "6"
input_menu_toggle_btn = "3"
input_save_state_btn = "5"
input_load_state_btn = "4"
input_save_state_btn = "5"
input_state_slot_decrease_btn = "h0left"
input_state_slot_increase_btn = "h0right"
input_reset_btn = "1"
input_screenshot_btn = "2"
input_hold_fast_forward_btn = "14"
input_rewind_btn = "13"
DS4CFG

# === Configure EmulationStation ===
cat > "$ROOTFS/home/PS4/.emulationstation/es_systems.cfg" << 'ESCFG'
<?xml version="1.0"?>
<systemList>
  <system>
    <name>snes</name>
    <fullname>Super Nintendo</fullname>
    <path>/home/PS4/ROMS/snes</path>
    <extension>.sfc .smc .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/snes9x_libretro.so %ROM%</command>
    <platform>snes</platform>
    <theme>snes</theme>
  </system>
  <system>
    <name>nes</name>
    <fullname>Nintendo Entertainment System</fullname>
    <path>/home/PS4/ROMS/nes</path>
    <extension>.nes .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/nestopia_libretro.so %ROM%</command>
    <platform>nes</platform>
    <theme>nes</theme>
  </system>
  <system>
    <name>n64</name>
    <fullname>Nintendo 64</fullname>
    <path>/home/PS4/ROMS/n64</path>
    <extension>.n64 .z64 .v64 .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mupen64plus_next_libretro.so %ROM%</command>
    <platform>n64</platform>
    <theme>n64</theme>
  </system>
  <system>
    <name>gba</name>
    <fullname>Game Boy Advance</fullname>
    <path>/home/PS4/ROMS/gba</path>
    <extension>.gba .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mgba_libretro.so %ROM%</command>
    <platform>gba</platform>
    <theme>gba</theme>
  </system>
  <system>
    <name>gb</name>
    <fullname>Game Boy</fullname>
    <path>/home/PS4/ROMS/gb</path>
    <extension>.gb .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/gambatte_libretro.so %ROM%</command>
    <platform>gb</platform>
    <theme>gb</theme>
  </system>
  <system>
    <name>gbc</name>
    <fullname>Game Boy Color</fullname>
    <path>/home/PS4/ROMS/gbc</path>
    <extension>.gbc .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/gambatte_libretro.so %ROM%</command>
    <platform>gbc</platform>
    <theme>gbc</theme>
  </system>
  <system>
    <name>megadrive</name>
    <fullname>Sega Mega Drive</fullname>
    <path>/home/PS4/ROMS/megadrive</path>
    <extension>.md .bin .gen .smd .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>megadrive</platform>
    <theme>megadrive</theme>
  </system>
  <system>
    <name>psx</name>
    <fullname>Sony PlayStation</fullname>
    <path>/home/PS4/ROMS/psx</path>
    <extension>.bin .cue .iso .pbp .chd .m3u .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_psx_libretro.so %ROM%</command>
    <platform>psx</platform>
    <theme>psx</theme>
  </system>
  <system>
    <name>tg16</name>
    <fullname>TurboGrafx-16</fullname>
    <path>/home/PS4/ROMS/tg16</path>
    <extension>.pce .cue .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_pce_fast_libretro.so %ROM%</command>
    <platform>tg16</platform>
    <theme>tg16</theme>
  </system>
  <system>
    <name>tgcd</name>
    <fullname>TurboGrafx-CD</fullname>
    <path>/home/PS4/ROMS/tgcd</path>
    <extension>.chd .cue .iso .m3u</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_pce_fast_libretro.so %ROM%</command>
    <platform>tgcd</platform>
    <theme>tgcd</theme>
  </system>
  <system>
    <name>arcade</name>
    <fullname>Arcade</fullname>
    <path>/home/PS4/ROMS/arcade</path>
    <extension>.zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/fbneo_libretro.so %ROM%</command>
    <platform>arcade</platform>
    <theme>arcade</theme>
  </system>
  <system>
    <name>neogeo</name>
    <fullname>Neo Geo</fullname>
    <path>/home/PS4/ROMS/neogeo</path>
    <extension>.zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/fbneo_libretro.so %ROM%</command>
    <platform>neogeo</platform>
    <theme>neogeo</theme>
  </system>
  <system>
    <name>atari2600</name>
    <fullname>Atari 2600</fullname>
    <path>/home/PS4/ROMS/atari2600</path>
    <extension>.a26 .bin .rom .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/stella_libretro.so %ROM%</command>
    <platform>atari2600</platform>
    <theme>atari2600</theme>
  </system>
  <system>
    <name>atari5200</name>
    <fullname>Atari 5200</fullname>
    <path>/home/PS4/ROMS/atari5200</path>
    <extension>.a52 .bin .xfd .atari .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/atari800_libretro.so %ROM%</command>
    <platform>atari5200</platform>
    <theme>atari5200</theme>
  </system>
  <system>
    <name>atari7800</name>
    <fullname>Atari 7800</fullname>
    <path>/home/PS4/ROMS/atari7800</path>
    <extension>.a78 .bin .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/prosystem_libretro.so %ROM%</command>
    <platform>atari7800</platform>
    <theme>atari7800</theme>
  </system>
  <system>
    <name>mastersystem</name>
    <fullname>Sega Master System</fullname>
    <path>/home/PS4/ROMS/mastersystem</path>
    <extension>.sms .bin .gen .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>mastersystem</platform>
    <theme>mastersystem</theme>
  </system>
  <system>
    <name>gamegear</name>
    <fullname>Sega Game Gear</fullname>
    <path>/home/PS4/ROMS/gamegear</path>
    <extension>.gg .bin .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>gamegear</platform>
    <theme>gamegear</theme>
  </system>
  <system>
    <name>famicom</name>
    <fullname>Nintendo Famicom</fullname>
    <path>/home/PS4/ROMS/famicom</path>
    <extension>.nes .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/nestopia_libretro.so %ROM%</command>
    <platform>famicom</platform>
    <theme>famicom</theme>
  </system>
  <system>
    <name>fds</name>
    <fullname>Nintendo Famicom Disk System</fullname>
    <path>/home/PS4/ROMS/fds</path>
    <extension>.fds .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mesen_libretro.so %ROM%</command>
    <platform>fds</platform>
    <theme>fds</theme>
  </system>
  <system>
    <name>genesis</name>
    <fullname>Sega Genesis</fullname>
    <path>/home/PS4/ROMS/genesis</path>
    <extension>.md .bin .gen .smd .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>genesis</platform>
    <theme>genesis</theme>
  </system>
  <system>
    <name>sfc</name>
    <fullname>Super Famicom</fullname>
    <path>/home/PS4/ROMS/sfc</path>
    <extension>.sfc .smc .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/snes9x_libretro.so %ROM%</command>
    <platform>sfc</platform>
    <theme>sfc</theme>
  </system>
  <system>
    <name>segacd</name>
    <fullname>Sega CD</fullname>
    <path>/home/PS4/ROMS/segacd</path>
    <extension>.bin .cue .iso .chd .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>segacd</platform>
    <theme>segacd</theme>
  </system>
  <system>
    <name>mega-cd</name>
    <fullname>Mega CD</fullname>
    <path>/home/PS4/ROMS/mega-cd</path>
    <extension>.bin .cue .iso .chd .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>mega-cd</platform>
    <theme>segacd</theme>
  </system>
  <system>
    <name>sega32x</name>
    <fullname>Sega 32X</fullname>
    <path>/home/PS4/ROMS/sega32x</path>
    <extension>.32x .bin .smd .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/picodrive_libretro.so %ROM%</command>
    <platform>sega32x</platform>
    <theme>sega32x</theme>
  </system>
  <system>
    <name>wonderswan</name>
    <fullname>Bandai WonderSwan</fullname>
    <path>/home/PS4/ROMS/wonderswan</path>
    <extension>.ws .wsc .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_wswan_libretro.so %ROM%</command>
    <platform>wonderswan</platform>
    <theme>wonderswan</theme>
  </system>
  <system>
    <name>wonderswancolor</name>
    <fullname>Bandai WonderSwan Color</fullname>
    <path>/home/PS4/ROMS/wonderswancolor</path>
    <extension>.wsc .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_wswan_libretro.so %ROM%</command>
    <platform>wonderswancolor</platform>
    <theme>wonderswancolor</theme>
  </system>
  <system>
    <name>atarijaguar</name>
    <fullname>Atari Jaguar</fullname>
    <path>/home/PS4/ROMS/atarijaguar</path>
    <extension>.j64 .jag .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/virtualjaguar_libretro.so %ROM%</command>
    <platform>atarijaguar</platform>
    <theme>atarijaguar</theme>
  </system>
  <system>
    <name>atarilynx</name>
    <fullname>Atari Lynx</fullname>
    <path>/home/PS4/ROMS/atarilynx</path>
    <extension>.lnx .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_lynx_libretro.so %ROM%</command>
    <platform>atarilynx</platform>
    <theme>atarilynx</theme>
  </system>
  <system>
    <name>colecovision</name>
    <fullname>ColecoVision</fullname>
    <path>/home/PS4/ROMS/colecovision</path>
    <extension>.col .bin .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/gearcoleco_libretro.so %ROM%</command>
    <platform>colecovision</platform>
    <theme>colecovision</theme>
  </system>
  <system>
    <name>gameandwatch</name>
    <fullname>Game and Watch</fullname>
    <path>/home/PS4/ROMS/gameandwatch</path>
    <extension>.gw .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/gw_libretro.so %ROM%</command>
    <platform>gameandwatch</platform>
    <theme>gameandwatch</theme>
  </system>
  <system>
    <name>ngp</name>
    <fullname>SNK Neo Geo Pocket</fullname>
    <path>/home/PS4/ROMS/ngp</path>
    <extension>.ngp .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_ngp_libretro.so %ROM%</command>
    <platform>ngp</platform>
    <theme>ngp</theme>
  </system>
  <system>
    <name>ngpc</name>
    <fullname>SNK Neo Geo Pocket Color</fullname>
    <path>/home/PS4/ROMS/ngpc</path>
    <extension>.ngc .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_ngp_libretro.so %ROM%</command>
    <platform>ngpc</platform>
    <theme>ngpc</theme>
  </system>
  <system>
    <name>psp</name>
    <fullname>Sony PlayStation Portable</fullname>
    <path>/home/PS4/ROMS/psp</path>
    <extension>.iso .cso .pbp .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/ppsspp_libretro.so %ROM%</command>
    <platform>psp</platform>
    <theme>psp</theme>
  </system>
  <system>
    <name>sg-1000</name>
    <fullname>Sega SG-1000</fullname>
    <path>/home/PS4/ROMS/sg-1000</path>
    <extension>.sg .bin .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/gearsystem_libretro.so %ROM%</command>
    <platform>sg-1000</platform>
    <theme>sg-1000</theme>
  </system>
  <system>
    <name>supergrafx</name>
    <fullname>NEC SuperGrafx</fullname>
    <path>/home/PS4/ROMS/supergrafx</path>
    <extension>.pce .sg .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_supergrafx_libretro.so %ROM%</command>
    <platform>supergrafx</platform>
    <theme>supergrafx</theme>
  </system>
  <system>
    <name>virtualboy</name>
    <fullname>Nintendo Virtual Boy</fullname>
    <path>/home/PS4/ROMS/virtualboy</path>
    <extension>.vb .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_vb_libretro.so %ROM%</command>
    <platform>virtualboy</platform>
    <theme>virtualboy</theme>
  </system>
  <system>
    <name>channelf</name>
    <fullname>Fairchild Channel F</fullname>
    <path>/home/PS4/ROMS/channelf</path>
    <extension>.chf .bin .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/freechaf_libretro.so %ROM%</command>
    <platform>channelf</platform>
    <theme>channelf</theme>
  </system>
  <system>
    <name>mame-libretro</name>
    <fullname>MAME</fullname>
    <path>/home/PS4/ROMS/mame-libretro</path>
    <extension>.zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/mame2003_plus_libretro.so %ROM%</command>
    <platform>mame-libretro</platform>
    <theme>mame-libretro</theme>
  </system>
  <system>
    <name>vectrex</name>
    <fullname>GCE Vectrex</fullname>
    <path>/home/PS4/ROMS/vectrex</path>
    <extension>.vec .zip</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/vecx_libretro.so %ROM%</command>
    <platform>vectrex</platform>
    <theme>vectrex</theme>
  </system>
  <system>
    <name>dreamcast</name>
    <fullname>Sega Dreamcast</fullname>
    <path>/home/PS4/ROMS/dreamcast</path>
    <extension>.cdi .chd .gdi .iso</extension>
    <command>/usr/local/bin/retroarch-wrapper.sh -L /usr/lib/x86_64-linux-gnu/libretro/flycast_libretro.so %ROM%</command>
    <platform>dreamcast</platform>
    <theme>dreamcast</theme>
  </system>
  <system>
    <name>ps2</name>
    <fullname>Sony PlayStation 2</fullname>
    <path>/home/PS4/ROMS/ps2</path>
    <extension>.iso .bin .img .mdf .nrg .chd .cso .gz</extension>
    <command>bash -c 'LD_PRELOAD=/usr/lib/x86_64-linux-gnu/amdgpu_shim.so MESA_LOADER_DRIVER_OVERRIDE=radeonsi /usr/bin/pcsx2-qt %ROM%'</command>
    <platform>ps2</platform>
    <theme>ps2</theme>
  </system>
  <system>
    <name>gamecube</name>
    <fullname>Nintendo GameCube</fullname>
    <path>/home/PS4/ROMS/gamecube</path>
    <extension>.iso .gcm .rvz .wbfs .ciso .dol</extension>
    <command>bash -c 'DISPLAY=:0 /usr/bin/dolphin-emu-nogui -e %ROM%'</command>
    <platform>gamecube</platform>
    <theme>gamecube</theme>
  </system>
  <system>
    <name>wii</name>
    <fullname>Nintendo Wii</fullname>
    <path>/home/PS4/ROMS/wii</path>
    <extension>.iso .wbfs .ciso .dol .wad .nkit.iso</extension>
    <command>bash -c 'DISPLAY=:0 /usr/bin/dolphin-emu-nogui -e %ROM%'</command>
    <platform>wii</platform>
    <theme>wii</theme>
  </system>
  <system>
    <name>ps4_retrobox</name>
    <fullname>PS4 RetroBox</fullname>
    <path>/usr/local/bin/scripts</path>
    <extension>.sh</extension>
    <command>bash %ROM%</command>
    <platform>settings</platform>
    <theme>ps4_retrobox</theme>
  </system>
</systemList>
ESCFG

# === Create helper scripts for PS4 RetroBox settings system ===
mkdir -p "$ROOTFS/usr/local/bin/scripts"

cat > "$ROOTFS/usr/local/bin/scripts/setup-samba.sh" << 'SAMBA'
#!/bin/bash
echo "=== PS4 RetroBox - Samba Setup ==="
echo "Edit /usr/local/bin/setup-samba.sh to set your PC IP and share name"
echo "Then run: sudo setup-samba.sh --setup"
echo ""
read -p "Press Enter to continue..."
SAMBA

cat > "$ROOTFS/usr/local/bin/scripts/toggle-storage.sh" << 'TOGGLE'
#!/bin/bash
echo "=== PS4 RetroBox - Storage Toggle ==="
echo "Options:"
echo "  1. Switch to UFS (Internal HDD)"
echo "  2. Switch to Samba/Network"
echo "  3. Cancel"
read -p "Choice [1-3]: " CHOICE
case $CHOICE in
    1) echo "Switching to UFS..." && sudo setup-samba.sh --restore 2>/dev/null && echo "Done! Restarting ES..." && sudo systemctl restart es-session.service ;;
    2) echo "Switching to Samba..." && sudo setup-samba.sh --setup 2>/dev/null && echo "Done! Restarting ES..." && sudo systemctl restart es-session.service ;;
    *) echo "Cancelled." ;;
esac
TOGGLE

cat > "$ROOTFS/usr/local/bin/scripts/system-info.sh" << 'SYSINFO'
#!/bin/bash
echo "=== PS4 RetroBox System Info ==="
echo ""
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "Kernel: $(uname -r)"
echo "RAM: $(free -h | awk '/^Mem:/{print $2 " total, " $3 " used"}')"
echo "Disk: $(df -h / | awk 'NR==2{print $2 " total, " $3 " used"}')"
echo "IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "RetroArch: $(retroarch --version 2>&1 | head -1)"
echo "ES: EmulationStation v2.0.1a"
echo ""
echo "Systems: $(grep '<name>' /home/PS4/.emulationstation/es_systems.cfg | grep -v ps4_retrobox | wc -l)"
echo "Cores: $(ls /usr/lib/x86_64-linux-gnu/libretro/*.so 2>/dev/null | wc -l)"
echo "ROMS: $(find /home/PS4/ROMS -type f 2>/dev/null | wc -l) files"
echo ""
read -p "Press Enter to continue..."
SYSINFO

cat > "$ROOTFS/usr/local/bin/scripts/reboot.sh" << 'REBOOT'
#!/bin/bash
echo "Rebooting PS4 in 3 seconds..."
sleep 3
sudo reboot
REBOOT

cat > "$ROOTFS/usr/local/bin/scripts/shutdown.sh" << 'SHUTDOWN'
#!/bin/bash
echo "Shutting down PS4 in 3 seconds..."
sleep 3
sudo shutdown -h now
SHUTDOWN

cat > "$ROOTFS/usr/local/bin/scripts/test-network.sh" << 'NETTEST'
#!/bin/bash
echo "=== Network Test ==="
echo "IP: $(hostname -I | awk '{print $1}')"
echo "Gateway: $(ip route | awk '/default/ {print $3}')"
echo ""
echo "Testing internet..."
ping -c 3 8.8.8.8 2>&1 | tail -3
echo ""
read -p "Press Enter to continue..."
NETTEST

cat > "$ROOTFS/usr/local/bin/scripts/setup-launching-images.sh" << 'IMAGES'
#!/bin/bash
echo "=== Launching Images Setup ==="
echo ""
echo "Place images to show before games launch:"
echo ""
echo "  Per-system:  /home/PS4/.emulationstation/downloaded_images/<system>/launching.png"
echo "  Per-ROM:     /home/PS4/.emulationstation/downloaded_images/<system>/images/<rom>-launching.png"
echo "  Fallback:    /home/PS4/ROMS/<system>/launching.png"
echo ""
echo "Supported formats: PNG, JPG"
echo "Recommended size: 1920x1080"
echo ""
echo "Example for NES:"
echo "  /home/PS4/.emulationstation/downloaded_images/nes/launching.png"
echo "  /home/PS4/.emulationstation/downloaded_images/nes/images/Mega Man-launching.png"
echo ""
echo "Use SCP/SFTP from your PC to upload images:"
echo "  scp my-image.png PS4@<IP>:/home/PS4/.emulationstation/downloaded_images/nes/launching.png"
echo ""
read -p "Press Enter to continue..."
IMAGES

cat > "$ROOTFS/usr/local/bin/scripts/download-bios.sh" << 'DOWNLOADBIOS'
#!/bin/bash
BIOS_DIR="/home/PS4/.config/retroarch/system"
REPO_BASE="https://raw.githubusercontent.com/Abdess/retrobios/main/bios"
info()  { echo "[OK] $1"; }
skip()  { echo "[SKIP] $1"; }
error() { echo "[FAIL] $1"; }
download_file() {
    local url="$1" dest="$2" desc="$3"
    [ -f "$dest" ] && skip "$desc (exists)" && return 0
    mkdir -p "$(dirname "$dest")"
    if curl -fsSL "$url" -o "$dest" 2>/dev/null || wget -qO "$dest" "$url" 2>/dev/null; then
        info "$desc"
    else
        error "$desc"; rm -f "$dest"; return 1
    fi
}
echo "=== PS4 RetroBox - BIOS Downloader ==="
echo "Source: Abdess/retrobios (MIT License)"
echo ""
echo "--- PlayStation ---"
download_file "$REPO_BASE/Sony/PlayStation/scph5500.bin" "$BIOS_DIR/scph5500.bin" "PS BIOS (Japan)"
download_file "$REPO_BASE/Sony/PlayStation/scph5501.bin" "$BIOS_DIR/scph5501.bin" "PS BIOS (US)"
download_file "$REPO_BASE/Sony/PlayStation/scph5502.bin" "$BIOS_DIR/scph5502.bin" "PS BIOS (Europe)"
echo "--- Sega 32X ---"
download_file "$REPO_BASE/Sega/32X/32X_M_BIOS.BIN" "$BIOS_DIR/32X_M_BIOS.BIN" "32X Main BIOS"
download_file "$REPO_BASE/Sega/32X/32X_S_BIOS.BIN" "$BIOS_DIR/32X_S_BIOS.BIN" "32X Slave BIOS"
download_file "$REPO_BASE/Sega/32X/32X_G_BIOS.BIN" "$BIOS_DIR/32X_G_BIOS.BIN" "32X Game BIOS"
echo "--- Atari 5200 ---"
download_file "$REPO_BASE/Atari/5200/5200.rom" "$BIOS_DIR/5200.rom" "Atari 5200 BIOS"
echo "--- TurboGrafx-CD ---"
download_file "$REPO_BASE/NEC/PC%20Engine%20CD/PCECD_3.0-(J).pce" "$BIOS_DIR/syscard3.pce" "TG-CD System Card v3.0"
echo "--- Neo Geo ---"
[ -f "$BIOS_DIR/neogeo.zip" ] && echo "[SKIP] Neo Geo BIOS (already installed)" || download_file "$REPO_BASE/SNK/Neo%20Geo/neogeo.zip" "$BIOS_DIR/neogeo.zip" "Neo Geo BIOS"
echo ""
echo "BIOS files: $BIOS_DIR"
ls -lh "$BIOS_DIR"/*.{bin,rom,pce,zip} 2>/dev/null
echo "Done! Restart RetroArch to use new BIOS files."
DOWNLOADBIOS

cat > "$ROOTFS/usr/local/bin/scripts/rest-mode.sh" << 'RESTMODE'
#!/bin/bash
echo "=== PS4 RetroBox - Rest Mode ==="
echo "Entering rest mode in 3 seconds... (Ctrl+C to cancel)"
sleep 3
sudo systemctl suspend
RESTMODE

cat > "$ROOTFS/usr/local/bin/scripts/led-control.sh" << 'LEDCONTROL'
#!/bin/bash
# DS4 LED Controller via USB HID
# Usage: led-control.sh --color red|green|blue|purple|cyan|yellow|white|off
COLOR="${2:-blue}"
case "$1" in
    --color) ;;
    *) echo "Usage: led-control.sh --color <red|green|blue|purple|cyan|yellow|white|off>"; exit 1 ;;
esac
case "$COLOR" in
    red) R=255; G=0; B=0 ;;
    green) R=0; G=255; B=0 ;;
    blue) R=0; G=0; B=255 ;;
    purple) R=255; G=0; B=255 ;;
    cyan) R=0; G=255; B=255 ;;
    yellow) R=255; G=255; B=0 ;;
    white) R=255; G=255; B=255 ;;
    off) R=0; G=0; B=0 ;;
    *) echo "Unknown color: $COLOR"; exit 1 ;;
esac
python3 -c "
import os
for i in range(4):
    try:
        with open(f'/sys/class/hidraw/hidraw{i}/device/uevent') as f:
            if '054C' in f.read():
                dev = f'/dev/hidraw{i}'
                report = bytes([0x05, 255 if $R+$G+$B>0 else 0, $R, $G, $B, 0, 0, 0])
                with open(dev, 'wb') as d: d.write(report)
                print(f'LED set: R=$R G=$G B=$B on {dev}')
                exit(0)
    except: pass
print('DS4 not found')
"
LEDCONTROL

chmod +x "$ROOTFS/usr/local/bin/scripts/"*.sh

# === Install RetroPie carbon theme ===
echo "=== Installing RetroPie carbon theme ==="

# ES 2.0.1a looks in ~/.emulationstation/themes/ AND /etc/emulationstation/themes/
THEME_DIR="$ROOTFS/etc/emulationstation/themes"
mkdir -p "$THEME_DIR"

# Clone the carbon theme (try user fork first, fall back to RetroPie 2021)
cd /tmp
rm -rf es-theme-carbon
git clone --depth 1 https://github.com/danyboy666/PSRB-es-theme-carbon.git es-theme-carbon 2>/dev/null || \
    git clone --depth 1 https://github.com/RetroPie/es-theme-carbon.git es-theme-carbon 2>/dev/null || \
    echo "Warning: Could not clone carbon theme."

if [ -d "es-theme-carbon" ]; then
    rm -rf "$THEME_DIR/carbon"
    cp -r es-theme-carbon "$THEME_DIR/carbon"
    # Rename theme folders to match es_systems.cfg theme names
    [ -d "$THEME_DIR/carbon/tg-cd" ] && mv "$THEME_DIR/carbon/tg-cd" "$THEME_DIR/carbon/tgcd"
    [ -d "$THEME_DIR/carbon/pcengine" ] && mv "$THEME_DIR/carbon/pcengine" "$THEME_DIR/carbon/tg16"
    [ -d "$THEME_DIR/carbon/gg" ] && mv "$THEME_DIR/carbon/gg" "$THEME_DIR/carbon/gamegear"
    [ -d "$THEME_DIR/carbon/sms" ] && mv "$THEME_DIR/carbon/sms" "$THEME_DIR/carbon/mastersystem"
    # Symlinks for systems that share a theme with another name
    [ -d "$THEME_DIR/carbon/segacd" ] && [ ! -e "$THEME_DIR/carbon/mega-cd" ] && ln -sf segacd "$THEME_DIR/carbon/mega-cd"
    [ -d "$THEME_DIR/carbon/snes" ] && [ ! -e "$THEME_DIR/carbon/sfc" ] && ln -sf snes "$THEME_DIR/carbon/sfc"
    [ -d "$THEME_DIR/carbon/superfamicom" ] && [ ! -e "$THEME_DIR/carbon/sfc" ] && ln -sf superfamicom "$THEME_DIR/carbon/sfc"
    echo "Theme installed: $THEME_DIR/carbon"
    _file_count=$(find "$THEME_DIR/carbon" -type f | wc -l)
    echo "Theme: $_file_count files (SVGs and PNGs kept as-is)"
else
    echo "ERROR: carbon theme clone failed"
    exit 1
fi

# === Create ps4_retrobox theme for ES carousel (AFTER theme install) ===
mkdir -p "$THEME_DIR/carbon/ps4_retrobox/art"
cat > "$THEME_DIR/carbon/ps4_retrobox/theme.xml" << 'THEME'
<?xml version="1.0"?>
<theme>
    <formatVersion>3</formatVersion>
    <include>./../carbon.xml</include>

    <view name="system">
        <image name="logo">
            <path>./art/system.svg</path>
        </image>
    </view>

    <view name="basic, detailed, video">
        <image name="logo">
            <path>./art/system.svg</path>
            <pos>0.266 0.074</pos>
            <maxSize>0.460 0.126</maxSize>
            <origin>0.5 0.5</origin>
        </image>
    </view>
</theme>
THEME

chown -R 1000:1000 "$THEME_DIR/carbon/ps4_retrobox"
chmod -R 775 "$THEME_DIR/carbon/ps4_retrobox"
chmod 755 "$ROOTFS/etc/emulationstation"
chmod 755 "$ROOTFS/etc/emulationstation/themes"
chmod 755 "$THEME_DIR/carbon"

# Create symlink from user themes dir (ES checks both paths)
mkdir -p "$ROOTFS/home/PS4/.emulationstation"
ln -sf /etc/emulationstation/themes "$ROOTFS/home/PS4/.emulationstation/themes"

echo "Theme: carbon (RetroPie, formatVersion=3)"

chown -R 1000:1000 "$ROOTFS/home/PS4"

# === systemd service: fix UFS permissions at boot ===
cat > "$ROOTFS/etc/systemd/system/fix-ufs-permissions.service" << 'UFSPERM'
[Unit]
Description=Fix UFS permissions for PS4 user
After=local-fs.target
Before=es-session.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'chown 1000:1000 /ps4hdd/home/ 2>/dev/null; chmod 777 /ps4hdd/home/ 2>/dev/null; chown 1000:1000 /ps4hdd/home/*.img 2>/dev/null; chmod 666 /ps4hdd/home/*.img 2>/dev/null; if [ -d /ps4hdd/ROMS ]; then chown -R 1000:1000 /ps4hdd/ROMS 2>/dev/null; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UFSPERM
ln -sf /etc/systemd/system/fix-ufs-permissions.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/fix-ufs-permissions.service" 2>/dev/null || true
echo "Systemd service: fix-ufs-permissions"

# === Remove unneeded cores and info files ===
echo "=== Cleaning up unneeded cores ==="
LIBRETRO_DIR="$ROOTFS/usr/lib/x86_64-linux-gnu/libretro"
rm -f "$LIBRETRO_DIR/desmume_libretro.so" "$LIBRETRO_DIR/desmume.libretro"
rm -f "$LIBRETRO_DIR/vice_x64_libretro.so" "$LIBRETRO_DIR/vice_x64.libretro"
echo "Remaining cores: $(ls "$LIBRETRO_DIR"/*.so 2>/dev/null | wc -l)"

# Remove unneeded .info files — keep only what we use
INFO_DIR="$ROOTFS/usr/share/libretro/info"
KEEP_INFO="bsnes_mercury_balanced_libretro.info snes9x_libretro.info fbneo_libretro.info gambatte_libretro.info genesis_plus_gx_libretro.info mednafen_pce_fast_libretro.info mednafen_psx_libretro.info mgba_libretro.info mupen64plus_next_libretro.info nestopia_libretro.info prosystem_libretro.info stella_libretro.info atari800_libretro.info mesen_libretro.info picodrive_libretro.info mednafen_wswan_libretro.info virtualjaguar_libretro.info mednafen_lynx_libretro.info gearcoleco_libretro.info gw_libretro.info mednafen_ngp_libretro.info ppsspp_libretro.info gearsystem_libretro.info mednafen_supergrafx_libretro.info mednafen_vb_libretro.info freechaf_libretro.info mame2003_plus_libretro.info vecx_libretro.info"
cd "$INFO_DIR"
for f in *.info; do
    if ! echo "$KEEP_INFO" | grep -qw "$f"; then
        rm -f "$f"
    fi
done
echo "Remaining info files: $(ls "$INFO_DIR"/*.info 2>/dev/null | wc -l)"

# === Install Plymouth es-logo splash theme ===
echo "=== Installing Plymouth es-logo theme ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq plymouth plymouth-themes" 2>/dev/null
mkdir -p "$ROOTFS/usr/share/plymouth/themes/es-logo"
cp "$SCRIPT_DIR/usr/share/plymouth/themes/es-logo/"* "$ROOTFS/usr/share/plymouth/themes/es-logo/" 2>/dev/null || true
cp "$SCRIPT_DIR/usr/share/plymouth/themes/default.plymouth" "$ROOTFS/usr/share/plymouth/themes/default.plymouth" 2>/dev/null || true
run_chroot "update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/es-logo/es-logo.plymouth 100" 2>/dev/null || true
run_chroot "update-alternatives --set default.plymouth /usr/share/plymouth/themes/es-logo/es-logo.plymouth" 2>/dev/null || true
run_chroot "update-initramfs -u" 2>/dev/null || true
echo "Plymouth theme: es-logo"

# === Remove build dependencies (after all compilation is done) ===
echo "=== Removing build dependencies ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get purge -y build-essential cmake nasm 2>/dev/null" || true
run_chroot "rm -rf /usr/include" 2>/dev/null
run_chroot "rm -rf /usr/share/icons" 2>/dev/null
run_chroot "rm -rf /usr/share/cmake-3.28" 2>/dev/null
run_chroot "rm -rf /usr/share/pocketsphinx" 2>/dev/null
run_chroot "rm -rf /usr/lib/git-core" 2>/dev/null
run_chroot "rm -rf /usr/share/devhelp" 2>/dev/null

# === Remove unnecessary files from rootfs ===
echo "=== Cleaning rootfs bloat ==="
run_chroot "rm -rf /usr/share/libretro/assets/wallpapers" 2>/dev/null
run_chroot "rm -f /usr/lib/x86_64-linux-gnu/libvulkan_*.so" 2>/dev/null
run_chroot "find /usr/lib/x86_64-linux-gnu -name '*.a' -delete" 2>/dev/null
run_chroot "find /usr/lib/gcc -name '*.a' -delete" 2>/dev/null
run_chroot "rm -rf /usr/share/X11/app-defaults /usr/share/X11/locale /usr/share/X11/rgb.txt" 2>/dev/null
run_chroot "rm -rf /usr/share/ghostscript" 2>/dev/null
run_chroot "rm -rf /usr/share/mime" 2>/dev/null
run_chroot "rm -rf /usr/share/bash-completion" 2>/dev/null
run_chroot "rm -rf /usr/share/iso-codes" 2>/dev/null
run_chroot "rm -rf /usr/share/bug" 2>/dev/null
run_chroot "rm -rf /usr/share/info" 2>/dev/null
run_chroot "rm -rf /usr/share/directfb-1.7*" 2>/dev/null
run_chroot "rm -rf /usr/share/tcltk" 2>/dev/null
run_chroot "rm -rf /usr/share/libretro/assets/branding" 2>/dev/null
run_chroot "rm -rf /usr/share/libretro/assets/xmb/dot-art /usr/share/libretro/assets/xmb/systematic /usr/share/libretro/assets/xmb/flatui /usr/share/libretro/assets/xmb/daite /usr/share/libretro/assets/xmb/flatux /usr/share/libretro/assets/xmb/retrosystem /usr/share/libretro/assets/xmb/automatic /usr/share/libretro/assets/xmb/monochrome/README.md" 2>/dev/null
run_chroot "rm -rf /usr/share/libretro/assets/ozone" 2>/dev/null
run_chroot "rm -rf /usr/share/libretro/assets/rgui" 2>/dev/null
run_chroot "rm -rf /usr/share/libretro/assets/glui" 2>/dev/null
run_chroot "rm -f /var/log/dpkg.log /var/log/apt/term.log /var/log/bootstrap.log /var/log/apt/history.log" 2>/dev/null
run_chroot "rm -rf /var/cache/apt/archives/*.deb" 2>/dev/null
run_chroot "rm -rf /usr/share/doc /usr/share/man /usr/share/info" 2>/dev/null
run_chroot "rm -rf /usr/share/locale" 2>/dev/null
run_chroot "find /usr/share/i18n -mindepth 1 -maxdepth 1 ! -name 'charmaps' ! -name 'locales' -exec rm -rf {} +" 2>/dev/null
echo "Rootfs bloat cleaned"

# === Re-generate locale after cleanup (locale-gen needs charmaps + locales source) ===
echo "=== Regenerating locale ==="
run_chroot "sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true"
run_chroot "locale-gen en_US.UTF-8" 2>/dev/null
run_chroot "update-locale LANG=en_US.UTF-8" 2>/dev/null
echo "Locale regenerated"

# === Cleanup ===
echo "=== Cleaning up ==="
# Save modetest before autoremove (it removes libdrm-tests)
echo "modetest before cleanup: $(ls "$ROOTFS/usr/bin/modetest" 2>/dev/null || echo MISSING)"
cp "$ROOTFS/usr/bin/modetest" /tmp/modetest-backup 2>/dev/null
echo "modetest backup: $(ls -la /tmp/modetest-backup 2>/dev/null || echo MISSING)"
run_chroot "apt-get autoremove -y && apt-get clean"
run_chroot "rm -rf /var/lib/apt/lists/* /var/tmp/*"
# Restore modetest
cp /tmp/modetest-backup "$ROOTFS/usr/bin/modetest" 2>/dev/null
chmod +x "$ROOTFS/usr/bin/modetest" 2>/dev/null
rm -f /tmp/modetest-backup
# Verify
echo "xkb symbols: $(ls "$ROOTFS/usr/share/X11/xkb/symbols/" 2>/dev/null | wc -l)"
echo "modetest after: $(ls "$ROOTFS/usr/bin/modetest" 2>/dev/null || echo MISSING)"

# === Unmount pseudo-filesystems ===
for fs in tmp run dev/pts dev sys proc; do
    umount "$ROOTFS/$fs" 2>/dev/null || true
done

# === Package rootfs as arch.tar.xz ===
echo "=== Packaging rootfs ==="
mkdir -p "$SCRIPT_DIR/community-files"
tar -cJf "$SCRIPT_DIR/community-files/arch.tar.xz" -C "$ROOTFS" \
    --exclude='./proc' --exclude='./sys' --exclude='./run' \
    --exclude='./dev' --exclude='./tmp' .

# === Rebuild initramfs from known-good source directories ===
echo "=== Rebuilding initramfs ==="
bash "$SCRIPT_DIR/scripts/build-initramfs.sh"

echo ""
echo "=== Build complete! ==="
echo "Files in community-files/:"
echo "  arch.tar.xz          $(du -h community-files/arch.tar.xz | cut -f1)  (Ubuntu rootfs)"
echo "  initramfs.cpio.gz    $(du -h community-files/initramfs.cpio.gz 2>/dev/null | cut -f1 || echo 'missing')  (with Plymouth splash)"
echo "  bzImage*             (kernel - already in community-files)"
echo "  payload-960-*.elf    (payloads - already in community-files)"
echo ""
echo "FTP these 3 files to your PS4:"
echo "  1. bzImage*           -> /data/linux/boot/bzImage"
echo "  2. initramfs.cpio.gz  -> /data/linux/boot/initramfs.cpio.gz"
echo "  3. arch.tar.xz        -> /user/system/boot/arch.tar.xz"
echo ""
echo "Then boot: send 1GB payload -> exec install-HDD.sh -> enter 32"
echo "After boot: sudo nano /usr/local/bin/setup-samba.sh -> sudo setup-samba.sh"

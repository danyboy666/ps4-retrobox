#!/bin/bash
# No set -e — we handle errors explicitly to avoid silent build failures

ROOTFS="/mnt/ps4root"
REPO="danyboy666/ps4-retrobox"

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
    libdrm-tests plymouth plymouth-themes"

# === Install EmulationStation build deps ===
echo "=== Installing EmulationStation build deps ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libsdl2-dev libboost-system-dev libboost-filesystem-dev \
    libboost-date-time-dev libboost-locale-dev libfreeimage-dev \
    libfreetype6-dev libeigen3-dev libcurl4-openssl-dev \
    libasound2-dev libgl1-mesa-dev build-essential cmake"

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

# === Download missing libretro cores from buildbot ===
echo "=== Downloading missing libretro cores ==="
LIBRETRO_DIR="$ROOTFS/usr/lib/x86_64-linux-gnu/libretro"
BUILDBOT="https://buildbot.libretro.com/nightly/linux/x86_64/latest"
for core in nestopia fbneo stella prosystem; do
    echo "  Downloading ${core}_libretro.so..."
    wget -q -O "$LIBRETRO_DIR/${core}_libretro.so.zip" "$BUILDBOT/${core}_libretro.so.zip" 2>/dev/null && \
        cd "$LIBRETRO_DIR" && unzip -o "${core}_libretro.so.zip" 2>/dev/null && \
        rm -f "${core}_libretro.so.zip" && \
        echo "    OK: ${core}_libretro.so" || \
        echo "    FAILED: ${core}_libretro.so"
done
chmod 644 "$LIBRETRO_DIR"/*.so 2>/dev/null
echo "Libretro cores: $(ls "$LIBRETRO_DIR"/*.so 2>/dev/null | wc -l) total"

# === Install extras ===
echo "=== Installing extras ==="
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    joystick jstest-gtk evtest ffmpeg netpbm"

# === Compile EmulationStation ===
echo "=== Compiling EmulationStation ==="
run_chroot "cd /tmp && rm -rf ES-build && git clone https://github.com/Aloshi/EmulationStation.git ES-build"

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
run_chroot "useradd -m -s /bin/bash -G sudo,video,input,plugdev,render PS4"
run_chroot "echo 'PS4:PS4' | chpasswd"
run_chroot "echo 'root:root' | chpasswd"
run_chroot "echo 'PS4 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/PS4"
run_chroot "chmod 440 /etc/sudoers.d/PS4"

# === Configure SSH ===
echo "=== Configuring SSH ==="
run_chroot "systemctl enable ssh.service"

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

# === ES systemd service (no X11 — PS4 can't switch VTs, ES uses SDL2 framebuffer directly) ===
mkdir -p "$ROOTFS/etc/systemd/system"
cat > "$ROOTFS/etc/systemd/system/es-session.service" << 'SVCEOF'
[Unit]
Description=EmulationStation (SDL2 framebuffer)
After=multi-user.target network-online.target plymouth-quit.service
Wants=network-online.target

[Service]
Type=simple
User=PS4
Environment=LIBGL_ALWAYS_SOFTWARE=1
Environment=MESA_LOADER_DRIVER_OVERRIDE=swrast
Environment=GBM_ALWAYS_SOFTWARE=1
Environment=XDG_RUNTIME_DIR=/tmp/runtime-PS4
Environment=vblank_mode=2
Environment=__GL_SYNC_TO_VBLANK=1
ExecStartPre=/bin/bash -c "plymouth quit --retain-splash 2>/dev/null || true"
ExecStart=emulationstation
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF
ln -sf /etc/systemd/system/es-session.service "$ROOTFS/etc/systemd/system/multi-user.target.wants/es-session.service"

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
  <bool name="MultiThreadedMedi" value="true" />
  <string name="MediaSystemInfo" value="true" />
  <string name="StartupSystem" value="" />
  <string name="ScreenSaverBehavior" value="dim" />
  <bool name="ScreenSaverEnabled" value="false" />
  <string name="VideoDriver" value="default" />
</config>
ESCFG

# es_input.cfg (keyboard + DS4 joystick)
cat > "$ROOTFS/home/PS4/.emulationstation/es_input.cfg" << 'INPUTEOF'
<?xml version="1.0"?>
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
  <inputConfig type="joystick" deviceName="PS4 Controller" deviceGUID="030000004c050000cc09000000016800">
    <input name="a" type="button" id="0" value="1" />
    <input name="b" type="button" id="1" value="1" />
    <input name="down" type="button" id="12" value="1" />
    <input name="left" type="button" id="13" value="1" />
    <input name="pagedown" type="button" id="10" value="1" />
    <input name="pageup" type="button" id="9" value="1" />
    <input name="right" type="button" id="14" value="1" />
    <input name="select" type="button" id="4" value="1" />
    <input name="start" type="button" id="6" value="1" />
    <input name="up" type="button" id="11" value="1" />
  </inputConfig>
</inputList>
INPUTEOF

echo "ES config: es_settings.cfg (ThemeSet=carbon, ShowMissingGames=true)"
echo "ES config: es_input.cfg (keyboard + DS4 joystick)"

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

# Create ROM directories in .img (empty fallback for UFS mode, populated for .img mode)
ROMS_DIR="$ROOTFS/home/PS4/ROMS"
for sys in snes nes n64 gba gb gbc megadrive psx tg16 tgcd arcade neogeo atari2600 atari5200 atari7800 mastersystem gamegear; do
    mkdir -p "$ROMS_DIR/$sys"
done

# Copy homebrew ROMs into .img (source: es_configs import/ROMS/)
# NOTE: tgcd excluded — empty, users can add via FTP/Samba
HOMEBREW_DIR="/mnt/c/Users/dferron/Desktop/opencode working folder/es_configs import/ROMS"
if [ -d "$HOMEBREW_DIR" ]; then
    echo "Copying homebrew ROMs to .img..."
    for sys in snes nes n64 gba gb gbc megadrive psx tg16 arcade neogeo atari2600 atari5200 atari7800 mastersystem gamegear; do
        if [ -d "$HOMEBREW_DIR/$sys" ]; then
            cp -r "$HOMEBREW_DIR/$sys"/* "$ROMS_DIR/$sys/" 2>/dev/null || true
        fi
    done
    echo "Homebrew ROMs copied."
fi

# If UFS mode, write flag for install-HDD.sh
if [ "$ROM_STORAGE" = "ufs" ]; then
    echo "ufs" > "$ROOTFS/home/PS4/.rom_storage"
    echo "Flag file written: .rom_storage=ufs"
fi

# Create empty gamelists so ES can parse systems on first boot
echo "=== Creating empty gamelists ==="
GAMEDIR="$ROOTFS/home/PS4/.emulationstation/gamelists"
for sys in snes nes n64 gba gb gbc megadrive psx tg16 tgcd arcade neogeo atari2600 atari5200 atari7800 mastersystem gamegear; do
    mkdir -p "$GAMEDIR/$sys"
    echo '<?xml version="1.0"?>' > "$GAMEDIR/$sys/gamelist.xml"
    echo '<gameList />' >> "$GAMEDIR/$sys/gamelist.xml"
done
echo "Gamelists: $(find $GAMEDIR -name gamelist.xml | wc -l) empty systems"

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

# === HDMI hotplug watcher ===
echo "=== Installing HDMI watcher ==="
cat > "$ROOTFS/usr/local/bin/hdmi-watcher.sh" << 'HDMI_EOF'
#!/bin/bash
DRM_STATUS="/sys/class/drm/card0-HDMI-A-1/status"
POLL_INTERVAL=3
LAST_STATE=""
echo "hdmi-watcher: monitoring $DRM_STATUS"
while true; do
    if [ -f "$DRM_STATUS" ]; then
        CURRENT=$(cat "$DRM_STATUS" 2>/dev/null)
        if [ "$CURRENT" = "connected" ] && [ "$LAST_STATE" = "disconnected" ]; then
            echo "hdmi-watcher: HDMI reconnected, forcing modeset"
            modetest -s HDMI-A-1:1920x1080@60 2>/dev/null
        fi
        LAST_STATE="$CURRENT"
    fi
    sleep "$POLL_INTERVAL"
done
HDMI_EOF
chmod +x "$ROOTFS/usr/local/bin/hdmi-watcher.sh"

# === HDMI watcher systemd service ===
cat > "$ROOTFS/etc/systemd/system/hdmi-watcher.service" << 'SVC2EOF'
[Unit]
Description=HDMI Hotplug Watcher
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
cat >> "$ROOTFS/etc/samba/smb.conf" << 'SAMBAEOF'

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

# === Configure RetroArch ===
mkdir -p "$ROOTFS/home/PS4/.config/retroarch"
cat > "$ROOTFS/home/PS4/.config/retroarch/retroarch.cfg" << 'RETROCFG'
video_fullscreen = "true"
video_driver = "gl"
video_context_driver = "kms"
audio_driver = "sdl2"
input_driver = "udev"
input_autodetect_enable = "true"
input_device_p1 = "Sony Interactive Entertainment Wireless Controller"
libretro_directory = "/usr/lib/x86_64-linux-gnu/libretro"
libretro_info_path = "/usr/share/libretro/info"
content_database_path = "/usr/share/retroarch/assets/retroarch/database/rdb"
cheat_database_path = "/usr/share/retroarch/assets/retroarch/cht"
screenshot_directory = "/home/PS4/screenshots"
savefile_directory = "/home/PS4/saves"
savestate_directory = "/home/PS4/saves"
system_directory = "/home/PS4/BIOS"
joypad_autoconfig_dir = "/home/PS4/.config/retroarch/autoconfig"
menu_driver = "xmb"
RETROCFG

# === Create DS4 autoconfig for RetroArch ===
mkdir -p "$ROOTFS/home/PS4/.config/retroarch/autoconfig/udev"
cat > "$ROOTFS/home/PS4/.config/retroarch/autoconfig/udev/Sony_DualShock_4.cfg" << 'DSCFG'
input_driver = "udev"
input_device = "Sony Interactive Entertainment Wireless Controller"
input_device_display_name = "PS4 Controller (USB)"

input_a_btn = "0"
input_b_btn = "1"
input_x_btn = "3"
input_y_btn = "4"
input_start_btn = "9"
input_select_btn = "8"
input_guide_btn = "10"
input_l3_btn = "11"
input_r3_btn = "12"

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

input_l_btn = "4"
input_r_btn = "5"
input_l2_axis = "+5"
input_r2_axis = "-5"
DSCFG

# === Create append config for DS4 controller bindings ===
cat > "$ROOTFS/home/PS4/.config/retroarch/retroarch-joypad.cfg" << 'APPENDCFG'
input_driver = "linuxraw"
input_autodetect_enable = "false"
input_player1_a = "0"
input_player1_b = "1"
input_player1_x = "2"
input_player1_y = "3"
input_player1_start = "9"
input_player1_select = "8"
input_player1_guide = "12"
input_player1_up = "h0up"
input_player1_down = "h0down"
input_player1_left = "h0left"
input_player1_right = "h0right"
input_player1_l = "4"
input_player1_r = "5"
input_player1_l2 = "6"
input_player1_r2 = "7"
input_player1_l_x = "+0"
input_player1_l_y = "+1"
input_player1_r_x = "+3"
input_player1_r_y = "+4"
input_player1_l3 = "10"
input_player1_r3 = "11"
input_player1_analog_dpad_mode = "0"
APPENDCFG

# === Create RetroArch wrapper (stops ES for exclusive DRM/KMS access) ===
cat > "$ROOTFS/usr/local/bin/retroarch-wrapper.sh" << 'WRAPPER'
#!/bin/bash
systemctl stop es-session.service 2>/dev/null
sleep 2
mkdir -p /tmp/runtime-PS4
chmod 700 /tmp/runtime-PS4
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export GBM_ALWAYS_SOFTWARE=1
export LIBGL_ALWAYS_SOFTWARE=1
export XDG_RUNTIME_DIR=/tmp/runtime-PS4
/usr/bin/retroarch --config /home/PS4/.config/retroarch/retroarch.cfg "$@" 2>&1 | tee /tmp/retroarch.log
RESULT=$?
systemctl start es-session.service 2>/dev/null
exit $RESULT
WRAPPER
chmod +x "$ROOTFS/usr/local/bin/retroarch-wrapper.sh"

# === Configure EmulationStation ===
cat > "$ROOTFS/home/PS4/.emulationstation/es_systems.cfg" << 'ESCFG'
<?xml version="1.0"?>
<systemList>
  <system>
    <name>snes</name>
    <fullname>Super Nintendo</fullname>
    <path>/home/PS4/ROMS/snes</path>
    <extension>.sfc .smc .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/snes9x_libretro.so %ROM%</command>
    <platform>snes</platform>
    <theme>snes</theme>
  </system>
  <system>
    <name>nes</name>
    <fullname>Nintendo Entertainment System</fullname>
    <path>/home/PS4/ROMS/nes</path>
    <extension>.nes .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/nestopia_libretro.so %ROM%</command>
    <platform>nes</platform>
    <theme>nes</theme>
  </system>
  <system>
    <name>n64</name>
    <fullname>Nintendo 64</fullname>
    <path>/home/PS4/ROMS/n64</path>
    <extension>.n64 .z64 .v64 .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/mupen64plus_libretro.so %ROM%</command>
    <platform>n64</platform>
    <theme>n64</theme>
  </system>
  <system>
    <name>gba</name>
    <fullname>Game Boy Advance</fullname>
    <path>/home/PS4/ROMS/gba</path>
    <extension>.gba .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/mgba_libretro.so %ROM%</command>
    <platform>gba</platform>
    <theme>gba</theme>
  </system>
  <system>
    <name>gb</name>
    <fullname>Game Boy</fullname>
    <path>/home/PS4/ROMS/gb</path>
    <extension>.gb .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/gambatte_libretro.so %ROM%</command>
    <platform>gb</platform>
    <theme>gb</theme>
  </system>
  <system>
    <name>gbc</name>
    <fullname>Game Boy Color</fullname>
    <path>/home/PS4/ROMS/gbc</path>
    <extension>.gbc .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/gambatte_libretro.so %ROM%</command>
    <platform>gbc</platform>
    <theme>gbc</theme>
  </system>
  <system>
    <name>megadrive</name>
    <fullname>Sega Mega Drive</fullname>
    <path>/home/PS4/ROMS/megadrive</path>
    <extension>.md .bin .gen .smd .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>megadrive</platform>
    <theme>megadrive</theme>
  </system>
  <system>
    <name>psx</name>
    <fullname>Sony PlayStation</fullname>
    <path>/home/PS4/ROMS/psx</path>
    <extension>.bin .cue .iso .pbp .chd .m3u .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_psx_libretro.so %ROM%</command>
    <platform>psx</platform>
    <theme>psx</theme>
  </system>
  <system>
    <name>tg16</name>
    <fullname>TurboGrafx-16</fullname>
    <path>/home/PS4/ROMS/tg16</path>
    <extension>.pce .cue .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_pce_fast_libretro.so %ROM%</command>
    <platform>tg16</platform>
    <theme>tg16</theme>
  </system>
  <system>
    <name>tgcd</name>
    <fullname>TurboGrafx-CD</fullname>
    <path>/home/PS4/ROMS/tgcd</path>
    <extension>.chd .cue .iso .m3u</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_pce_fast_libretro.so %ROM%</command>
    <platform>tgcd</platform>
    <theme>tgcd</theme>
  </system>
  <system>
    <name>arcade</name>
    <fullname>Arcade</fullname>
    <path>/home/PS4/ROMS/arcade</path>
    <extension>.zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/fbneo_libretro.so %ROM%</command>
    <platform>arcade</platform>
    <theme>arcade</theme>
  </system>
  <system>
    <name>neogeo</name>
    <fullname>Neo Geo</fullname>
    <path>/home/PS4/ROMS/neogeo</path>
    <extension>.zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/fbneo_libretro.so %ROM%</command>
    <platform>neogeo</platform>
    <theme>neogeo</theme>
  </system>
  <system>
    <name>atari2600</name>
    <fullname>Atari 2600</fullname>
    <path>/home/PS4/ROMS/atari2600</path>
    <extension>.a26 .bin .rom .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/stella_libretro.so %ROM%</command>
    <platform>atari2600</platform>
    <theme>atari2600</theme>
  </system>
  <system>
    <name>atari5200</name>
    <fullname>Atari 5200</fullname>
    <path>/home/PS4/ROMS/atari5200</path>
    <extension>.a52 .bin .xfd .atari .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/atari800_libretro.so %ROM%</command>
    <platform>atari5200</platform>
    <theme>atari5200</theme>
  </system>
  <system>
    <name>atari7800</name>
    <fullname>Atari 7800</fullname>
    <path>/home/PS4/ROMS/atari7800</path>
    <extension>.a78 .bin .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/prosystem_libretro.so %ROM%</command>
    <platform>atari7800</platform>
    <theme>atari7800</theme>
  </system>
  <system>
    <name>mastersystem</name>
    <fullname>Sega Master System</fullname>
    <path>/home/PS4/ROMS/mastersystem</path>
    <extension>.sms .bin .gen .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>mastersystem</platform>
    <theme>mastersystem</theme>
  </system>
  <system>
    <name>gamegear</name>
    <fullname>Sega Game Gear</fullname>
    <path>/home/PS4/ROMS/gamegear</path>
    <extension>.gg .bin .zip</extension>
    <command>retroarch --appendconfig /home/PS4/.config/retroarch/retroarch-joypad.cfg -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>gamegear</platform>
    <theme>gamegear</theme>
  </system>
</systemList>
ESCFG

# === Install RetroPie carbon theme ===
echo "=== Installing RetroPie carbon theme ==="

# ES 2.0.1a looks in ~/.emulationstation/themes/ AND /etc/emulationstation/themes/
THEME_DIR="$ROOTFS/etc/emulationstation/themes"
mkdir -p "$THEME_DIR"

# Clone the carbon theme (try user fork first, fall back to RetroPie 2021)
cd /tmp
rm -rf es-theme-carbon
git clone --depth 1 https://github.com/danyboy666/es-theme-carbon.git 2>/dev/null || \
    git clone --depth 1 https://github.com/RetroPie/es-theme-carbon-2021.git es-theme-carbon 2>/dev/null || \
    git clone --depth 1 https://github.com/RetroPie/es-theme-carbon.git es-theme-carbon 2>/dev/null || \
    echo "Warning: Could not clone carbon theme."

if [ -d "es-theme-carbon" ]; then
    cp -r es-theme-carbon "$THEME_DIR/carbon"
    # Rename theme folders to match es_systems.cfg theme names
    [ -d "$THEME_DIR/carbon/genesis" ] && mv "$THEME_DIR/carbon/genesis" "$THEME_DIR/carbon/megadrive"
    [ -d "$THEME_DIR/carbon/tg-cd" ] && mv "$THEME_DIR/carbon/tg-cd" "$THEME_DIR/carbon/tgcd"
    [ -d "$THEME_DIR/carbon/pcengine" ] && mv "$THEME_DIR/carbon/pcengine" "$THEME_DIR/carbon/tg16"
    [ -d "$THEME_DIR/carbon/gg" ] && mv "$THEME_DIR/carbon/gg" "$THEME_DIR/carbon/gamegear"
    [ -d "$THEME_DIR/carbon/sms" ] && mv "$THEME_DIR/carbon/sms" "$THEME_DIR/carbon/mastersystem"
    echo "Theme installed: $THEME_DIR/carbon"
    _file_count=$(find "$THEME_DIR/carbon" -type f | wc -l)
    echo "Theme: $_file_count files (SVGs and PNGs kept as-is)"
else
    echo "ERROR: carbon theme clone failed"
    exit 1
fi

# Create symlink from user themes dir (ES checks both paths)
mkdir -p "$ROOTFS/home/PS4/.emulationstation"
ln -sf /etc/emulationstation/themes "$ROOTFS/home/PS4/.emulationstation/themes"

echo "Theme: carbon (RetroPie, formatVersion=3)"

chown -R 1000:1000 "$ROOTFS/home/PS4"

# === systemd service: fix UFS permissions at boot ===
cat > "$ROOTFS/etc/systemd/system/fix-ufs-permissions.service" << 'UFSPERM'
[Unit]
Description=Fix UFS ROM directory ownership for PS4 user
After=local-fs.target
Before=es-session.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if mountpoint -q /ps4hdd/ROMS 2>/dev/null || [ -d /ps4hdd/ROMS ]; then chown -R 1000:1000 /ps4hdd/ROMS; fi'
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
KEEP_INFO="bsnes_mercury_balanced_libretro.info snes9x_libretro.info fbneo_libretro.info gambatte_libretro.info genesis_plus_gx_libretro.info mednafen_pce_fast_libretro.info mednafen_psx_libretro.info mgba_libretro.info mupen64plus_libretro.info nestopia_libretro.info prosystem_libretro.info stella_libretro.info"
cd "$INFO_DIR"
for f in *.info; do
    if ! echo "$KEEP_INFO" | grep -qw "$f"; then
        rm -f "$f"
    fi
done
echo "Remaining info files: $(ls "$INFO_DIR"/*.info 2>/dev/null | wc -l)"

# === Install Plymouth es-logo splash theme ===
echo "=== Installing Plymouth es-logo theme ==="
run_chroot "cd /usr/share/plymouth/themes && git clone https://github.com/raelgc/es-logo.git"
run_chroot "update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/es-logo/es-logo.plymouth 100"
run_chroot "plymouth-set-default-theme es-logo"
run_chroot "systemctl enable plymouth-start.service"
echo "Plymouth theme: es-logo"

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
tar -cJf community-files/arch.tar.xz -C "$ROOTFS" \
    --exclude='./proc' --exclude='./sys' --exclude='./run' \
    --exclude='./dev' --exclude='./tmp' .

# === Rebuild initramfs from source tree ===
echo "=== Rebuilding initramfs ==="
cd "$SCRIPT_DIR"
find . \
    -not -path './.git/*' \
    -not -path './.github/*' \
    -not -path './community-files/*' \
    -not -path './es_configs import/*' \
    -not -name 'build.sh' \
    -not -name 'README.md' \
    -not -name 'LICENSE' \
    -not -name 'AUTHORS' \
    -not -name 'LICENCE.Marvell' \
    -not -name 'VERSION' \
    -not -name '.gitignore' \
    -not -name '.gitattributes' \
    -print0 | cpio --null -o --format=newc 2>/dev/null | gzip > community-files/initramfs.cpio.gz
echo "  initramfs rebuilt from source tree (with Plymouth)"

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

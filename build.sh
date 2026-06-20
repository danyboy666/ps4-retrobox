#!/bin/bash
# No set -e — we handle errors explicitly to avoid silent build failures

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
run_chroot "apt-get update"
run_chroot "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    retroarch retroarch-assets libretro-core-info \
    libretro-beetle-pce-fast libretro-beetle-psx \
    libretro-bsnes-mercury-balanced \
    libretro-gambatte libretro-genesisplusgx \
    libretro-mgba libretro-mupen64plus libretro-nestopia libretro-snes9x" || true

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
run_chroot "useradd -m -s /bin/bash -G sudo,video,input,plugdev PS4"
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

# Start EmulationStation (software GL to avoid glamor/Kaveri crash)
exec env LIBGL_ALWAYS_SOFTWARE=1 emulationstation
XINITEOF
chmod +x "$ROOTFS/home/PS4/.xinitrc"

cat > "$ROOTFS/home/PS4/.bash_profile" << 'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && ! pgrep -x Xorg > /dev/null 2>&1; then
    killall -9 emulationstation 2>/dev/null
    startx
fi
EOF
chmod +x "$ROOTFS/home/PS4/.bash_profile"

# NOTE: No systemd service for ES — it must start from .bash_profile -> startx -> .xinitrc
# so it gets keyboard input from the console X session. systemd-started ES cannot
# receive keyboard events from the console.

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

# es_input.cfg (keyboard only — ES auto-detects joystick via input wizard)
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
</inputList>
INPUTEOF

echo "ES config: es_settings.cfg (ThemeSet=carbon, ShowMissingGames=true)"
echo "ES config: es_input.cfg (keyboard only — DS4 auto-detected via input wizard)"

# === Create directories ===
echo "=== Creating directories ==="
mkdir -p "$ROOTFS/home/PS4/BIOS"
mkdir -p "$ROOTFS/home/PS4/ROMs/saves"
mkdir -p "$ROOTFS/home/PS4/ROMs/screenshots"
mkdir -p "$ROOTFS/home/PS4/ROMs/nes"
mkdir -p "$ROOTFS/mnt/roms"
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

# Override: manage ALL NetworkManager interfaces (default Ubuntu server unmanages wired)
mkdir -p "$ROOTFS/etc/NetworkManager/conf.d"
cat > "$ROOTFS/etc/NetworkManager/conf.d/10-managed-ethernet.conf" << 'NMOVERRIDE'
[keyfile]
unmanaged-devices=none
NMOVERRIDE

# === Input kernel modules ===
echo "=== Loading input modules ==="
mkdir -p "$ROOTFS/etc/modules-load.d"
cat > "$ROOTFS/etc/modules-load.d/input.conf" << 'INPUTMOD'
joydev
usbhid
INPUTMOD

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
   path = /ps4hdd/ROMs
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0664
   directory mask = 0775
   force user = PS4
   force group = PS4
SAMBAEOF

# === NFS client ===
echo "=== Configuring NFS client ==="
cat > "$ROOTFS/etc/exports" << 'NFSEOF'
# NFS client only — mount ROMs from PC via: sudo mount -t nfs <IP>:<share> /mnt/roms
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

echo "Mounting //$PC_IP/$SHARE to /mnt/roms ..."
sudo mkdir -p /mnt/roms

if ! grep -q "$SHARE" /etc/fstab; then
    echo "//$PC_IP/$SHARE /mnt/roms cifs user=$USER,password=$PASS,uid=1000,gid=1000,iocharset=utf8,x-systemd.automount,_netdev,nofail 0 0" | sudo tee -a /etc/fstab
    echo "Added to /etc/fstab"
fi

sudo mount -a
echo "Done! ROMs available at /mnt/roms/"
ls /mnt/roms/
SAMBA
chmod +x "$ROOTFS/usr/local/bin/setup-samba.sh"

# === Configure RetroArch ===
mkdir -p "$ROOTFS/home/PS4/.config/retroarch"
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
    <path>/home/PS4/ROMs/snes</path>
    <extension>.sfc .smc</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/bsnes_mercury_balanced_libretro.so %ROM%</command>
    <platform>snes</platform>
    <theme>snes</theme>
  </system>
  <system>
    <name>nes</name>
    <fullname>Nintendo Entertainment System</fullname>
    <path>/home/PS4/ROMs/nes</path>
    <extension>.nes .zip</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/nestopia_libretro.so %ROM%</command>
    <platform>nes</platform>
    <theme>nes</theme>
  </system>
  <system>
    <name>n64</name>
    <fullname>Nintendo 64</fullname>
    <path>/home/PS4/ROMs/n64</path>
    <extension>.n64 .z64 .v64</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mupen64plus_libretro.so %ROM%</command>
    <platform>n64</platform>
    <theme>n64</theme>
  </system>
  <system>
    <name>gba</name>
    <fullname>Game Boy Advance</fullname>
    <path>/home/PS4/ROMs/gba</path>
    <extension>.gba</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mgba_libretro.so %ROM%</command>
    <platform>gba</platform>
    <theme>gba</theme>
  </system>
  <system>
    <name>gb</name>
    <fullname>Game Boy / Color</fullname>
    <path>/home/PS4/ROMs/gameboy</path>
    <extension>.gb .gbc</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/gambatte_libretro.so %ROM%</command>
    <platform>gb</platform>
    <theme>gb</theme>
  </system>
  <system>
    <name>genesis</name>
    <fullname>Sega Genesis / Mega Drive</fullname>
    <path>/home/PS4/ROMs/genesis</path>
    <extension>.md .bin .gen .smd</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>genesis</platform>
    <theme>genesis</theme>
  </system>
  <system>
    <name>psx</name>
    <fullname>Sony PlayStation</fullname>
    <path>/home/PS4/ROMs/psx</path>
    <extension>.bin .cue .iso .pbp .chd</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_psx_libretro.so %ROM%</command>
    <platform>psx</platform>
    <theme>psx</theme>
  </system>
  <system>
    <name>pce</name>
    <fullname>TurboGrafx-16</fullname>
    <path>/home/PS4/ROMs/tg16</path>
    <extension>.pce .cue</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_pce_fast_libretro.so %ROM%</command>
    <platform>pcengine</platform>
    <theme>pce</theme>
  </system>
  <system>
    <name>arcade</name>
    <fullname>Arcade</fullname>
    <path>/home/PS4/ROMs/arcade</path>
    <extension>.zip</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/fbneo_libretro.so %ROM%</command>
    <platform>arcade</platform>
    <theme>arcade</theme>
  </system>
  <system>
    <name>neogeo</name>
    <fullname>Neo Geo</fullname>
    <path>/home/PS4/ROMs/neogeo</path>
    <extension>.zip</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/fbneo_libretro.so %ROM%</command>
    <platform>neogeo</platform>
    <theme>neogeo</theme>
  </system>
  <system>
    <name>atari2600</name>
    <fullname>Atari 2600</fullname>
    <path>/home/PS4/ROMs/atari2600</path>
    <extension>.a26 .bin .rom</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/stella_libretro.so %ROM%</command>
    <platform>atari2600</platform>
    <theme>atari2600</theme>
  </system>
  <system>
    <name>atari7800</name>
    <fullname>Atari 7800</fullname>
    <path>/home/PS4/ROMs/atari7800</path>
    <extension>.a78 .bin</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/prosystem_libretro.so %ROM%</command>
    <platform>atari7800</platform>
    <theme>atari7800</theme>
  </system>
  <system>
    <name>sms</name>
    <fullname>Sega Master System</fullname>
    <path>/home/PS4/ROMs/sms</path>
    <extension>.sms .bin .gen</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>mastersystem</platform>
    <theme>sms</theme>
  </system>
  <system>
    <name>gg</name>
    <fullname>Sega Game Gear</fullname>
    <path>/home/PS4/ROMs/gg</path>
    <extension>.gg .bin .zip</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so %ROM%</command>
    <platform>gamegear</platform>
    <theme>gg</theme>
  </system>
  <system>
    <name>pcecd</name>
    <fullname>PC Engine CD</fullname>
    <path>/home/PS4/ROMs/pcecd</path>
    <extension>.cue .chd .iso</extension>
    <command>retroarch -L /usr/lib/x86_64-linux-gnu/libretro/mednafen_pce_fast_libretro.so %ROM%</command>
    <platform>pcengine</platform>
    <theme>pcecd</theme>
  </system>
</systemList>
ESCFG

# === Install RetroPie carbon theme ===
echo "=== Installing RetroPie carbon theme ==="

# ES 2.0.1a looks in ~/.emulationstation/themes/ AND /etc/emulationstation/themes/
THEME_DIR="$ROOTFS/etc/emulationstation/themes"
mkdir -p "$THEME_DIR"

# Clone the carbon theme (try user fork first, fall back to RetroPie)
cd /tmp
rm -rf es-theme-carbon
git clone --depth 1 https://github.com/danyboy666/es-theme-carbon.git 2>/dev/null || \
    git clone --depth 1 https://github.com/RetroPie/es-theme-carbon.git 2>/dev/null || \
    echo "Warning: Could not clone carbon theme."

if [ -d "es-theme-carbon" ]; then
    cp -r es-theme-carbon "$THEME_DIR/carbon"
    # Rename theme folders that don't match es_systems.cfg theme names
    [ -d "$THEME_DIR/carbon/pce-cd" ] && mv "$THEME_DIR/carbon/pce-cd" "$THEME_DIR/carbon/pcecd"
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

# === Download feeRnt initramfs ===
echo "=== Downloading feeRnt initramfs ==="
if command -v gh &>/dev/null; then
    gh release download "$FEEINT_INITRAMFS_TAG" -R feeRnt/ps4-linux-initramfs \
        -p "initramfs.cpio.gz" -D community-files --clobber 2>/dev/null || \
    echo "Warning: Could not download initramfs via gh. Download manually from:"
    echo "  https://github.com/feeRnt/ps4-linux-initramfs/releases/tag/$FEEINT_INITRAMFS_TAG"
else
    echo "Warning: gh CLI not found. Download initramfs manually from:"
    echo "  https://github.com/feeRnt/ps4-linux-initramfs/releases/tag/$FEEINT_INITRAMFS_TAG"
fi

echo ""
echo "=== Build complete! ==="
echo "Files in community-files/:"
echo "  arch.tar.xz          $(du -h community-files/arch.tar.xz | cut -f1)  (Ubuntu rootfs)"
echo "  initramfs.cpio.gz    $(du -h community-files/initramfs.cpio.gz 2>/dev/null | cut -f1 || echo 'missing')  (feeRnt initramfs)"
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

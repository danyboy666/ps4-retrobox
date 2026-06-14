#!/bin/bash
set -e

echo "=== Updating apt ==="
apt-get update

echo "=== Installing core system ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    systemd systemd-sysv init \
    kmod udev \
    locales \
    sudo bash-completion \
    network-manager wpasupplicant \
    openssh-server \
    vim nano htop curl wget git \
    pulseaudio alsa-utils \
    ntfs-3g exfat-fuse exfatprogs \
    usbutils pciutils \
    net-tools iputils-ping \
    dbus \
    console-setup keyboard-configuration

echo "=== Generating locale ==="
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

echo "=== Installing Bluetooth ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bluez bluez-tools \
    pulseaudio-module-bluetooth

echo "=== Installing Samba + NFS ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    samba samba-common-bin \
    nfs-kernel-server nfs-common

echo "=== Installing Graphics stack ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    mesa-vulkan-drivers \
    libdrm-amdgpu1 \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    libglu1-mesa \
    libegl1-mesa \
    xserver-xorg-video-amdgpu \
    xinit xterm \
    x11-xserver-utils \
    xserver-xorg-input-libinput

echo "=== Installing EmulationStation build deps ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libsdl2-dev libboost-system-dev libboost-filesystem-dev \
    libboost-date-time-dev libboost-locale-dev libfreeimage-dev \
    libfreetype6-dev libeigen3-dev libcurl4-openssl-dev \
    libasound2-dev libgl1-mesa-dev build-essential cmake

echo "=== Installing RetroArch + cores ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    retroarch retroarch-assets \
    libretro-beetle-pce-fast \
    libretro-bsnes \
    libretro-desmume \
    libretro-dolphin \
    libretro-fceumm \
    libretro-gambatte \
    libretro-genplus \
    libretro-mame \
    libretro-mgba \
    libretro-mupen64plus \
    libretro-nestopia \
    libretro-nxengine \
    libretro-pcsx2 \
    libretro-picodrive \
    libretro-ppsspp \
    libretro-prosystem \
    libretro-snes9x \
    libretro-stella \
    libretro-tgbdual \
    libretro-vecx \
    libretro-vice \
    libretro-yabasanshiro \
    libretro-melonDS

echo "=== Installing extras ==="
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    joystick jstest-gtk evtest \
    ffmpeg \
    netpbm \
    network-manager-gnome

echo "=== Cleaning up ==="
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "=== All packages installed ==="

# Troubleshooting

## Common Issues

### ES shows but no game systems

ES may not have found your ROMs. Check:

```bash
ssh PS4@<IP>
ls /home/PS4/ROMS/nes/
```

If empty, copy ROMs via SCP:

```bash
scp game.nes PS4@<IP>:/home/PS4/ROMS/nes/
```

### RetroArch crashes on launch

The amdgpu_shim.so may not be loaded. Check:

```bash
ssh PS4@<IP>
cat /tmp/retroarch.log | head -5
```

If you see `amdgpu_query_info(ACCEL_WORKING) failed`, the shim is working (it catches the error). If RetroArch still crashes, check the video driver:

```bash
grep video_driver /home/PS4/.config/retroarch/retroarch.cfg
```

Should be `video_driver = "gl"`.

### Sound not working

PulseAudio/ALSA is configured but the PS4's audio hardware isn't fully supported. This is a known issue.

### Controller not detected

1. Make sure DS4 is connected via USB (not Bluetooth)
2. Check if the device is visible:

```bash
ls /dev/input/js*
cat /proc/bus/input/devices | grep -A4 "Sony"
```

3. If the device shows up but buttons are wrong, edit the appendconfig:

```bash
nano /home/PS4/.config/retroarch/retroarch-ps4.cfg
```

### Plymouth boot splash not showing

Plymouth theme is installed but the PS4's amdgpu DRM doesn't support Plymouth rendering. This is a known limitation.

### ES is slow/sluggish

ES uses software GL rendering. This is expected until the PS4 kernel gets proper amdgpu firmware support.

## Building from Source

### Prerequisites

- Ubuntu/Debian host
- Root access
- Internet connection

### Steps

```bash
git clone https://github.com/danyboy666/ps4-retrobox.git
cd ps4-retrobox
sudo ./build.sh
```

This will:
1. Bootstrap Ubuntu 24.04 rootfs
2. Build RetroArch 1.22.2 from source
3. Build EmulationStation from PS4 fork
4. Install 27 libretro cores
5. Package as `community-files/arch.tar.xz`

### Rebuilding initramfs

```bash
cd community-files
find . -not -path './.git/*' -not -name '*.sh' -not -name '*.md' -print0 | \
    cpio --null -o --format=newc | gzip > initramfs.cpio.gz
```

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

### N64 games laggy or graphical glitches

N64 uses GLideN64 renderer with radeonsi GPU. Performance is limited by the eth0 interrupt storm (~3,600 spurious interrupts/sec all on CPU1). The kernel IRQ round-robin fix distributes xhci interrupts but eth0 is pinned by Aeolia hardware.

To check interrupt load:
```bash
ssh PS4@<IP>
ps aux --sort=-%cpu | head -5  # Look for ksoftirqd/1
cat /proc/interrupts | grep eth0
```

**Workaround**: `isolcpus=1` in bootargs reserves CPU1 for kernel, giving emulators full access to CPUs 2-7.

### PSX crashes or runs very slow

PSX uses Beetle PSX with Lightrec JIT dynarec. Known issues:
- Dynasty Warriors crashes at gameplay start (Lightrec bug with specific memory access patterns)
- Other games may crash with Lightrec — use interpreter fallback if needed
- Performance is limited by CPU (1.6GHz Jaguar) and eth0 interrupt storm

To check dynarec status:
```bash
ssh PS4@<IP>
grep dynarec /home/PS4/.config/retroarch/config/Beetle\ PSX/Beetle\ PSX.opt
```

### HDMI signal lost after TV power cycle or cable replug

The PS4 Linux amdgpu driver doesn't detect HDMI cable disconnect/reconnect events. When the TV is power-cycled or the HDMI cable is replugged, the TV loses sync and doesn't re-detect the signal.

**Recovery**: SSH into the PS4 and run:
```bash
sudo hdmi-recover
```

This stops ES, starts Xorg, runs xrandr off/on to force EDID re-read, then restarts ES. Takes ~10 seconds.

**Known limitation**: Auto-recovery is not possible without kernel driver changes. The amdgpu driver on PS4 hardware doesn't fire hotplug events for cable disconnect/reconnect.

### RetroArch XMB menu navigation not working

Keyboard and DS4 navigation in the RetroArch XMB menu may not work properly. Known issue under investigation (#2).

**Workaround**: Change PSX/N64 settings directly via config files:
```bash
ssh PS4@<IP>
nano /home/PS4/.config/retroarch/config/Beetle\ PSX/Beetle\ PSX.opt
nano /home/PS4/.config/retroarch/config/Mupen64Plus-Next/Mupen64Plus-Next.opt
```

### eth0 interrupt storm (ksoftirqd high CPU)

eth0 generates ~3,600 spurious interrupts/sec, all pinned to CPU1. This causes ksoftirqd/1 to consume 60-90% CPU1, impacting emulator performance.

**Current workaround**: `isolcpus=1` in bootargs reserves CPU1 for kernel, giving emulators CPUs 2-7.

**Known limitation**: Cannot be fixed from userspace. Requires kernel driver patch for Aeolia PCIe interrupt routing.

### Scraping not working

Scrapers require API keys configured in the ES SCRAPER menu:
1. Open ES → MAIN MENU → SCRAPER
2. Set **THEGAMESDB API KEY** (get one at https://api.thegamesdb.net)
3. Optionally set **SCREENSCRAPER USER/PASS** for higher rate limits

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

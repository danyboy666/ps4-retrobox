# Build From Source

## Pre-built (Recommended)

Download the [latest release](https://github.com/danyboy666/ps4-retrobox/releases) — no build needed. FTP the 4 files to your PS4 and boot.

## Full Build (Linux PC Only)

> **⚠ Do NOT build on the PS4.** This must be done on an x86_64 Linux PC or laptop.

### Requirements

- x86_64 Linux PC (Ubuntu/Debian recommended)
- `sudo` access
- Internet connection
- ~5GB free disk space
- ~15-30 minutes

### Build

```bash
git clone https://github.com/danyboy666/ps4-retrobox.git
cd ps4-retrobox
sudo ./build.sh
```

### What build.sh Does

1. Bootstraps Ubuntu 24.04 rootfs (~1.5GB)
2. Builds RetroArch 1.22.2 from source (DRM/KMS + EGL)
3. Builds EmulationStation from the PS4 fork (25-button input)
4. Compiles `amdgpu_shim.so` (tricks Mesa into using radeonsi)
5. Compiles `fb_display` (stride-aware framebuffer image viewer)
6. Downloads 27 libretro cores from the buildbot
7. Installs 39 system configs, launching images, carbon theme
8. Creates ps4_retrobox settings menu with helper scripts
9. Packages as `community-files/arch.tar.xz`
10. Rebuilds initramfs from source tree

### Output Files

| File | Size | Description |
|------|------|-------------|
| `arch.tar.xz` | ~358MB | Ubuntu rootfs with RetroArch, ES, cores, configs |
| `initramfs.cpio.gz` | ~8MB | Boot initramfs with Plymouth splash |
| `bzImage_*` | ~9-18MB | Linux kernel (provided, not built) |
| `payload-960-*.elf` | ~300KB each | PS4 payloads for 1GB-4GB RAM models |

### Packaging the Release ZIP

```bash
cd community-files
zip -j ps4-retrobox-v1.3.zip \
    arch.tar.xz initramfs.cpio.gz \
    bzImage_no-built-in-fw_Clang_fullLTO \
    bzImage_Baikal_5.4.247 bootargs.txt \
    payloads/payload-960-*.bin payloads/payload-960-*.elf
```

## Updating a Running PS4

If you already have PS4 RetroBox installed and want to push updates without reflashing:

### Via SSH/SFTP

```bash
ssh PS4@<PS4_IP>
# Password: PS4
```

### Key Files to Update

| File | Purpose |
|------|---------|
| `/usr/local/bin/retroarch-wrapper.sh` | Game launcher (shows launching images) |
| `/usr/local/bin/fb_display` | Framebuffer image viewer |
| `/home/PS4/.config/retroarch/retroarch.cfg` | Main RetroArch config |
| `/home/PS4/.config/retroarch/retroarch-ps4.cfg` | DS4 bindings + hotkeys |
| `/home/PS4/.emulationstation/es_systems.cfg` | System definitions |
| `/usr/lib/x86_64-linux-gnu/libretro/*.so` | Libretro cores |
| `/usr/local/bin/scripts/*` | PS4 RetroBox helper scripts |

### Example: Update the wrapper

```bash
scp retroarch-wrapper.sh PS4@<IP>:/tmp/
ssh PS4@<IP> "sudo cp /tmp/retroarch-wrapper.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/retroarch-wrapper.sh"
```

### Restart ES

```bash
ssh PS4@<IP> "sudo systemctl restart es-session.service"
```

### Full Reflash (preferred for major updates)

1. Build new `arch.tar.xz` on PC
2. Package into release ZIP
3. FTP all files to PS4
4. Reboot → GoldHEN → BinLoader → send 1GB payload
5. Choose reinstall when prompted

## Architecture

```
PS4 payload → initramfs → Ubuntu 24.04 rootfs
                                    │
                          ┌─────────┴─────────┐
                          │  EmulationStation   │
                          │  (SDL2 framebuffer) │
                          └─────────┬─────────┘
                                    │ launch game
                          ┌─────────┴─────────┐
                          │   retroarch-wrapper │
                          │  (stops ES, shows   │
                          │   launching image,   │
                          │   runs RetroArch)    │
                          └─────────┬─────────┘
                                    │
                          ┌─────────┴─────────┐
                          │     RetroArch       │
                          │  (GL + KMS context) │
                          │  amdgpu_shim.so     │
                          │  → radeonsi GPU     │
                          └───────────────────┘
```

The `amdgpu_shim.so` library intercepts `amdgpu_query_info(ACCEL_WORKING)` to return success, tricking Mesa into using the radeonsi driver despite the PS4's kernel not reporting GPU acceleration as ready.

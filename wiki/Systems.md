# Supported Systems

PS4 RetroBox supports **39 systems** across 27 libretro cores.

## ROM Paths

Each system has its own ROM directory:

```
/home/PS4/ROMS/<system>/
```

Launch images are stored in:

```
/home/PS4/.emulationstation/downloaded_images/<system>/launching.png
```

## Systems List

### Nintendo

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| Super Nintendo | `snes` | snes9x | .sfc .smc .zip |
| Super Famicom | `sfc` | snes9x | .sfc .smc .zip |
| NES | `nes` | nestopia | .nes .zip |
| Famicom | `famicom` | nestopia | .nes .zip |
| Famicom Disk System | `fds` | mesen | .fds .zip |
| Nintendo 64 | `n64` | mupen64plus | .n64 .z64 .v64 .zip |
| Game Boy | `gb` | gambatte | .gb .zip |
| Game Boy Color | `gbc` | gambatte | .gbc .zip |
| Game Boy Advance | `gba` | mgba | .gba .zip |
| Virtual Boy | `virtualboy` | mednafen_vb | .vb .zip |

### Sega

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| Mega Drive | `megadrive` | genesis_plus_gx | .md .bin .gen .smd .zip |
| Genesis | `genesis` | genesis_plus_gx | .md .bin .gen .smd .zip |
| Sega CD | `segacd` | genesis_plus_gx | .bin .cue .iso .chd .zip |
| Mega CD | `mega-cd` | genesis_plus_gx | .bin .cue .iso .chd .zip |
| Sega 32X | `sega32x` | picodrive | .32x .bin .smd .zip |
| Master System | `mastersystem` | genesis_plus_gx | .sms .bin .gen .zip |
| Game Gear | `gamegear` | genesis_plus_gx | .gg .bin .zip |
| SG-1000 | `sg-1000` | gearsystem | .sg .bin .zip |

### Sony

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| PlayStation | `psx` | mednafen_psx | .bin .cue .iso .pbp .chd .m3u .zip |
| PlayStation Portable | `psp` | ppsspp | .iso .cso .pbp .zip |

### NEC

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| TurboGrafx-16 | `tg16` | mednafen_pce_fast | .pce .cue .zip |
| TurboGrafx-CD | `tgcd` | mednafen_pce_fast | .chd .cue .iso .m3u |
| SuperGrafx | `supergrafx` | mednafen_supergrafx | .pce .sg .zip |

### Atari

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| Atari 2600 | `atari2600` | stella | .a26 .bin .rom .zip |
| Atari 5200 | `atari5200` | atari800 | .a52 .bin .xfd .atari .zip |
| Atari 7800 | `atari7800` | prosystem | .a78 .bin .zip |
| Atari Jaguar | `atarijaguar` | virtualjaguar | .j64 .jag .zip |
| Atari Lynx | `atarilynx` | mednafen_lynx | .lnx .zip |

### SNK

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| Neo Geo | `neogeo` | fbneo | .zip |
| Neo Geo Pocket | `ngp` | mednafen_ngp | .ngp .zip |
| Neo Geo Pocket Color | `ngpc` | mednafen_ngp | .ngc .zip |

### Bandai

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| WonderSwan | `wonderswan` | mednafen_wswan | .ws .wsc .zip |
| WonderSwan Color | `wonderswancolor` | mednafen_wswan | .wsc .zip |

### Arcade

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| Arcade (FinalBurn Neo) | `arcade` | fbneo | .zip |
| MAME | `mame-libretro` | mame2003_plus | .zip |

### Others

| System | Folder | Core | Extensions |
|--------|--------|------|-----------|
| ColecoVision | `colecovision` | gearcoleco | .col .bin .zip |
| Fairchild Channel F | `channelf` | freechaf | .chf .bin .zip |
| Game and Watch | `gameandwatch` | gw | .gw .zip |
| GCE Vectrex | `vectrex` | vecx | .vec .zip |

## Adding ROMs

### Via SSH/SCP (from PC)

```bash
# Copy a ROM to the NES folder
scp game.nes PS4@192.168.121.183:/home/PS4/ROMS/nes/

# Copy a folder of ROMs
scp -r roms/* PS4@192.168.121.183:/home/PS4/ROMS/snes/
```

### Via Samba

Edit `/usr/local/bin/setup-samba.sh` with your PC's IP, then run:

```bash
sudo setup-samba.sh --setup
```

### Adding Launching Images

Place `launching.png` (1920x1080 recommended) in:

```
/home/PS4/.emulationstation/downloaded_images/<system>/launching.png
```

Per-ROM images:

```
/home/PS4/.emulationstation/downloaded_images/<system>/images/<rom-name>-launching.png
```

## Notes

- **Genesis** and **Mega Drive** are the same console (different region names). Both are available as separate carousel entries with different ROM folders.
- **Sega CD** and **Mega CD** are the same system. Both available separately.
- **SNES** and **Super Famicom** are the same console. Both available separately.
- **WonderSwan** and **WonderSwan Color** share the same core but have separate ROM folders.
- **Neo Geo Pocket** and **Neo Geo Pocket Color** share the same core but have separate ROM folders.
- **Arcade** (fbneo) and **MAME** (mame2003_plus) use different ROM sets. fbneo is for FinalBurn-compatible ROMs, MAME is for MAME 0.78+ ROMs.

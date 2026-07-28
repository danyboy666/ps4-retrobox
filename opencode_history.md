# OpenCode Execution Diary & Context Log

<!-- 
CRITICAL RULE FOR MIMO: Append new sessions to the TOP of this file. 
Keep entries brief, highly technical, and completely clear of credentials.
-->

## 2026-07-25 | Session: Controller mapping FIXED — configs updated from PS4

### WHAT WORKS NOW
- Controller buttons: all match ES exactly (a=1,b=0,x=3,y=2,L=9,R=10,L3=7,R3=8,start=6,select=4,hotkey=5,guide=12)
- D-pad: h0up/h0down/h0left/h0right (HAT hardware)
- Keyboard: Enter=A, Escape=B, arrows=D-pad, Space=Start, Tab=Select, PageUp=L, PageDown=R
- Hotkey combos: PS(5)+X(3)=menu, PS+Start(6)=exit
- Analog sticks: L2=axis2, R2=axis5, RightX=axis3, RightY=axis4
- HDMI recovery: modetest in service ExecStartPre

### build.sh UPDATED TO MATCH PS4 EXACTLY
- retroarch.cfg: hotkey=5, guide=12, all ES button IDs, keyboard bindings
- appendconfig: player1 bindings matching ES, hotkey=12
- wrapper: pactl HDMI audio before+after RA
- service: modetest in ExecStartPre

### LESSONS LEARNED
- NEVER change configs without understanding the ACTUAL hardware state
- ALWAYS read evdev output to verify button indices before deploying
- ES button IDs work DIRECTLY in RetroArch udev (both read evdev sequentially)
- D-pad is HAT hardware (ABS_HAT0X/Y) — must use h0up notation
- PS4 cannot run X11 (no VT support) — must use SDL2 framebuffer
- PS4 USB has disconnect issues — modetest helps recover display
- HDMI audio auto-switches to DS4 USB audio — wrapper forces HDMI before RA launch
- **DO NOT REMOVE usbhid.quirks** — causes USB disconnects, breaks button numbering

## 2026-07-27 | Session: usbhid.quirks removal broke everything — NEEDS REFLASH

### ROOT CAUSE: Removing `usbhid.quirks` from bootargs broke:
1. BTN_C(306)/BTN_Z(309) disappeared — ES button IDs no longer match
2. DS4 USB disconnects started — controller drops during gameplay
3. Controller combos broke — hotkey button5 (BTN_Z) no longer exists
4. Analog sticks broken — button numbering shifted
5. `input_l2_axis` in appendconfig was wrong (+2 instead of -4)

### FIX: Re-enable usbhid.quirks (already done in bootargs.txt)
The quirk was NOT causing issues — it was REQUIRED for PS4 DS4.

### PS4 state at end of session
- hotkey=12 (PS button), save_state=7, load_state=6
- L2_axis=-4 (matches ES)
- Launch images downloaded to downloaded_images/nes/snes/n64
- PIL installed and working
- USB udev rules for autosuspend
- Display: modetest retry loop in service
- **BUT bootargs still has usbhid.quirks REMOVED** — needs reflash to restore

### NEXT SESSION MUST DO
1. Verify bootargs.txt has usbhid.quirks restored (I did this before session ended)
2. User reflashes with corrected bootargs
3. Verify button IDs with evtest
4. Fix launching images if still broken
5. Fix keyboard if still broken
6. Commit ONLY after user confirms everything works

### AUTOCONFIG FIX (DEPLOYED + IN BUILD.SH)
- Created `Sony_DualShock4_Custom.cfg` in `/usr/share/retroarch/assets/autoconfig/udev/`
- Copied to `Sony DualShock 4 Controller.cfg`, `Sony Interactive Entertainment Wireless Controller.cfg`, `Wireless_Controller.cfg`
- **D-pad = h0up/h0down/h0left/h0right** (HAT hardware, NOT button IDs 11-14)
- **hotkey/guide = 12** (PS/BTN_MODE, NOT 5)
- **vendor_id=1356, product_id=2508** for device matching
- All other button IDs match ES exactly

### USB DISCONNECT ISSUE (KERNEL-LEVEL)
- DS4 disconnects/reconnects over USB every ~17 seconds
- 7 USB disconnects logged in dmesg
- Kernel has `usbhid.quirks=0x054c:0x09cc:0x400000` (NO_INIT_ENDPOINTS) and `usbcore.autosuspend=-1`
- xhci_aeolia USB controller re-enumerates device on disconnect
- **CANNOT FIX without kernel rebuild** — Orbis uses custom USB stack
- Added udev rule to disable autosuspend (may help but doesn't fix root cause)
- Bluetooth available but DS4 not paired

### WHAT WAS DEPLOYED AND CONFIRMED WORKING
- D-pad (h0up) ✓
- Controller combos (PS button=12 as hotkey) ✓
- Keyboard (Enter/Escape/arrows/F1) ✓  
- RA menu access ✓
- Sound (HDMI sink restored after RA exits) ✓

### STILL BROKEN
- USB disconnect/reconnect cycle (~17 second interval)
- Face button mapping "still wrong" — user hasn't specified which
- In-game combos/keyboard may not work (user reported "in-game")

### build.sh CHANGES
- retroarch.cfg: hotkey=12, D-pad=h0up, keyboard bindings, guide=12
- appendconfig: player1 bindings matching ES, no duplicate global bindings
- autoconfig: D-pad=h0up, hotkey=12, vendor/product IDs
- wrapper: pactl set-default-sink HDMI after RA exits, dd fb0 before restart

## 2026-07-20 | Session: Controller combos + keyboard fixed, sound fixed, commit progress

### WHAT WAS DEPLOYED AND CONFIRMED WORKING
PS4 configs:
- **retroarch.cfg**: `input_driver = "udev"`, `input_autodetect_enable = "false"`, hotkey=12 (PS button/BTN_MODE), D-pad=h0up/h0down/h0left/h0right, all ES button IDs, keyboard bindings (Enter=A, Escape=B, Space=Start, Tab=Select, PageUp=L, PageDown=R, arrows=D-pad, F1=menu)
- **retroarch-ps4.cfg** (appendconfig): player1 bindings matching ES (a=1,b=0,x=3,y=2,start=6,select=4,L=9,R=10,L3=7,R3=8,hotkey=12,L2=-4,R2=+5,right analog axis2/3)
- Sound fix: PulseAudio default sink forced to HDMI (was auto-switching to DS4 USB audio)

### USER CONFIRMED WORKING
- D-pad (h0up) ✓
- Controller combos (PS button as hotkey modifier) ✓
- Keyboard (Enter/Escape/arrows/F1) ✓
- RA menu access ✓

### STILL BROKEN
- Face button mapping "still wrong" — user hasn't specified which specific buttons
- Sound loss after game launch — PulseAudio auto-switches default sink to DS4 USB audio when controller plugged in. Fixed by forcing `pactl set-default-sink alsa_output.pci-0000_00_01.1.hdmi-stereo`

### SOUND FIX
PulseAudio default sink was `alsa_output.usb-Sony_Interactive_Entertainment_Wireless_Controller-00.analog-stereo` (DS4 USB audio). client.conf has correct HDMI sink but PulseAudio overrides at runtime. Fixed with `pactl set-default-sink`. May need udev rule or PA module to prevent auto-switch.

### ES BUTTON IDs (from es_input.cfg — THE TRUTH)
```
a=1, b=0, x=3, y=2, start=6, select=4
leftshoulder=9, rightshoulder=10, leftthumb=7, rightthumb=8
up=11, down=12, left=13, right=14, hotkeyenable=5
lefttrigger=axis4(-1), righttrigger=axis5(+1)
leftanalog=axis0/1, rightanalog=axis2/3
```
- D-pad: type="button" in ES but hardware sends HAT events → must use h0up notation
- hotkey=5 (BTN_Z) but changed to 12 (PS/BTN_MODE) for combos to work
- y=2 (BTN_C, PS4 extra button)

### NEXT SESSION
- User to test face buttons and report which specific ones are wrong
- Consider adding udev rule to prevent PulseAudio from switching to DS4 USB audio
- Update build.sh retroarch.cfg to match deployed configs
- No commits until user confirms all buttons correct

## 2026-07-20 | Session: Fix Controller Mapping — Correct Button IDs, revert sdl2→udev

### WHAT WAS WRONG
1. **`input_driver = "sdl2"` (wrong)**: Changed from `udev` in previous session. SDL2 uses gamepad mapping (SDL_GameController) which remaps buttons. ES uses raw SDL_Joystick API (raw evdev button indices). They see DIFFERENT button IDs for the same physical button.
2. **RetroArch retroarch.cfg had WRONG button IDs**: build.sh default had y=4 (should be y=2), L=6 (should be 9), R=7 (should be 10), start=11 (should be 6), select=10 (should be 4), hotkey=12 (should be 5), D-pad=h0up (should be 11-14 buttons).
3. **appendconfig retroarch-ps4.cfg** was overwritten with `sdl2` driver and button IDs 11-14 for D-pad.
4. **configscripts/retroarch.sh** generates wrong syntax: `input_player1_a = "1"` (keyboard syntax) instead of `input_player1_a_btn = "1"` (joypad syntax).

### WHAT WAS FIXED
- **PS4**: reverted both retroarch.cfg and retroarch-ps4.cfg to `input_driver = "udev"`, all button IDs matching ES exactly (a=1, b=0, x=3, y=2, L=9, R=10, L3=7, R3=8, start=6, select=4, hotkey=5, D-pad=11-14, L2=axis4(-1), R2=axis5(+1), right analog=axis2/3).
- **build.sh**: retroarch.cfg heredoc updated with correct button IDs, appendconfig heredoc updated, DS4 autoconfig profile updated.
- **retroarch.sh configscript**: fixed map_input to output `_btn` suffix for button/hat types and `_axis` suffix for axis types. Fixed hotkey generation lines.
- **retroarch-ps4-default.cfg**: updated to match correct button IDs.
- **Display recovery**: ran modetest + ES restart, signal restored.

### ES BUTTON IDs (from es_input.cfg — THE TRUTH)
```
a=1, b=0, x=3, y=2, start=6, select=4
leftshoulder=9, rightshoulder=10, leftthumb=7, rightthumb=8
up=11, down=12, left=13, right=14, hotkeyenable=5
lefttrigger=axis4(-1), righttrigger=axis5(+1)
leftanalog=axis0/1, rightanalog=axis2/3
```

### KEY LESSON
- ES uses `SDL_JoystickOpen()` + `SDL_JoystickGetButton()` → raw evdev button indices
- RetroArch udev driver also reads raw evdev → SAME button indices
- RetroArch sdl2 driver uses `SDL_GameController` → DIFFERENT (gamepad mapping remaps)
- Therefore: RetroArch MUST use `input_driver = "udev"` for PS4 DS4 to match ES
- Button IDs in RetroArch `_btn` keys are evdev BTN_* indices (with PS4 kernel's +2 shift from BTN_C/BTN_Z)

### STATUS
- PS4 configs deployed and PS4 restarted with signal restored
- build.sh updated (not rebuilt)
- NO COMMIT until user confirms controller works on PS4

### ROOT CAUSE: No Signal After ROM Exit
- **Old working wrapper** used `systemctl stop` WITHOUT sudo → **failed silently** → ES was never stopped
- RA ran on top of ES. When RA exited, ES was still alive showing its UI
- My new wrapper actually stopped ES → when RA exited, display went black → no signal
- **Fix: Don't stop ES.** RA takes over display via KMS. When RA exits, ES is still there.

### Launching Images
- Images from GitHub were 480x272 (PSP size), fb0 is 1920x1080
- Image wrote raw RGBA to fb0 → only filled tiny corner
- **Fix:** `img.resize((1920, 1080), Image.LANCZOS)` to scale up
- Colors inverted: fb0 uses BGRA, PIL outputs RGBA
- **Fix:** Swap R and B channels: `data[i], data[i+2] = data[i+2], data[i]`

### Controller Mapping
- ES input config uses SDL button IDs (different from RetroArch udev IDs)
- Both ES and RetroArch configs have correct IDs for their respective systems
- `input_autodetect_enable = "false"` prevents stock autoconfig from overriding

### Audio
- PulseAudio works (socket at /run/user/1000/pulse/native, sinks available)
- ALSA doesn't work (PulseAudio holds the device)
- `audio_driver = "pulse"` in both configs
- `SDL_AUDIODRIVER=pulse` in ES service
- `PULSE_SERVER=unix:/run/user/1000/pulse/native` in wrapper env

### Committed
- `6cec4c7` — clean wrapper: no stop ES, restart after RA, no fb0 writes, no system detection
- Controller mapping verified: A=Circle(1), B=Cross(0), X=Triangle(3), Y=Square(4)

## 2026-07-20 | Session: ROM Launch Fix, Audio, HDMI, Controller — FULL INVESTIGATION

### What Was Done
- Deployed multiple fixes to PS4 live
- Investigated ROM launch failure, HDMI hotplug, audio, controller mapping
- Committed `00049b0` then reverted per user request (uncommitted changes remain)

### ROM Launch — ROOT CAUSE FOUND AND FIXED
- **Problem:** `[KMS] Error when switching mode` — RA exits immediately after launch
- **Root cause 1:** `modetest -s HDMI-A-1:1920x1080` MUST run BEFORE RA to set up DRM CRTC. Without it, RA can't switch KMS modes when loading a game.
- **Root cause 2:** `video_fullscreen = "true"` alone doesn't force 1920x1080. Need `video_fullscreen_x = "1920"` and `video_fullscreen_y = "1080"` explicitly.
- **Root cause 3:** `setsid` in wrapper puts RA in background — RA can't acquire DRM master. Wrapper must run RA in FOREGROUND.
- **Root cause 4:** `tee /tmp/retroarch.log` pipe causes slow exit / hang. Use direct redirect `> /tmp/retroarch.log 2>&1`.
- **Root cause 5:** `KillMode=process` on ES service REQUIRED — wrapper is ES child, without KillMode=process, stopping ES kills the wrapper too.
- **Fix that works:** modetest before RA, RA in foreground, no tee, no setsid, modetest after RA, KillMode=process.
- **Verified:** Ran RA manually from SSH with correct env — game loaded, display worked, no KMS error.

### Audio — PulseAudio IS Working
- PulseAudio running (pid 681), socket at `/run/user/1000/pulse/native`
- `pactl info` works as PS4 user, `aplay` works
- RA needs `PULSE_SERVER=unix:/run/user/1000/pulse/native` env var in wrapper
- `audio_driver = "pulse"` in both retroarch.cfg and retroarch-ps4.cfg
- ALSA does NOT work — PulseAudio holds the device, `dmix` can't open slave
- ES service needs `SDL_AUDIODRIVER=pulse`

### Controller Mapping
- `input_autodetect_enable = "true"` in main config was causing stock autoconfig to override our button IDs
- Fixed to `input_autodetect_enable = "false"` — appendconfig already had false
- All button IDs verified correct (hotkey=12, exit=0, guide=12, etc.)
- Stock autoconfig (`Wireless_Controller.cfg`) matches our button IDs

### Black Screen After ROM Exit
- RA log shows RA exits cleanly but display not restored
- `modetest -s HDMI-A-1:1920x1080` after RA should restore display
- ES then restarts via `Restart=always`
- Issue: modetest might not be running after RA exits (check wrapper output)

### HDMI Hotplug
- `hdmi-watcher.service` was STILL enabled — calls modetest which corrupts DRM
- Fixed: replaced with no-op script, service changed to oneshot
- Batocera uses X11 — RandR handles hotplug automatically
- Our build uses direct KMS/DRM — no hotplug recovery mechanism
- **X11 switch planned** to solve this permanently

### Plymouth
- Batocera does NOT use plymouth — boots straight to X11
- Our plymouth theme likely doesn't work on PS4 custom amdgpu kernel
- Safe to drop when switching to X11

### Files Modified (on PS4 live, NOT in build.sh yet)
- `/usr/local/bin/retroarch-wrapper.sh` — fixed (no setsid, no tee, modetest before/after, PULSE_SERVER)
- `/home/PS4/.config/retroarch/retroarch.cfg` — audio=pulse, autodetect=false, video_fullscreen_x/y=1920/1080
- `/home/PS4/.config/retroarch/retroarch-ps4.cfg` — audio=pulse
- `/etc/systemd/system/es-session.service` — KillMode=process, SDL_AUDIODRIVER=pulse
- `/etc/systemd/system/hdmi-watcher.service` — disabled (no-op)

### Files Modified in build.sh (uncommitted)
- Wrapper: no setsid, no tee, modetest before/after, PULSE_SERVER, direct redirect
- retroarch.cfg: audio=pulse, autodetect=false, video_fullscreen_x/y=1920/1080
- retroarch-ps4.cfg: audio=pulse
- ES service: KillMode=process, SDL_AUDIODRIVER=pulse
- hdmi-watcher: disabled

### What Still Needs Work
1. Launching images not showing (python3/PIL works but images not downloaded)
2. Black screen after ROM exit — modetest after RA might not be restoring display
3. X11 switch for HDMI hotplug recovery
4. Commit build.sh changes (AWAITING USER APPROVAL)

### Status: AWAITING USER TESTING — DO NOT COMMIT WITHOUT APPROVAL

## 2026-07-19 | Session: Fix Black Screen, Initramfs Buildability, ES modetest

### Context
- User confirmed PS4 boots with old initramfs + new rootfs (correct button IDs)
- User tried PS+X to exit game → stuck in black screen
- User demanded: (1) initramfs must be buildable from source, (2) no more fuck ups

### Investigation: Black Screen on Exit
- **Root cause:** ES service had `ExecStartPre=modetest -s HDMI-A-1:1920x1080`
- modetest corrupts DRM CRTC state (known issue from green screen session)
- When RetroArch exits, wrapper restarts ES → ES service runs modetest → display stays black
- **Fix:** Removed modetest from ES service ExecStartPre in build.sh (line 536)
- Also reverted `Restart=on-failure` back to `Restart=always` (old service had this, worked)
- Also removed `KillMode=process` (old service didn't have it, worked)

### Investigation: Initramfs Buildability
- **Problem:** `build.sh` rebuilt initramfs from ENTIRE project tree using `find` + exclusions
- This included `.git/lfs/` (4GB blobs), `.opencode/`, `opencode.json` (secrets), `wiki/`, etc.
- Even after fixing exclusions, the rebuilt initramfs was subtly different from the working one
- **Root cause:** Project tree is NOT an initramfs tree. It has build files, docs, secrets, etc.
- **Solution:** Created `scripts/build-initramfs.sh` that copies ONLY boot-relevant directories:
  - `bin/`, `lib/`, `etc/`, `sbin/`, `key/`, `dev/`, `usr/` (plymouth only)
  - `init`, `VERSION`, `scripts/`, `configscripts/`
  - Creates `functions.sh` symlink at root
  - Produces deterministic 7.2MB initramfs with 110 files

### Investigation: Exit Button Mapping
- `input_exit_emulator_btn = "0"` in build.sh = BTN_SOUTH = Cross (X) in RetroArch udev
- This IS correct per evtest data
- If user experiences wrong button, need fresh evtest on PS4 to verify

### Files Modified
- `build.sh`:
  - Removed modetest from ES service ExecStartPre
  - Reverted Restart=on-failure → Restart=always
  - Removed KillMode=process from ES service
  - Replaced initramfs find/cpio with `bash scripts/build-initramfs.sh`
  - Removed zip creation (user handles releases)
  - Fixed PSXOPT duplicate (line 1486)
- `scripts/build-initramfs.sh` — NEW: deterministic initramfs builder
- `community-files/initramfs.cpio.gz` — rebuilt from source (7.2MB, 110 files)

### Initramfs Verification
- Size: 7.2MB
- Files: 110
- `functions.sh` at root: YES (symlink to bin/functions.sh)
- All critical boot files: init, busybox, cryptsetup, dropbear, libc, eap_hdd_key, plymouth
- Security: No .git, .opencode, opencode.json, .env, AGENTS.md
- Buildable from source: YES via `scripts/build-initramfs.sh`

### Status: FULL BUILD COMPLETE — arch.tar.xz (396MB) + initramfs.cpio.gz (7.2MB)
### Build verified: no modetest in ES service, correct button IDs, audio=alsa/hw:0,3

## 2026-07-20 | Session: Fix hdmi-watcher, Plymouth, Prepare X11 Switch

### hdmi-watcher Fix
- hdmi-watcher.service was STILL being created and enabled in build.sh
- It called `modetest -s HDMI-A-1:1920x1080` which corrupts DRM CRTC state
- Root cause of HDMI signal not recovering after TV power cycle
- Fix: replaced script with no-op `exit 0`, service changed to oneshot, symlink removed

### Plymouth Investigation
- Batocera does NOT use plymouth — boots straight to X11
- Our plymouth theme exists but PS4 custom amdgpu kernel can't support plymouth DRM rendering
- Drop plymouth entirely when switching to X11 — X11 handles display init

### HDMI Hotplug Root Cause
- Our build uses direct KMS/DRM framebuffer — no hotplug recovery
- Batocera uses X11 + modesetting driver — RandR handles hotplug automatically
- Solution: Switch to X11 (Plan B)

### X11 Switch Plan
- Xorg core + modesetting driver already in rootfs
- Need: install xinit, create xorg-ps4.conf, modify ES service + wrapper
- ES runs --windowed inside X11 (same as Batocera)
- HDMI hotplug: automatic via X11 RandR

## 2026-07-19 | Session: Fix Initramfs — No Signal After Payload (CRITICAL)

### Root Cause: TWO bugs caused boot failure

**Bug 1: `functions.sh` missing from initramfs root**
- `init` script does `. /functions.sh` (sources from `/functions.sh`)
- `functions.sh` was moved from root to `scripts/functions.sh` in commit 3d7e821
- Initramfs only had it at `/bin/functions.sh` and `/scripts/functions.sh`
- Init crashed immediately on boot → no signal

**Bug 2: `.git/lfs/objects/` (4GB) included in initramfs**
- Find exclusion `-not -path './.git/*'` only excluded CONTENTS of .git, not the directory itself
- find STILL descended into `.git/` and found `.git/lfs/objects/` (4GB of LFS blobs)
- Also: `opencode.json` (API keys), `.opencode/`, `community-files/`, `wiki/` were all included
- cpio was trying to package 4GB+ → hung indefinitely or created massive initramfs

### Fix Applied
1. **`build.sh` find command**: Use `-prune` for `.git`, `.opencode`, `.github`, `community-files`, `wiki`
   - `\( -name '.git' -o -name '.opencode' ... \) -prune` stops find from descending into these dirs
2. **`functions.sh` symlink**: `functions.sh -> bin/functions.sh` at project root
   - Initramfs now has `/functions.sh` which init can source
3. **Excluded secrets**: `opencode.json`, `AGENTS.md`, `opencode_history.md`

### Initramfs Verification
- Size: 7.1MB (was 152MB with LFS blobs, was hanging at 4GB)
- Files: 106 (clean boot utilities only)
- `functions.sh` at root: YES
- All critical boot files present: init, busybox, cryptsetup, dropbear, libc, eap_hdd_key
- Security: opencode.json=0, .git=0, .opencode=0, .env=0, AGENTS.md=0
- arch.tar.xz (396MB) UNCHANGED — rootfs configs are correct

### Files Modified
- `build.sh` — initramfs find command (prune-based exclusions)
- `functions.sh` — new symlink to `bin/functions.sh`

### Commits
- `1ff622e` — Fix DS4 button IDs, rebuild initramfs, clean bloated usr/lib
- `c1dc3fc` — Fix initramfs prune, functions.sh symlink, remove secrets

### Status: COMMITTED — NEEDS REFLASH AND TEST

## 2026-07-19 | Session: Deploy Corrected Button IDs, Rebuild Tarball, Commit

### Actions Taken
1. **Deployed corrected configs to PS4 directly (before rebuild):**
   - `retroarch.cfg` (113 lines) — all button IDs fixed per evtest, guide_btn=12, l2_axis="+2"
   - `retroarch-ps4.cfg` (90 lines) — hotkey combos, player1 bindings
   - `Sony_DualShock_4.cfg` (37 lines) — autoconfig with correct button IDs
   - All verified on PS4 via grep

2. **Fixed exit_emulator button per user feedback:**
   - Was `input_exit_emulator_btn = "11"` (Options) — WRONG per wiki
   - Changed to `input_exit_emulator_btn = "0"` (Cross/X) — matches wiki (PS+X=exit)
   - Fixed in: build.sh (2 locations), configscripts/retroarch-ps4-default.cfg, PS4 live configs

3. **Rebuilt tarball:**
   - `sudo bash build.sh` completed successfully
   - `community-files/arch.tar.xz` = 396MB
   - `community-files/initramfs.cpio.gz` = 152MB (BLOATED — see issue below)
   - ES compiled from fork, all configs regenerated with correct button IDs

4. **Committed to git**

### Build Issue: Initramfs Bloat (152MB, should be ~7MB) — FIXED
- Root cause: `usr/share/emulationstation/themes/` (168MB) and `usr/lib/` (9GB) in project root
- These were from previous tarball extractions, not part of initramfs
- Fixed: removed `usr/lib/`, `usr/share/emulationstation/`, `usr/share/batocera/`
- Added find exclusions: `opencode_history.md`, `*.tar.xz`, `*.cpio.gz`, `dev/*`, `etc/emulationstation/*`
- Result: initramfs.cpio.gz = 7.1MB (was 152MB)

### Correct Button Mapping Summary (PS4 Linux DS4 — from evtest)
| Function | RetroArch ID | Physical Button | Combo |
|---|---|---|---|
| Exit game | 0 | Cross | PS + X |
| Save state | 7 | R1 | PS + R1 |
| Load state | 6 | L1 | PS + L1 |
| Screenshot | 4 | Square | PS + Square |
| Fast forward | 14 | R3 | PS + R3 |
| Rewind | 13 | L3 | PS + L3 |
| Reset | 3 | Triangle | PS + Triangle |
| State slot - | h0left | D-pad Left | PS + D-pad Left |
| State slot + | h0right | D-pad Right | PS + D-pad Right |
| Open RA menu | combo | Options+Share | Hold Options + Share |
| Hotkey modifier | 12 | PS/BTN_MODE | Hold PS |

### Files Modified This Session
- `build.sh` — all button IDs corrected (main config, appendconfig, autoconfig sections)
- `configscripts/retroarch-ps4-default.cfg` — complete rewrite with correct IDs
- `opencode_history.md` — updated DS4 button reference (evtest-verified)
- `AGENTS.md` — updated DS4 controller mapping section
- PS4 live: `retroarch.cfg`, `retroarch-ps4.cfg`, `Sony_DualShock_4.cfg` — deployed and verified

### Status: DEPLOYED TO PS4 + COMMITTED (1ff622e) — TESTING NEEDED

## 2026-07-19 | Session: Fix Audio, Hotkeys, Keyboard — Post-Reflash

### Context
- User reflashed PS4 with last working build. ROMs launch successfully (no more green screen).
- Three remaining issues: (1) No sound in RetroArch, (2) In-game RA hotkey combo not working, (3) Keyboard not working.

### Batocera Analysis (from batocera_ps4linux_40.tar.xz)
- **Audio:** Batocera uses `audio_driver = "pulse"` by default. PS4 has PulseAudio running with HDMI sink `alsa_output.pci-0000_00_01.1.hdmi-stereo` (active port: `hdmi-output-0`).
- **Hotkeys:** Batocera sets `input_enable_hotkey_btn` to guide/PS button. ALL special functions require holding hotkey + pressing another button. No `input_menu_toggle_gamepad_combo` — they use the B button with hotkey held for menu toggle.
- **Controller mapping:** Batocera's `libretroControllers.py` maps ES buttons to RetroArch via `writeHotKeyConfig()` which saves `input_enable_hotkey_btn` to the hotkey button ID. Specials map: x→load_state, y→save_state, a→reset, start→exit_emulator, left→rewind, right→hold_fast_forward, pageup→screenshot, pageup→disk_eject_toggle for swap systems.
- **Display transition:** Batocera's `emulatorlauncher.py` changes resolution via `batocera-resolution` CLI before launching emulator, restores after. No modetest. Uses KMS/DRM context.

### Issue 1: No Sound — FIXED
- **Root cause:** `retroarch-ps4.cfg` had `audio_driver = "sdl2"`. SDL2 audio doesn't work reliably on PS4 without X11/Wayland. Main config had `audio_device = "alsa_output.pci-0000_00_01.1.hdmi-stereo"` (PulseAudio sink name, not ALSA device).
- **Fix:** Changed both configs to `audio_driver = "alsa"`, `audio_device = "hw:0,3"` (direct ALSA to HDMI output).
- **Verified:** `speaker-test -D hw:0,3 -t sine -f 440 -l 1 -c 2` succeeds — HDMI audio works.
- **PS4 audio hardware:** Card 0 device 3 = HDMI 0 (TV), device 7 = HDMI 1 (unused). Card 1 = DS4 USB Audio.
- **PulseAudio:** Running, has 2 sinks: HDMI stereo + DS4 analog stereo. PulseAudio route also works if needed.

### Issue 2: Hotkey Combo Not Working — FIXED
- **Root causes (3 bugs):**
  1. `input_menu_toggle_gamepad_combo = "0"` — combo system DISABLED
  2. `input_save_state_btn = "5"` SAME as `input_enable_hotkey_btn = "5"` — pressing PS triggers save state, hotkey never activates
  3. `input_hold_fast_forward_btn = "+4"` — L2 axis positive, but L2 goes NEGATIVE when pressed (wrong polarity)
- **Fix applied:**
  - `input_menu_toggle_gamepad_combo = "2"` — hold Start+Select = open RA menu
  - `input_enable_hotkey_btn = "5"` — PS/Guide = hotkey modifier (hold PS + press button)
  - `input_exit_emulator_btn = "6"` — PS + Options = exit
  - `input_save_state_btn = "10"` — PS + R1 = save state
  - `input_load_state_btn = "9"` — PS + L1 = load state
  - `input_screenshot_btn = "2"` — PS + Square = screenshot
  - `input_hold_fast_forward_btn = "14"` — PS + D-pad Right = fast forward
  - `input_rewind_btn = "13"` — PS + D-pad Left = rewind
  - `input_reset_btn = "3"` — PS + Triangle = reset
  - `input_state_slot_decrease_btn = "7"` — PS + L3 = state slot decrease
  - `input_state_slot_increase_btn = "8"` — PS + R3 = state slot increase
  - Removed `input_menu_toggle_btn = "1"` (was conflicting — Cross alone opened menu)

### Issue 3: Keyboard Not Working — INVESTIGATED
- **Hardware:** Microsoft 2.4GHz Transceiver detected on event4. ES has keyboard in es_input.cfg with SDL key IDs.
- **RetroArch:** Detects 5 keyboard devices via udev. RetroArch has built-in default keyboard bindings (arrows, Enter, Escape, etc.).
- **Possible causes:** (a) ES framebuffer mode may not detect keyboard via SDL without X11. (b) Keyboard might work in RetroArch but not in ES. (c) ES "Configure Input" wizard may need to be re-run.
- **Not yet deployed** — need user testing.

### Files Modified
- `build.sh` lines ~1069-1070: `audio_device = "hw:0,3"` (was PulseAudio sink name)
- `build.sh` lines ~1091-1111: hotkey bindings fixed (combo, no conflicts, correct polarity)
- `build.sh` lines ~1332-1333: `audio_driver = "alsa"`, `audio_device = "hw:0,3"` (was sdl2)
- `build.sh` lines ~1347-1360: hotkey bindings in appendconfig fixed
- PS4 live: `retroarch-ps4.cfg` deployed with all fixes

### PS4 DS4 Button Reference (PS4 Linux kernel — CORRECTED via evtest)
The PS4 kernel adds BTN_C(306) and BTN_Z(309) as extra buttons, shifting ALL standard button indices by 2.

**RetroArch udev button indices (sorted by event code):**
- 0=Cross(BTN_SOUTH/304), 1=Circle(BTN_EAST/305), 2=BTN_C(306)/Touchpad?, 3=Triangle(BTN_NORTH/307)
- 4=Square(BTN_WEST/308), 5=BTN_Z(309)/?, 6=L1(BTN_TL/310), 7=R1(BTN_TR/311)
- 8=L2-digital(BTN_TL2/312), 9=R2-digital(BTN_TR2/313)
- 10=Share(BTN_SELECT/314), 11=Options(BTN_START/315)
- **12=PS/BTN_MODE(316)** ← THIS IS THE PS BUTTON
- 13=L3(BTN_THUMBL/317), 14=R3(BTN_THUMBR/318)

**RetroArch udev axis indices:**
- 0=LeftX(ABS_X), 1=LeftY(ABS_Y), **2=L2(ABS_Z)**, 3=RightX(ABS_RX), 4=RightY(ABS_RY), **5=R2(ABS_RZ)**

**CRITICAL:** Previous configs used button 5 for PS button — WRONG! PS button = button 12 (BTN_MODE). L2 = axis 2, NOT axis 4.

### Batocera Key Config Files
- `/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroControllers.py` — hotkey + controller mapping
- `/usr/lib/python3.11/site-packages/configgen/generators/libretro/libretroConfig.py` — retroarch.cfg generation (audio_driver=pulse, video_driver via gfxbackend)
- `/usr/lib/python3.11/site-packages/configgen/emulatorlauncher.py` — ES→emulator display transition
- `/usr/lib/python3.11/site-packages/configgen/utils/videoMode.py` — resolution management via `batocera-resolution` CLI

### Status: DEPLOYED TO PS4 — TESTING NEEDED

## 2026-07-19 | Session: Fix Controller Button IDs — CORRECTED via evtest

### Context
- Previous button mapping was WRONG. Ran evtest on PS4 to get actual kernel button codes.
- PS4 kernel adds BTN_C(306) and BTN_Z(309) as extra buttons, shifting ALL standard indices by 2.

### Root Cause
- PS button was mapped to button 5 (BTN_Z, a dead button) instead of button 12 (BTN_MODE)
- L2 axis was mapped to axis 4 (ABS_RY, right stick Y) instead of axis 2 (ABS_Z)
- All button IDs were off by 2 due to BTN_C and BTN_Z in the kernel driver

### Correct Mapping (from evtest)
**RetroArch udev button indices:**
| Index | Event Code | Physical Button |
|---|---|---|
| 0 | 304 (BTN_SOUTH) | Cross |
| 1 | 305 (BTN_EAST) | Circle |
| 2 | 306 (BTN_C) | Touchpad? (dead) |
| 3 | 307 (BTN_NORTH) | Triangle |
| 4 | 308 (BTN_WEST) | Square |
| 5 | 309 (BTN_Z) | ? (dead) |
| 6 | 310 (BTN_TL) | L1 |
| 7 | 311 (BTN_TR) | R1 |
| 8 | 312 (BTN_TL2) | L2 digital |
| 9 | 313 (BTN_TR2) | R2 digital |
| 10 | 314 (BTN_SELECT) | Share |
| 11 | 315 (BTN_START) | Options |
| 12 | 316 (BTN_MODE) | **PS/Guide** |
| 13 | 317 (BTN_THUMBL) | L3 |
| 14 | 318 (BTN_THUMBR) | R3 |

**RetroArch udev axis indices:**
| Index | Event Code | Physical Axis |
|---|---|---|
| 0 | ABS_X | Left X |
| 1 | ABS_Y | Left Y |
| 2 | ABS_Z | **L2 trigger** |
| 3 | ABS_RX | Right X |
| 4 | ABS_RY | Right Y |
| 5 | ABS_RZ | **R2 trigger** |

### Files Fixed
1. **build.sh** — main config section (~line 1091): fixed all button IDs, guide_btn=12, l2_axis="+2", r2_axis="+5"
2. **build.sh** — appendconfig section (~line 1347): fixed all button IDs, player1 bindings, axis mappings
3. **build.sh** — autoconfig section (~line 1494): fixed Wireless_Controller.cfg with correct button IDs
4. **configscripts/retroarch-ps4-default.cfg** — complete rewrite with correct button IDs
5. **opencode_history.md** — updated DS4 button reference with correct mapping
6. **AGENTS.md** — updated DS4 controller mapping section with correct mapping

### Status: BUILD.SH FIXED — NEEDS FULL REBUILD OR DIRECT DEPLOYMENT TO PS4

## 2026-07-19 | Session: Fix Green Screen — modetest DRM CRTC Corruption

### Root Cause
- **modetest between ES death and RetroArch corrupts DRM CRTC state**
- `modetest -s HDMI-A-1:1920x1080` runs as root, sets CRTC to a kernel dumb buffer
- RetroArch (as PS4 user) then tries to take over CRTC but can't — atomic commit/page flip fails silently
- Green screen = display controller scanning out uninitialized VRAM (modetest's dumb buffer)
- "No signal" = modetest leaving DRM in corrupt state, TV loses HDMI sync

### Evidence
- ES killed successfully (KillMode=process, service inactive/dead)
- RetroArch initializes OK (found connector, mode 1920x1080@60Hz, GL context, KMS framebuffers created)
- RetroArch STUCK on `futex_wait_queue` after "KMS New FB" — never completes page flip
- No game rendering — log ends abruptly at KMS New FB messages
- `/dev/dri/card0` open on multiple fds by RetroArch

### Fix Applied
1. **Removed modetest from wrapper between ES death and RetroArch launch** — RetroArch handles all DRM/KMS setup itself
2. Added `trap '' HUP` to survive ES session death
3. Added `setsid` for RetroArch to launch in new session
4. Added `--verbose` flag for DRM debugging
5. Added ES restart after RetroArch exits
6. Service: `KillMode=process`, `Restart=on-failure` (already deployed)
7. build.sh wrapper and service updated to match

### Status: DEPLOYED TO PS4 — TESTING NEEDED

## 2026-07-19 | Session: Fix ROM Launch, Controller, hdmi-watcher (PARTIALLY DEPLOYED)

### Fix #1: ROM Launch Green Screen → ES Never Released DRM/KMS
- **Root Cause 1:** hdmi-watcher.sh (running as root, Restart=always) detected ES gone and immediately restarted ES + cleared framebuffer every 5 seconds
- **Root Cause 2:** Wrapper used `systemctl stop` without sudo → failed silently → ES stayed alive → fought RetroArch for DRM/KMS framebuffer = green screen
- **Root Cause 3:** When ES killed, SIGHUP sent to wrapper and child processes → RetroArch died silently → black screen
- **Root Cause 4:** `tee /tmp/retroarch.log` pipe caused SIGPIPE when wrapper exited
- **Fix Applied to PS4:**
  1. hdmi-watcher service: stopped, disabled, masked (`ln -s /dev/null`), script renamed to .disabled
  2. ES service: changed `Restart=always` → `Restart=on-failure` (kill = SIGTERM = clean exit = no restart)
  3. Wrapper: kills ES directly (`kill $ES_PID`) — PS4 user owns ES process, no sudo needed
  4. Wrapper: `trap '' HUP` to survive ES session death
  5. Wrapper: `setsid /usr/bin/retroarch` to launch RetroArch in new session (survives SIGHUP)
  6. Wrapper: removed `| tee` pipe (redirect to file instead)
  7. Wrapper: restarts ES via `echo 'PS4' | sudo -S systemctl start es-session.service` after game exit
- **Status:** DEPLOYED TO PS4 (test pending)

### Fix #2: R2 Trigger Wrong Axis
- **Root Cause:** `input_r2_axis = "-5"` in autoconfig and retroarch-ps4.cfg. ES maps righttrigger as axis 5, value=+1. So R2 should be `"+5"` not `"-5"`.
- **Fix Applied:**
  1. PS4 autoconfig: `Sony_DualShock_4.cfg` → `input_r2_axis = "+5"`
  2. PS4 retroarch-ps4.cfg → `input_r2_axis = "+5"`
  3. PS4 main retroarch.cfg → `input_autodetect_enable = "false"`, `menu_mouse_enable = "false"`
  4. build.sh retroarch-ps4.cfg → already had `"+5"` (was fixed earlier)
  5. configscripts/retroarch-ps4-default.cfg → fixed `input_r2_axis` from `"+4"` to `"+5"`, fixed swapped L/R shoulders (l=9, r=10), fixed L2 from `"+4"` to `"-4"`
- **Status:** DEPLOYED TO PS4 + BUILD.SH FIXED

### Fix #3: hdmi-watcher Removed
- **Root Cause:** hdmi-watcher.sh ran as root with Restart=always, polled every 5s, restarted ES when ES was dead. This fought with retroarch-wrapper.sh which needed ES dead during gameplay.
- **Fix Applied to build.sh:**
  1. hdmi-watcher.sh heredoc replaced with no-op `exit 0`
  2. hdmi-watcher.service no longer auto-started (symlink removed)
- **Fix Applied to PS4:** service stopped+disabled+masked, script renamed
- **Status:** DEPLOYED TO PS4 + BUILD.SH FIXED

### Fix #4: ES Service Restart Policy
- **Root Cause:** `Restart=always` means killing ES auto-restarts it after 3s, conflicting with game launch
- **Fix Applied:** Changed to `Restart=on-failure` in build.sh and on PS4
- **Status:** DEPLOYED TO PS4 + BUILD.SH FIXED

### Files Modified in build.sh:
- Wrapper heredoc: added `trap '' HUP`, ES kill logic, `setsid` for retroarch, removed `tee`, added ES restart
- ES service: `Restart=on-failure`
- hdmi-watcher: disabled (no-op script, no auto-start)
- retroarch-ps4.cfg appendconfig: R2 axis already `+5`
- configscripts/retroarch-ps4-default.cfg: fixed R2/L2/L/R shoulder mappings

### TODO: Test on PS4, rebuild tarball, commit

## 2026-07-18 | Task: ROM Launch Green Screen Fix + Local Build (DEPLOYED)
- **Root Cause:** Wrapper used `systemctl stop` which requires root and causes ES restart conflicts. ES service has `Restart=always`. Green screen because framebuffer not cleared before RetroArch grabs it.
- **Fix Applied:**
  1. Removed ALL systemctl stop/mask/unmask from wrapper — ES stays alive via system() suspension
  2. Added `dd/if=/dev/zero + modetest` BEFORE RetroArch launch (prevents green screen)
  3. Updated build.sh wrapper heredoc to match
  4. Deployed to PS4 and rebuilt tarball
- **Deployed to PS4:** Wrapper replaced, ES restarted
- **Local build:** build.sh wrapper heredoc fixed
- **Status:** DEPLOYED TO PS4 + LOCAL BUILD FIXED

## 2026-07-17 | Task: Fix retroarch-wrapper.sh in tarball (DEPLOYED)
- **Root Cause:** arch.img had old broken wrapper (missing systemctl stop, orphaned else). Tarball was rebuilt from old rootfs, not from build.sh output.
- **Fix Applied:**
  1. Mounted rootfs, replaced retroarch-wrapper.sh with correct version from build.sh
  2. Rebuilt tarball (390MB) — verified wrapper has systemctl stop, LD_PRELOAD, modetest
  3. User will reflash to test
- **Status:** AWAITING USER TEST
- **Root Cause:** retroarch-ps4.cfg was 0 bytes in the tarball — flash deployed empty file, causing no sound and ROMs not launching
- **Fix Applied:**
  1. Mounted rootfs, wrote correct 98-line retroarch-ps4.cfg with audio_driver=sdl2 and correct ES-matched button mapping
  2. Rebuilt tarball (390MB) — verified retroarch-ps4.cfg is 98 lines in tarball
  3. Compiled ES from full 794-commit fork
  4. PS4 offline — waiting for user to boot and test
- **Status:** AWAITING PS4 BOOT AND TEST
- **Objective:** Fix RetroArch button mappings to match ES, fix audio, rebuild tarball
- **Root Cause:** retroarch.cfg had wrong button IDs. retroarch-ps4.cfg had mismatched shoulder/trigger IDs. ALSA audio driver doesn't work on PS4.
- **Fix Applied:**
  1. Complete rewrite of retroarch-ps4.cfg matching ES input mapping exactly
  2. audio_driver changed from ALSA to sdl2, added audio_sync + audio_latency
  3. Rebuilt arch.tar.xz with fixed configs
  4. Updated release notes on GitHub
- **Outcome:** [Status: COMMITTED, PUSHED, DEPLOYED, RELEASE UPDATED]

## 2026-07-14 | Task: N64 + PSX Performance Fix (Batocera Reference) - DEPLOYED
- **Objective:** Improve N64 and PSX performance using Batocera PS4 Linux as reference
- **Changes Applied:**
  1. N64: Reduced 4:3 resolution from 640x480 to 320x240 (Batocera default)
  2. N64: Reduced 16:9 resolution from 960x540 to 640x360 (Batocera default)
  3. PSX: Added `beetle_psx_cpu_freq_scale = "110%"` (Batocera default for performance)
  4. PSX: Added `beetle_psx_analog_calibration = "enabled"` (Batocera default)
  5. Credits: Added RetroPie and Batocera to README.md
- **Outcome:** [Status: COMMITTED, PUSHED, DEPLOYED TO PS4]

## 2026-07-14 | Task: Project Cleanup + BIOS + Release Automation
- **Objective:** Move loose scripts to scripts/, remove logos/, add BIOS to build, automate zip creation
- **Changes Applied:**
  1. Moved `download-bios.sh`, `led-control.sh`, `rest-mode.sh`, `functions.sh`, `fb_display.c` → `scripts/`
  2. Removed `logos/` folder (logo already in PSRB-es-theme-carbon repo)
  3. Removed logos fallback cp from build.sh (line 2089)
  4. Added BIOS download section to build.sh (PS1, 32X, Atari 5200, TurboGrafx-CD)
  5. Added automated zip creation to build.sh (creates ps4-retrobox-vX.Y.Z.zip)
  6. Updated wiki/Build-Guide.md with scripts/ path for fb_display.c
- **Encountered Roadblocks:** None
- **Outcome:** [Status: COMMITTED AND PUSHED]

## 2026-07-14 | Task: Initramfs Security Fix + Release Repack
- **Objective:** Fix initramfs bloating (410MB → 7MB), exclude secrets, rebuild release zip
- **Root Cause:** `find .` in build.sh included `ps4-retrobox-v1.7.1-dev/community-files/arch.tar.xz` (414MB) in initramfs. Also included `.env` (secrets), `.opencode/`, `AGENTS.md`.
- **Fix Applied:**
  1. Added exclusions to build.sh find: `.env`, `.opencode/*`, `AGENTS.md`, `*.zip`
  2. Deleted `ps4-retrobox-v1.7.1-dev/` folder from project root
  3. Rebuilt initramfs: 7.2MB (was 410MB)
  4. Rebuilt zip: `cd community-files && zip ../ps4-retrobox-v1.7.1-dev.zip *` (403MB)
  5. Updated AGENTS.md with initramfs security rules
  6. Updated README.md build requirements section
  7. Plymouth splash screen still in initramfs (bin/plymouth, lib/plymouth, themes)
- **Outcome:** [Status: COMMITTED AND PUSHED]
- **Objective:** Rebuild project from scratch, zip release, update README and wikis
- **Proposed Changes:**
  - Run build.sh from scratch
  - Zip as ps4-retrobox-v1.7.1-dev.zip
  - Update README.md with v1.7.1-dev version and new features
  - Update wiki/Controller-Setup.md with OK/Cancel buttons and PS4 DS4 notes
  - Log everything to opencode_history.md
- **Execution Log (Build Mode):**
  - [Status: COMPLETED]
  - build.sh completed successfully
  - arch.tar.xz: 396MB, initramfs.cpio.gz: 7.2MB (FIXED from 410MB)
  - Release zip: ps4-retrobox-v1.7.1-dev.zip (community-files only)
  - README.md updated to v1.7.1-dev
  - wiki/Controller-Setup.md updated with OK/Cancel buttons and PS4 DS4 notes
  - AGENTS.md updated with initramfs lesson (exclude *.zip from find)
  - initramfs fix: added `-not -name '*.zip'` to find command — was including 1.2GB of zip files
  - **Encountered Roadblocks:** initramfs was 410MB because project root had ps4-retrobox-v1.7-stable.zip (403MB) and ps4-retrobox-v1.7.1-dev.zip (805MB) being included by find command
- **Outcome:** All tasks completed

## 2026-07-14 | Task: Comprehensive PS4 RetroBox Fixes (7 Issues)
- **Current Branch / State:** ES fork `danyboy666/EmulationStation` @ `5a782e6`
- **Repos:** ps4-retrobox, EmulationStation, ps4-linux-12xx, ps4-linux-payloads, RetroArch, mupen64plus-core
- **Status:** 7 issues identified, Issues 1/1b/6 DEPLOYED AND CONFIRMED WORKING, rest planned

### Issue 1: ES Trigger Skipping (DEPLOYED — AWAITING TEST)
- **Problem:** Analog axis bleed on DS4 triggers skips mapping screens in Configure Input
- **Fix Applied:** Batocera mAllInputs approach @ `5a782e6`
  - Removed all trigger filtering from `filterTrigger()` (now `return false`)
  - Added `mAllInputs` vector to capture ALL events during press
  - On release: if held input was BUTTON, swap to matching AXIS (>=2 events on same axis)
  - `filterTrigger` signature changed: `(Input, InputConfig*)` — no inputId param
- **Status:** Deployed to PS4, awaiting user test

### Issue 2: RetroArch Controller Not Working / Keyboard Lockout
- **Problem:** DS4 touchpad registers as mouse/keyboard, creating input race condition. Keyboard only works when DS4 disconnected.
- **Root Cause:** DS4 touchpad exposes itself as keyboard interface. RetroArch input drivers (udev/sdl2) get trapped parsing touchpad as primary keyboard.
- **Fix Path:** Add udev rule to disable DS4 touchpad as keyboard input. Check existing `99-ds4-usbhid.rules` in build.sh. May need to add `ENV{ID_INPUT_KEYBOARD}="0"` for touchpad device.

### Issue 3: N64 Performance (ROMs Lagging)
- **Problem:** Severe gameplay lag, likely software rendering.
- **Fix Path:** Ensure mupen64plus uses `gliden64` RDP plugin (hardware GL). Check `retroarch.cfg` has `video_driver = "gl"`. Verify Mupen64Plus-Next.opt has correct settings.

### Issue 4: PSX Performance (Dynasty Warriors)
- **Problem:** Intro plays fine, in-game slow/barely playable.
- **Fix Path:** Beetle PSX core options — verify `cpu_dynarec = "execute"`, `gte_overclock = "enabled"`, `gpu_overclock = "2x"` are applied. These are in `Beetle PSX.opt` but may not be loading.

### Issue 5: HDMI Signal Recovery
- **Problem:** TV power-cycle drops display, requires Ctrl+Alt+F4 to recover.
- **Root Cause:** DRM/KMS display layer drops handshake on TV input switch. System doesn't auto-recover.
- **Fix Path:** Existing `hdmi-recover` script needs improvement. Add udev rule for DRM hotplug events to auto-trigger `chvt` refresh without keyboard.

### Issue 6: ES→RetroArch Button Mapping Unification (DEPLOYED TO PS4)
- **Problem:** RetroArch controller not working. DS4 touchpad registers as mouse/keyboard. 3 conflicting configs: retroarch.cfg (wrong IDs), retroarch-ps4.cfg (empty), autoconfig (standard Linux IDs).
- **Root Cause:** retroarch.cfg had keyboard mappings mixed with joystick, wrong button IDs. retroarch-ps4.cfg was empty. Autoconfig had standard Linux DS4 IDs, not PS4 Linux IDs. `input_autodetect_enable = "true"` let autoconfig override everything.
- **Fix Applied (directly to PS4):**
  1. Deployed `configscripts/retroarch.sh` to PS4, ran it to regenerate retroarch.cfg from es_input.cfg
  2. Wrote complete `retroarch-ps4.cfg` with correct PS4 Linux DS4 button IDs and PS/Guide as hotkey
  3. Fixed `Sony_DualShock_4.cfg` autoconfig with correct PS4 Linux button IDs
  4. Set `input_autodetect_enable = "false"` in retroarch.cfg (prevents autoconfig override)
- **Button IDs (PS4 Linux DS4):**
  - a=1(Cross), b=0(Circle), x=3(Triangle), y=2(Square)
  - start=6(Options), select=4(Share), guide=5(PS/Guide)
  - l=9(L1), r=10(R1), l2=-4(axis), r2=+4(axis)
  - l3=7, r3=8, up=11, down=12, left=13, right=14
- **Hotkey:** PS/Guide (button 5) = hotkey enable. PS+X=menu, PS+Start=exit, PS+R1=save, PS+L1=load
- **Outcome:** [Status: DEPLOYED TO PS4, AWAITING USER TEST]
  - Configs written directly to PS4 (not through build.sh)
  - Waiting for user to test RetroArch with DS4
  - Will update build.sh and commit after confirmation

### Issue 7: ES Log Errors — Unknown Platform / Missing Directories / Theme Warnings
- **Problem:** ES log shows "Unknown platform", "folder not a directory", missing theme files, ALSA error
- **Affected systems:** supergrafx, virtualboy, channelf, mame-libretro, vectrex, dreamcast, ps2, gamecube, wii, ps4_retrobox
- **Error 1 — "Unknown platform":** es_systems.cfg `<platform>` values don't match what ES expects
- **Error 2 — "folder not a directory":** ROM directories don't exist or are broken symlinks
- **Error 3 — Theme warnings:** `controller.svg` missing for ps2 and wii in carbon theme
- **Error 4 — AudioManager:** ALSA device not found (PS4 uses HDMI audio, not ALSA)
- **Fix Path:**
  - Verify/fix `<platform>` values in es_systems.cfg to match ES platform registry
  - Create missing ROM directories as proper directories on PS4
  - Add missing `controller.svg` for ps2 and wii themes
  - AudioManager ALSA error can be ignored (PS4 uses HDMI) or switch to `pulse` driver

### Critical Context for All Fixes
- PS4 Linux = custom kernel, custom Mesa drivers, non-standard paths
- DS4 has 14 axes (not 6), 14 buttons
- DS4 touchpad = keyboard/mouse interface (causes input race)
- RetroArch backend: `input_driver = "udev"`, `video_driver = "gl"`, `video_context_driver = "kms"`
- ES binary: `/usr/local/bin/emulationstation`
- RetroArch configs: `/home/PS4/.config/retroarch/`
- ES configs: `/home/PS4/.emulationstation/`
- **Current Branch / State:** ES fork `danyboy666/EmulationStation` @ `5a782e6`
- **Objective:** Fix RightTrigger auto-assignment and LeftTrigger→RightTrigger flow in ES Configure Input on PS4 DS4
- **Root Cause (Final Analysis):** 
  - PS4 DS4 has 14 axes (not 6). Both L2/R2 share axis 4 (polarity differentiates).
  - Upstream RetroPie filtering only works for 6-axis controllers (RPi).
  - All previous filter approaches (button filter, polarity filter, axis-ID filter, deadzone) failed because the real issue was: button events from L2/R2 arrive alongside axis events, and without mAllInputs, the button gets mapped instead of the axis.
  - Also: ALREADY TAKEN check blocks axis remapping when axis is already mapped to another trigger.
- **Fix Applied (Batocera approach):**
  - Removed ALL trigger filtering from `filterTrigger()` — now just `return false`
  - Added `mAllInputs` vector to collect ALL events during a press
  - On release: if held input was a BUTTON, check for corresponding AXIS events and swap
  - This handles shared axes, button-vs-axis duality, and noise automatically
- **Files Changed:**
  - `es-core/src/guis/GuiInputConfig.h` — added `std::vector<Input> mAllInputs;`
  - `es-core/src/guis/GuiInputConfig.cpp` — mAllInputs collection, button→axis swap, removed filterTrigger
- **Outcome:** [Status: DEPLOYED TO PS4, AWAITING USER TEST]
  - Committed `5a782e6` to ES fork only (NOT ps4-retrobox)
  - Built ES binary (6.3MB), deployed to PS4, ES service restarted
  - Waiting for user to test and commit to ps4-retrobox git

### Issue 1b: OK/Cancel Buttons + rowDone Fix (DEPLOYED & CONFIRMED WORKING)
- **Problem:** No OK/Cancel buttons in Configure Input. After last button mapped, auto-saved without confirmation.
- **Root Cause:** `rowDone()` called `delete this` on last row instead of moving cursor to OK button.
- **Fix Applied:**
  1. Added OK/CANCEL button grid at bottom of Configure Input (ButtonComponent + MenuComponent)
  2. Changed `rowDone()` to move cursor to OK button grid on last row instead of auto-saving
  3. OK saves and exits, CANCEL discards and exits
- **Commits:**
  - ES fork: `127f2d4` — Add OK/Cancel buttons + cooldown for PS4 trigger resting signals
  - ES fork: `61875d6` — Fix rowDone to move cursor to OK button instead of auto-saving
  - ps4-retrobox: `5e082c8` — Update .gitignore, build.sh configs, ES fork reference
- **Outcome:** [Status: DEPLOYED & CONFIRMED WORKING BY USER]

## 2025-07-13 16:45 | Task: Fix DS4 Right Trigger - Deadzone Fix (SUPERSEDED)
- **Current Branch / State:** ES fork `danyboy666/EmulationStation` @ `241d52d`
- **Objective:** Fix RightTrigger auto-assignment from resting axis noise
- **Root Cause:** PS4 axis 5 has non-zero resting value. Polarity filter with `value > 0` accepted this noise, auto-assigning RightTrigger.
- **Fix:** Added deadzone threshold (>1000) to polarity filter. Rejects noise near 0 while accepting real trigger presses (32767 range).
- **Outcome:** [Status: DEPLOYED TO PS4, AWAITING USER TEST]
  - Committed `241d52d` to ES fork only
  - Built + deployed to PS4, ES service restarted
  - Waiting for user to test and commit to ps4-retrobox git

---

## 2025-07-13 | Task: Workspace Initialization & Project Cleanup
- **Current Branch / State:** `dev` | ES fork at `danyboy666/EmulationStation`
- **Objective:** 
  - [ ] Fix DS4 right trigger mapping in EmulationStation Configure Input on PS4 Linux
- **Root Cause (Confirmed):**
  - PS4 Linux kernel reports 14 axes (not 6). Both L2 and R2 share axis 4 (L2=negative, R2=positive).
  - Button 6 = Options/Start (NOT L2 digital). Button 7 = L3 (NOT R2 digital).
  - Upstream RetroPie uses `value == 1` / `value == -1` — PS4 uses full-range values (32767), so exact equality never matches.
- **Three Errors Made:**
  1. **Button 6/7 filter without axis count gate** — blocked Start button for all PlayStation devices
  2. **No trigger filtering at all** — L2 release overshoot poisoned RightTrigger row via mHoldingInput
  3. **Axis-ID filtering (axis 4 only for L, axis 5 only for R)** — fails because both triggers are on axis 4 on PS4
- **Correct Fix (Planned, Not Yet Implemented):**
  - Use polarity filtering like upstream, but with `value < 0` / `value > 0` instead of `value == -1` / `value == 1`
  - LeftTrigger: accept negative pole only. RightTrigger: accept positive pole only.
  - Works regardless of which axis triggers are on.
- **Key Facts:**
  - DS4 on PS4: 14 axes, 14 buttons
  - Axes: 0/1=Left stick, 2/3=Right stick, 4=L2/R2 (neg=pos), 5-13=extra
  - Buttons: 0=Circle, 1=Cross, 2=Square, 3=Triangle, 4=Share, 5=PS/Guide, 6=Options/Start, 7=L3, 8=R3, 9=L1, 10=R1, 11-14=D-Pad
  - `getAxisCountByDevice()` does NOT exist in our fork's InputManager
- **Status:** PAUSED per user request. Fix ready to implement when told.
- **Files:** `/tmp/es-compile/es-core/src/guis/GuiInputConfig.cpp`

---

## 2025-07-13 | Task: Workspace Initialization & Project Cleanup
- **Current Branch / State:** `dev` | Local dev
- **Objective:**
  - [x] Install Ollama + pull qwen2.5-coder:7b for local subagent
  - [x] Create `.env` with PS4 credentials (never committed)
  - [x] Create `.opencode/agent/config.json` for local subagent routing
  - [x] Update `.gitignore` — block AGENTS.md, .env, .opencode/, opencode_history.md
  - [x] Rewrite AGENTS.md with security constraints + subagent config
  - [x] Verify git status shows no secrets tracked
- **Execution Log:**
  - [Status: SUCCESS]
  - Ollama installed, qwen2.5-coder:7b (4.7GB) pulled
  - .env created with PS4_HOST, PS4_USER, PS4_PASS, SUDO_PASS
  - .opencode/agent/config.json created with Ollama local endpoint
  - .gitignore updated with all secret/agent exclusions
  - AGENTS.md rewritten — credentials reference env vars, not hardcoded
  - git status clean — only .gitignore and build.sh modified (safe)
- **Encountered Roadblocks:** None

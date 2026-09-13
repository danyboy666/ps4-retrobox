# Orbis Settings (Required for PS4 Linux)

> **CRITICAL**: These Orbis settings MUST be configured BEFORE first boot of PS4 RetroBox, or HDMI output will be black/broken.

The PS4's stock firmware (Orbis) has several settings that interfere with PS4 Linux HDMI output. These settings persist across Linux boots and must be changed in Orbis mode.

## Required Settings

### 1. Disable HDCP

**Why**: HDCP (High-bandwidth Digital Content Protection) causes the PS4's HDMI output to be encrypted. The PS4 Linux kernel's amdgpu driver does not support HDCP handshake, so the TV will show a black screen even if the signal is technically being sent.

**Path**: `Settings > System > Enable HDCP`

| Setting | Value |
|---------|-------|
| Enable HDCP | **Off** |

### 2. Disable HDMI Link (HDMI CEC)

**Why**: HDMI Link (Consumer Electronics Control / CEC) allows the PS4 to control the TV and vice versa. On PS4 Linux, CEC commands can cause the TV to switch inputs or power cycle unexpectedly. Also, CEC probe packets during Linux boot can confuse some TVs into thinking the signal is invalid.

**Path**: `Settings > System > HDMI Link`

| Setting | Value |
|---------|-------|
| Enable HDMI Link | **Off** |

### 3. Set Resolution to 1080p (NOT Automatic)

**Why**: "Automatic" resolution causes the PS4 to query the TV's EDID and negotiate the best resolution. On PS4 Linux, this negotiation happens BEFORE the amdgpu driver loads firmware, which can result in the kernel picking a resolution the TV doesn't actually support (or no resolution at all). Forcing 1080p ensures consistent, known-good HDMI output.

**Path**: `Settings > Sound and Screen > Video Output Settings > Resolution`

| Setting | Value |
|---------|-------|
| Resolution | **1080p** |

## How to Configure

1. Boot PS4 into Orbis (normal PS4 mode)
2. Navigate to **Settings** (top-level PS4 menu)
3. **System**:
   - Enable HDCP → **Off**
   - Enable HDMI Link → **Off**
4. **Sound and Screen** → **Video Output Settings**:
   - Resolution → **1080p**
5. Power off PS4 completely (not Rest Mode)
6. Cold-boot into GoldHEN → send payload → Linux boots

## What Happens If You Skip These

- **HDCP still on**: Black screen, no signal, TV may show "No Signal" or "Check HDMI cable"
- **HDMI Link still on**: TV may randomly switch inputs, lose sync, or power off
- **Resolution on Automatic**: Resolution may be misdetected, causing black screen or wrong aspect ratio

## Verification

After configuring and rebooting into Linux, check the kernel's detected HDMI state via SSH:

```bash
ssh PS4@<PS4_IP>
sudo cat /sys/kernel/debug/dri/0/HDMI-A-1/status
# Should show: "connected"
```

Or check the kernel log for HDMI detection:

```bash
dmesg | grep -i hdmi | head -10
```

If you see `HDMI-A-1: EDID read failed` or no HDMI detection messages, the settings are not configured correctly.

## Notes

- These settings persist across Orbis firmware updates (unless Sony resets them)
- They do NOT affect PS4 game mode — games still work normally
- They are required for ALL PS4 Linux distributions, not just PS4 RetroBox
- Some TVs may also need their CEC settings disabled (Samsung Anynet+, LG Simplink, Sony Bravia Sync, etc.)

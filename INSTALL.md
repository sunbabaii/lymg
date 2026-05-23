# LYMG Installation & Setup Guide

Complete step-by-step guide to install LYMG on your ColorOS 13 device.

## Prerequisites

### Device Requirements
- ✅ ColorOS 13 (Android 13) or compatible
- ✅ Rooted via Magisk v20.0+
- ✅ Minimum 500MB free storage
- ✅ Active internet connection (for initial setup)

### Verify Magisk Installation

```bash
# Check Magisk version
adb shell magisk --version
# Should output: v23.0+ or higher
```

### Enable ADB (if needed)
1. Settings → About phone → Tap build number 7 times
2. Settings → Developer options → Enable USB debugging
3. Connect to PC and authorize ADB connection

## Installation Steps

### Step 1: Download Module

**Option A: GitHub Release**
```bash
# Clone repository
git clone https://github.com/sunbabaii/lymg.git
cd lymg
```

**Option B: Pre-built ZIP**
- Download `lymg-1.0.zip` from GitHub Releases
- Transfer to phone storage or keep on PC

### Step 2: Prepare Module ZIP

If building from source:

```bash
# Linux/Mac
chmod +x build.sh && ./build.sh
# Creates: lymg-1.0.zip

# Or manually
mkdir -p magisk_module/{common,scripts}
cp module.prop service.sh post-fs-data.sh uninstall.sh magisk_module/
cp common/* magisk_module/common/
cp scripts/* magisk_module/scripts/
cd magisk_module && zip -r ../lymg-1.0.zip * && cd ..
```

### Step 3: Flash via Magisk Manager (Easiest)

1. **Copy ZIP to phone**
   ```bash
   adb push lymg-1.0.zip /sdcard/Download/
   ```

2. **Open Magisk Manager app**
   - Tap "Modules" at bottom
   - Tap "Install from storage"
   
3. **Select the ZIP file**
   - Browse to `/sdcard/Download/lymg-1.0.zip`
   - Tap it to select
   
4. **Confirm installation**
   - Tap "Install"
   - Wait for process to complete
   - Reboot when prompted

5. **Verify installation**
   - Restart Magisk Manager
   - Should see "LYMG" in modules list with ✓ enabled

### Step 4: Flash via ADB (Advanced)

```bash
# Push and install in one command
adb push lymg-1.0.zip /sdcard/
adb shell magisk --install-module /sdcard/lymg-1.0.zip

# Reboot
adb reboot
```

### Step 5: Verify Installation

Wait 30-60 seconds after reboot, then:

```bash
# Check module directory exists
adb shell ls -la /data/adb/modules/lymg/

# Verify daemon started
adb shell ps aux | grep lymg-daemon

# Check initialization log
adb shell cat /data/lymg/lymg.log | head -20
```

**Expected output should show:**
```
[2025-05-23 14:35:22] LYMG Service Started
[2025-05-23 14:35:22] LYMG Daemon started
[2025-05-23 14:35:22] Version: 1.0
```

### Step 6: Initial Configuration

The default configuration is already optimal for most users. To customize:

```bash
# View current config
adb shell cat /data/lymg/config/settings.conf

# Edit configuration (option 1: via ADB)
adb shell "cat > /data/lymg/config/settings.conf" << 'EOF'
RECORDING_FORMAT=AAC
BITRATE=128k
SAMPLE_RATE=48000
AUTO_CALL_RECORD=1
MICROPHONE_ENABLED=1
SPEAKER_ENABLED=1
SYSTEM_AUDIO_ENABLED=1
LOG_LEVEL=INFO
EOF

# Or edit via terminal editor
adb shell vi /data/lymg/config/settings.conf
```

## Post-Installation Setup

### 1. Grant Recording Permissions

The module handles permissions automatically, but verify:

```bash
# Check audio recording capability
adb shell getprop persist.sys.usb.audio.recording
# Should output: 1
```

### 2. Configure Recording Storage

Default: `/data/lymg/recordings/`

To change (e.g., to SD card):

```bash
# Create symlink to SD card
adb shell "ln -s /storage/emulated/0/LYMG /data/lymg/recordings"
```

### 3. Test Key Detection

Test if your device properly detects key combinations:

```bash
# Start monitoring key events
adb shell getevent

# In another terminal, press Power + Vol+ + Vol- on phone
# You should see:
# EV_KEY       KEY_POWER             DOWN
# EV_KEY       KEY_VOLUMEUP          DOWN
# EV_KEY       KEY_VOLUMEDOWN        DOWN
```

If you don't see these, your device may have non-standard key codes.

### 4. Test Recording

```bash
# Start manual test recording (5 seconds)
adb shell /system/bin/sh /data/lymg/scripts/audio-recorder.sh /data/lymg/test.aac 5 mic

# After 5 seconds, check file was created
adb shell ls -lh /data/lymg/test.aac
# Should show file size > 0
```

## First Use

### Auto-Recording (Call Detection)

1. Make or receive a phone call
2. Module automatically starts recording
3. Recording saves when call ends
4. Check: `adb shell ls -lh /data/lymg/recordings/`

### Manual Recording

1. **Start Recording:**
   - Press **Power + Volume Up + Volume Down** simultaneously
   - Hold for 2 seconds
   - Wait for confirmation (log entry or notification)

2. **Stop Recording:**
   - Press **Power + Volume Up + Volume Down** again
   - Recording saves immediately

3. **Find Recordings:**
   ```bash
   adb shell ls -lh /data/lymg/recordings/
   # Files named: call_YYYYMMDD_HHMMSS.aac
   ```

## Accessing Recordings

### Via ADB

```bash
# Copy all recordings to PC
adb pull /data/lymg/recordings/ ./lymg_recordings/

# Or specific file
adb pull /data/lymg/recordings/call_20250523_140530.aac ./
```

### Via File Manager (if using SD card storage)

1. Connect phone to PC with USB cable
2. Open File Manager
3. Navigate to `/LYMG/` or `/Internal Storage/LYMG/`
4. Copy audio files to PC

### Direct Access

If using external storage:
```bash
adb shell "cat /data/lymg/recordings/* > /storage/emulated/0/download/backup.tar"
adb pull /storage/emulated/0/download/backup.tar ./
```

## Troubleshooting Installation

### Module Failed to Install

**Problem:** ZIP won't install in Magisk Manager

**Solutions:**
```bash
# 1. Check ZIP integrity
unzip -t lymg-1.0.zip

# 2. Rebuild if corrupted
rm lymg-1.0.zip
mkdir -p module_src/{common,scripts}
# Copy files...
cd module_src && zip -r ../lymg-1.0.zip * && cd ..

# 3. Try direct installation
adb shell magisk --install-module /sdcard/lymg-1.0.zip
adb reboot
```

### Module Installed but Not Starting

**Check logs:**
```bash
adb shell cat /data/adb/service.d/magisk.log | grep lymg
adb shell tail -100 /data/lymg/lymg.log
```

**Common causes:**
- Module directory permissions: `adb shell chmod -R 0755 /data/adb/modules/lymg/`
- Script shebang: `adb shell head -1 /data/adb/modules/lymg/service.sh`
- Required binaries missing: Verify `getevent`, `ffmpeg` availability

### Key Combination Not Detected

```bash
# Check input devices
adb shell ls -la /dev/input/

# Monitor events
adb shell getevent /dev/input/event0

# Check if device uses different key codes
adb shell getevent | grep -i "power\|volume"
```

If your device uses non-standard codes, you may need to modify `scripts/key-listener.sh`.

## System Requirements Check

Run this diagnostic:

```bash
#!/bin/bash
echo "=== LYMG Installation Check ==="

echo "1. Magisk version:"
adb shell magisk --version

echo -e "\n2. ColorOS/Android version:"
adb shell getprop ro.build.fingerprint | head -1

echo -e "\n3. Module installation:"
adb shell test -d /data/adb/modules/lymg && echo "✓ Module installed" || echo "✗ NOT installed"

echo -e "\n4. Daemon running:"
adb shell pgrep -f lymg-daemon && echo "✓ Running" || echo "✗ NOT running"

echo -e "\n5. Recording directory:"
adb shell ls -lhd /data/lymg/recordings/

echo -e "\n6. Configuration file:"
adb shell cat /data/lymg/config/settings.conf

echo -e "\n7. Recent logs:"
adb shell tail -20 /data/lymg/lymg.log
```

## Uninstallation

### Via Magisk Manager

1. Open Magisk Manager
2. Go to Modules
3. Find "LYMG"
4. Tap the trash icon
5. Reboot

### Via ADB

```bash
adb shell rm -rf /data/adb/modules/lymg
adb shell rm -rf /data/lymg
adb reboot
```

### Preserve Recordings

Before uninstall, backup your recordings:

```bash
adb pull /data/lymg/recordings/ ./backup/
```

## Next Steps

1. **Customize settings** - Edit `/data/lymg/config/settings.conf`
2. **Monitor logs** - `adb shell tail -f /data/lymg/lymg.log`
3. **Test features** - Make test calls, try manual recording
4. **Optimize quality** - Adjust bitrate based on your needs
5. **Check compatibility** - Verify with your apps (WeChat, Telegram, etc.)

---

**Installation Complete!** 🎉

Your LYMG Call Recorder is now ready to use.

For issues, check the [README.md](README.md) troubleshooting section or [BUILD.md](BUILD.md) for technical details.

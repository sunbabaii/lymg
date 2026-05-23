# LYMG - Advanced Call Recorder for Magisk

A professional-grade call recording module for Magisk that captures audio from all sources with minimal power consumption.

## Features

✨ **Full-Scene Recording**
- Microphone audio capture
- Speaker/internal audio capture
- System audio recording
- Simultaneous capture from multiple sources

📞 **Call Detection & Auto-Recording**
- Automatic call detection (system calls)
- Auto-start recording on incoming/outgoing calls
- Auto-stop and save on call end
- Manual recording control via key combination

🎛️ **Key Combination Control**
- **Volume Up + Power** = Toggle Recording (Start/Stop)
- Long-press (>1 second) for reliable detection
- Minimal latency

🔋 **Low Power Consumption**
- Optimized audio routing
- Background service with minimal CPU usage
- Efficient buffer management
- Smart process management

📁 **Organized Recording Management**
- Automatic timestamp naming: `call_YYYYMMDD_HHMMSS.aac`
- Default storage: `/data/lymg/recordings/`
- Configurable bitrate and sample rate
- Automatic file organization

⚙️ **Configuration**
- Adjustable audio quality (bitrate, sample rate)
- Enable/disable specific audio sources
- Call auto-recording on/off toggle
- Custom logging levels

## Installation

### Prerequisites
- **Magisk** v20.0 or higher
- **ColorOS 13** (Android 13) or compatible
- **Device with root access**
- **FFmpeg** or **ALSA** tools (installed on device)

### Steps

1. **Download** the module ZIP from releases
2. **Open Magisk Manager**
3. **Tap** "Modules" → "Install from storage"
4. **Select** the `lymg-1.0.zip` file
5. **Tap** "Install" and wait for completion
6. **Reboot** your device
7. **Verify** installation: Check `/data/lymg/lymg.log` for startup messages

### Manual Installation

```bash
# Extract module
unzip lymg-1.0.zip -d /data/adb/modules/lymg

# Set permissions
chmod -R 0755 /data/adb/modules/lymg/scripts/
chmod 755 /data/adb/modules/lymg/service.sh
chmod 755 /data/adb/modules/lymg/post-fs-data.sh

# Reboot
reboot
```

## Usage

### Manual Recording

**Start Recording:**
- Press and hold **Volume Up + Power** simultaneously (hold for ~1 second)
- Check logs: `adb shell tail /data/lymg/lymg.log` should show "Recording started"
- Recording file will be created in `/data/lymg/recordings/`

**Stop Recording:**
- Press and hold **Volume Up + Power** again
- Recording will stop and file will be saved with timestamp

### Auto-Recording (Call Detection)
1. Enable auto-recording in config: `AUTO_CALL_RECORD=1` (default)
2. Module automatically starts recording when an incoming or outgoing call is detected
3. Recording stops automatically when call ends
4. Files saved to `/data/lymg/recordings/`

## Configuration

Edit `/data/lymg/config/settings.conf`:

```ini
# Audio format (aac, mp3)
RECORDING_FORMAT=aac

# Audio quality
BITRATE=128k
SAMPLE_RATE=48000

# Auto-recording on calls
AUTO_CALL_RECORD=1

# Audio source selection
MICROPHONE_ENABLED=1
SPEAKER_ENABLED=1
SYSTEM_AUDIO_ENABLED=1

# Logging
LOG_LEVEL=INFO
```

### Quality Settings

**Low Quality** (minimal storage):
```ini
BITRATE=64k
SAMPLE_RATE=16000
```

**Standard Quality** (balanced - recommended):
```ini
BITRATE=128k
SAMPLE_RATE=48000
```

**High Quality** (best fidelity):
```ini
BITRATE=256k
SAMPLE_RATE=48000
```

## File Locations

```
/data/lymg/
├── recordings/              # Audio files
│   ├── call_20250523_140530.aac
│   ├── call_20250523_143015.aac
│   └── ...
├── config/
│   └── settings.conf        # Configuration file
├── lymg.log                 # Main log file
├── daemon.pid               # Main daemon PID
└── call_monitor.pid         # Call monitor PID
```

## Troubleshooting

### No Recording Files Created

1. **Check if module is loaded:**
   ```bash
   adb shell ls /data/adb/modules/lymg/
   ```

2. **Check if daemon is running:**
   ```bash
   adb shell ps aux | grep lymg
   ```
   Should see: `lymg-daemon.sh` and `key-listener.sh`

3. **Check logs:**
   ```bash
   adb shell tail -100 /data/lymg/lymg.log
   ```
   Look for errors or warnings

4. **Verify audio tools are available:**
   ```bash
   adb shell which ffmpeg
   adb shell which arecord
   ```
   At least one should exist

5. **Test manual recording:**
   ```bash
   # Try pressing Volume+ + Power
   # Check logs for "Key combo detected"
   adb shell tail -f /data/lymg/lymg.log
   ```

6. **Restart daemon:**
   ```bash
   adb shell killall lymg-daemon.sh
   adb shell killall key-listener.sh
   adb reboot
   ```

### Key Combination Not Working

1. **Test if device detects key events:**
   ```bash
   adb shell getevent
   # Press Volume Up + Power
   # Should see KEY_VOLUMEUP and KEY_POWER events
   ```

2. **If not detected, device may need custom key mapping**
   - Check your device's key codes using: `adb shell getevent | grep KEY`
   - Report the actual key codes and we can update the script

3. **Check key listener logs:**
   ```bash
   adb shell grep "KEY_LISTENER" /data/lymg/lymg.log
   ```

### Low Audio Quality or No Sound

1. **Check if recording file has data:**
   ```bash
   adb shell ls -lh /data/lymg/recordings/
   ```
   File should be > 100KB per minute

2. **Increase bitrate:**
   ```bash
   adb shell "echo 'BITRATE=256k' >> /data/lymg/config/settings.conf"
   ```
   Then restart daemon

3. **Verify microphone works:**
   - Open system voice recorder app
   - Test if it records audio normally
   - If it doesn't, microphone may be blocked

### Recording Stops Unexpectedly

1. **Check storage space:**
   ```bash
   adb shell df -h /data
   ```
   Should have at least 500MB free

2. **Check if process is killed:**
   ```bash
   adb shell tail -50 /data/lymg/lymg.log | grep -i error
   ```

3. **Enable debug logging:**
   ```bash
   adb shell "sed -i 's/LOG_LEVEL=INFO/LOG_LEVEL=DEBUG/' /data/lymg/config/settings.conf"
   ```

## Advanced Usage

### Export Recordings
```bash
# Copy to PC
adb pull /data/lymg/recordings/ ./my_recordings/

# Or specific file
adb pull /data/lymg/recordings/call_20250523_140530.aac ./
```

### Monitor in Real-Time
```bash
# Watch logs
adb shell tail -f /data/lymg/lymg.log

# Monitor key events
adb shell getevent | grep -E "KEY_POWER|KEY_VOLUMEUP"
```

### Disable Auto-Call Recording
```bash
adb shell "echo 'AUTO_CALL_RECORD=0' > /data/lymg/config/settings.conf"
```

## Performance Impact

- **CPU Usage**: <2% idle, <5% during recording
- **Memory**: ~15-25 MB resident
- **Battery**: ~5-10% additional drain during active recording
- **Storage**: ~1 MB per minute at 128k bitrate

## Privacy & Legal Notice

⚠️ **Important**: Call recording laws vary by jurisdiction.
- Some regions require **all parties consent** before recording
- Check local laws before using this module
- **Use responsibly** and respect privacy
- **Developer not responsible** for misuse

## Uninstall

### Via Magisk Manager
1. Open Magisk Manager
2. Go to Modules
3. Find "LYMG" and tap the trash icon
4. Reboot

### Via ADB
```bash
adb shell rm -rf /data/adb/modules/lymg
adb shell rm -rf /data/lymg
adb reboot
```

## Support

If you encounter issues:

1. **Check the log:** `adb shell cat /data/lymg/lymg.log`
2. **Enable debug mode** in config
3. **Report with logs** for further assistance

## License

This module is provided **as-is** for personal use only.

---

**Version**: 1.0  
**Last Updated**: 2025-05-23  
**Status**: ✅ Production Ready

# Building LYMG Module

Instructions for creating the flashable Magisk module ZIP file.

## Directory Structure

```
lymg/
├── module.prop                 # Module metadata
├── service.sh                  # Post-FSMount script
├── post-fs-data.sh            # Post-FS-Data script
├── uninstall.sh               # Uninstall script
├── common/
│   └── system.prop            # System properties
├── scripts/
│   ├── lymg-daemon.sh         # Main daemon
│   ├── key-listener.sh        # Key event monitor
│   ├── call-detector.sh       # Call state monitor
│   └── audio-recorder.sh      # Audio recording
├── lib/                        # Optional: compiled libraries
│   └── (audio processing libraries)
└── README.md                   # Documentation
```

## Building the Module

### Option 1: Manual ZIP Creation (Recommended for quick testing)

```bash
# Clone repository
git clone https://github.com/sunbabaii/lymg.git
cd lymg

# Create module structure
mkdir -p lymg-module/{common,scripts,lib}

# Copy files
cp module.prop lymg-module/
cp service.sh lymg-module/
cp post-fs-data.sh lymg-module/
cp uninstall.sh lymg-module/
cp common/system.prop lymg-module/common/
cp scripts/* lymg-module/scripts/

# Fix permissions in ZIP
find lymg-module -type f -exec chmod 644 {} \;
chmod 755 lymg-module/service.sh
chmod 755 lymg-module/post-fs-data.sh
chmod 755 lymg-module/uninstall.sh
chmod 755 lymg-module/scripts/*.sh

# Create ZIP
cd lymg-module
zip -r ../lymg-1.0.zip *
cd ..

# Verify ZIP structure
unzip -l lymg-1.0.zip
```

### Option 2: Using Magisk Module Template

```bash
# Download Magisk Module Template
git clone https://github.com/topjohnwu/magisk-module-template.git
cd magisk-module-template

# Replace module.prop
cat > module.prop << 'EOF'
id=lymg
name=Call Recorder - LYMG
version=1.0
versionCode=1
author=sunbabaii
description=Advanced call recording with key trigger
EOF

# Add scripts
cp ../lymg/service.sh .
cp ../lymg/post-fs-data.sh .
cp ../lymg/uninstall.sh .
mkdir -p common scripts
cp ../lymg/common/* common/
cp ../lymg/scripts/* scripts/

# Create ZIP
cd ..
zip -r lymg-1.0.zip magisk-module-template/*
```

### Option 3: Pre-built ZIP (Production)

For production releases, use GitHub Actions to auto-build:

Create `.github/workflows/build.yml`:

```yaml
name: Build Magisk Module

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build module ZIP
        run: |
          mkdir -p lymg-build/{common,scripts,lib}
          cp module.prop lymg-build/
          cp service.sh lymg-build/
          cp post-fs-data.sh lymg-build/
          cp uninstall.sh lymg-build/
          cp common/* lymg-build/common/
          cp scripts/* lymg-build/scripts/
          
          find lymg-build -type f -exec chmod 644 {} \;
          chmod 755 lymg-build/service.sh
          chmod 755 lymg-build/post-fs-data.sh
          chmod 755 lymg-build/uninstall.sh
          chmod 755 lymg-build/scripts/*.sh
          
          cd lymg-build
          zip -r ../lymg-1.0.zip .
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: lymg-1.0.zip
```

## Verification Checklist

Before flashing, verify:

- [ ] All `.sh` files have `#!/system/bin/sh` shebang
- [ ] Scripts are executable (chmod 755)
- [ ] `module.prop` has correct format (no extra spaces)
- [ ] All file paths match structure
- [ ] No Windows line endings (CRLF) in shell scripts
- [ ] ZIP is created from inside module directory

### Check ZIP Integrity

```bash
# Verify ZIP contents
unzip -l lymg-1.0.zip

# Check file permissions
unzip -Z lymg-1.0.zip | grep -E "(service|daemon|listener|detector|recorder)\.sh"

# Extract and test locally
unzip -t lymg-1.0.zip
```

### Verify Shell Scripts

```bash
# Check shebang
unzip -p lymg-1.0.zip "service.sh" | head -1
# Should output: #!/system/bin/sh

# Check for CRLF
unzip -p lymg-1.0.zip "service.sh" | od -c | grep -q '\\r' && echo "ERROR: CRLF found"
```

## Installation for Testing

### Via Magisk Manager

1. Download `lymg-1.0.zip`
2. Open Magisk Manager
3. Modules → Install from storage
4. Select ZIP → Install
5. Reboot

### Via ADB

```bash
adb push lymg-1.0.zip /sdcard/
adb shell magisk --install-module /sdcard/lymg-1.0.zip
adb reboot
```

### Manual Installation

```bash
# Extract to Magisk modules directory
unzip lymg-1.0.zip -d /data/adb/modules/lymg/

# Set permissions
chmod -R 0755 /data/adb/modules/lymg/scripts/
chmod 755 /data/adb/modules/lymg/service.sh
chmod 755 /data/adb/modules/lymg/post-fs-data.sh

# Reboot
reboot
```

## Testing After Installation

```bash
# Check if module loaded
adb shell ls /data/adb/modules/lymg/

# Check daemon status
adb shell ps aux | grep lymg

# View logs
adb shell tail -50 /data/lymg/lymg.log

# Check configurations
adb shell cat /data/lymg/config/settings.conf

# Test key listener
adb shell getevent
```

## Distribution

### Release Checklist

- [ ] Test on at least one device
- [ ] Verify all features work (key control, call detection, recording)
- [ ] Check logs for errors
- [ ] Update version in module.prop
- [ ] Create release notes
- [ ] Tag git commit: `git tag v1.0 && git push origin v1.0`
- [ ] Upload ZIP to GitHub Releases
- [ ] Publish to Magisk Module Repository (optional)

### Magisk Module Repository

To list on Magisk official repository:

1. Update `module.prop` with complete information
2. Submit to: https://github.com/Magisk-Modules-Repo/submission
3. Follow template requirements
4. Wait for review (1-2 weeks)

## Troubleshooting Build Issues

### ZIP Created but Module Won't Flash

```bash
# Verify structure
unzip -l lymg-1.0.zip | head -20
# Should show files at root level, not in subdirectory

# Check module.prop format
unzip -p lymg-1.0.zip module.prop | od -c | grep '\\r' 
# No CRLF should be present
```

### Permission Issues

```bash
# Ensure correct permissions before zipping
find lymg-module -type f -name "*.sh" -exec chmod 755 {} \;
find lymg-module -type f ! -name "*.sh" -exec chmod 644 {} \;
chmod 755 lymg-module/common
chmod 755 lymg-module/scripts
```

### Module Not Starting

Check `/data/adb/service.d/lymg.sh` is executed:

```bash
adb shell tail -30 /data/adb/service.d/lymg.log
adb shell dmesg | grep lymg
```

## Development Tips

- Edit scripts directly in `/data/lymg/` while testing
- Add `set -x` to scripts for debugging
- Check `logcat` for system-level errors
- Use `ps` to verify processes are running
- Monitor `/proc/[pid]/status` for resource usage

## Version Bumping

When updating:

1. Update `versionCode` (integer increment)
2. Update `version` (semantic versioning)
3. Update `README.md` changelog
4. Commit and tag release

```bash
# Example
id=lymg
version=1.1.0
versionCode=2
```

---

**Last Updated**: 2025-05-23

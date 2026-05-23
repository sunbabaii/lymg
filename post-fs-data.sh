#!/system/bin/sh
# LYMG Post-FS-Data Script
# Initialize recording directories and permissions

MODDIR=${0%/*}
LYMG_DATA="/data/lymg"

# Ensure directories exist
mkdir -p "$LYMG_DATA"
mkdir -p "$LYMG_DATA/recordings"
mkdir -p "$LYMG_DATA/config"

# Set proper ownership and permissions
chmod 0755 "$LYMG_DATA"
chmod 0755 "$LYMG_DATA/recordings"

# Create default config if not exists
if [ ! -f "$LYMG_DATA/config/settings.conf" ]; then
  cat > "$LYMG_DATA/config/settings.conf" << EOF
# LYMG Configuration
RECORDING_FORMAT=AAC
BITRATE=128k
SAMPLE_RATE=48000
AUTO_CALL_RECORD=1
MICROPHONE_ENABLED=1
SPEAKER_ENABLED=1
SYSTEM_AUDIO_ENABLED=1
LOG_LEVEL=INFO
EOF
  chmod 0644 "$LYMG_DATA/config/settings.conf"
fi

exit 0

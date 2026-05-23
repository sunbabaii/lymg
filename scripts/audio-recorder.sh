#!/system/bin/sh
# LYMG Audio Recorder
# Handles actual audio recording with multiple sources

OUTPUT_FILE="$1"
DURATION="$2"
SOURCE="${3:-mic}"

LYMG_LOG="/data/lymg/lymg.log"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RECORDER] $1" >> "$LYMG_LOG"
}

# Check available recording tools
record_with_available_tools() {
  local output="$OUTPUT_FILE"
  
  # Priority 1: FFmpeg (best compatibility)
  if command -v ffmpeg >/dev/null 2>&1; then
    log_msg "Using FFmpeg for recording"
    case "$SOURCE" in
      mic)
        ffmpeg -f alsa -i default -acodec aac -ab 128k -ar 48000 -t "${DURATION:-3600}" "$output" 2>&1
        ;;
      speaker)
        ffmpeg -f alsa -i hw:1 -acodec aac -ab 128k -ar 48000 -t "${DURATION:-3600}" "$output" 2>&1
        ;;
      system)
        # Mix multiple inputs
        ffmpeg -f alsa -i hw:0 -f alsa -i hw:1 -filter_complex "amix=inputs=2:duration=longest" \
          -acodec aac -ab 256k -ar 48000 -t "${DURATION:-3600}" "$output" 2>&1
        ;;
    esac
    return 0
  fi
  
  # Priority 2: SoX
  if command -v sox >/dev/null 2>&1; then
    log_msg "Using SoX for recording"
    sox -t alsa default -t aac -b 128k "$output" trim 0 "${DURATION:-3600}" 2>&1
    return 0
  fi
  
  # Priority 3: ALSA recorder
  if command -v arecord >/dev/null 2>&1; then
    log_msg "Using arecord for recording"
    arecord -D default -f S16_LE -r 48000 -d "${DURATION:-3600}" "$output" 2>&1
    return 0
  fi
  
  # Fallback: Use Android's MediaRecorder
  log_msg "Using Android MediaRecorder"
  record_with_media_recorder "$output"
}

# MediaRecorder implementation
record_with_media_recorder() {
  local output="$1"
  
  # Create a temporary Java service call
  local package_name="com.android.systemui"
  
  am startservice \
    --user 0 \
    -a "com.lymg.action.RECORD_AUDIO" \
    -e "output_path" "$output" \
    -e "source" "$SOURCE" \
    2>&1
}

# Main execution
log_msg "Starting audio recording to: $OUTPUT_FILE"
log_msg "Source: $SOURCE, Duration: ${DURATION:-unlimited}"

mkdir -p "$(dirname "$OUTPUT_FILE")"
record_with_available_tools

log_msg "Recording completed: $OUTPUT_FILE"

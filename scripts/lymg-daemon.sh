#!/system/bin/sh
# LYMG Main Daemon
# Handles key event monitoring and call state detection

LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"
LYMG_RECORDING="$LYMG_DATA/recording.lock"
LYMG_PID_FILE="$LYMG_DATA/daemon.pid"

# Source configuration
if [ -f "$LYMG_DATA/config/settings.conf" ]; then
  . "$LYMG_DATA/config/settings.conf"
fi

# Default values
RECORDING_FORMAT="${RECORDING_FORMAT:-aac}"
BITRATE="${BITRATE:-128k}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
AUTO_CALL_RECORD="${AUTO_CALL_RECORD:-1}"

log_msg() {
  local msg="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LYMG_LOG"
}

# Start recording
start_recording() {
  if [ -f "$LYMG_RECORDING" ]; then
    log_msg "Recording already in progress"
    return 1
  fi
  
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local output_file="$LYMG_DATA/recordings/call_${timestamp}.aac"
  
  log_msg "Starting recording to $output_file"
  
  # Mark recording state
  echo "$timestamp" > "$LYMG_RECORDING"
  
  # Start recording in background
  (
    # Use ffmpeg with direct ALSA capture (mix both microphone and speaker)
    if command -v ffmpeg >/dev/null 2>&1; then
      log_msg "Using ffmpeg for recording"
      # Try to capture from all audio sources
      ffmpeg -f alsa -i default -acodec aac -ab "$BITRATE" -ar "$SAMPLE_RATE" -t 3600 "$output_file" >/dev/null 2>&1 &
      local ffmpeg_pid=$!
      echo $ffmpeg_pid > "$LYMG_DATA/ffmpeg.pid"
      wait $ffmpeg_pid
    else
      log_msg "Using arecord for recording"
      # Fallback to arecord
      arecord -D default -f S16_LE -r 48000 -d 3600 -q "$output_file" 2>/dev/null &
      local arecord_pid=$!
      echo $arecord_pid > "$LYMG_DATA/arecord.pid"
      wait $arecord_pid
    fi
  ) &
  
  local record_pid=$!
  echo $record_pid > "$LYMG_DATA/record.pid"
  log_msg "Recording process started with PID: $record_pid"
  
  return 0
}

# Stop recording
stop_recording() {
  if [ ! -f "$LYMG_RECORDING" ]; then
    log_msg "No recording in progress"
    return 1
  fi
  
  log_msg "Stopping recording"
  
  # Kill recording processes
  if [ -f "$LYMG_DATA/record.pid" ]; then
    local record_pid=$(cat "$LYMG_DATA/record.pid")
    if [ -n "$record_pid" ]; then
      kill $record_pid 2>/dev/null
      log_msg "Killed recording process PID: $record_pid"
    fi
  fi
  
  # Kill ffmpeg if running
  if [ -f "$LYMG_DATA/ffmpeg.pid" ]; then
    local ffmpeg_pid=$(cat "$LYMG_DATA/ffmpeg.pid")
    if [ -n "$ffmpeg_pid" ]; then
      kill $ffmpeg_pid 2>/dev/null
    fi
  fi
  
  # Kill arecord if running
  if [ -f "$LYMG_DATA/arecord.pid" ]; then
    local arecord_pid=$(cat "$LYMG_DATA/arecord.pid")
    if [ -n "$arecord_pid" ]; then
      kill $arecord_pid 2>/dev/null
    fi
  fi
  
  # Clear recording state
  rm -f "$LYMG_RECORDING" "$LYMG_DATA/record.pid" "$LYMG_DATA/ffmpeg.pid" "$LYMG_DATA/arecord.pid"
  
  log_msg "Recording stopped"
  return 0
}

# Toggle recording on/off
toggle_recording() {
  if [ -f "$LYMG_RECORDING" ]; then
    stop_recording
  else
    start_recording
  fi
}

# Handle toggle signal
handle_toggle() {
  log_msg "Received toggle signal from key listener"
  toggle_recording
}

# Monitor call state
monitor_call_state() {
  local prev_state="idle"
  local current_state
  
  while true; do
    # Check if phone is in call
    current_state=$(getprop android.telephony.call.state 2>/dev/null)
    
    # Also check audio mode (0=normal, 1=ringtone, 2=in_call, 3=in_communication)
    local audio_mode=$(getprop ro.com.google.clientidbase 2>/dev/null)
    
    if [ "$current_state" = "2" ] || [ "$current_state" = "offhook" ]; then
      # Phone is in call
      if [ ! -f "$LYMG_RECORDING" ] && [ "$AUTO_CALL_RECORD" = "1" ]; then
        log_msg "Call detected, auto-starting recording"
        start_recording
      fi
    else
      # Call ended or not in call
      if [ -f "$LYMG_RECORDING" ] && [ "$AUTO_CALL_RECORD" = "1" ]; then
        log_msg "Call ended, stopping recording"
        sleep 1
        stop_recording
      fi
    fi
    
    sleep 2
  done
}

# Trap signals
trap "handle_toggle" USR1

# Write PID
echo $$ > "$LYMG_PID_FILE"

log_msg "====================================="
log_msg "LYMG Daemon started"
log_msg "Version: 1.0"
log_msg "Recording format: $RECORDING_FORMAT"
log_msg "Bitrate: $BITRATE"
log_msg "Sample rate: $SAMPLE_RATE Hz"
log_msg "Auto call record: $AUTO_CALL_RECORD"
log_msg "====================================="

# Start call state monitoring
if [ "$AUTO_CALL_RECORD" = "1" ]; then
  log_msg "Starting call state monitor"
  (monitor_call_state) &
  echo $! > "$LYMG_DATA/call_monitor.pid"
fi

# Keep daemon running
log_msg "Daemon waiting for signals..."
while true; do
  sleep 1
done

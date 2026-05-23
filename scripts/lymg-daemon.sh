#!/system/bin/sh
# LYMG Main Daemon
# Handles key event monitoring and call state detection

LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"
LYMG_STATE="$LYMG_DATA/state.lock"
LYMG_RECORDING="$LYMG_DATA/recording.lock"
LYMG_PID_FILE="$LYMG_DATA/daemon.pid"

# Source configuration
if [ -f "$LYMG_DATA/config/settings.conf" ]; then
  . "$LYMG_DATA/config/settings.conf"
fi

# Default values
RECORDING_FORMAT="${RECORDING_FORMAT:-AAC}"
BITRATE="${BITRATE:-128k}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
AUTO_CALL_RECORD="${AUTO_CALL_RECORD:-1}"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LYMG_LOG"
}

# Monitor /dev/input for key events
# Power button = KEY_POWER (116)
# Volume Up = KEY_VOLUMEUP (115)
# Volume Down = KEY_VOLUMEDOWN (114)
monitor_key_events() {
  local power_pressed=0
  local vol_up_pressed=0
  local vol_down_pressed=0
  
  # Read from input event device
  for dev in /dev/input/event*; do
    [ -r "$dev" ] || continue
    
    # Use hexdump to read key events
    hexdump -C "$dev" 2>/dev/null | grep -q "0072\|0073\|0074" && {
      log_msg "Key event detected from $dev"
      
      # Check if it's Power + Vol+ + Vol- combination
      if [ -f "$LYMG_DATA/power_pressed" ] && [ -f "$LYMG_DATA/vol_up_pressed" ] && [ -f "$LYMG_DATA/vol_down_pressed" ]; then
        toggle_recording
      fi
    }
  done
}

# Monitor key events with timeout mechanism
monitor_key_press() {
  local timeout=2
  local start_time=$(date +%s)
  
  # Monitor input devices
  while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
    # Check getevent tool if available
    if command -v getevent >/dev/null 2>&1; then
      getevent -t 2>/dev/null | grep -E "KEY_(POWER|VOLUMEUP|VOLUMEDOWN)" && {
        log_msg "Triple key combo detected"
        toggle_recording
      }
    else
      # Fallback: monitor input devices directly
      for dev in /dev/input/event*; do
        [ -r "$dev" ] || continue
        cat "$dev" 2>/dev/null | od -An -tx1 | grep -qE "74|72|73" && {
          log_msg "Key event from $dev"
          check_key_combo
        }
      done
    fi
    
    sleep 0.1
  done
}

# Check for key combination
check_key_combo() {
  local power_state=$(cat /sys/devices/virtual/input/input0/key_power 2>/dev/null || echo 0)
  
  # Use input event polling
  if [ -f "/system/bin/getevent" ] || [ -f "/system/xbin/getevent" ]; then
    timeout 1 getevent 2>/dev/null | grep -q "KEY_POWER" && toggle_recording
  fi
}

# Start/Stop recording
toggle_recording() {
  if [ -f "$LYMG_RECORDING" ]; then
    stop_recording
  else
    start_recording
  fi
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
  
  # Start recording process
  nohup /system/bin/bash -c "record_audio '$output_file'" >> "$LYMG_LOG" 2>&1 &
  echo $! >> "$LYMG_DATA/record.pid"
  
  return 0
}

# Stop recording
stop_recording() {
  if [ ! -f "$LYMG_RECORDING" ]; then
    log_msg "No recording in progress"
    return 1
  fi
  
  log_msg "Stopping recording"
  
  # Kill recording process
  if [ -f "$LYMG_DATA/record.pid" ]; then
    while read pid; do
      [ -n "$pid" ] && kill $pid 2>/dev/null
    done < "$LYMG_DATA/record.pid"
    rm -f "$LYMG_DATA/record.pid"
  fi
  
  # Clear recording state
  rm -f "$LYMG_RECORDING"
  
  return 0
}

# Record audio function
record_audio() {
  local output="$1"
  
  # Try using FFmpeg if available
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -f alsa -i hw:0 -acodec aac -ab $BITRATE -ar $SAMPLE_RATE "$output" 2>&1 | tee -a "$LYMG_LOG"
    return
  fi
  
  # Try using Audacity's recording
  if [ -x "/system/bin/sox" ]; then
    sox -t alsa hw:0 -t aac -b $BITRATE "$output" 2>&1 | tee -a "$LYMG_LOG"
    return
  fi
  
  # Fallback: use mediarecorder
  record_with_mediarecorder "$output"
}

# MediaRecorder based recording (more reliable)
record_with_mediarecorder() {
  local output="$1"
  
  # Create Java/Android based recording process
  am startservice --user 0 -a com.android.intent.action.RECORD_AUDIO \
    -e output "$output" \
    -e format "$RECORDING_FORMAT" \
    -e bitrate "$BITRATE" \
    2>&1 | tee -a "$LYMG_LOG"
}

# Monitor call state
monitor_call_state() {
  while true; do
    # Check if phone is in call
    local call_state=$(getprop "android.telephony.call.state" 2>/dev/null)
    
    if [ "$call_state" = "2" ] || [ "$call_state" = "offhook" ]; then
      # Phone is in call
      if [ ! -f "$LYMG_RECORDING" ] && [ "$AUTO_CALL_RECORD" = "1" ]; then
        log_msg "Call detected, auto-starting recording"
        start_recording
      fi
    else
      # Call ended
      if [ -f "$LYMG_RECORDING" ] && [ "$AUTO_CALL_RECORD" = "1" ]; then
        log_msg "Call ended, stopping recording"
        sleep 1
        stop_recording
      fi
    fi
    
    sleep 2
  done
}

# Write PID
echo $$ > "$LYMG_PID_FILE"

log_msg "LYMG Daemon started"
log_msg "Version: 1.0"
log_msg "Recording format: $RECORDING_FORMAT"
log_msg "Auto call record: $AUTO_CALL_RECORD"

# Start monitoring
(
  while true; do
    check_key_combo
    sleep 0.5
  done
) &

# Start call state monitoring
if [ "$AUTO_CALL_RECORD" = "1" ]; then
  (monitor_call_state) &
fi

# Keep daemon running
wait

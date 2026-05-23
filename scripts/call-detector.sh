#!/system/bin/sh
# LYMG Call Detector
# Monitors call state and controls recording automatically

LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"
LYMG_CALL_STATE="$LYMG_DATA/call_state.lock"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CALL_DETECTOR] $1" >> "$LYMG_LOG"
}

# Get call state using multiple methods
get_call_state() {
  local state
  
  # Method 1: Check telephony property
  state=$(getprop android.telephony.call.state 2>/dev/null)
  if [ -n "$state" ]; then
    case "$state" in
      0|IDLE) echo "idle" ;;
      1|RINGING) echo "ringing" ;;
      2|OFFHOOK) echo "active" ;;
      *) echo "unknown" ;;
    esac
    return 0
  fi
  
  # Method 2: Check audio mode
  local audio_mode=$(getprop ro.com.google.clientidbase 2>/dev/null)
  if command -v dumpsys >/dev/null 2>&1; then
    dumpsys audio | grep -q "mode=2" && echo "active" || echo "idle"
    return 0
  fi
  
  echo "unknown"
}

# Monitor for call start/end events
monitor_calls() {
  local prev_state="idle"
  local current_state
  local recording_pid=""
  
  while true; do
    current_state=$(get_call_state)
    
    if [ "$current_state" != "$prev_state" ]; then
      log_msg "Call state changed: $prev_state -> $current_state"
      
      case "$current_state" in
        active|ringing)
          log_msg "Call started - initiating recording"
          
          # Signal main daemon to start recording
          touch "$LYMG_DATA/call_active"
          
          # Start recording with all audio sources
          local timestamp=$(date +%Y%m%d_%H%M%S)
          local recording_file="$LYMG_DATA/recordings/call_${timestamp}.aac"
          
          nohup /system/bin/sh "$LYMG_DATA/audio-recorder.sh" "$recording_file" "3600" "system" \
            >> "$LYMG_LOG" 2>&1 &
          recording_pid=$!
          echo $recording_pid > "$LYMG_DATA/call_recording.pid"
          
          log_msg "Recording PID: $recording_pid"
          ;;
          
        idle)
          log_msg "Call ended - stopping recording"
          
          if [ -f "$LYMG_DATA/call_recording.pid" ]; then
            recording_pid=$(cat "$LYMG_DATA/call_recording.pid")
            kill $recording_pid 2>/dev/null
            wait $recording_pid 2>/dev/null
            rm -f "$LYMG_DATA/call_recording.pid"
            
            log_msg "Recording stopped"
          fi
          
          rm -f "$LYMG_DATA/call_active"
          ;;
      esac
      
      prev_state="$current_state"
    fi
    
    sleep 1
  done
}

# WeChat call detection (optional)
detect_wechat_calls() {
  # Monitor WeChat package activity
  if command -v dumpsys >/dev/null 2>&1; then
    dumpsys activity | grep -q "com.tencent.mm" && {
      # WeChat is active
      dumpsys audio | grep -q "mode=2" && {
        log_msg "WeChat call detected"
        touch "$LYMG_DATA/wechat_call"
      }
    }
  fi
}

log_msg "Call detector started"

# Start monitoring
monitor_calls &
MONITOR_PID=$!

echo $MONITOR_PID > "$LYMG_DATA/call_detector.pid"

# Keep running
wait $MONITOR_PID

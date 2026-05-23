#!/system/bin/sh
# LYMG Call Detector (simplified version)
# Monitors call state and controls recording automatically

LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"
LYMG_DAEMON_PID="$LYMG_DATA/daemon.pid"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CALL_DETECTOR] $1" >> "$LYMG_LOG"
}

log_msg "Call detector started"

# Get call state
get_call_state() {
  # Check telephony property
  local state=$(getprop android.telephony.call.state 2>/dev/null)
  echo "$state"
}

# Main loop
prev_state="0"

while true; do
  current_state=$(get_call_state)
  
  if [ "$current_state" != "$prev_state" ]; then
    log_msg "Call state changed: $prev_state -> $current_state"
    
    case "$current_state" in
      2|offhook)
        log_msg "Call detected (state: $current_state)"
        if [ -f "$LYMG_DAEMON_PID" ]; then
          DAEMON_PID=$(cat "$LYMG_DAEMON_PID")
          kill -USR1 $DAEMON_PID 2>/dev/null
          log_msg "Sent signal to start recording"
        fi
        ;;
      1|ringing)
        log_msg "Phone ringing (state: $current_state)"
        ;;
      0|idle)
        log_msg "Call ended (state: $current_state)"
        if [ -f "$LYMG_DAEMON_PID" ]; then
          DAEMON_PID=$(cat "$LYMG_DAEMON_PID")
          # Send another signal to toggle if recording
          sleep 1
          kill -USR1 $DAEMON_PID 2>/dev/null
          log_msg "Sent signal to stop recording"
        fi
        ;;
    esac
    
    prev_state="$current_state"
  fi
  
  sleep 1
done

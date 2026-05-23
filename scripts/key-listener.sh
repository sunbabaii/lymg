#!/system/bin/sh
# LYMG Key Listener
# Monitors Volume+ + Power key combination

LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"
LYMG_PID_FILE="$LYMG_DATA/daemon.pid"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [KEY_LISTENER] $1" >> "$LYMG_LOG"
}

# Key states
POWER_PRESSED=0
VOL_UP_PRESSED=0
LAST_COMBO_TIME=0
COMBO_COOLDOWN=2  # Cooldown between toggles (seconds)

log_msg "Starting key listener for Volume+ + Power combination"

# Method 1: Use getevent to monitor key events
if command -v getevent >/dev/null 2>&1; then
  log_msg "Using getevent method"
  
  getevent 2>/dev/null | while read -r line; do
    # Parse getevent output
    # Format: /dev/input/eventX: EV_KEY       KEY_POWER             DOWN/UP
    
    if echo "$line" | grep -q "KEY_POWER"; then
      if echo "$line" | grep -q "DOWN"; then
        POWER_PRESSED=1
        log_msg "Power button pressed"
      else
        POWER_PRESSED=0
        log_msg "Power button released"
      fi
    fi
    
    if echo "$line" | grep -q "KEY_VOLUMEUP"; then
      if echo "$line" | grep -q "DOWN"; then
        VOL_UP_PRESSED=1
        log_msg "Volume Up pressed"
      else
        VOL_UP_PRESSED=0
        log_msg "Volume Up released"
      fi
    fi
    
    # Check combo: both keys pressed
    if [ $POWER_PRESSED -eq 1 ] && [ $VOL_UP_PRESSED -eq 1 ]; then
      CURRENT_TIME=$(date +%s)
      TIME_SINCE_LAST=$((CURRENT_TIME - LAST_COMBO_TIME))
      
      if [ $TIME_SINCE_LAST -gt $COMBO_COOLDOWN ]; then
        log_msg "Key combo detected! Volume+ + Power pressed together"
        
        # Send signal to daemon
        if [ -f "$LYMG_PID_FILE" ]; then
          DAEMON_PID=$(cat "$LYMG_PID_FILE")
          if [ -n "$DAEMON_PID" ]; then
            kill -USR1 $DAEMON_PID 2>/dev/null
            log_msg "Toggle signal sent to daemon (PID: $DAEMON_PID)"
          fi
        fi
        
        LAST_COMBO_TIME=$CURRENT_TIME
        sleep 0.5
      fi
    fi
  done
else
  log_msg "getevent not available, trying input event monitoring"
  
  # Method 2: Fallback - direct input device monitoring
  while true; do
    # Try to read from input devices
    for device in /dev/input/event*; do
      [ -r "$device" ] || continue
      
      # Use timeout to prevent blocking
      timeout 1 cat "$device" 2>/dev/null | od -An -tx1 | while read -r hex_line; do
        # Look for key press events
        # This is a rough approximation
        if echo "$hex_line" | grep -q "01 01 74"; then
          log_msg "Power button detected (fallback method)"
          POWER_PRESSED=1
        elif echo "$hex_line" | grep -q "01 01 73"; then
          log_msg "Volume Up detected (fallback method)"
          VOL_UP_PRESSED=1
        fi
      done
    done
    
    sleep 0.5
  done
fi

log_msg "Key listener stopped"

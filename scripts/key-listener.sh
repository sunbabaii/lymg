#!/system/bin/sh
# LYMG Key Listener
# Monitors Power + Volume+ + Volume- key combination

LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [KEY_LISTENER] $1" >> "$LYMG_LOG"
}

# Key event constants (EV_KEY = 0x01)
KEY_POWER=116
KEY_VOLUMEUP=115
KEY_VOLUMEDOWN=114

# State tracking
power_pressed=0
vol_up_pressed=0
vol_down_pressed=0
combo_time=0

# Listen for key events using getevent
listen_with_getevent() {
  if ! command -v getevent >/dev/null 2>&1; then
    log_msg "getevent not found, trying alternative methods"
    listen_with_input_devices
    return
  fi
  
  log_msg "Starting key listener with getevent"
  
  getevent 2>/dev/null | while IFS=: read -r device event_type event_code event_value; do
    # Parse key events
    # Format: /dev/input/eventX: EV_KEY       KEY_POWER             DOWN
    
    case "$event_code" in
      *KEY_POWER*)
        power_pressed="$event_value"
        log_msg "Power button: $event_value"
        ;;
      *KEY_VOLUMEUP*)
        vol_up_pressed="$event_value"
        log_msg "Volume Up: $event_value"
        ;;
      *KEY_VOLUMEDOWN*)
        vol_down_pressed="$event_value"
        log_msg "Volume Down: $event_value"
        ;;
    esac
    
    # Check for combo (all three pressed)
    if [ "$power_pressed" = "DOWN" ] && [ "$vol_up_pressed" = "DOWN" ] && [ "$vol_down_pressed" = "DOWN" ]; then
      log_msg "Triple key combo detected! Triggering recording toggle"
      touch "$LYMG_DATA/toggle_request"
      
      # Debounce - wait for keys to be released
      sleep 1
      power_pressed=0
      vol_up_pressed=0
      vol_down_pressed=0
    fi
  done
}

# Alternative: Listen directly from input devices
listen_with_input_devices() {
  log_msg "Starting key listener with input device monitoring"
  
  # Find event devices
  local input_devices=$(find /dev/input -name "event*" -type c 2>/dev/null)
  
  if [ -z "$input_devices" ]; then
    log_msg "ERROR: No input devices found"
    return 1
  fi
  
  # Monitor all event devices
  for device in $input_devices; do
    (
      log_msg "Monitoring $device"
      hexdump -C "$device" 2>/dev/null | while read line; do
        # Parse hexdump output for key events
        # EV_KEY = 0x01, look for key codes
        
        if echo "$line" | grep -qE "01 01"; then
          # This is a KEY event
          
          if echo "$line" | grep -qE " 74"; then
            # Power key (116 = 0x74)
            power_pressed=1
            log_msg "Power button detected"
          elif echo "$line" | grep -qE " 73"; then
            # Volume Up (115 = 0x73)
            vol_up_pressed=1
            log_msg "Volume Up detected"
          elif echo "$line" | grep -qE " 72"; then
            # Volume Down (114 = 0x72)
            vol_down_pressed=1
            log_msg "Volume Down detected"
          fi
          
          # Check for combo
          if [ $power_pressed -eq 1 ] && [ $vol_up_pressed -eq 1 ] && [ $vol_down_pressed -eq 1 ]; then
            log_msg "Triple key combo detected! Triggering recording toggle"
            touch "$LYMG_DATA/toggle_request"
            
            power_pressed=0
            vol_up_pressed=0
            vol_down_pressed=0
            sleep 2
          fi
        fi
      done
    ) &
  done
  
  wait
}

# Monitor toggle requests
monitor_toggle_requests() {
  log_msg "Toggle request monitor started"
  
  while true; do
    if [ -f "$LYMG_DATA/toggle_request" ]; then
      rm -f "$LYMG_DATA/toggle_request"
      
      # Send signal to main daemon
      if [ -f "$LYMG_DATA/daemon.pid" ]; then
        local pid=$(cat "$LYMG_DATA/daemon.pid")
        kill -USR1 $pid 2>/dev/null
        log_msg "Toggle signal sent to daemon PID $pid"
      fi
    fi
    
    sleep 0.2
  done
}

log_msg "Key listener service starting"

# Start monitoring in parallel
listen_with_getevent &
LISTEN_PID=$!

monitor_toggle_requests &
MONITOR_PID=$!

echo $LISTEN_PID > "$LYMG_DATA/key_listener.pid"
echo $MONITOR_PID >> "$LYMG_DATA/key_listener.pid"

log_msg "Key listener started (PIDs: $LISTEN_PID, $MONITOR_PID)"

# Keep running
wait

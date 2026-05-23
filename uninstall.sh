#!/system/bin/sh
# LYMG Uninstall Script
# Clean up all LYMG related processes and files

LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"

log_msg() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNINSTALL] $1" >> "$LYMG_LOG"
}

log_msg "Starting LYMG uninstall"

# Kill all LYMG processes
if [ -d "$LYMG_DATA" ]; then
  for pid_file in "$LYMG_DATA"/*.pid; do
    if [ -f "$pid_file" ]; then
      while read pid; do
        kill $pid 2>/dev/null
        log_msg "Killed process: $pid"
      done < "$pid_file"
    fi
  done
fi

# Stop any active recording
if [ -f "$LYMG_DATA/record.pid" ]; then
  while read pid; do
    kill $pid 2>/dev/null
  done < "$LYMG_DATA/record.pid"
fi

# Optional: Keep recordings (user should backup manually)
# Uncomment to delete recordings on uninstall:
# rm -rf "$LYMG_DATA/recordings"

log_msg "LYMG uninstall completed"

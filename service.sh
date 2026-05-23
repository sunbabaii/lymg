#!/system/bin/sh
# LYMG Call Recorder Service
# Magisk Post-FSMount Script
# This script initializes the recording daemon

MODDIR=${0%/*}
LYMG_DATA="/data/lymg"
LYMG_LOG="$LYMG_DATA/lymg.log"

# Create directories with proper permissions
mkdir -p "$LYMG_DATA/recordings"
mkdir -p "$LYMG_DATA/cache"
chmod 777 "$LYMG_DATA"
chmod 777 "$LYMG_DATA/recordings"
chmod 777 "$LYMG_DATA/cache"

# Initialize log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] LYMG Service Started" > "$LYMG_LOG"

# Copy daemon script
cp "$MODDIR/scripts/lymg-daemon.sh" "$LYMG_DATA/lymg-daemon.sh"
chmod 755 "$LYMG_DATA/lymg-daemon.sh"

# Copy hook library
mkdir -p "$LYMG_DATA/lib"
cp "$MODDIR/lib/"*.so "$LYMG_DATA/lib/" 2>/dev/null

# Start the main daemon in background
nohup "$LYMG_DATA/lymg-daemon.sh" >> "$LYMG_LOG" 2>&1 &

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daemon PID: $!" >> "$LYMG_LOG"

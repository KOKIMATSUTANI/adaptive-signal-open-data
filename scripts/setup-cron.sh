#!/bin/bash
# Setup system cron for real-time data collection
# This script sets up cron jobs for high-frequency data collection
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CRON_SCRIPT="$SCRIPT_DIR/cron-realtime.sh"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to setup cron jobs
setup_cron() {
    log "Setting up cron jobs for real-time data collection"
    
    # Create temporary cron file
    TEMP_CRON=$(mktemp)
    
    # Add existing cron jobs (excluding our project)
    crontab -l 2>/dev/null | grep -v "tram-delay-reduction-management" > "$TEMP_CRON" || true
    
    # Add our cron jobs
    cat >> "$TEMP_CRON" << EOF

# Tram Delay Reduction Management - Real-time data collection
# GTFS-RT data collection every 20 seconds
* * * * * $CRON_SCRIPT rt-ingest
* * * * * sleep 20; $CRON_SCRIPT rt-ingest
* * * * * sleep 40; $CRON_SCRIPT rt-ingest

EOF
    
    # Install new cron jobs
    crontab "$TEMP_CRON"
    rm "$TEMP_CRON"
    
    log "Cron jobs installed successfully"
    log "GTFS-RT data collection: every 20 seconds"
}

# Function to remove cron jobs
remove_cron() {
    log "Removing cron jobs for real-time data collection"
    
    # Create temporary cron file without our project
    TEMP_CRON=$(mktemp)
    crontab -l 2>/dev/null | grep -v "tram-delay-reduction-management" > "$TEMP_CRON" || true
    
    # Install updated cron jobs
    crontab "$TEMP_CRON"
    rm "$TEMP_CRON"
    
    log "Cron jobs removed successfully"
}

# Function to show current cron jobs
show_cron() {
    log "Current cron jobs:"
    crontab -l 2>/dev/null | grep "tram-delay-reduction-management" || echo "No cron jobs found"
}

# Main execution
case "$1" in
    "setup")
        setup_cron
        ;;
    "remove")
        remove_cron
        ;;
    "show")
        show_cron
        ;;
    *)
        echo "Usage: $0 {setup|remove|show}"
        echo "  setup  - Install cron jobs for real-time data collection"
        echo "  remove - Remove cron jobs"
        echo "  show   - Show current cron jobs"
        exit 1
        ;;
esac

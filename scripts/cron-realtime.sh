#!/bin/bash
# Cron-based real-time data collection
# Uses system cron for high-frequency scheduling
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROJECT_DIR/logs/cron-realtime.log"
}

# Function to run GTFS-RT ingestion
run_rt_ingest() {
    log "Starting GTFS-RT ingestion task"
    cd "$PROJECT_DIR"
    docker compose -f docker/docker compose.yml run --rm gtfs-ingest-static --feed-type rt --once
    log "GTFS-RT ingestion task completed"
}

# Function to run backup
run_backup() {
    log "Starting backup task"
    cd "$PROJECT_DIR"
    docker compose -f docker/docker compose.yml run --rm backup
    log "Backup task completed"
}

# Main execution
case "$1" in
    "rt-ingest")
        run_rt_ingest
        ;;
    "backup")
        run_backup
        ;;
    *)
        echo "Usage: $0 {rt-ingest|backup}"
        exit 1
        ;;
esac

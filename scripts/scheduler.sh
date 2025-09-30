#!/bin/bash
# Scheduler script for short-lived tasks
# Runs GTFS ingestion and backup tasks at specified intervals
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INGEST_INTERVAL=${INGEST_INTERVAL:-20}  # seconds
BACKUP_INTERVAL=${BACKUP_INTERVAL:-300}  # seconds (5 minutes)

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROJECT_DIR/logs/scheduler.log"
}

# Function to run GTFS ingestion
run_ingest() {
    log "Starting GTFS ingestion task"
    cd "$PROJECT_DIR"
    docker compose -f docker/docker-compose.yml run --rm gtfs-ingest
    log "GTFS ingestion task completed"
}

# Function to run backup
run_backup() {
    log "Starting backup task"
    cd "$PROJECT_DIR"
    docker compose -f docker/docker-compose.yml run --rm backup
    log "Backup task completed"
}

# Function to cleanup on exit
cleanup() {
    log "Scheduler stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main scheduler loop
main() {
    log "Starting scheduler with intervals: ingest=${INGEST_INTERVAL}s, backup=${BACKUP_INTERVAL}s"
    
    # Start background processes
    (
        while true; do
            run_ingest
            sleep "$INGEST_INTERVAL"
        done
    ) &
    INGEST_PID=$!
    
    (
        while true; do
            run_backup
            sleep "$BACKUP_INTERVAL"
        done
    ) &
    BACKUP_PID=$!
    
    log "Scheduler started with PIDs: ingest=$INGEST_PID, backup=$BACKUP_PID"
    
    # Wait for processes
    wait $INGEST_PID
    wait $BACKUP_PID
}

# Check if running in single execution mode
if [ "$1" = "--once" ]; then
    log "Single execution mode"
    run_ingest
    run_backup
    log "Single execution completed"
    exit 0
fi

# Start scheduler
main "$@"

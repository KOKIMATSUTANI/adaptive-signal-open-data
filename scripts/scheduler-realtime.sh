#!/bin/bash
# High-frequency scheduler for real-time data collection
# Runs GTFS-RT ingestion every 20 seconds using short-lived tasks
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RT_INTERVAL=${RT_INTERVAL:-20}  # seconds
BACKUP_INTERVAL=${BACKUP_INTERVAL:-60}  # seconds (1 minute for real-time data backup)

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROJECT_DIR/logs/scheduler-realtime.log"
}

# Function to run GTFS-RT ingestion
run_rt_ingest() {
    log "Starting GTFS-RT ingestion task"
    cd "$PROJECT_DIR"
    docker-compose -f docker/docker-compose.yml run --rm gtfs-ingest-realtime
    log "GTFS-RT ingestion task completed"
}

# Function to run backup
run_backup() {
    log "Starting backup task"
    cd "$PROJECT_DIR"
    docker-compose -f docker/docker-compose.yml run --rm backup
    log "Backup task completed"
}

# Function to cleanup on exit
cleanup() {
    log "Real-time scheduler stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main scheduler loop
main() {
    log "Starting real-time scheduler with intervals: rt=${RT_INTERVAL}s, backup=${BACKUP_INTERVAL}s"
    
    # Start background processes
    (
        while true; do
            run_rt_ingest
            sleep "$RT_INTERVAL"
        done
    ) &
    RT_PID=$!
    
    (
        while true; do
            run_backup
            sleep "$BACKUP_INTERVAL"
        done
    ) &
    BACKUP_PID=$!
    
    log "Real-time scheduler started with PIDs: rt=$RT_PID, backup=$BACKUP_PID"
    
    # Wait for processes
    wait $RT_PID
    wait $BACKUP_PID
}

# Check if running in single execution mode
if [ "$1" = "--once" ]; then
    log "Single execution mode"
    run_rt_ingest
    run_backup
    log "Single execution completed"
    exit 0
fi

# Start scheduler
main "$@"

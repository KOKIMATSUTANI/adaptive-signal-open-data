#!/bin/bash
# High-frequency scheduler for real-time data collection
# Runs GTFS-RT ingestion every 20 seconds using short-lived tasks
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RT_INTERVAL=${RT_INTERVAL:-20}  # seconds
# Legacy backup scheduling removed; this script only runs GTFS-RT ingestion.
export TZ=Asia/Tokyo

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
COMPOSE_CMD_ENV="${COMPOSE_CMD:-}"
COMPOSE_CMD_ARR=()

resolve_container_runtime() {
    if [ -z "$CONTAINER_RUNTIME" ]; then
        if command -v docker >/dev/null 2>&1; then
            CONTAINER_RUNTIME="docker"
        elif command -v podman >/dev/null 2>&1; then
            CONTAINER_RUNTIME="podman"
        else
            echo "[ERROR] No container runtime found (docker or podman)." >&2
            exit 1
        fi
    fi

    if [ -n "$COMPOSE_CMD_ENV" ]; then
        # shellcheck disable=SC2206
        COMPOSE_CMD_ARR=($COMPOSE_CMD_ENV)
        return
    fi

    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(docker compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="docker"
        return
    fi

    if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(podman compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="podman"
        return
    fi

    if command -v podman-compose >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(podman-compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="podman"
        return
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(docker-compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="docker"
        return
    fi

    echo "[ERROR] No compose implementation found (docker compose, podman compose, podman-compose, docker-compose)." >&2
    exit 1
}

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROJECT_DIR/logs/scheduler-realtime.log"
}

# Function to run GTFS-RT ingestion
run_rt_ingest() {
    if [ ${#COMPOSE_CMD_ARR[@]} -eq 0 ]; then
        resolve_container_runtime
    fi
    log "Starting GTFS-RT ingestion task"
    cd "$PROJECT_DIR"
    "${COMPOSE_CMD_ARR[@]}" -f docker/docker-compose.yml run --rm gtfs-ingest-realtime
    log "GTFS-RT ingestion task completed"
}

# # Function to cleanup on exit
# cleanup() {
#     log "Real-time scheduler stopped"
#     exit 0
# }

# # Set up signal handlers
# trap cleanup SIGTERM SIGINT

# Main scheduler loop
main() {
    resolve_container_runtime
    mkdir -p "$PROJECT_DIR/logs"
    out_dir="$PROJECT_DIR/data/raw/$(date +%Y/%m/%d)"
    mkdir -p "$out_dir"
    
    # log "Starting real-time scheduler with interval: rt=${RT_INTERVAL}s"
    log "Starting real-time scheduler with interval: rt=${RT_INTERVAL}s"
    log "Current time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Start background processes
    (
        while true; do
            
            hour=$(date +%H)
            if [ "$hour" -lt 5 ]; then
                log "Sleeping (00:00–04:59): Skipping ingestion cycle."
                sleep "$RT_INTERVAL"
                continue
            fi

            run_rt_ingest || { log "Ingestion failed (exit=$?), retry after ${RT_INTERVAL}s"; sleep "$RT_INTERVAL"; continue; }
            sleep "$RT_INTERVAL"
        done
    ) &
    RT_PID=$!
    
    # log "Real-time scheduler started with PID: rt=$RT_PID"
    log "Real-time scheduler started with PIDs: rt=$RT_PID"
    
    # Wait for processes
    wait $RT_PID
    # wait for additional background tasks if reintroduced
}

# Resolve runtime/compose command before handling CLI mode
resolve_container_runtime

# Check if running in single execution mode
if [ "${1:-}" = "--once" ]; then
    log "Single execution mode"
    run_rt_ingest
    log "Single execution completed"
    exit 0
fi

# Start scheduler
main "$@"

#!/bin/bash
# Cron-based real-time data collection
# Uses system cron for high-frequency scheduling
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
COMPOSE_CMD_ENV="${COMPOSE_CMD:-}"
COMPOSE_CMD_ARR=()

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROJECT_DIR/logs/cron-realtime.log"
}

resolve_container_runtime() {
    if [ -z "$CONTAINER_RUNTIME" ]; then
        if command -v docker >/dev/null 2>&1; then
            CONTAINER_RUNTIME="docker"
        elif command -v podman >/dev/null 2>&1; then
            CONTAINER_RUNTIME="podman"
        else
            log "ERROR: No container runtime found (docker or podman)."
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

    log "ERROR: No compose implementation found (docker compose, podman compose, podman-compose, docker-compose)."
    exit 1
}

# Function to run GTFS-RT ingestion
run_rt_ingest() {
    if [ ${#COMPOSE_CMD_ARR[@]} -eq 0 ]; then
        resolve_container_runtime
    fi
    log "Starting GTFS-RT ingestion task"
    cd "$PROJECT_DIR"
    "${COMPOSE_CMD_ARR[@]}" -f docker/docker-compose.yml run --rm gtfs-ingest-realtime --feed-type realtime --once
    log "GTFS-RT ingestion task completed"
}

# Main execution
resolve_container_runtime
case "$1" in
    "rt-ingest")
        run_rt_ingest
        ;;
    *)
        echo "Usage: $0 {rt-ingest}"
        exit 1
        ;;
esac

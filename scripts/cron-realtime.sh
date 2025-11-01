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
PREFER_PODMAN_RUN=${PREFER_PODMAN_RUN:-1}
# Export PREFER_PODMAN_RUN=0 to force compose-based execution even with Podman.
PODMAN_RUN_FLAGS=()
PODMAN_VOLUME_SUFFIX=""
INGEST_REALTIME_IMAGE="${INGEST_REALTIME_IMAGE:-tram-ingest-realtime:latest}"
DATA_DIR="${DATA_DIR:-$PROJECT_DIR/data}"
LOGS_DIR="${LOGS_DIR:-$PROJECT_DIR/logs}"
CONFIGS_DIR="${CONFIGS_DIR:-$PROJECT_DIR/configs}"
APP_UID="${APP_UID:-1000}"
APP_GID="${APP_GID:-1000}"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PROJECT_DIR/logs/cron-realtime.log"
}

resolve_container_runtime() {
    if [ -z "$CONTAINER_RUNTIME" ]; then
        if command -v podman >/dev/null 2>&1; then
            CONTAINER_RUNTIME="podman"
        elif command -v docker >/dev/null 2>&1; then
            CONTAINER_RUNTIME="docker"
        else
            log "ERROR: No container runtime found (podman or docker)."
            exit 1
        fi
    fi

    if [ "$CONTAINER_RUNTIME" = "podman" ] && [ "$PREFER_PODMAN_RUN" = "1" ] && [ -z "$COMPOSE_CMD_ENV" ]; then
        COMPOSE_CMD_ARR=()
        configure_runtime_flags
        return
    fi

    if [ -n "$COMPOSE_CMD_ENV" ]; then
        # shellcheck disable=SC2206
        COMPOSE_CMD_ARR=($COMPOSE_CMD_ENV)
        configure_runtime_flags
        return
    fi

    if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(podman compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="podman"
        configure_runtime_flags
        return
    fi

    if command -v podman-compose >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(podman-compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="podman"
        configure_runtime_flags
        return
    fi

    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(docker compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="docker"
        configure_runtime_flags
        return
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(docker-compose)
        [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="docker"
        configure_runtime_flags
        return
    fi

    log "ERROR: No compose implementation found (podman compose, podman-compose, docker compose, docker-compose)."
    exit 1
}

configure_runtime_flags() {
    if [ "$CONTAINER_RUNTIME" = "podman" ]; then
        PODMAN_RUN_FLAGS=(--userns=keep-id)
        PODMAN_VOLUME_SUFFIX=":z"
    else
        PODMAN_RUN_FLAGS=()
        PODMAN_VOLUME_SUFFIX=""
    fi
}

ensure_image_available() {
    if [ "$CONTAINER_RUNTIME" = "podman" ] && [ "$PREFER_PODMAN_RUN" = "1" ] && [ ${#COMPOSE_CMD_ARR[@]} -eq 0 ]; then
        if ! "$CONTAINER_RUNTIME" image inspect "$INGEST_REALTIME_IMAGE" >/dev/null 2>&1; then
            log "Building ${INGEST_REALTIME_IMAGE} image for Podman execution..."
            (
                cd "$PROJECT_DIR"
                "$CONTAINER_RUNTIME" build \
                    --build-arg APP_UID="$APP_UID" \
                    --build-arg APP_GID="$APP_GID" \
                    -f docker/Dockerfile.ingest-realtime \
                    -t "$INGEST_REALTIME_IMAGE" .
            )
        fi
    else
        (
            cd "$PROJECT_DIR"
            "${COMPOSE_CMD_ARR[@]}" -f docker/docker-compose.yml build gtfs-ingest-realtime >/dev/null
        )
    fi
}

# Function to run GTFS-RT ingestion
run_rt_ingest() {
    if [ ${#COMPOSE_CMD_ARR[@]} -eq 0 ]; then
        resolve_container_runtime
    fi
    configure_runtime_flags
    log "Starting GTFS-RT ingestion task"
    if [ "$CONTAINER_RUNTIME" = "podman" ] && [ "$PREFER_PODMAN_RUN" = "1" ]; then
        mkdir -p "$DATA_DIR" "$LOGS_DIR" "$CONFIGS_DIR"
        "$CONTAINER_RUNTIME" run --rm "${PODMAN_RUN_FLAGS[@]}" \
            -v "${DATA_DIR}:/app/data${PODMAN_VOLUME_SUFFIX}" \
            -v "${LOGS_DIR}:/app/logs${PODMAN_VOLUME_SUFFIX}" \
            -v "${CONFIGS_DIR}:/app/configs${PODMAN_VOLUME_SUFFIX}" \
            "$INGEST_REALTIME_IMAGE" --feed-type realtime --once
    else
        (
            cd "$PROJECT_DIR"
            "${COMPOSE_CMD_ARR[@]}" -f docker/docker-compose.yml run --rm gtfs-ingest-realtime --feed-type realtime --once
        )
    fi
    log "GTFS-RT ingestion task completed"
}

# Main execution
resolve_container_runtime
case "$1" in
    "rt-ingest")
        ensure_image_available
        run_rt_ingest
        ;;
    *)
        echo "Usage: $0 {rt-ingest}"
        exit 1
        ;;
esac

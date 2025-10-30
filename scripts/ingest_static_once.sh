#!/bin/bash
# One-off GTFS static ingestion helper.
# Ensures only a single snapshot exists by clearing prior gtfs_static_*.json files.
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="${DATA_DIR:-$PROJECT_DIR/data/raw}"
CONTAINER_DATA_DIR="${CONTAINER_DATA_DIR:-/app/data/raw}"
COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
DOCKER_COMPOSE_CMD=()

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

ensure_dependencies() {
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR: docker command not found. Install Docker before running this script."
        exit 1
    fi

    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD=(docker compose)
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD=(docker-compose)
    else
        log "ERROR: docker compose plugin (or docker-compose) is not available."
        exit 1
    fi
}

remove_via_container() {
    log "Attempting container-based cleanup for remaining snapshots..."
    if ! (
        cd "$PROJECT_DIR"
        "${DOCKER_COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" run --rm --user 0:0 \
            --entrypoint sh gtfs-ingest-static -c "set -e; rm -f ${CONTAINER_DATA_DIR}/gtfs_static_*.json"
    ); then
        log "WARNING: Container-based cleanup failed. Manual removal may be required."
    fi
}

cleanup_snapshots() {
    mkdir -p "$DATA_DIR"
    mapfile -t existing < <(find "$DATA_DIR" -maxdepth 1 -type f -name "gtfs_static_*.json" -printf "%p\n" 2>/dev/null || true)

    if ((${#existing[@]} == 0)); then
        log "No prior GTFS static snapshots found."
        return
    fi

    log "Removing existing GTFS static snapshots (host-side attempt)..."
    stubborn=()
    for file in "${existing[@]}"; do
        if rm -f -- "$file"; then
            log "  - deleted: $file"
        else
            log "  - unable to delete: $file"
            stubborn+=("$file")
        fi
    done

    if ((${#stubborn[@]} > 0)); then
        remove_via_container
    fi
}

ingest_static() {
    log "Starting GTFS static ingestion (single run)..."
    (
        cd "$PROJECT_DIR"
        "${DOCKER_COMPOSE_CMD[@]}" -f "$COMPOSE_FILE" run --rm gtfs-ingest-static
    )
    log "GTFS static ingestion finished."
}

verify_result() {
    local snapshots
    snapshots=($(find "$DATA_DIR" -maxdepth 1 -type f -name "gtfs_static_*.json"))
    case ${#snapshots[@]} in
        0)
            log "WARNING: No GTFS static snapshot found after ingestion. Check container logs."
            return 1
            ;;
        1)
            log "GTFS static snapshot stored at: ${snapshots[0]}"
            ;;
        *)
            log "WARNING: Multiple GTFS static snapshots detected:"
            for file in "${snapshots[@]}"; do
                log "  - $file"
            done
            return 1
            ;;
    esac
}

ensure_dependencies
cleanup_snapshots
ingest_static
verify_result

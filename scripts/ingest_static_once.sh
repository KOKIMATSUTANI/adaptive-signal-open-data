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
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
COMPOSE_CMD_ENV="${COMPOSE_CMD:-}"
COMPOSE_CMD_ARR=()
CLEAN_PREVIOUS=${CLEAN_PREVIOUS:-0}
BEFORE_SNAPSHOTS=()

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

ensure_dependencies() {
    if [ -n "$COMPOSE_CMD_ENV" ]; then
        # shellcheck disable=SC2206
        COMPOSE_CMD_ARR=($COMPOSE_CMD_ENV)
    else
        if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
            COMPOSE_CMD_ARR=(podman compose)
            [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="podman"
        elif command -v podman-compose >/dev/null 2>&1; then
            COMPOSE_CMD_ARR=(podman-compose)
            [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="podman"
        elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
            COMPOSE_CMD_ARR=(docker compose)
            [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="docker"
        elif command -v docker-compose >/dev/null 2>&1; then
            COMPOSE_CMD_ARR=(docker-compose)
            [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="docker"
        else
            log "ERROR: No compose implementation found (podman compose, podman-compose, docker compose, or docker-compose)."
            exit 1
        fi
    fi

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
}

remove_via_container() {
    log "Attempting container-based cleanup for remaining snapshots..."
    if ! (
        cd "$PROJECT_DIR"
        "${COMPOSE_CMD_ARR[@]}" -f "$COMPOSE_FILE" run --rm --user 0:0 \
            --entrypoint sh gtfs-ingest-static -c "set -e; rm -f ${CONTAINER_DATA_DIR}/gtfs_static_*.json"
    ); then
        log "WARNING: Container-based cleanup failed. Manual removal may be required."
    fi
}

cleanup_snapshots() {
    if [ "$CLEAN_PREVIOUS" != "1" ]; then
        log "Skipping cleanup of existing GTFS static snapshots (CLEAN_PREVIOUS!=1)"
        return
    fi

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

snapshot_list() {
    find "$DATA_DIR" -maxdepth 1 -type f -name "gtfs_static_*.json" -printf "%p\n" 2>/dev/null | sort
}

ingest_static() {
    log "Starting GTFS static ingestion (single run)..."
    (
        cd "$PROJECT_DIR"
        "${COMPOSE_CMD_ARR[@]}" -f "$COMPOSE_FILE" run --rm gtfs-ingest-static
    )
    log "GTFS static ingestion finished."
}

verify_result() {
    mapfile -t snapshots < <(snapshot_list)

    if ((${#snapshots[@]} == 0)); then
        log "WARNING: No GTFS static snapshot found after ingestion. Check container logs."
        return 1
    fi

    # Track newly created files by comparing to pre-ingest list
    declare -A before_map=()
    for file in "${BEFORE_SNAPSHOTS[@]}"; do
        before_map["$file"]=1
    done

    local new_snapshots=()
    for file in "${snapshots[@]}"; do
        if [[ -z "${before_map["$file"]:-}" ]]; then
            new_snapshots+=("$file")
        fi
    done

    if ((${#new_snapshots[@]} == 0)); then
        log "WARNING: No new GTFS static snapshots detected (files may have been overwritten)."
        return 1
    fi

    if ((${#new_snapshots[@]} == 1)); then
        log "GTFS static snapshot stored at: ${new_snapshots[0]}"
    else
        log "GTFS static snapshots stored at:"
        for file in "${new_snapshots[@]}"; do
            log "  - $file"
        done
    fi
}

ensure_dependencies
(
    cd "$PROJECT_DIR"
    "${COMPOSE_CMD_ARR[@]}" -f "$COMPOSE_FILE" build gtfs-ingest-static >/dev/null
)
mkdir -p "$DATA_DIR"
cleanup_snapshots
mapfile -t BEFORE_SNAPSHOTS < <(snapshot_list)
ingest_static
verify_result

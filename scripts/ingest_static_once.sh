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
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
COMPOSE_CMD_ENV="${COMPOSE_CMD:-}"
COMPOSE_CMD_ARR=()
CLEAN_PREVIOUS=${CLEAN_PREVIOUS:-0}
BEFORE_SNAPSHOTS=()
INGEST_STATIC_IMAGE="${INGEST_STATIC_IMAGE:-tram-ingest:latest}"
APP_UID="${APP_UID:-1000}"
APP_GID="${APP_GID:-1000}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

ensure_dependencies() {
    if [ "$CONTAINER_RUNTIME" != "docker" ]; then
        log "ERROR: Only docker is supported. Set CONTAINER_RUNTIME=docker."
        exit 1
    fi

    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR: Docker CLI not found. Install Docker before running this script."
        exit 1
    fi

    if [ -n "$COMPOSE_CMD_ENV" ]; then
        # shellcheck disable=SC2206
        COMPOSE_CMD_ARR=($COMPOSE_CMD_ENV)
        return
    fi

    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(docker compose)
        return
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD_ARR=(docker-compose)
        return
    fi

    log "ERROR: Docker Compose not available (docker compose or docker-compose)."
    exit 1
}

ensure_image_available() {
    if [ "$CONTAINER_RUNTIME" = "podman" ] && [ "$PREFER_PODMAN_RUN" = "1" ] && [ ${#COMPOSE_CMD_ARR[@]} -eq 0 ]; then
        if ! "$CONTAINER_RUNTIME" image inspect "$INGEST_STATIC_IMAGE" >/dev/null 2>&1; then
            log "Building ${INGEST_STATIC_IMAGE} image for Podman execution..."
            (
                cd "$PROJECT_DIR"
                "$CONTAINER_RUNTIME" build \
                    --build-arg APP_UID="${APP_UID:-1000}" \
                    --build-arg APP_GID="${APP_GID:-1000}" \
                    -f docker/Dockerfile.ingest \
                    -t "$INGEST_STATIC_IMAGE" .
            )
        fi
    else
        (
            cd "$PROJECT_DIR"
            "${COMPOSE_CMD_ARR[@]}" -f "$COMPOSE_FILE" build gtfs-ingest-static >/dev/null
        )
    fi
}

remove_via_container() {
    log "Attempting container-based cleanup for remaining snapshots..."
    if [ "$CONTAINER_RUNTIME" = "podman" ] && [ "$PREFER_PODMAN_RUN" = "1" ]; then
        if ! "$CONTAINER_RUNTIME" run --rm "${PODMAN_RUN_FLAGS[@]}" \
            --user 0:0 \
            -v "${PROJECT_DIR}/data:/app/data${PODMAN_VOLUME_SUFFIX}" \
            "$INGEST_STATIC_IMAGE" \
            sh -c "set -e; rm -f ${CONTAINER_DATA_DIR}/gtfs_static_*.json"; then
            log "WARNING: Podman-based cleanup failed. Manual removal may be required."
        fi
    else
        if ! (
            cd "$PROJECT_DIR"
            "${COMPOSE_CMD_ARR[@]}" -f "$COMPOSE_FILE" run --rm --user 0:0 \
                --entrypoint sh gtfs-ingest-static -c "set -e; rm -f ${CONTAINER_DATA_DIR}/gtfs_static_*.json"
        ); then
            log "WARNING: Container-based cleanup failed. Manual removal may be required."
        fi
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
    if [ "$CONTAINER_RUNTIME" = "podman" ] && [ "$PREFER_PODMAN_RUN" = "1" ]; then
        mkdir -p "$PROJECT_DIR/data" "$PROJECT_DIR/logs" "$PROJECT_DIR/configs"
        "$CONTAINER_RUNTIME" run --rm "${PODMAN_RUN_FLAGS[@]}" \
            -v "${PROJECT_DIR}/data:/app/data${PODMAN_VOLUME_SUFFIX}" \
            -v "${PROJECT_DIR}/logs:/app/logs${PODMAN_VOLUME_SUFFIX}" \
            -v "${PROJECT_DIR}/configs:/app/configs${PODMAN_VOLUME_SUFFIX}" \
            "$INGEST_STATIC_IMAGE" --feed-type gtfs_static --once
    else
        (
            cd "$PROJECT_DIR"
            "${COMPOSE_CMD_ARR[@]}" -f "$COMPOSE_FILE" run --rm gtfs-ingest-static
        )
    fi
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
ensure_image_available
mkdir -p "$DATA_DIR"
cleanup_snapshots
mapfile -t BEFORE_SNAPSHOTS < <(snapshot_list)
ingest_static
verify_result

#!/bin/bash
# Google Drive auto backup script
# Automatically upload GTFS data to Google Drive

set -e

# Configuration
DATA_DIR="/app/data"
LOG_DIR="/app/logs"
BACKUP_INTERVAL=${BACKUP_INTERVAL:-300}  # Default 5-minute interval
GOOGLE_DRIVE_ENABLED=${GOOGLE_DRIVE_ENABLED:-true}

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/backup.log"
}

# Google Drive authentication check
check_google_drive_auth() {
    if [ "$GOOGLE_DRIVE_ENABLED" = "true" ]; then
        if [ ! -f "/app/configs/google_drive/credentials.json" ]; then
            log "WARNING: Google Drive credentials not found. Backup disabled."
            return 1
        fi
        if [ ! -f "/app/configs/google_drive/token.json" ]; then
            log "WARNING: Google Drive token not found. Backup disabled."
            return 1
        fi
        return 0
    else
        log "INFO: Google Drive backup disabled by environment variable."
        return 1
    fi
}

# Data backup
backup_data() {
    local backup_type="$1"
    local source_path="$2"
    local backup_name="$3"
    
    if [ ! -f "$source_path" ]; then
        log "WARNING: Source file not found: $source_path"
        return 1
    fi
    
    log "Starting backup: $backup_name"
    
    # Upload to Google Drive using Python script
    python3 -c "
import sys
sys.path.append('/app/src')
from gtfs_pipeline.google_drive import GoogleDriveManager
import os

try:
    manager = GoogleDriveManager('/app/configs/google_drive')
    success = manager.upload_file('$source_path', '$backup_name')
    if success:
        print('SUCCESS: Backup completed - $backup_name')
    else:
        print('ERROR: Backup failed - $backup_name')
        sys.exit(1)
except Exception as e:
    print(f'ERROR: Backup failed - $backup_name: {e}')
    sys.exit(1)
"
    
    if [ $? -eq 0 ]; then
        log "SUCCESS: Backup completed - $backup_name"
        return 0
    else
        log "ERROR: Backup failed - $backup_name"
        return 1
    fi
}

# Main processing
main() {
    log "Starting Google Drive backup service"
    
    # Google Drive authentication check
    if ! check_google_drive_auth; then
        log "Google Drive backup not available. Exiting."
        exit 0
    fi
    
    log "Google Drive backup enabled. Starting backup loop..."
    
    while true; do
        # Monitor data directory
        if [ -d "$DATA_DIR" ]; then
            # Backup latest files
            find "$DATA_DIR" -type f -name "*.json" -o -name "*.zip" -o -name "*.parquet" | while read -r file; do
                # Check file modification time (only files updated within 5 minutes)
                if [ $(find "$file" -mmin -5 | wc -l) -gt 0 ]; then
                    filename=$(basename "$file")
                    timestamp=$(date '+%Y%m%d_%H%M%S')
                    backup_name="${timestamp}_${filename}"
                    
                    backup_data "file" "$file" "$backup_name"
                fi
            done
        fi
        
        # Log file backup (once per hour)
        if [ -d "$LOG_DIR" ] && [ $(date '+%M') = "00" ]; then
            find "$LOG_DIR" -name "*.log" -mmin -60 | while read -r logfile; do
                filename=$(basename "$logfile")
                timestamp=$(date '+%Y%m%d_%H%M%S')
                backup_name="logs_${timestamp}_${filename}"
                
                backup_data "log" "$logfile" "$backup_name"
            done
        fi
        
        # Wait
        log "Waiting ${BACKUP_INTERVAL} seconds until next backup cycle..."
        sleep "$BACKUP_INTERVAL"
    done
}

# Signal handling
trap 'log "Backup service stopped"; exit 0' SIGTERM SIGINT

# Main execution
main "$@"

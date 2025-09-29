#!/bin/bash
# Google Drive auto backup script
# Automatically upload GTFS data to Google Drive
# NOTE: Do not use chmod 777 or 666.
# Use proper ownership (chown) and safe permissions instead (chmod 755).

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

# Google Drive authentication check (rclone)
check_google_drive_auth() {
    if [ "$GOOGLE_DRIVE_ENABLED" != "true" ]; then
        log "INFO: Google Drive backup disabled by environment variable."
        return 1
    fi
    
    # Check if rclone is available
    if ! command -v rclone >/dev/null 2>&1; then
        log "ERROR: rclone not found. Please install rclone."
        return 1
    fi
    
    # Try multiple config locations for security
    local config_locations=(
        "/home/appuser/.config/rclone/rclone.conf"
        "/root/.config/rclone/rclone.conf"
        "$HOME/.config/rclone/rclone.conf"
    )
    
    local config_found=false
    local config_path=""
    
    for config_path in "${config_locations[@]}"; do
        if [ -f "$config_path" ]; then
            log "INFO: Found rclone config at: $config_path"
            config_found=true
            break
        fi
    done
    
    if [ "$config_found" != "true" ]; then
        log "ERROR: rclone config file not found in any expected location"
        log "Expected locations: ${config_locations[*]}"
        return 1
    fi
    
    # Test authentication
    if rclone lsd gdrive: >/dev/null 2>&1; then
        log "INFO: rclone Google Drive authentication successful"
        return 0
    else
        log "ERROR: rclone Google Drive authentication failed"
        log "Please check your rclone configuration and credentials"
        return 1
    fi
}

# Data backup
backup_data() {
    local backup_type="$1"
    local source_path="$2"
    local backup_name="$3"
    
    # Validate input parameters
    if [ -z "$source_path" ] || [ -z "$backup_name" ]; then
        log "ERROR: Invalid parameters for backup_data function"
        return 1
    fi
    
    # Check if source file exists and is readable
    if [ ! -f "$source_path" ]; then
        log "ERROR: Source file not found: $source_path"
        return 1
    fi
    
    if [ ! -r "$source_path" ]; then
        log "ERROR: Source file not readable: $source_path"
        return 1
    fi
    
    # Check file size (avoid backing up empty files)
    local file_size=$(stat -f%z "$source_path" 2>/dev/null || stat -c%s "$source_path" 2>/dev/null || echo "0")
    if [ "$file_size" -eq 0 ]; then
        log "WARNING: Skipping empty file: $source_path"
        return 1
    fi
    
    log "Starting backup: $backup_name (size: ${file_size} bytes)"
    
    # Upload to Google Drive using rclone (maintain host directory structure)
    # Extract relative path from source_path to maintain directory structure
    local relative_path=$(echo "$source_path" | sed "s|$DATA_DIR/||")
    local backup_dir="gdrive:gtfs-backup/$(dirname "$relative_path")"
    
    # Create directory structure if it doesn't exist
    if ! rclone mkdir "$backup_dir" 2>/dev/null; then
        log "WARNING: Failed to create backup directory: $backup_dir"
    fi
    
    # Upload file maintaining directory structure
    if rclone copy "$source_path" "$backup_dir/" --progress --retries 3 >/dev/null 2>&1; then
        log "SUCCESS: Backup completed - $backup_name (to $backup_dir/)"
        return 0
    else
        log "ERROR: Backup failed - $backup_name"
        log "Please check rclone configuration and network connectivity"
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
    
    # Check if this is a single execution
    if [ "$1" = "--once" ]; then
        log "Single backup execution mode"
        execute_backup_cycle
        log "Backup completed. Exiting."
        exit 0
    fi
    
    log "Google Drive backup enabled. Starting backup loop..."
    
    while true; do
        execute_backup_cycle
        
        # Wait
        log "Waiting ${BACKUP_INTERVAL} seconds until next backup cycle..."
        sleep "$BACKUP_INTERVAL"
    done
}

# Execute a single backup cycle
execute_backup_cycle() {
        # Monitor data directory
        if [ -d "$DATA_DIR" ]; then
            # Backup latest files (including GTFS-RT data and Protocol Buffers)
            log "Scanning for files to backup in: $DATA_DIR"
            # Get the latest files (most recent 10 files) for backup
            find "$DATA_DIR" -type f \( -name "*.json" -o -name "*.zip" -o -name "*.parquet" -o -name "*.pb" \) -printf '%T@ %p\n' | sort -nr | head -10 | cut -d' ' -f2- | while read -r file; do
            # Check if file exists and is not empty
            if [ -f "$file" ] && [ -s "$file" ]; then
                # Extract file type and extension from original filename
                original_filename=$(basename "$file")
                file_extension="${original_filename##*.}"
                
                # Determine file type from filename
                if [[ "$original_filename" == *"gtfs_static"* ]]; then
                    file_type="gtfs_static"
                elif [[ "$original_filename" == *"trip_updates"* ]]; then
                    file_type="gtfs_rt_trip_updates"
                elif [[ "$original_filename" == *"vehicle_positions"* ]]; then
                    file_type="gtfs_rt_vehicle_positions"
                else
                    file_type="gtfs_data"
                fi
                
                # Generate JST timestamp for backup filename
                jst_timestamp=$(TZ='Asia/Tokyo' date '+%Y%m%d_%H%M%S')
                backup_name="${file_type}_${jst_timestamp}.${file_extension}"
                
                log "Found file to backup: $file (latest file)"
                log "Backup filename: $backup_name"
                backup_data "file" "$file" "$backup_name"
            else
                log "Skipping file (empty or not found): $file"
            fi
        done
    fi
    
    # Log file backup (once per hour)
    if [ -d "$LOG_DIR" ] && [ $(date '+%M') = "00" ]; then
        find "$LOG_DIR" -name "*.log" -mmin -60 | while read -r logfile; do
            # Extract log file type from filename
            original_filename=$(basename "$logfile")
            file_extension="${original_filename##*.}"
            
            # Generate JST timestamp for log backup filename
            jst_timestamp=$(TZ='Asia/Tokyo' date '+%Y%m%d_%H%M%S')
            backup_name="logs_${jst_timestamp}.${file_extension}"
            
            log "Backing up log file: $logfile"
            log "Log backup filename: $backup_name"
            backup_data "log" "$logfile" "$backup_name"
        done
    fi
}

# Signal handling
trap 'log "Backup service stopped"; exit 0' SIGTERM SIGINT

# Main execution
main "$@"

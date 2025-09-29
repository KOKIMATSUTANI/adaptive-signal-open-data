#!/bin/bash
# Google Drive自動バックアップスクリプト
# GTFSデータをGoogle Driveに自動アップロード

set -e

# 設定
DATA_DIR="/app/data"
LOG_DIR="/app/logs"
BACKUP_INTERVAL=${BACKUP_INTERVAL:-300}  # デフォルト5分間隔
GOOGLE_DRIVE_ENABLED=${GOOGLE_DRIVE_ENABLED:-true}

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/backup.log"
}

# Google Drive認証チェック
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

# データバックアップ
backup_data() {
    local backup_type="$1"
    local source_path="$2"
    local backup_name="$3"
    
    if [ ! -f "$source_path" ]; then
        log "WARNING: Source file not found: $source_path"
        return 1
    fi
    
    log "Starting backup: $backup_name"
    
    # PythonスクリプトでGoogle Driveにアップロード
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

# メイン処理
main() {
    log "Starting Google Drive backup service"
    
    # Google Drive認証チェック
    if ! check_google_drive_auth; then
        log "Google Drive backup not available. Exiting."
        exit 0
    fi
    
    log "Google Drive backup enabled. Starting backup loop..."
    
    while true; do
        # データディレクトリの監視
        if [ -d "$DATA_DIR" ]; then
            # 最新のファイルをバックアップ
            find "$DATA_DIR" -type f -name "*.json" -o -name "*.zip" -o -name "*.parquet" | while read -r file; do
                # ファイルの更新時間をチェック（5分以内に更新されたファイルのみ）
                if [ $(find "$file" -mmin -5 | wc -l) -gt 0 ]; then
                    filename=$(basename "$file")
                    timestamp=$(date '+%Y%m%d_%H%M%S')
                    backup_name="${timestamp}_${filename}"
                    
                    backup_data "file" "$file" "$backup_name"
                fi
            done
        fi
        
        # ログファイルのバックアップ（1時間に1回）
        if [ -d "$LOG_DIR" ] && [ $(date '+%M') = "00" ]; then
            find "$LOG_DIR" -name "*.log" -mmin -60 | while read -r logfile; do
                filename=$(basename "$logfile")
                timestamp=$(date '+%Y%m%d_%H%M%S')
                backup_name="logs_${timestamp}_${filename}"
                
                backup_data "log" "$logfile" "$backup_name"
            done
        fi
        
        # 待機
        log "Waiting ${BACKUP_INTERVAL} seconds until next backup cycle..."
        sleep "$BACKUP_INTERVAL"
    done
}

# シグナルハンドリング
trap 'log "Backup service stopped"; exit 0' SIGTERM SIGINT

# メイン実行
main "$@"

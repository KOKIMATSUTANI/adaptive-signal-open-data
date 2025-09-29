# Google Drive Integration

## Overview

This feature automatically backs up GTFS data to Google Drive. You can use either rclone or Google Drive API.

## Authentication Method Selection

| Method | Benefits | Use Case | Setup Difficulty | Maintenance |
|--------|----------|----------|------------------|-------------|
| **rclone** | High functionality, stability, large data transfer | **Production use** | ⭐⭐ Easy | ⭐⭐ Low |
| **Google Drive API** | Fine control, custom functionality | **Development & testing** | ⭐⭐⭐ Complex | ⭐⭐⭐ High |

**Recommendation**: Use rclone for production environments. Use Google Drive API only for development, testing, or when you need custom functionality not available in rclone.

## Setup

### Method 1: rclone (Recommended)

#### 1. Installation
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install rclone

# macOS
brew install rclone

# Windows
# Download from https://rclone.org/downloads/
```

#### 2. Authentication Setup
```bash
rclone config
# n) New remote
# name> gdrive
# Storage> drive
# (Press Enter for other defaults)
# Use auto config?> Y
```

#### 3. Place Configuration File
```bash
cp ~/.config/rclone/rclone.conf ./configs/rclone/
```

#### 4. Test Operation
```bash
rclone lsd gdrive:
```

### Method 2: Google Drive API

#### 1. Google Cloud Console Setup
1. Create project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Google Drive API
3. Create credentials (OAuth 2.0)
4. Download credentials

#### 2. Place Configuration File
```bash
# Place downloaded credentials
cp ~/Downloads/credentials.json ./configs/google_drive/
```

#### 3. Initial Authentication
```bash
# Generate authentication token
python -c "
from src.gtfs_pipeline.google_drive import GoogleDriveManager
manager = GoogleDriveManager('./configs/google_drive')
"
```

## Usage

### Using rclone
```bash
# Run with auto backup
make run-ingest-rclone

# Or directly with Docker
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/configs/rclone:/root/.config/rclone \
  -e RCLONE_ENABLED=true \
  tram-ingest:latest
```

### Using Google Drive API
```bash
# Run with auto backup
make run-ingest

# Or directly with Docker
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/configs/google_drive:/app/configs/google_drive \
  -e GOOGLE_DRIVE_ENABLED=true \
  tram-ingest:latest
```

### Without Backup
```bash
# Disable backup functionality
make run-ingest-no-backup
```

## Configuration

### Environment Variables

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `RCLONE_ENABLED` | `false` | Enable/disable rclone auto backup |
| `GOOGLE_DRIVE_ENABLED` | `false` | Enable/disable Google Drive API auto backup |
| `BACKUP_INTERVAL` | `300` | Backup interval (seconds) |

### Files to be Backed Up

- **Data files**: `*.json`, `*.zip`, `*.parquet`
- **Log files**: `*.log`
- **File naming**: `{timestamp}_{original_filename}`

## Troubleshooting

### Authentication Error
```
ERROR: failed to get drive: oauth2: cannot fetch token
```
**Solution**: Check if configuration files are properly placed

### Permission Error
```
ERROR: permission denied
```
**Solution**: Check Google Drive API permission settings

### Network Error
```
ERROR: connection timeout
```
**Solution**: Check network connection

## Logs

Backup process logs are output to `logs/backup.log`.

## Security

- Manage authentication files appropriately
- Set only minimum necessary permissions
- Take backups of configuration files

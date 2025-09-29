# rclone Configuration Directory

This directory contains rclone configuration files.

## Configuration Files

```
configs/rclone/
├── rclone.conf    # rclone configuration file (manually placed)
└── README.md      # This file
```

## Setup Instructions

### 1. Install rclone
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install rclone

# macOS
brew install rclone

# Windows
# Download from https://rclone.org/downloads/
```

### 2. Google Drive Authentication Setup
```bash
# Start rclone configuration
rclone config

# Create new remote
n) New remote
name> gdrive
Storage> drive
client_id> (press Enter for default)
client_secret> (press Enter for default)
scope> drive
root_folder_id> (press Enter)
service_account_file> (press Enter)
Use auto config?> Y
```

### 3. Place Configuration File
```bash
# Copy configuration file to this directory
cp ~/.config/rclone/rclone.conf ./configs/rclone/
```

### 4. Verify Configuration
```bash
# Check configuration
rclone listremotes

# Test Google Drive connection
rclone lsd gdrive:
```

## Usage with Docker

### Basic Usage
```bash
# Run with rclone configuration mounted
docker run --rm \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/configs/rclone:/root/.config/rclone \
  -e RCLONE_ENABLED=true \
  tram-ingest:latest
```

### Using Makefile
```bash
# Run with rclone auto backup
make run-ingest-rclone
```

## Troubleshooting

### 1. Authentication Error
```
ERROR: failed to get drive: failed to get drive: oauth2: cannot fetch token
```

**Solution**: Verify that the configuration file is properly placed.

### 2. Permission Error
```
ERROR: failed to get drive: failed to get drive: permission denied
```

**Solution**: Check Google Drive API permission settings.

### 3. Network Error
```
ERROR: failed to get drive: failed to get drive: connection timeout
```

**Solution**: Check network connection.

## Security

- **Configuration File**: Contains authentication information, manage appropriately
- **Permissions**: Set only minimum required permissions
- **Backup**: Take backup of configuration files

## References

- [rclone Official Documentation](https://rclone.org/)
- [Google Drive Setup Guide](https://rclone.org/drive/)
- [Authentication Setup](https://rclone.org/docs/#authentication)
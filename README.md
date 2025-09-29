# Tram Delay Reduction Management

A GTFS data collection, analysis, and optimization system designed to reduce tram delays.

## Overview

- **GTFS Data Collection**: Real-time data acquisition at 20-second intervals
- **Auto Backup**: Automatic upload to Google Drive
- **Simulation**: Traffic simulation using SUMO/Flow
- **Optimization**: Delay reduction through reinforcement learning and mathematical optimization

## Quick Start

### 1. Install Dependencies
```bash
# Docker & Docker Compose
sudo apt update
sudo apt install docker.io docker-compose

# rclone (for Google Drive integration)
sudo apt install rclone
```

### 2. Google Drive Setup (Optional)
```bash
# rclone configuration
rclone config
cp ~/.config/rclone/rclone.conf ./configs/rclone/
```

### 3. Run
```bash
# Start GTFS data collection
make run-ingest-rclone

# Or start all services
make compose-up
```

## Directory Structure

```
tram-delay-reduction-management/
├── docs/                    # Documentation
│   ├── GOOGLE_DRIVE.md     # Google Drive integration overview
│   ├── GOOGLE_DRIVE_API.md # Google Drive API setup
│   ├── RCLONE_SETUP.md     # rclone configuration
│   └── REQUIREMENTS.md     # Dependencies management
├── docker/                  # Docker configuration
│   ├── docker-compose.yml  # Service definitions
│   ├── Dockerfile.base     # Base image
│   ├── Dockerfile.ingest   # Data collection
│   ├── Dockerfile.sim      # Simulation
│   └── Dockerfile.train    # Training
├── requirements/            # Python dependencies
│   ├── base.txt            # Common dependencies
│   ├── ingest.txt          # Data collection
│   ├── sim.txt             # Simulation
│   └── train.txt           # Training
├── src/                    # Source code
│   ├── gtfs_pipeline/      # GTFS data processing
│   ├── simulation/         # Simulation
│   └── training/           # Training
├── configs/                # Configuration files
│   ├── rclone/             # rclone configuration (recommended)
│   └── google_drive/       # Google Drive API configuration (alternative)
├── scripts/                # Scripts
│   └── backup_to_google_drive.sh
├── data/                   # Data storage
├── logs/                   # Log files
└── Makefile               # Build and execution commands
```

## Key Features

### GTFS Data Collection
- **Interval**: 20 seconds
- **Data**: GTFS Static, Trip Updates, Vehicle Positions
- **Storage**: Local + Google Drive auto backup

### Simulation
- **Engine**: SUMO/Flow
- **Purpose**: Traffic flow simulation
- **Output**: Delay analysis results

### Optimization
- **Methods**: Reinforcement learning (Q-DDQN), mathematical optimization
- **Goal**: Delay reduction
- **Output**: Optimized operation plans

## Usage

### Data Collection
```bash
# Using rclone (recommended)
make run-ingest-rclone

# Using Google Drive API
make run-ingest

# Without backup
make run-ingest-no-backup
```

### Simulation
```bash
make run-sim
```

### Training
```bash
make run-train
```

### All Services
```bash
make compose-up
```

## Configuration

### Environment Variables
- `RCLONE_ENABLED`: rclone auto backup (recommended)
- `GOOGLE_DRIVE_ENABLED`: Google Drive API auto backup (alternative)
- `BACKUP_INTERVAL`: Backup interval (seconds)

### Configuration Files
- `configs/rclone/rclone.conf`: rclone configuration (recommended)
- `configs/google_drive/`: Google Drive API configuration (alternative)

### Documentation
- `docs/RCLONE_SETUP.md`: Complete rclone setup guide
- `docs/GOOGLE_DRIVE_API.md`: Google Drive API setup guide
- `docs/REQUIREMENTS.md`: Dependencies management guide

## Troubleshooting

### Build Errors
```bash
make clean
make build-all
```

### Authentication Errors
- Check rclone configuration: `rclone lsd gdrive:`
- Check Google Drive API configuration: `docs/GOOGLE_DRIVE.md`

### Log Checking
```bash
# Application logs
tail -f logs/ingest.log

# Backup logs
tail -f logs/backup.log
```

## Development

### Adding Dependencies
```bash
# Common for all jobs
echo "package>=1.0.0" >> requirements/base.txt

# Specific job only
echo "package>=1.0.0" >> requirements/ingest.txt
```

### Building
```bash
# Individual builds
make build-ingest
make build-sim
make build-train

# Build all
make build-all
```

## License

MIT License

## Contributing

Pull requests and issue reports are welcome.

## References

- [GTFS Specification](https://developers.google.com/transit/gtfs)
- [SUMO Official Documentation](https://sumo.dlr.de/docs/)
- [rclone Official Documentation](https://rclone.org/)
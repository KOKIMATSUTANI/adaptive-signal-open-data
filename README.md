# Tram Delay Reduction Management

A GTFS data collection, analysis, and optimization system designed to reduce tram delays.

## Overview

- **GTFS Data Collection**: Real-time data acquisition at 20-second intervals
- **Auto Backup**: Automatic upload to Google Drive
- **Simulation**: Traffic simulation using SUMO/FLOW
- **Optimization**: Delay reduction through reinforcement learning and mathematical optimization

## Quick Start

### 1. Install Dependencies
```bash
# Docker & Docker Compose
sudo apt update
sudo apt install docker.io docker compose

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
adptive-signal-open-data/
├── configs/                # Credentials & sync configuration templates
│   ├── google_drive/       # Google Drive API OAuth/credential files
│   └── rclone/             # rclone remote definitions and tokens
├── data/                   # Local storage layers for collected feeds
│   ├── bronze/
│   ├── raw_GCP/
│   ├── raw_test/
│   └── silver/
├── docker/                 # Container definitions and compose manifests
├── docs/                   # Project documentation (setup guides, notes)
├── logs/                   # Runtime and ingestion logs
├── requirements/           # Python dependency lockfiles per component
├── results/                # Analysis outputs, evaluation artefacts
├── reveal-slides/          # Presentation material (assets, slide decks)
├── scripts/                # Operational utilities (e.g. cloud backups)
├── src/                    # Application source code
│   ├── gtfs_pipeline/      # GTFS ingestion CLI, config, persistence glue
│   ├── sim_bridge/         # Interfaces bridging to SUMO/FLOW simulations
│   └── training/           # RL/optimisation experiments and notebooks
├── Makefile                # Top-level automation and shortcuts
├── README.md
└── http-server.log         # Local dev HTTP server output (optional)
```

<small>補足: `.github/`（CI 設定）や `venv/`（ローカル仮想環境）などの補助ディレクトリは状況に応じて生成されます。</small>

## Key Features

### GTFS Data Collection
- **Interval**: 20 seconds
- **Data**: GTFS Static, Trip Updates, Vehicle Positions
- **Storage**: Local + Google Drive auto backup

### Simulation
- **Engine**: SUMO/FLOW
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
- `GTFS_RT_SAVE_PROTO`: Set to `1` to archive raw GTFS-RT protobuf (`.pb`) alongside parsed JSON
- `GTFS_STATIC_SAVE_ZIP`: Set to `1` to archive raw GTFS Static ZIP payloads alongside parsed JSON

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

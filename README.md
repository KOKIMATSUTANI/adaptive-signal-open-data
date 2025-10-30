# Tram Delay Reduction Management

A GTFS data collection, analysis, and optimization system designed to reduce tram delays.

## Overview

- **GTFS Data Collection**: Real-time data acquisition at 20-second intervals
- **Simulation**: Traffic simulation using SUMO/FLOW
- **Optimization**: Delay reduction through reinforcement learning and mathematical optimization

## Quick Start

### 1. Install Dependencies
```bash
# Docker & Docker Compose
sudo apt update
sudo apt install docker.io docker compose

```

### 2. Run
```bash
# Fetch GTFS static feed once (cleans old snapshots first)
make run-ingest-static

# Fetch GTFS real-time feeds once (Docker container)
make run-ingest-realtime

# Use docker compose helpers (single-run containers)
make compose-ingest-realtime
```

### 3. Cross-Platform Notes
- The Makefile is the canonical entry point for builds and one-off tasks.  
- macOS/Linux include `make` by default. On Windows, install a POSIX shell with `make` support (e.g. WSL, Git Bash, MSYS2) before running the commands above.  
- If you need to invoke the underlying shell scripts directly, see `scripts/`, but `make` keeps workflows consistent across laptops, servers, and CI/cloud runners.

## Directory Structure

```
adptive-signal-open-data/
├── configs/                # Configuration templates (ingestion, simulation)
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
├── scripts/                # Operational utilities (schedulers, helpers)
├── src/                    # Application source code
│   ├── gtfs_pipeline/      # GTFS ingestion CLI, config, persistence glue
│   ├── sim_bridge/         # Interfaces bridging to SUMO/FLOW simulations
│   └── training/           # RL/optimisation experiments and notebooks
├── Makefile                # Top-level automation and shortcuts
├── README.md
└── http-server.log         # Local dev HTTP server output (optional)
```

<small>Note: Auxiliary directories such as `.github/` (CI configuration) and `venv/` (local virtual environment) are created only when needed.</small>

## Key Features

### GTFS Data Collection
- **Interval**: 20 seconds (real-time feeds)
- **Data**: GTFS Static (manual trigger), Trip Updates, Vehicle Positions
- **Storage**: Local filesystem

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
# GTFS real-time feeds (one-off)
make run-ingest-realtime

# GTFS real-time feeds with raw protobuf/ZIP archives
make run-ingest-realtime-raw

# Compose helpers (one-off containers)
make compose-ingest-realtime

# GTFS static feed (one-off, manual)
docker compose -f docker/docker-compose.yml run --rm gtfs-ingest-static
```

### Simulation
```bash
make run-sim
```

### Training
```bash
make run-train
```

## Configuration

### Environment Variables
- `GTFS_RT_SAVE_PROTO`: Set to `1` to archive raw GTFS-RT protobuf (`.pb`) alongside parsed JSON
- `GTFS_STATIC_SAVE_ZIP`: Set to `1` to archive raw GTFS Static ZIP payloads alongside parsed JSON

### Documentation
- `docs/REQUIREMENTS.md`: Dependencies management guide

## Troubleshooting

### Build Errors
```bash
make clean
make build-all
```

### Log Checking
```bash
# Application logs
tail -f logs/ingest.log
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

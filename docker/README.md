# Docker Configuration - Tram Delay Reduction Management System

This directory contains Docker configuration files for the Tram Delay Reduction Management system.

## Architecture Overview

This project uses **separated Docker images** to optimize dependencies for each job and reduce build time.

| File                  | Role (What is this container for?)                                           | Goal / Benefits from this separation                                                                  |
| --------------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **Dockerfile.base**   | Common foundation (Python, pip/poetry, pandas/pyarrow and other dependencies shared across all jobs) | Install heavy dependencies **once** and cache them → subsequent derived images build **efficiently**. **Centralize** environment for improved reproducibility.                    |
| **Dockerfile.ingest** | GTFS/GTFS-RT collection + Parquet conversion dedicated                          | Minimize execution permissions and dependencies (secure & lightweight). Jobs are short-lived and easy to run periodically. Designed with data **volumes** in mind.                    |
| **Dockerfile.sim**    | SUMO / FLOW simulation dedicated                               | **Isolate** SIM-related additional dependencies (SUMO, FLOW, OS packages). Prevent heavy/specialized dependencies from affecting other jobs.                        |
| **Dockerfile.train**  | RL / MIP training dedicated                                         | Future **GPU support (CUDA-based replacement)** can be completed in this layer only. **Separate** training libraries (torch, etc.) from others to optimize size and security. |

## Quick Start

### 1. Build All Images
```bash
make build-all
```

### 2. Run Real-time Collection
```bash
make run-ingest-realtime
```

### 3. Run Simulation
```bash
make run-sim
```

### 4. Run Training
```bash
make run-train
```

## File Structure

```
docker/
├── docker-compose.yml    # Orchestration for all services
├── Dockerfile.base       # Base image (common dependencies)
├── Dockerfile.ingest     # Image for GTFS static data collection
├── Dockerfile.sim        # Image for simulation
├── Dockerfile.train      # Image for training
└── README.md            # This file
```

## Usage

### 1. Start All Services
```bash
# Run from project root
make compose-up

# Or use docker compose command directly
docker compose -f docker/docker-compose.yml up --build
```

### 2. Start Individual Services
```bash
# Simulation only
make compose-sim

# Training only
make compose-train
```

### 3. Build Individual Images
```bash
# Base image
make build-base

# Simulation image
make build-sim

# Training image
make build-train
```

## Service Details

### gtfs-ingest-static
- **Purpose**: One-off GTFS static data downloads
- **Execution**: Manual trigger (`docker compose run --rm gtfs-ingest-static`)
- **Restart**: None

### gtfs-ingest-realtime
- **Purpose**: GTFS-RT (trip updates & vehicle positions) collection
- **Execution Interval**: 20 seconds (when scheduled externally)
- **Restart**: None (run-once container)

### simulation
- **Purpose**: SUMO/FLOW simulation execution
- **Execution**: Manual execution
- **Restart**: None

### training
- **Purpose**: Reinforcement learning and optimization execution
- **Execution**: Manual execution
- **Restart**: None

## Volume Mounts

### Data Directories
- `../data` → `/app/data` - GTFS data storage
- `../logs` → `/app/logs` - Log files
- `../results` → `/app/results` - Execution results
- `../models` → `/app/models` - Trained models

## Environment Variables

### Common
- `PYTHONPATH=/app/src` - Python path configuration

### simulation
- `SUMO_HOME=/opt/sumo` - SUMO installation path

## Troubleshooting

### 1. Build Errors
```bash
# Clear cache and rebuild
make clean
make build-all
```

### 2. Volume Mount Errors
```bash
# Check directory existence
ls -la ../data ../logs ../results ../models
```

### 3. Permission Errors
```bash
# Check directory permissions
ls -la ../data ../logs
```

## Development Notes

1. **Dockerfile Changes**: Image rebuild required
2. **docker-compose.yml Changes**: Service restart required
3. **Volume Mounts**: Use relative paths (`../`)
4. **Environment Variables**: Set appropriate values for each service

## Performance Optimization

### Multi-stage Build
- Install heavy dependencies once in base image
- Add only lightweight dependencies in derived images

### Layer Caching
- Place low-change-frequency layers first
- Separate dependency installation

### Image Size Optimization
- Remove unnecessary files
- Utilize multi-stage builds

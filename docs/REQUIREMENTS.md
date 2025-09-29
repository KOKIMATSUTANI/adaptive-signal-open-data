# Requirements Management

This directory contains Python dependency files for the Tram Delay Reduction Management system.

## File Structure

```
requirements/
├── base.txt      # Common dependencies for all jobs (install heavy dependencies once here)
├── ingest.txt    # Lightweight dependencies for GTFS data collection only
├── sim.txt       # Dependencies for simulation only
├── train.txt     # Dependencies for training only (GPU support possible)
└── README.md     # This file
```

## Dependency Strategy

### Multi-stage Build Utilization

1. **base.txt** - Heavy dependencies common to all jobs
   - pandas, numpy, pyarrow (data processing)
   - aiohttp, asyncpg, sqlalchemy (communication & DB)
   - google-auth, google-api-python-client (Google Drive integration)

2. **ingest.txt** - Lightweight dependencies for data collection only
   - zipfile36, python-dateutil (data processing)
   - structlog (logging)

3. **sim.txt** - Dependencies for simulation only
   - SUMO/FLOW related libraries
   - Visualization libraries

4. **train.txt** - Dependencies for training only
   - torch, torchvision, torchaudio (deep learning)
   - stable-baselines3, gym (reinforcement learning)
   - cvxpy, ortools (optimization)

## Build Efficiency

### Traditional Method (Inefficient)
```dockerfile
# Install all dependencies every time
COPY requirements.txt .
RUN pip install -r requirements.txt  # 5 minutes every time
```

### This Project's Method (Efficient)
```dockerfile
# Base image (install heavy dependencies once)
FROM python:3.12-slim
COPY requirements/base.txt .
RUN pip install -r requirements/base.txt  # 5 minutes once

# Derived image (lightweight dependencies only)
FROM tram-base:latest
COPY requirements/ingest.txt .
RUN pip install -r requirements/ingest.txt  # 30 seconds every time
```

## Effects

### Build Time Reduction
- **Traditional**: 5 min × 4 jobs = 20 min
- **Current**: 5 min (base) + 30 sec (ingest) + 1 min (sim) + 2 min (train) = 8.5 min
- **Reduction**: 57% shorter

### Image Size Optimization
- **base**: 2GB (common dependencies)
- **ingest**: 2.1GB (+100MB)
- **sim**: 2.5GB (+500MB)
- **train**: 3GB (+1GB)

## Usage

### Adding Dependencies During Development

#### 1. Dependencies Common to All Jobs
```bash
# Add to requirements/base.txt
echo "new-package>=1.0.0" >> requirements/base.txt
```

#### 2. Job-specific Dependencies
```bash
# GTFS data collection only
echo "new-package>=1.0.0" >> requirements/ingest.txt

# Simulation only
echo "new-package>=1.0.0" >> requirements/sim.txt

# Training only
echo "new-package>=1.0.0" >> requirements/train.txt
```

### Updating Dependencies

#### 1. Version Updates
```bash
# Update specific package version
sed -i 's/pandas>=1.5.0/pandas>=2.0.0/' requirements/base.txt
```

#### 2. Package Removal
```bash
# Remove unused packages
sed -i '/unused-package/d' requirements/base.txt
```

## Troubleshooting

### 1. Dependency Conflicts
```bash
# Check dependencies
pip check

# Resolve conflicts
pip install --upgrade package-name
```

### 2. Build Errors
```bash
# Clear cache and rebuild
make clean
make build-all
```

### 3. Package Compatibility
```bash
# Check compatibility
pip install -r requirements/base.txt --dry-run
```

## Best Practices

### 1. Dependency Separation
- Common to all jobs → `base.txt`
- Job-specific → Each job's requirements.txt

### 2. Version Pinning
- Pin versions in production environment
- Use range specification in development environment

### 3. Security
- Regular dependency updates
- Vulnerability checks

### 4. Performance
- Aggregate heavy dependencies in base.txt
- Distribute lightweight dependencies to each job

## Future Extensions

- [ ] Automatic dependency updates
- [ ] Automated vulnerability scanning
- [ ] Dependency visualization
- [ ] Performance monitoring